########################################
<#
.SYNOPSIS
    Publishes AzLocal.DeploymentAutomation to the PowerShell Gallery.
.DESCRIPTION
    Copies the module to a clean staging folder (C:\Temp\AzLocal.DeploymentAutomation),
    removes files that should not be included in the published package (tests,
    test results, .vscode settings, cluster-specific parameter files,
    deployment-parameter-files), validates the manifest, then publishes via
    Publish-Module.

    The NuGet API key is prompted interactively and is never stored on disk.
.NOTES
    Author  : Neil Bird, MSFT
    Version : 1.0
    Created : 2026-03-16
#>
########################################
[CmdletBinding(SupportsShouldProcess)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Paths ──────────────────────────────────────────────────────────────────────
$ModuleName  = 'AzLocal.DeploymentAutomation'
$SourceDir   = $PSScriptRoot                          # repo module folder
$StagingDir  = Join-Path 'C:\Temp' $ModuleName

# ── 1. Clean staging area ──────────────────────────────────────────────────────
Write-Host "[$ModuleName] Cleaning staging folder: $StagingDir" -ForegroundColor Cyan
if (Test-Path $StagingDir) {
    Remove-Item $StagingDir -Recurse -Force
}

# ── 2. Copy module to staging ──────────────────────────────────────────────────
Write-Host "[$ModuleName] Copying module to staging..." -ForegroundColor Cyan
Copy-Item -Path $SourceDir -Destination $StagingDir -Recurse -Force

# ── 3. Remove files/folders not needed in published package ────────────────────
Write-Host "[$ModuleName] Removing files not needed for publishing..." -ForegroundColor Cyan

$RemovePaths = @(
    # Tests and test results
    'Tests'
    # VS Code workspace settings
    '.vscode'
    # Cluster-specific parameter files (user-generated, example only)
    'cluster-specific-parameter-files'
    # Deployment parameter files output folder (empty or user-generated)
    'deployment-parameter-files'
    # This publish script itself
    'Publish-Module.ps1'
)

foreach ($relativePath in $RemovePaths) {
    $fullPath = Join-Path $StagingDir $relativePath
    if (Test-Path $fullPath) {
        Remove-Item $fullPath -Recurse -Force
        Write-Host "  Removed: $relativePath" -ForegroundColor DarkGray
    }
}

# ── 4. Show what will be published ─────────────────────────────────────────────
Write-Host ""
Write-Host "[$ModuleName] Files to be published:" -ForegroundColor Yellow
Get-ChildItem $StagingDir -Recurse -File | ForEach-Object {
    Write-Host "  $($_.FullName.Replace($StagingDir + '\', ''))" -ForegroundColor Gray
}
Write-Host ""

# ── 5. Validate manifest ──────────────────────────────────────────────────────
Write-Host "[$ModuleName] Validating module manifest..." -ForegroundColor Cyan
$manifestPath = Join-Path $StagingDir "$ModuleName.psd1"
$manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
Write-Host "  Module:  $($manifest.Name)" -ForegroundColor Green
Write-Host "  Version: $($manifest.Version)" -ForegroundColor Green

# ── 6. Prompt for API key (masked) and publish ─────────────────────────────────
Write-Host ""
Write-Host "Paste your PowerShell Gallery NuGet API key (input is masked, nothing will echo):" -ForegroundColor Yellow
$secureApiKey = Read-Host -Prompt "API key" -AsSecureString
if ($null -eq $secureApiKey -or $secureApiKey.Length -eq 0) {
    throw 'API key cannot be empty. Publish cancelled.'
}

# Convert SecureString to plaintext only at the moment of use, then scrub it.
$bstr   = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureApiKey)
$apiKey = $null
try {
    $apiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        throw 'API key cannot be empty. Publish cancelled.'
    }

    Write-Host ""
    Write-Host "[$ModuleName] Publishing v$($manifest.Version) to PSGallery..." -ForegroundColor Cyan

    if ($PSCmdlet.ShouldProcess("$ModuleName v$($manifest.Version)", 'Publish to PowerShell Gallery')) {
        Publish-Module -Path $StagingDir -Repository PSGallery -NuGetApiKey $apiKey -Verbose
        Write-Host ""
        Write-Host "[$ModuleName] Published successfully!" -ForegroundColor Green
        Write-Host "  https://www.powershellgallery.com/packages/$ModuleName/$($manifest.Version)" -ForegroundColor Gray
    }
}
finally {
    # Zero the unmanaged plaintext buffer and drop references so the key
    # is not left sitting in process memory after publish completes.
    if ($bstr -ne [IntPtr]::Zero) {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) | Out-Null
    }
    $apiKey = $null
    if ($secureApiKey) { $secureApiKey.Dispose() }
    $secureApiKey = $null
    [System.GC]::Collect()
}
