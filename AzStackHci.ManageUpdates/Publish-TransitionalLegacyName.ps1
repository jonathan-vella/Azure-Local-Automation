########################################
<#
.SYNOPSIS
    One-shot publisher for the AzStackHci.ManageUpdates v0.7.3 TRANSITIONAL STUB.

.DESCRIPTION
    Publishes the deprecation-warning-only stub to PowerShell Gallery so that
    any automation still running `Install-Module AzStackHci.ManageUpdates`
    gets a clear migration message pointing to AzLocal.UpdateManagement.

    Run this ONCE, after AzLocal.UpdateManagement v0.7.3 has been published.
    The folder AzStackHci.ManageUpdates/ (containing this stub) should be
    removed from the repository in a follow-up commit after the stub has been
    published successfully and any remaining automation has migrated.

    The stub:
      - Has the same GUID as the AzStackHci.ManageUpdates module already on
        PSGallery (required - PSGallery rejects mismatched GUIDs).
      - Exports no functions.
      - Has no NestedModules and no RequiredModules.
      - Emits Write-Warning on import telling the user to install
        AzLocal.UpdateManagement instead.

    Workflow:
      1. Publish AzLocal.UpdateManagement v0.7.3 via AzLocal.UpdateManagement/Publish-Module.ps1
      2. Run THIS script (AzStackHci.ManageUpdates/Publish-TransitionalLegacyName.ps1)
      3. (Optional but recommended) After a few weeks, log in to PSGallery and
         unlist v0.7.3 of AzStackHci.ManageUpdates too.
      4. Open a follow-up PR that deletes AzStackHci.ManageUpdates/ from the repo.

    The NuGet API key is prompted interactively and is never stored on disk.

.NOTES
    Author  : Neil Bird, MSFT
    Version : 1.0
    Created : 2026-05-13
#>
########################################
[CmdletBinding(SupportsShouldProcess)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Paths
# IMPORTANT: Publish-Module requires the staging folder name to MATCH the module
# name (i.e. <FolderName>.psd1 must exist directly under the folder). We therefore
# stage to a parent folder + a child folder literally named AzStackHci.ManageUpdates.
$ModuleName  = 'AzStackHci.ManageUpdates'
$StagingRoot = Join-Path 'C:\Temp' 'AzStackHci.ManageUpdates-transitional-stage'
$SourceDir   = $PSScriptRoot
$StagingDir  = Join-Path $StagingRoot $ModuleName

# 1. Clean staging area
Write-Host "[$ModuleName] Cleaning staging folder: $StagingRoot" -ForegroundColor Cyan
if (Test-Path $StagingRoot) {
    Remove-Item $StagingRoot -Recurse -Force
}

# 2. Copy module files to staging (only the two files; nothing else)
Write-Host "[$ModuleName] Copying transitional stub to staging..." -ForegroundColor Cyan
New-Item -Path $StagingDir -ItemType Directory -Force | Out-Null
Copy-Item -Path (Join-Path $SourceDir "$ModuleName.psd1") -Destination $StagingDir -Force
Copy-Item -Path (Join-Path $SourceDir "$ModuleName.psm1") -Destination $StagingDir -Force

# 3. Show what will be published
Write-Host ""
Write-Host "[$ModuleName] Files to be published:" -ForegroundColor Yellow
Get-ChildItem $StagingDir -Recurse -File | ForEach-Object {
    Write-Host "  $($_.FullName.Replace($StagingDir + '\', ''))" -ForegroundColor Gray
}
Write-Host ""

# 4. Validate manifest
Write-Host "[$ModuleName] Validating module manifest..." -ForegroundColor Cyan
$manifestPath = Join-Path $StagingDir "$ModuleName.psd1"
$manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
Write-Host "  Module:  $($manifest.Name)" -ForegroundColor Green
Write-Host "  Version: $($manifest.Version)" -ForegroundColor Green
Write-Host "  GUID:    $($manifest.Guid)" -ForegroundColor Green

if ($manifest.ExportedFunctions.Count -ne 0) {
    throw "Transitional stub must export zero functions but exports $($manifest.ExportedFunctions.Count). Aborting."
}

# 5. Prompt for API key (masked) and publish
Write-Host ""
Write-Host "Paste your PowerShell Gallery NuGet API key (input is masked, nothing will echo):" -ForegroundColor Yellow
$secureApiKey = Read-Host -Prompt "API key" -AsSecureString
if ($null -eq $secureApiKey -or $secureApiKey.Length -eq 0) {
    throw 'API key cannot be empty. Publish cancelled.'
}

$bstr   = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureApiKey)
$apiKey = $null
try {
    $apiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        throw 'API key cannot be empty. Publish cancelled.'
    }

    Write-Host ""
    Write-Host "[$ModuleName] Publishing transitional stub v$($manifest.Version) to PSGallery..." -ForegroundColor Cyan

    if ($PSCmdlet.ShouldProcess("$ModuleName v$($manifest.Version) (transitional stub)", 'Publish to PowerShell Gallery')) {
        Publish-Module -Path $StagingDir -Repository PSGallery -NuGetApiKey $apiKey -Verbose
        Write-Host ""
        Write-Host "[$ModuleName] Transitional stub published successfully!" -ForegroundColor Green
        Write-Host "  https://www.powershellgallery.com/packages/$ModuleName/$($manifest.Version)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "  1. Verify the stub on PSGallery shows the deprecation message in its description." -ForegroundColor Gray
        Write-Host "  2. After a few weeks, log in to PSGallery and unlist this v0.7.3 too." -ForegroundColor Gray
        Write-Host "  3. Open a follow-up PR that deletes AzStackHci.ManageUpdates/ from the repo." -ForegroundColor Gray
    }
}
finally {
    if ($bstr -ne [IntPtr]::Zero) {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) | Out-Null
    }
    $apiKey = $null
    if ($secureApiKey) { $secureApiKey.Dispose() }
    $secureApiKey = $null
    [System.GC]::Collect()
}
