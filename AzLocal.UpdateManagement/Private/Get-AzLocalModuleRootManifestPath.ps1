function Get-AzLocalModuleRootManifestPath {
    <#
    .SYNOPSIS
        Resolves the absolute path to the root AzLocal.UpdateManagement.psd1
        (or .psm1 fallback). Safe to call from any Public/ or Private/ script
        file in the module.
    .DESCRIPTION
        The v0.7.3 refactor split the monolithic .psm1 into nested-module
        .ps1 files. Inside any of those files:
            - $PSScriptRoot resolves to <ModuleRoot>\Public or
              <ModuleRoot>\Private (NOT the module root)
            - $PSCommandPath resolves to that .ps1 file itself
        Code that previously assumed "$PSScriptRoot is the module root"
        therefore now points one level too deep and Import-Module / file
        existence checks fail when the module is installed by PSGallery
        into 'Program Files\WindowsPowerShell\Modules\...\<version>\'.

        Several call sites in fleet read functions need the ROOT manifest
        path so background Start-Job runspaces can do
        'Import-Module $ModulePath -Force' and re-import the full module
        (root + every nested helper) into the child runspace. Passing a
        nested-module .ps1 to Import-Module loads only that one file as a
        transient module - none of the module-private helpers are reachable
        and every '& $mod { Get-AzLocal... }' fails with
        "Cannot use '&' to invoke in the context of module '<helper-name>'
        because it is not imported."

        Resolution order (first match wins):
          1. The currently-loaded AzLocal.UpdateManagement module whose
             .Path ends in 'AzLocal.UpdateManagement.psd1' or '.psm1'.
             Prefer .psd1.
          2. The .psd1 alongside the caller's parent folder (works for
             both Public/<name>.ps1 and Private/<name>.ps1 - both are one
             level below the module root).
          3. The .psm1 in the same location, as last-resort fallback.

        Returns $null only when none of the three above can be located,
        which would indicate a malformed install. Callers should treat
        $null as "parallel path cannot be used; fall back to sequential".
    .PARAMETER CallerScriptPath
        The full path of the calling .ps1 file. Pass $PSCommandPath from
        the caller so this helper can derive the module root by going up
        two levels (one level if the caller already lives at the module
        root, but no shipped files do).
    .OUTPUTS
        [string] absolute manifest path, or $null if unresolvable.
    .NOTES
        Added in v0.7.41 alongside the Invoke-FleetJobsInParallel and
        Get-AzLocalFleetStatusData hotfix. Centralising the resolution
        in one helper means future Public/ or Private/ additions won't
        re-introduce the same "$PSScriptRoot is module root" assumption.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$CallerScriptPath
    )

    # 1. Prefer the already-loaded root module entry.
    $loaded = Get-Module -Name 'AzLocal.UpdateManagement' -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Path -and (
                $_.Path -like '*AzLocal.UpdateManagement.psd1' -or
                $_.Path -like '*AzLocal.UpdateManagement.psm1'
            )
        } |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if ($loaded -and $loaded.Path) {
        $manifestCandidate = [IO.Path]::ChangeExtension($loaded.Path, '.psd1')
        if (Test-Path -LiteralPath $manifestCandidate) {
            return $manifestCandidate
        }
        if (Test-Path -LiteralPath $loaded.Path) {
            return $loaded.Path
        }
    }

    # 2. Derive from the caller's location: <ModuleRoot>\(Public|Private)\<file>.ps1
    #    -> Split-Path -Parent => <ModuleRoot>\(Public|Private)
    #    -> Split-Path -Parent => <ModuleRoot>
    if ($CallerScriptPath) {
        $parent = Split-Path -Parent $CallerScriptPath
        if ($parent) {
            $grandparent = Split-Path -Parent $parent
            foreach ($root in @($grandparent, $parent)) {
                if (-not $root) { continue }
                $psd1 = Join-Path -Path $root -ChildPath 'AzLocal.UpdateManagement.psd1'
                if (Test-Path -LiteralPath $psd1) { return $psd1 }
                $psm1 = Join-Path -Path $root -ChildPath 'AzLocal.UpdateManagement.psm1'
                if (Test-Path -LiteralPath $psm1) { return $psm1 }
            }
        }
    }

    # 3. Unresolvable - return $null. Callers decide whether to throw or
    #    fall back to a single-runspace sequential mode.
    return $null
}
