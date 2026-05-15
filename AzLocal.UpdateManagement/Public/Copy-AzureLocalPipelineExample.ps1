function Copy-AzureLocalPipelineExample {
    <#
    .SYNOPSIS
        Copy the bundled Automation-Pipeline-Examples files out of the module
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

        Behaviour depends on -Platform:
          - 'All' (default)  - copies the full `Automation-Pipeline-Examples`
                               source tree (both platform subfolders, the
                               shared README and the .itsm samples) into a
                               child folder named `Automation-Pipeline-Examples`
                               under `-Destination`. Intended for browsing
                               or inspecting the samples before committing to
                               a platform.
          - 'GitHub'         - copies ONLY the `.yml` workflow files from the
                               source `github-actions/` subfolder directly
                               into `-Destination` (flat - no wrapper folder,
                               no README, no .itsm). Drop
                               `-Destination .\.github\workflows` for the
                               canonical GitHub Actions layout.
          - 'AzureDevOps'    - copies ONLY the `.yml` pipeline files from the
                               source `azure-devops/` subfolder directly into
                               `-Destination` (flat). ADO has no fixed-path
                               convention, so any folder works.

        The function is read-only relative to the module install (it never
        modifies anything under `$module.ModuleBase`). It also REFUSES to
        overwrite any file that already exists at the destination - all
        conflicts are listed in the error message and the copy is aborted.
        To refresh after a module upgrade, delete the existing copies first.
        Supports `-WhatIf` and `-Confirm`.

    .PARAMETER Destination
        Target folder to copy into. Created if missing.

        For `-Platform GitHub` and `-Platform AzureDevOps` the YAMLs land
        directly here (flat). For the default `-Platform All`, an
        `Automation-Pipeline-Examples` child folder is created underneath it
        (matching the source layout).

        Defaults to the current working directory ($PWD).

    .PARAMETER Platform
        Which platform's pipeline files to copy. See the Description for the
        exact layout produced by each value. Valid values:
          - 'All'         - full source tree into an `Automation-Pipeline-Examples` child (default)
          - 'GitHub'      - only `*.yml` from `github-actions/`, flat into -Destination
          - 'AzureDevOps' - only `*.yml` from `azure-devops/`, flat into -Destination

    .PARAMETER PassThru
        Return the [System.IO.DirectoryInfo] of the destination folder. By
        default the function writes only informational messages.

    .OUTPUTS
        [System.IO.DirectoryInfo] when -PassThru is specified. Nothing
        otherwise.

    .EXAMPLE
        Copy-AzureLocalPipelineExample

        Copies the full sample tree into
        `.\Automation-Pipeline-Examples\` under the current directory
        (browse / inspect mode).

    .EXAMPLE
        New-Item -ItemType Directory .\.github\workflows -Force | Out-Null
        Copy-AzureLocalPipelineExample -Destination .\.github\workflows -Platform GitHub

        Copies the GitHub Actions workflow `*.yml` files straight into
        `.\.github\workflows\` where the GitHub Actions runner expects them.

    .EXAMPLE
        New-Item -ItemType Directory .\pipelines -Force | Out-Null
        Copy-AzureLocalPipelineExample -Destination .\pipelines -Platform AzureDevOps

        Copies the Azure DevOps pipeline `*.yml` files straight into
        `.\pipelines\`. Then import each YAML as a new pipeline via
        Pipelines -> New pipeline -> Existing Azure Pipelines YAML file.

    .EXAMPLE
        $dest = Copy-AzureLocalPipelineExample -Destination C:\repos\fleet -PassThru
        Set-Location $dest

        Copy the full sample tree and cd into the destination folder.

    .NOTES
        Author      : Neil Bird, Microsoft
        Module      : AzLocal.UpdateManagement
        Added in    : v0.7.4
        Changed in  : v0.7.5 - removed `-Flatten` and `-Force` switches.
                      Platform-specific copies now drop YAMLs directly into
                      `-Destination` (no intermediate `github-actions\` or
                      `azure-devops\` subfolder), and the function refuses to
                      overwrite any pre-existing destination file. To refresh
                      a copy, delete the existing files first.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    [OutputType([System.IO.DirectoryInfo])]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Destination = $PWD.Path,

        [ValidateSet('All', 'GitHub', 'AzureDevOps')]
        [string]$Platform = 'All',

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

    # ------------------------------------------------------------------
    # 3. Decide what to copy based on -Platform. Build a flat list of
    #    (Source, Destination) pairs so the collision check (step 4) and
    #    copy loop (step 5) can be uniform across all -Platform values.
    # ------------------------------------------------------------------
    $copyPairs = New-Object System.Collections.Generic.List[pscustomobject]
    $targetRoot = $null
    switch ($Platform) {
        'GitHub' {
            # Platform-specific: copy ONLY *.yml from github-actions/ into
            # -Destination directly. No README, no .itsm/, no wrapper folder.
            $targetRoot = $destResolved
            $platformSrc = Join-Path -Path $sourceRoot -ChildPath 'github-actions'
            if (-not (Test-Path -LiteralPath $platformSrc -PathType Container)) {
                throw "Copy-AzureLocalPipelineExample: GitHub Actions source folder not found at '$platformSrc'."
            }
            Get-ChildItem -LiteralPath $platformSrc -Filter '*.yml' -File | ForEach-Object {
                [void]$copyPairs.Add([pscustomobject]@{
                    Source      = $_.FullName
                    Destination = Join-Path -Path $targetRoot -ChildPath $_.Name
                })
            }
        }
        'AzureDevOps' {
            # Platform-specific: copy ONLY *.yml from azure-devops/ into
            # -Destination directly. Same flat semantics as 'GitHub'.
            $targetRoot = $destResolved
            $platformSrc = Join-Path -Path $sourceRoot -ChildPath 'azure-devops'
            if (-not (Test-Path -LiteralPath $platformSrc -PathType Container)) {
                throw "Copy-AzureLocalPipelineExample: Azure DevOps source folder not found at '$platformSrc'."
            }
            Get-ChildItem -LiteralPath $platformSrc -Filter '*.yml' -File | ForEach-Object {
                [void]$copyPairs.Add([pscustomobject]@{
                    Source      = $_.FullName
                    Destination = Join-Path -Path $targetRoot -ChildPath $_.Name
                })
            }
        }
        default {
            # 'All' - mirror the full source tree under .\Automation-Pipeline-Examples\
            $targetRoot = Join-Path -Path $destResolved -ChildPath 'Automation-Pipeline-Examples'
            Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Force | ForEach-Object {
                $relative = $_.FullName.Substring($sourceRoot.Length).TrimStart('\', '/')
                [void]$copyPairs.Add([pscustomobject]@{
                    Source      = $_.FullName
                    Destination = Join-Path -Path $targetRoot -ChildPath $relative
                })
            }
        }
    }

    if ($copyPairs.Count -eq 0) {
        Write-Warning "Copy-AzureLocalPipelineExample: nothing to copy for -Platform '$Platform'."
        return
    }

    # ------------------------------------------------------------------
    # 4. Pre-flight check: refuse to overwrite. Collect every destination
    #    that already exists as a file, list them all in one error, and
    #    abort. There is no -Force escape hatch by design - if the user
    #    wants to refresh, they must delete the existing files first.
    # ------------------------------------------------------------------
    $conflicts = @($copyPairs | Where-Object { Test-Path -LiteralPath $_.Destination -PathType Leaf })
    if ($conflicts.Count -gt 0) {
        $conflictList = ($conflicts | ForEach-Object { "  - $($_.Destination)" }) -join [Environment]::NewLine
        throw ("Copy-AzureLocalPipelineExample: refusing to overwrite {0} existing file(s) under '{1}'. Delete them manually if you want to refresh the copy.`n{2}" -f $conflicts.Count, $targetRoot, $conflictList)
    }

    # ------------------------------------------------------------------
    # 5. Perform the copy. One ShouldProcess gate at the operation level
    #    rather than per file - the per-platform filter already limits
    #    scope, and per-file -Confirm would be unusably chatty. Parent
    #    folders for each destination file are created on demand.
    # ------------------------------------------------------------------
    $copyDescription = "Copy {0} file(s) from '{1}' to '{2}' (Platform='{3}')" -f `
        $copyPairs.Count, $sourceRoot, $targetRoot, $Platform
    if (-not $PSCmdlet.ShouldProcess($targetRoot, $copyDescription)) {
        return
    }

    foreach ($pair in $copyPairs) {
        $destDir = Split-Path -Parent $pair.Destination
        if (-not (Test-Path -LiteralPath $destDir)) {
            $null = New-Item -ItemType Directory -Path $destDir -Force -ErrorAction Stop
        }
        Copy-Item -LiteralPath $pair.Source -Destination $pair.Destination -ErrorAction Stop
    }

    Write-Verbose "Copied $($copyPairs.Count) file(s) from '$sourceRoot' to '$targetRoot'."

    # ------------------------------------------------------------------
    # 6. Friendly "what now" summary so the user does not have to open
    #    the README first to know what they just copied. Uses Write-Host
    #    (intentional - this is operator-facing UI text, not pipeline
    #    output; per Microsoft guidance Write-Host is appropriate for
    #    interactive cmdlet output that should not pollute the pipeline).
    # ------------------------------------------------------------------
    Write-Host ""
    Write-Host "Copy-AzureLocalPipelineExample - copy complete" -ForegroundColor Green
    Write-Host ("  Source      : {0}" -f $sourceRoot)
    Write-Host ("  Destination : {0}" -f $targetRoot)
    Write-Host ("  Platform    : {0}" -f $Platform)
    Write-Host ("  Files copied: {0}" -f $copyPairs.Count)
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    switch ($Platform) {
        'GitHub' {
            # Detect the canonical .github\workflows\ destination so we can
            # tell the user they are already done vs. need to move files.
            $normalised = ($targetRoot -replace '[\\/]+$', '')
            $isWorkflowsFolder = $normalised -match '[\\/]\.github[\\/]workflows$'
            if ($isWorkflowsFolder) {
                Write-Host "  1. You are already in '.github\workflows\' - commit and push:" -ForegroundColor Yellow
                Write-Host "       git add . ; git commit -m 'Add AzLocal update workflows' ; git push"
            }
            else {
                Write-Host ("  1. Move the YAML files from '{0}' into '.github\workflows\' in your repo, then commit and push." -f $targetRoot)
            }
            Write-Host "  2. RECOMMENDED: run 'auth-smoke-test.yml' FIRST (one-shot) to validate OIDC / RBAC before wiring the other workflows. See section 5.1 of the Automation-Pipeline-Examples README."
            Write-Host "  3. Wire up authentication (OIDC / Workload Identity / Managed Identity / SP) - see section 3 of the README."
            Write-Host "  4. Optional: enable the ITSM connector by setting 'raise_itsm_ticket=true' (setup in ITSM/README.md)."
        }
        'AzureDevOps' {
            Write-Host ("  1. Commit the YAML files from '{0}' to your Azure Repo." -f $targetRoot)
            Write-Host "  2. RECOMMENDED: import 'auth-smoke-test.yml' FIRST (one-shot) to validate the service connection / RBAC before wiring the other pipelines. See section 5.2 of the Automation-Pipeline-Examples README."
            Write-Host "  3. For each remaining YAML: Pipelines -> New pipeline -> Existing Azure Pipelines YAML file -> point at the file -> Save."
            Write-Host "  4. Each pipeline references service connection 'AzureLocal-ServiceConnection' - either name yours to match or edit 'azureSubscription:' in each YAML."
            Write-Host "  5. Optional: enable the ITSM connector by setting 'raise_itsm_ticket=true' (setup in ITSM/README.md)."
        }
        default {
            $readmePath = Join-Path -Path $targetRoot -ChildPath 'README.md'
            if (Test-Path -LiteralPath $readmePath) {
                Write-Host "  1. Open the step-by-step setup guide:"
                Write-Host ("       {0}" -f $readmePath) -ForegroundColor Yellow
            }
            else {
                Write-Host "  1. Refer to the module's online README for the step-by-step setup guide:"
                Write-Host "       https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/Automation-Pipeline-Examples/README.md" -ForegroundColor Yellow
            }
            Write-Host "  2. Pick the platform you use and copy the YAML into your repo (or re-run this function with -Platform GitHub or -Platform AzureDevOps):"
            Write-Host ("       - GitHub Actions  : copy '{0}\github-actions\*.yml' to '.github\workflows\'" -f $targetRoot)
            Write-Host ("       - Azure DevOps    : import '{0}\azure-devops\*.yml' as new pipelines" -f $targetRoot)
            Write-Host "  3. Wire up authentication (OIDC / Workload Identity / Managed Identity / SP) - see section 3 of the README."
            Write-Host "  4. Optional: enable the ITSM connector by setting 'raise_itsm_ticket=true' (setup in ITSM/README.md)."
        }
    }
    Write-Host ""

    if ($PassThru.IsPresent) {
        return Get-Item -LiteralPath $targetRoot
    }
}
