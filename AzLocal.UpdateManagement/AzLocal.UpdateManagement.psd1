@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'AzLocal.UpdateManagement.psm1'

    # Version number of this module.
    ModuleVersion = '0.7.77'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID = 'a8b9c0d1-e2f3-4a5b-6c7d-8e9f0a1b2c3d'

    # Author of this module
    Author = 'Neil Bird, Microsoft'

    # Company or vendor of this module
    CompanyName = 'Microsoft'

    # Copyright statement for this module
    Copyright = '(c) Microsoft. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'PowerShell module to manage Azure Local (formerly Azure Stack HCI) cluster updates using Azure Update Manager APIs. Provides functions to start updates, check update status, list available updates, and monitor update runs. Renamed from AzStackHci.ManageUpdates in v0.7.3 to align with the Azure Local product name.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    NestedModules = @(
        # Private helpers (loaded first)
        'Private/Convert-AzLocalUpdateWindowToCron.ps1',
        'Private/ConvertFrom-AzLocalCronExpression.ps1',
        'Private/ConvertFrom-AzLocalUpdateExclusion.ps1',
        'Private/ConvertFrom-AzLocalScheduleYaml.ps1',
        'Private/ConvertFrom-AzLocalUpdateSideloaded.ps1',
        'Private/ConvertFrom-AzLocalUpdateWindow.ps1',
        'Private/Convert-AzLocalScheduleSchemaVersion.ps1',
        'Private/ConvertTo-AzLocalAdditionalProperties.ps1',
        'Private/ConvertTo-SafeCsvCollection.ps1',
        'Private/ConvertTo-SafeCsvField.ps1',
        'Private/ConvertTo-ScrubbedCliOutput.ps1',
        'Private/ConvertTo-AzLocalUpdateRingKqlFilter.ps1',
        'Private/Export-ResultsToJUnitXml.ps1',
        'Private/Format-AzLocalDurationHuman.ps1',
        'Private/Format-AzLocalIncidentBody.ps1',
        'Private/Format-AzLocalUpdateRun.ps1',
        'Private/Get-AzLocalClusterUpdateRuns.ps1',
        'Private/Get-AzLocalItsmDedupeKey.ps1',
        'Private/Get-AzLocalItsmTriggerDecision.ps1',
        'Private/Get-AzLocalModuleRootManifestPath.ps1',
        'Private/Get-AzLocalPipelineCustomiseMarkers.ps1',
        'Private/Get-AzLocalRunEndTime.ps1',
        'Private/Get-CurrentStepPath.ps1',
        'Private/Get-ExportFormat.ps1',
        'Private/Get-HealthCheckFailureSummary.ps1',
        'Private/Get-LastUpdateRunErrorSummary.ps1',
        'Private/Get-LatestUpdateByYYMM.ps1',
        'Private/Get-TagValue.ps1',
        'Private/Import-AzLocalFleetState.ps1',
        'Private/Install-AzGraphExtension.ps1',
        'Private/Invoke-AzCliJson.ps1',
        'Private/Invoke-AzLocalSideloadedAutoReset.ps1',
        'Private/Invoke-AzLocalSideloadedAutoResetForCluster.ps1',
        'Private/Invoke-AzLocalItsmHttp.ps1',
        'Private/Invoke-AzLocalServiceNowAdapter.ps1',
        'Private/Invoke-AzResourceGraphQuery.ps1',
        'Private/Invoke-AzRestJson.ps1',
        'Private/Invoke-AzLocalUpdateApply.ps1',
        'Private/Invoke-FleetJobsInParallel.ps1',
        'Private/Invoke-FleetOpClusterAction.ps1',
        'Private/Read-AzLocalApplyUpdatesYamlCrons.ps1',
        'Private/Resolve-AzLocalItsmSecret.ps1',
        'Private/Resolve-AzLocalUpdateRunDeepestError.ps1',
        'Private/Resolve-SafeOutputPath.ps1',
        'Private/Resolve-WildcardDate.ps1',
        'Private/Resolve-WildcardDateRange.ps1',
        'Private/Set-AzLocalClusterTagsMerge.ps1',
        'Private/Test-AzCliAvailable.ps1',
        'Private/Test-AzLocalUpdateExclusion.ps1',
        'Private/Test-AzLocalUpdateSideloadedAllowed.ps1',
        'Private/Test-AzLocalUpdateVersionInProgressMatch.ps1',
        'Private/Test-AzLocalUpdateWindow.ps1',
        'Private/Test-ExportPathWritable.ps1',
        'Private/Write-Log.ps1',
        'Private/Write-UpdateCsvLog.ps1',
        'Private/Write-Utf8NoBomFile.ps1',

        # Public exported functions
        'Public/Connect-AzLocalServicePrincipal.ps1',
        'Public/Copy-AzLocalItsmSample.ps1',
        'Public/Copy-AzLocalPipelineExample.ps1',
        'Public/Export-AzLocalFleetState.ps1',
        'Public/Get-AzLocalApplyUpdatesScheduleConfig.ps1',
        'Public/Get-AzLocalApplyUpdatesScheduleNextFirings.ps1',
        'Public/Get-AzLocalAvailableUpdates.ps1',
        'Public/Get-AzLocalClusterInfo.ps1',
        'Public/Get-AzLocalClusterInventory.ps1',
        'Public/Get-AzLocalClusterUpdateReadiness.ps1',
        'Public/Get-AzLocalFleetProgress.ps1',
        'Public/Get-AzLocalFleetStatusData.ps1',
        'Public/Get-AzLocalFleetHealthFailures.ps1',
        'Public/Get-AzLocalFleetHealthOverview.ps1',
        'Public/Get-AzLocalItsmConfig.ps1',
        'Public/Get-AzLocalLatestSolutionVersion.ps1',
        'Public/Get-AzLocalUpdateRunFailures.ps1',
        'Public/Get-AzLocalUpdateRuns.ps1',
        'Public/Get-AzLocalUpdateSummary.ps1',
        'Public/Invoke-AzLocalFleetOperation.ps1',
        'Public/New-AzLocalApplyUpdatesScheduleConfig.ps1',
        'Public/New-AzLocalFleetStatusHtmlReport.ps1',
        'Public/New-AzLocalIncident.ps1',
        'Public/Reset-AzLocalSideloadedTag.ps1',
        'Public/Resolve-AzLocalCurrentUpdateRing.ps1',
        'Public/Resume-AzLocalFleetUpdate.ps1',
        'Public/Set-AzLocalClusterUpdateRingTag.ps1',
        'Public/Start-AzLocalClusterUpdate.ps1',
        'Public/Stop-AzLocalFleetUpdate.ps1',
        'Public/Test-AzLocalApplyUpdatesScheduleCoverage.ps1',
        'Public/Test-AzLocalClusterHealth.ps1',
        'Public/Test-AzLocalFleetHealthGate.ps1',
        'Public/Test-AzLocalItsmConnection.ps1',
        'Public/Test-AzLocalUpdateScheduleAllowed.ps1',
        'Public/Update-AzLocalApplyUpdatesScheduleConfig.ps1',
        'Public/Update-AzLocalPipelineExample.ps1'
    )

    FunctionsToExport = @(
        'Connect-AzLocalServicePrincipal',
        'Start-AzLocalClusterUpdate',
        'Get-AzLocalClusterUpdateReadiness',
        'Get-AzLocalClusterInventory',
        'Get-AzLocalClusterInfo',
        'Get-AzLocalUpdateSummary',
        'Get-AzLocalAvailableUpdates',
        'Get-AzLocalUpdateRuns',
        'Set-AzLocalClusterUpdateRingTag',
        # Fleet-Scale Operations (v0.5.6)
        'Invoke-AzLocalFleetOperation',
        'Get-AzLocalFleetProgress',
        'Test-AzLocalFleetHealthGate',
        'Export-AzLocalFleetState',
        'Resume-AzLocalFleetUpdate',
        'Stop-AzLocalFleetUpdate',
        # Pre-Update Health Validation (v0.6.1)
        'Test-AzLocalClusterHealth',
        # Fleet Status Data Collection & Reporting (v0.6.4)
        'Get-AzLocalFleetStatusData',
        'New-AzLocalFleetStatusHtmlReport',
        # Update Schedule Tag Helpers (v0.6.4)
        'Test-AzLocalUpdateScheduleAllowed',
        # Sideloaded Payload Workflow (v0.7.1)
        'Reset-AzLocalSideloadedTag',
        # ITSM Connector Phase 1 (v0.7.4)
        'Get-AzLocalItsmConfig',
        'Test-AzLocalItsmConnection',
        'New-AzLocalIncident',
        # Pipeline-Examples Convenience (v0.7.4 / Update added v0.7.68)
        'Copy-AzLocalPipelineExample',
        'Update-AzLocalPipelineExample',
        # ITSM Sample Convenience (v0.7.50)
        'Copy-AzLocalItsmSample',
        # Fleet Health Failures (v0.7.65) - 24-hour system health-check failures across the fleet
        'Get-AzLocalFleetHealthFailures',
        # Apply-Updates Schedule Coverage Advisor (v0.7.65) - compares apply-updates YAML cron(s) to UpdateWindow tags
        'Test-AzLocalApplyUpdatesScheduleCoverage',
        # Update Run Failures (v0.7.68) - ARG-only deep-error extraction (9 levels deep) for fleet-scale verbose error information
        'Get-AzLocalUpdateRunFailures',
        # Ring-Aware Apply-Updates Schedule (v0.7.69) - human-readable schedule file + cycle-based resolver
        'Get-AzLocalApplyUpdatesScheduleConfig',
        'Resolve-AzLocalCurrentUpdateRing',
        'Get-AzLocalApplyUpdatesScheduleNextFirings',
        'New-AzLocalApplyUpdatesScheduleConfig',
        'Update-AzLocalApplyUpdatesScheduleConfig',
        # Fleet Health Overview (v0.7.70) - one row per cluster, ARG-first projection of cluster + updateSummaries (fleet-scale)
        'Get-AzLocalFleetHealthOverview',
        # Latest Released Solution Version (v0.7.70) - public manifest probe (aka.ms/AzureEdgeUpdates) that anchors the rolling YYMM support window
        'Get-AzLocalLatestSolutionVersion'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Azure', 'AzureLocal', 'AzureStackHCI', 'Updates', 'UpdateManager', 'HCI', 'Automation', 'CICD', 'Pipeline', 'ServiceNow', 'ITSM', 'Incident')

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/NeilBird/Azure-Local/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/NeilBird/Azure-Local'

            # A URL to an icon representing this module.
            IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
## Version 0.7.77 - Step.4 fleet-connectivity hotfix (ARG JSON parse hardening)

### Fixed

- **Step.4 `fleet-connectivity-status` (GitHub Actions + Azure DevOps):**
  `Invoke-ArgQuery` no longer merges az CLI stderr into stdout before
  `ConvertFrom-Json`. Some runs emitted warning text (notably around
  `extensibilityresources`) that prefixed the JSON payload and caused
  `ConvertFrom-Json` failures with `Unexpected character encountered while
  parsing value: W`.
- Query execution now uses `--only-show-errors` and captures stderr to a
  temp file (`2> $errFile`) so warning noise cannot corrupt JSON parsing.
- Parsed stdout is normalized with `($raw -join "`n").Trim()` before
  `ConvertFrom-Json`, and non-zero az exit paths now surface stderr text
  directly.

### Pipeline pin bumps

- All 18 bundled `Step.{0..8}.yml` templates (9 GitHub Actions + 9 Azure
  DevOps) bump `GENERATED_AGAINST_MODULE_VERSION` from `'0.7.76'` to
  `'0.7.77'`.

## Version 0.7.76 - Renamed to -AzLocal* + nine MODULE-REVIEW findings + ARM healthCheckResult dedup

### Breaking (rename) - operator-controlled module, no other consumers

- **All exported cmdlets renamed from `-AzureLocal*` to `-AzLocal*`** to align
  with the published module name (`AzLocal.UpdateManagement`) and PowerShell
  module-prefix convention. Internal private helpers were also renamed. The
  module GUID is preserved; PSGallery installs `AzLocal.UpdateManagement` and
  the rename is invisible to users who install via `Install-Module`. Callers
  who had pinned previous versions and used the old `-AzureLocal*` names must
  re-import. No deprecation aliases were added (module is still pre-1.0 and
  has no external consumers).

### Fixed (bonus)

- **`Test-AzLocalClusterHealth` and `Get-HealthCheckFailureSummary` (private)
  now dedup byte-identical ARM `healthCheckResult` rows.** ARM upstream was
  observed emitting two byte-identical rows for the same logical check (e.g.
  "Test Network intent on existing cluster nodes" on a 2-node cluster, same
  CheckName / Severity / Description / Remediation / TargetResourceName /
  Timestamp), which doubled the displayed failure count and made Step.4
  readiness reports confusing. Dedup is by the COMPLETE row tuple, so per-
  node distinct findings (different TargetResourceName e.g.
  `UserStorage_1-Repair` vs `UserStorage_2-Repair`) stay separate.

### Findings from MODULE-REVIEW-AND-RECOMMENDATIONS (all addressed)

- **Finding 1 P0 (row-collapse bug, v0.7.75):** `Invoke-AzResourceGraphQuery`
  used `return , $allRows.ToArray()` but `Get-AzureLocalUpdateRuns` (and 23
  other consumers) wrapped the call with `@(...)`, collapsing 136 rows into
  a 1-row array containing the inner Object[136]. Property access then
  silently aggregated values into per-column arrays-of-strings. Fixed by
  changing all callers to direct assignment (`$x = func`); helper warning
  comment added.
- **Finding 2 (test gaps):** Added regression tests for row-collapse,
  ARM healthCheckResult dedup (3 cases), and KQL arg-length safety.
- **Finding 3 (SP secret leak):** `Connect-AzLocalServicePrincipal` now
  writes the secret to a temp file with restricted ACL, passes via
  `Get-Content` not env var, removes the file in a `finally` block.
- **Finding 4 (README appendix demote):** Older What's-New entries moved to
  bottom of README, then extracted entirely to `docs/release-history.md`.
- **Finding 5 P2 (README split, Section 6.3):** Main README trimmed from
  3372 to ~600 lines. New docs/ tree: `cmdlet-reference.md`,
  `concepts.md`, `rbac.md`, `troubleshooting.md`, `release-history.md`.
  Pipeline README appendices also extracted to
  `Automation-Pipeline-Examples/docs/`.
- **Finding 6 (.psm1 housekeeping):** Removed dead-code commented blocks,
  consolidated import boilerplate.
- **Finding 8 (review artefact archive):** Moved review files into a
  gitignored `docs/MODULE-REVIEW-AND-RECOMMENDATIONS.md` so they do not
  leak into the published module.
- **Finding 9 (.psm1 rationale):** Added top-of-file comment block
  explaining the deliberate `Set-StrictMode -Version 1.0` choice (rather
  than `Latest`) and the dot-source-then-export pattern.

### Pipeline pin bumps

- All 18 bundled `Step.{0..8}.yml` templates (9 GitHub Actions + 9 Azure
  DevOps) bump `GENERATED_AGAINST_MODULE_VERSION` from `'0.7.75'` to
  `'0.7.76'`. The pin is a runtime drift-detection constant read by
  `Step.0_authentication-test.yml` (and the other Step.* templates) and
  compared to the version of `AzLocal.UpdateManagement` it just installed
  from PSGallery; on mismatch, the Step Summary emits a drift warning
  telling the operator to refresh the YAML. The pin does NOT control
  which module is installed (`Install-Module -Force` always pulls
  PSGallery latest), so existing pre-v0.7.76 consumer YAMLs continue to
  function - they just emit the warning until refreshed. **New in
  v0.7.76:** Step.0 itself now carries the pin (previously only
  `Step.{1..7}` did), per the 'Step.0 module-drift parity' item in the
  release title - so the drift warning fires from the very first job in
  the pipeline rather than waiting for Step.1. Refresh consumer YAMLs
  to silence the warning with:
  `Update-AzLocalPipelineExample -Destination .\.github\workflows -Platform GitHubActions`
  and / or `-Destination .\.azure-pipelines -Platform AzureDevOps`.

### Migration

- After `Install-Module AzLocal.UpdateManagement -Force` or
  `Update-Module`, callers using `-AzureLocal*` cmdlet names will get a
  "command not found" error. Search-and-replace `-AzureLocal` with
  `-AzLocal` in your scripts. Module GUID unchanged - downstream consumers
  of the manifest (CI cache keys, ARM template `requiredModules`) continue
  to resolve.

## Version 0.7.75 - Hardening: Test-AzLocalApplyUpdatesScheduleCoverage auto-detects the CI host platform when -Platform is omitted, so stale consumer yml self-heals against cross-platform output noise

### Fixed

- **`Test-AzLocalApplyUpdatesScheduleCoverage` cross-platform noise
  is now fixed at the cmdlet layer**, not just the yml layer.
  v0.7.74 patched the symptom by adding `-Platform GitHubActions` /
  `-Platform AzureDevOps` to the bundled Step.3 yml templates, but
  consumers whose Step.3 yml is a verbatim pre-v0.7.74 copy (i.e.
  they have not yet run `Update-AzLocalPipelineExample`) still see
  both snippets in their Step Summary because the yml does not pass
  `-Platform` and the cmdlet defaults to `'Both'`. v0.7.75 closes
  that gap: when the caller does not bind `-Platform`, the cmdlet
  inspects `$env:GITHUB_ACTIONS` (-> `GitHubActions`) and
  `$env:TF_BUILD` / `$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI`
  (-> `AzureDevOps`) and self-selects. Result: GH workflow runs
  emit only the GH snippet, ADO pipeline runs emit only the ADO
  snippet, interactive sessions keep the existing `'Both'` default.
  Auto-detect is gated on `$PSBoundParameters.ContainsKey('Platform')`
  so an explicit caller value (including an explicit `-Platform Both`)
  always wins. The v0.7.74 yml `-Platform` arguments stay in place
  as defence in depth for runs against older modules.

### Pipeline pin bumps

- All 14 `Step.{1..7}.yml` files (7 GitHub Actions + 7 Azure DevOps)
  bump `GENERATED_AGAINST_MODULE_VERSION` from `'0.7.74'` to `'0.7.75'`.

### Migration

- No cmdlet signature change. No yml change required - the v0.7.75
  cmdlet fix self-heals stale consumer yml the next time the workflow
  runs against the v0.7.75 module on PSGallery. Refresh existing yml
  copies (recommended for the version-pin bump and any other v0.7.75
  changes flagged via `GENERATED_AGAINST_MODULE_VERSION`) with:
  `Update-AzLocalPipelineExample -Destination .\.github\workflows -Platform GitHub`
  and / or `-Destination .\.azure-pipelines -Platform AzureDevOps`.

## Version 0.7.74 - Bug fix: Get-AzLocalFleetHealthOverview KQL regression (ParserFailure at char 2757) + Step.3 recommendation UX rewrite

For full v0.7.74 release notes see:
https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md

## Version 0.7.73 - Bug fix: Get-AzLocalFleetHealthOverview normalises ARG HealthState values so Step.7 "Healthy Clusters" count is correct (was 0 against any fleet)

For full v0.7.73 release notes see:
https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md

## Version 0.7.72 - Pipeline samples hotfix: Step.1/2/5 GitHub Actions Summary panels now render, AZURE_TENANT_ID secret->variable, pipeline pin bumps

For full v0.7.72 release notes see:
https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md

## Version 0.7.71 - Step.3 markdown render fix + UnparseableCron action-required section, Step.4 critical-count undercount fix, Step.6 cluster portal link + collapsible Verbose Error, AZURE_SUBSCRIPTION_ID secret->variable

For full v0.7.71 release notes see:
https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md

---

## Version 0.7.70 - Step.0 recurring auth audit, Step.6 update run history, Step.3/Step.7 UX + new ARG-first fleet health summary cmdlet

For v0.7.70 details and release notes covering v0.7.69 and earlier, see the CHANGELOG:
https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md

---

## Older releases

For release notes covering v0.7.69 and earlier, see the CHANGELOG:
https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md

'@

            # Prerelease string of this module
            # Prerelease = ''

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            # RequireLicenseAcceptance = $false

            # External dependent modules of this module
            # ExternalModuleDependencies = @()
        }
    }

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
}
