function Copy-AzureLocalPipelineExample {
    <#
    .SYNOPSIS
        Copy the bundled Automation-Pipeline-Examples folder out of the module
        install location into a target folder of the user's choice.

    .DESCRIPTION
        The AzLocal.UpdateManagement module ships a working set of CI/CD
        pipeline files (GitHub Actions YAML, Azure DevOps Pipelines YAML, an
        ITSM example config and ticket-body template, plus a step-by-step
        README) under its `Automation-Pipeline-Examples/` subfolder. Those
        files live inside the PowerShell module install path (typically
        `C:\Program Files\WindowsPowerShell\Modules\AzLocal.UpdateManagement\
        <version>\Automation-Pipeline-Examples\` for AllUsers installs or the
        equivalent under `%USERPROFILE%\Documents\PowerShell\Modules\` for
        CurrentUser installs), which is awkward to browse manually.

        This function copies the entire `Automation-Pipeline-Examples` folder
        out of the module install location into a destination folder the user
        controls (default: the current working directory) so the YAML files
        and README can be opened, edited and committed into the user's own
        CI/CD repo without hunting through the module folder hierarchy.

        The function is read-only relative to the module install (it never
        modifies anything under `$module.ModuleBase`). It is destructive only
        relative to the destination folder, and only when `-Force` is supplied
        and a non-empty target already exists. Supports `-WhatIf` and
        `-Confirm`.

    .PARAMETER Destination
        Target folder to copy the pipeline examples into. If the folder does
        not exist it will be created. A subfolder named
        `Automation-Pipeline-Examples` will be created underneath it (matching
        the source layout) unless `-Flatten` is supplied.

        Defaults to the current working directory ($PWD).

    .PARAMETER Platform
        Which platform's pipeline files to copy. Valid values:
          - 'All'         - copy everything (default)
          - 'GitHub'      - copy only the `github-actions/` subfolder
          - 'AzureDevOps' - copy only the `azure-devops/` subfolder

        The top-level `README.md`, the `.itsm/` sample folder, and any other
        shared assets are always copied regardless of -Platform, because the
        README references files in both subfolders and the ITSM samples are
        platform-agnostic.

    .PARAMETER Flatten
        Copy the contents of `Automation-Pipeline-Examples` directly into
        `-Destination` rather than into a child folder of that name. Useful
        when the user has already created a dedicated CI folder and wants the
        YAML files to land there directly.

    .PARAMETER Force
        Overwrite existing files in the destination. Required when the
        destination already contains an `Automation-Pipeline-Examples` folder
        (or, with -Flatten, when the destination already contains any of the
        files the copy would write).

    .PARAMETER PassThru
        Return the [System.IO.DirectoryInfo] of the destination folder. By
        default the function writes only informational messages.

    .OUTPUTS
        [System.IO.DirectoryInfo] when -PassThru is specified. Nothing
        otherwise.

    .EXAMPLE
        Copy-AzureLocalPipelineExample

        Copies all pipeline examples into
        `.\Automation-Pipeline-Examples\` under the current directory.

    .EXAMPLE
        Copy-AzureLocalPipelineExample -Destination C:\repos\my-fleet -Platform GitHub

        Copies only the GitHub Actions YAML files (plus README and .itsm
        samples) into `C:\repos\my-fleet\Automation-Pipeline-Examples\`.

    .EXAMPLE
        New-Item -ItemType Directory .\.github\workflows -Force | Out-Null
        Copy-AzureLocalPipelineExample -Destination .\.github\workflows -Platform GitHub -Flatten -Force

        Copies the GitHub Actions YAML files directly into
        `.\.github\workflows\` (no `Automation-Pipeline-Examples` parent
        folder), overwriting any files of the same name.

    .EXAMPLE
        $dest = Copy-AzureLocalPipelineExample -Destination C:\repos\fleet -PassThru
        Set-Location $dest

        Copy the examples and cd into the destination folder.

    .NOTES
        Author      : Neil Bird, Microsoft
        Module      : AzLocal.UpdateManagement
        Added in    : v0.7.4
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    [OutputType([System.IO.DirectoryInfo])]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Destination = $PWD.Path,

        [ValidateSet('All', 'GitHub', 'AzureDevOps')]
        [string]$Platform = 'All',

        [switch]$Flatten,

        [switch]$Force,

        [switch]$PassThru
    )

    # ------------------------------------------------------------------
    # 1. Locate the module install folder. We deliberately use
    #    (Get-Module).ModuleBase rather than $PSScriptRoot so the function
    #    works correctly when imported via the .psd1 path AND when the
    #    function is dot-sourced standalone (e.g. in some test scenarios).
    # ------------------------------------------------------------------
    $module = Get-Module -Name 'AzLocal.UpdateManagement' | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $module) {
        # Fallback: walk up from this file (Public/ -> module root)
        $moduleRoot = Split-Path -Parent $PSScriptRoot
    }
    else {
        $moduleRoot = $module.ModuleBase
    }

    $sourceRoot = Join-Path -Path $moduleRoot -ChildPath 'Automation-Pipeline-Examples'
    if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
        throw "Copy-AzureLocalPipelineExample: pipeline examples folder not found at '$sourceRoot'. The module install may be corrupt or this is a development checkout without the sample folder."
    }

    # ------------------------------------------------------------------
    # 2. Resolve destination. Create parent if missing.
    # ------------------------------------------------------------------
    if (-not (Test-Path -LiteralPath $Destination)) {
        if ($PSCmdlet.ShouldProcess($Destination, 'Create destination folder')) {
            $null = New-Item -ItemType Directory -Path $Destination -Force -ErrorAction Stop
        }
    }
    # When -WhatIf is supplied and the destination did not pre-exist, it still
    # does not exist at this point; fall back to the literal -Destination string
    # so the rest of the function can describe what *would* happen without
    # throwing on Resolve-Path.
    $destResolved = if (Test-Path -LiteralPath $Destination) {
        (Resolve-Path -LiteralPath $Destination -ErrorAction Stop).ProviderPath
    }
    else {
        # Best-effort absolute path for WhatIf messaging
        [System.IO.Path]::GetFullPath($Destination)
    }

    $targetRoot = if ($Flatten.IsPresent) {
        $destResolved
    }
    else {
        Join-Path -Path $destResolved -ChildPath 'Automation-Pipeline-Examples'
    }

    # ------------------------------------------------------------------
    # 3. Decide what to copy based on -Platform. The README, .itsm/ and any
    #    other top-level assets are always included.
    # ------------------------------------------------------------------
    $includePlatformGitHub = $Platform -in @('All', 'GitHub')
    $includePlatformAdo    = $Platform -in @('All', 'AzureDevOps')

    $sourceItems = Get-ChildItem -LiteralPath $sourceRoot -Force
    $itemsToCopy = New-Object System.Collections.Generic.List[System.IO.FileSystemInfo]
    foreach ($item in $sourceItems) {
        switch ($item.Name) {
            'github-actions' {
                if ($includePlatformGitHub) { [void]$itemsToCopy.Add($item) }
            }
            'azure-devops' {
                if ($includePlatformAdo) { [void]$itemsToCopy.Add($item) }
            }
            default {
                # README.md, .itsm/, and anything else added later: always copy
                [void]$itemsToCopy.Add($item)
            }
        }
    }

    if ($itemsToCopy.Count -eq 0) {
        Write-Warning "Copy-AzureLocalPipelineExample: nothing to copy for -Platform '$Platform'."
        return
    }

    # ------------------------------------------------------------------
    # 4. Pre-flight check: refuse to overwrite an existing populated target
    #    unless -Force was supplied. This prevents accidental clobber of an
    #    in-progress fork of the samples.
    # ------------------------------------------------------------------
    if (Test-Path -LiteralPath $targetRoot) {
        $existing = @(Get-ChildItem -LiteralPath $targetRoot -Force -ErrorAction SilentlyContinue)
        if ($existing.Count -gt 0 -and -not $Force.IsPresent) {
            throw "Copy-AzureLocalPipelineExample: target folder '$targetRoot' already exists and is not empty. Re-run with -Force to overwrite."
        }
    }
    else {
        if ($PSCmdlet.ShouldProcess($targetRoot, 'Create pipeline-examples folder')) {
            $null = New-Item -ItemType Directory -Path $targetRoot -Force -ErrorAction Stop
        }
    }

    # ------------------------------------------------------------------
    # 5. Perform the copy. One ShouldProcess gate at the operation level
    #    rather than per file - the per-platform filter already limits
    #    scope, and per-file -Confirm would be unusably chatty.
    # ------------------------------------------------------------------
    $copyDescription = "Copy {0} item(s) from '{1}' to '{2}' (Platform='{3}', Flatten={4})" -f `
        $itemsToCopy.Count, $sourceRoot, $targetRoot, $Platform, $Flatten.IsPresent
    if (-not $PSCmdlet.ShouldProcess($targetRoot, $copyDescription)) {
        return
    }

    foreach ($item in $itemsToCopy) {
        $destItem = Join-Path -Path $targetRoot -ChildPath $item.Name
        Copy-Item -LiteralPath $item.FullName -Destination $destItem -Recurse -Force:$Force.IsPresent -ErrorAction Stop
    }

    Write-Verbose "Copied $($itemsToCopy.Count) item(s) from '$sourceRoot' to '$targetRoot'."

    # ------------------------------------------------------------------
    # 6. Friendly "what now" summary so the user does not have to open
    #    the README first to know what they just copied. Uses Write-Host
    #    (intentional - this is operator-facing UI text, not pipeline
    #    output; per Microsoft guidance Write-Host is appropriate for
    #    interactive cmdlet output that should not pollute the pipeline).
    # ------------------------------------------------------------------
    $readmePath = Join-Path -Path $targetRoot -ChildPath 'README.md'
    $hasReadme = Test-Path -LiteralPath $readmePath
    $copiedFileCount = (Get-ChildItem -LiteralPath $targetRoot -Recurse -File -ErrorAction SilentlyContinue).Count

    Write-Host ""
    Write-Host "Copy-AzureLocalPipelineExample - copy complete" -ForegroundColor Green
    Write-Host ("  Source      : {0}" -f $sourceRoot)
    Write-Host ("  Destination : {0}" -f $targetRoot)
    Write-Host ("  Platform    : {0}" -f $Platform)
    Write-Host ("  Files copied: {0}" -f $copiedFileCount)
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    if ($hasReadme) {
        Write-Host ("  1. Open the step-by-step setup guide:")
        Write-Host ("       {0}" -f $readmePath) -ForegroundColor Yellow
    }
    else {
        Write-Host ("  1. Refer to the module's online README for the step-by-step setup guide:")
        Write-Host ("       https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/Automation-Pipeline-Examples/README.md") -ForegroundColor Yellow
    }
    switch ($Platform) {
        'GitHub' {
            Write-Host "  2. Drop the YAML files under '$targetRoot\github-actions\' into your repo's '.github/workflows/' folder."
        }
        'AzureDevOps' {
            Write-Host "  2. Import the YAML files under '$targetRoot\azure-devops\' into a new Azure DevOps Pipeline."
        }
        default {
            Write-Host "  2. Pick the platform you use and move the YAML into your repo:"
            Write-Host "       - GitHub Actions  : copy '$targetRoot\github-actions\*.yml' to '.github/workflows/'"
            Write-Host "       - Azure DevOps    : import '$targetRoot\azure-devops\*.yml' into a new Pipeline"
        }
    }
    Write-Host "  3. Wire up authentication (OIDC / Workload Identity / Managed Identity / SP) - see section 3 of the README."
    Write-Host "  4. Optional: enable the ITSM connector by setting 'raise_itsm_ticket=true' (setup in ITSM/README.md)."
    Write-Host ""

    if ($PassThru.IsPresent) {
        return Get-Item -LiteralPath $targetRoot
    }
}
