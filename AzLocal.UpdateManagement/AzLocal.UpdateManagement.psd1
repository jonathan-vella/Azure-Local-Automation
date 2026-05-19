@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'AzLocal.UpdateManagement.psm1'

    # Version number of this module.
    ModuleVersion = '0.7.70'

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
        'Private/Import-AzureLocalFleetState.ps1',
        'Private/Install-AzGraphExtension.ps1',
        'Private/Invoke-AzCliJson.ps1',
        'Private/Invoke-AzLocalSideloadedAutoReset.ps1',
        'Private/Invoke-AzLocalSideloadedAutoResetForCluster.ps1',
        'Private/Invoke-AzLocalItsmHttp.ps1',
        'Private/Invoke-AzLocalServiceNowAdapter.ps1',
        'Private/Invoke-AzResourceGraphQuery.ps1',
        'Private/Invoke-AzRestJson.ps1',
        'Private/Invoke-AzureLocalUpdateApply.ps1',
        'Private/Invoke-FleetJobsInParallel.ps1',
        'Private/Invoke-FleetOpClusterAction.ps1',
        'Private/Read-AzLocalApplyUpdatesYamlCrons.ps1',
        'Private/Resolve-AzLocalItsmSecret.ps1',
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
        'Public/Connect-AzureLocalServicePrincipal.ps1',
        'Public/Copy-AzureLocalItsmSample.ps1',
        'Public/Copy-AzureLocalPipelineExample.ps1',
        'Public/Export-AzureLocalFleetState.ps1',
        'Public/Get-AzLocalApplyUpdatesScheduleConfig.ps1',
        'Public/Get-AzLocalApplyUpdatesScheduleNextFirings.ps1',
        'Public/Get-AzureLocalAvailableUpdates.ps1',
        'Public/Get-AzureLocalClusterInfo.ps1',
        'Public/Get-AzureLocalClusterInventory.ps1',
        'Public/Get-AzureLocalClusterUpdateReadiness.ps1',
        'Public/Get-AzureLocalFleetProgress.ps1',
        'Public/Get-AzureLocalFleetStatusData.ps1',
        'Public/Get-AzureLocalFleetHealthFailures.ps1',
        'Public/Get-AzLocalFleetHealthOverview.ps1',
        'Public/Get-AzureLocalItsmConfig.ps1',
        'Public/Get-AzureLocalLatestSolutionVersion.ps1',
        'Public/Get-AzureLocalUpdateRunFailures.ps1',
        'Public/Get-AzureLocalUpdateRuns.ps1',
        'Public/Get-AzureLocalUpdateSummary.ps1',
        'Public/Invoke-AzureLocalFleetOperation.ps1',
        'Public/New-AzLocalApplyUpdatesScheduleConfig.ps1',
        'Public/New-AzureLocalFleetStatusHtmlReport.ps1',
        'Public/New-AzureLocalIncident.ps1',
        'Public/Reset-AzureLocalSideloadedTag.ps1',
        'Public/Resolve-AzLocalCurrentUpdateRing.ps1',
        'Public/Resume-AzureLocalFleetUpdate.ps1',
        'Public/Set-AzureLocalClusterUpdateRingTag.ps1',
        'Public/Start-AzureLocalClusterUpdate.ps1',
        'Public/Stop-AzureLocalFleetUpdate.ps1',
        'Public/Test-AzureLocalApplyUpdatesScheduleCoverage.ps1',
        'Public/Test-AzureLocalClusterHealth.ps1',
        'Public/Test-AzureLocalFleetHealthGate.ps1',
        'Public/Test-AzureLocalItsmConnection.ps1',
        'Public/Test-AzureLocalUpdateScheduleAllowed.ps1',
        'Public/Update-AzLocalApplyUpdatesScheduleConfig.ps1',
        'Public/Update-AzureLocalPipelineExample.ps1'
    )

    FunctionsToExport = @(
        'Connect-AzureLocalServicePrincipal',
        'Start-AzureLocalClusterUpdate',
        'Get-AzureLocalClusterUpdateReadiness',
        'Get-AzureLocalClusterInventory',
        'Get-AzureLocalClusterInfo',
        'Get-AzureLocalUpdateSummary',
        'Get-AzureLocalAvailableUpdates',
        'Get-AzureLocalUpdateRuns',
        'Set-AzureLocalClusterUpdateRingTag',
        # Fleet-Scale Operations (v0.5.6)
        'Invoke-AzureLocalFleetOperation',
        'Get-AzureLocalFleetProgress',
        'Test-AzureLocalFleetHealthGate',
        'Export-AzureLocalFleetState',
        'Resume-AzureLocalFleetUpdate',
        'Stop-AzureLocalFleetUpdate',
        # Pre-Update Health Validation (v0.6.1)
        'Test-AzureLocalClusterHealth',
        # Fleet Status Data Collection & Reporting (v0.6.4)
        'Get-AzureLocalFleetStatusData',
        'New-AzureLocalFleetStatusHtmlReport',
        # Update Schedule Tag Helpers (v0.6.4)
        'Test-AzureLocalUpdateScheduleAllowed',
        # Sideloaded Payload Workflow (v0.7.1)
        'Reset-AzureLocalSideloadedTag',
        # ITSM Connector Phase 1 (v0.7.4)
        'Get-AzureLocalItsmConfig',
        'Test-AzureLocalItsmConnection',
        'New-AzureLocalIncident',
        # Pipeline-Examples Convenience (v0.7.4 / Update added v0.7.68)
        'Copy-AzureLocalPipelineExample',
        'Update-AzureLocalPipelineExample',
        # ITSM Sample Convenience (v0.7.50)
        'Copy-AzureLocalItsmSample',
        # Fleet Health Failures (v0.7.65) - 24-hour system health-check failures across the fleet
        'Get-AzureLocalFleetHealthFailures',
        # Apply-Updates Schedule Coverage Advisor (v0.7.65) - compares apply-updates YAML cron(s) to UpdateWindow tags
        'Test-AzureLocalApplyUpdatesScheduleCoverage',
        # Update Run Failures (v0.7.68) - ARG-only deep-error extraction (9 levels deep) for fleet-scale verbose error information
        'Get-AzureLocalUpdateRunFailures',
        # Ring-Aware Apply-Updates Schedule (v0.7.69) - human-readable schedule file + cycle-based resolver
        'Get-AzLocalApplyUpdatesScheduleConfig',
        'Resolve-AzLocalCurrentUpdateRing',
        'Get-AzLocalApplyUpdatesScheduleNextFirings',
        'New-AzLocalApplyUpdatesScheduleConfig',
        'Update-AzLocalApplyUpdatesScheduleConfig',
        # Fleet Health Overview (v0.7.70) - one row per cluster, ARG-first projection of cluster + updateSummaries (fleet-scale)
        'Get-AzLocalFleetHealthOverview',
        # Latest Released Solution Version (v0.7.70) - public manifest probe (aka.ms/AzureEdgeUpdates) that anchors the rolling YYMM support window
        'Get-AzureLocalLatestSolutionVersion'
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
## Version 0.7.70 - Step.0 recurring auth audit, Step.6 update run history, Step.3/Step.7 UX + new ARG-first fleet health summary cmdlet

### Added

- New cmdlet `Get-AzLocalFleetHealthOverview`: ARG-first fleet
  health summary. One row per cluster joining
  `microsoft.azurestackhci/clusters` with the cluster's
  `updateSummaries` extensibility resource via ARG. 12 columns
  including ClusterName, ClusterPortalUrl, HealthStatus, UpdateStatus,
  CurrentVersion, SbeVersion, AzureConnection, LastChecked,
  HealthResultsAgeDays. Supports `-SubscriptionId`, `-UpdateRingTag`
  (incl. wildcard `***`), `-ExportPath`, `-PassThru`.

### Changed (cmdlets)

- `Test-AzureLocalApplyUpdatesScheduleCoverage` Audit rows carry a
  new `Section` discriminator (`Schedule` / `Cron`). Output sorts
  Schedule-first. `-View Recommend` emits a multi-section markdown
  report. When `-SchedulePath` is omitted only the cron section is
  emitted (back-compat).
- `Get-AzureLocalFleetHealthFailures` Summary sorts Severity-first
  (Critical, Warning, else), then ClusterCount desc, FailureCount
  desc. Detail rows gain `TargetResourceName`, `TargetResourceType`,
  `ClusterPortalUrl`. Summary rows gain `AffectedClusterPortalUrls`.

### Changed (pipeline samples)

- `Step.0_authentication-test.yml` (GH + ADO) repositioned as a
  recurring `Authentication Validation and Subscription Scope Report`:
  emits JUnit XML (Authentication / Subscription Scope / Resource
  Graph suites - one testcase per accessible subscription), a
  markdown summary with subscription count + per-subscription detail
  table, and an `auth-report` artifact (XML + JSON + CSV). Re-run
  monthly (or after RBAC changes) instead of deleting after the
  first green run.
- `Step.6_fleet-update-status.yml` (GH + ADO) gains an "Update Run
  History and Error Details" section: new JUnit `<testsuite>` +
  markdown table surfacing up to 25 recent unresolved Failed update
  runs (last 30d) with portal deep-links, from
  `Get-AzureLocalUpdateRunFailures -State Failed -OnlyUnresolved`.
- `Step.3_apply-updates-schedule-audit.yml` (GH + ADO) emits TWO
  JUnit `<testsuite>` blocks and TWO Audit Detail tables; Recommend
  output prepended when `$hasIssues -and $reco`.
- `Step.7_fleet-health-status.yml` (GH + ADO): Summary + Detailed
  Results cluster cells render as `[ClusterName](portalUrl)` markdown
  links. Detailed Results adds Failure Remediation (auto-renders as
  `[link](url)` for https values), Target Resource Name, Target
  Resource Type columns. New "Fleet Health Overview (fleet rollup)"
  section calls `Get-AzLocalFleetHealthOverview` and publishes
  `fleet-health-overview.csv` / `.json`.

### Notes

- All v0.7.70 changes are backward compatible. New columns/properties
  are additive (`Section` defaults to `Cron`).
- Pipeline samples bump to `GENERATED_AGAINST_MODULE_VERSION: '0.7.70'`.
  Refresh existing copies with `Update-AzureLocalPipelineExample`.

For full release notes on this and previous versions, see:
https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md

---

## Version 0.7.69 - Ring-aware apply-updates schedule (schema v1, hard break vs v0.7.68)

### Added

- New cmdlet `Get-AzLocalApplyUpdatesScheduleConfig`: parses and
  validates an `apply-updates-schedule.yml` (schema v1). Hard-fails
  when the schedule has no active rows (safety gate the apply-updates
  pipeline depends on).
- New cmdlet `Resolve-AzLocalApplyUpdatesScheduleRing`: maps a UTC
  date to the matching UpdateRing(s) via cycle-week math anchored at
  `cycleAnchorISOWeek` / `cycleAnchorYear`. Union semantics: when
  multiple rows match, the resolver concatenates their `rings`
  columns with `;`.
- New cmdlet `Get-AzLocalApplyUpdatesScheduleNextFirings`: previews
  the next N days of resolved firings.
- New cmdlet `New-AzLocalApplyUpdatesScheduleConfig`: generates a
  **STRAWMAN** schedule from live fleet `UpdateRing` tags (or
  `-Rings` for offline use). Every generated row is emitted
  **commented out** by design - the apply-updates pipeline hard-stops
  until the operator reviews and uncomments at least one row.
- New cmdlet `Update-AzLocalApplyUpdatesScheduleConfig`: idempotent
  migrator framework. v0.7.69 ships the recipes table empty.
- `Test-AzureLocalApplyUpdatesScheduleCoverage` gained
  `-SchedulePath`. When supplied, emits two new status rows:
  `RingMissingFromSchedule` (fleet ring with no schedule row) and
  `RingOrphanedInSchedule` (schedule ring no cluster carries).

### Changed (pipeline samples)

- `Step.5_apply-updates.yml` (GH + ADO) resolves the `UpdateRing`
  from `apply-updates-schedule.yml` on every scheduled firing. Manual
  `workflow_dispatch` / non-Schedule runs still honour the operator's
  `-UpdateRingValue` input verbatim. GH workflow-level `concurrency:`
  block prevents overlapping cron firings.
- `Step.3_apply-updates-schedule-audit.yml` (GH + ADO) gained
  `schedule_path` / `schedulePath` input, a `debug` toggle, and
  surfaces the new RingMissing / RingOrphan counts.
- `apply-updates-schedule.example.yml` ships as documentation only.

### Breaking

- Schema `schemaVersion: 1` is a hard break vs any pre-v0.7.69
  experimental schedule format. No v0 -> v1 migrations shipped.
  Regenerate via `New-AzLocalApplyUpdatesScheduleConfig`.

### Migration

Strawman + review + uncomment workflow:

```powershell
New-AzLocalApplyUpdatesScheduleConfig -OutputPath .\.github\apply-updates-schedule.yml
# Review / uncomment rows that match your change-control policy.
Get-AzLocalApplyUpdatesScheduleNextFirings `
  -Schedule (Get-AzLocalApplyUpdatesScheduleConfig -Path .\.github\apply-updates-schedule.yml)
Update-AzureLocalPipelineExample -Destination .\.github\workflows -Platform GitHub
```

Without an active (uncommented) row the apply-updates pipeline
hard-fails at the reader step (this is the v0.7.69 safety gate).

For full release notes on this and previous versions, see:
https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md

---

## Version 0.7.68 - ARG-first refactor, pipeline rename to Step.X_ prefix, Layer 1 customisation markers

### Added

- New cmdlet `Get-AzureLocalUpdateRunFailures`: ARG-only deep-error
  extraction (9 levels deep) for fleet-scale verbose error information
  from cluster update runs. No per-cluster shell-outs.
- New cmdlet `Update-AzureLocalPipelineExample`: marker-aware merge
  for the bundled pipeline YAMLs. Refreshes the shipped sample set in
  a customer repo while preserving any content inside
  `BEGIN-AZLOCAL-CUSTOMIZE:<section>` / `END-AZLOCAL-CUSTOMIZE:<section>`
  marker pairs (schedule-triggers, itsm-secrets). Companion to
  `Copy-AzureLocalPipelineExample` (clean overwrite).
- Throttle/retry handling in `Invoke-AzResourceGraphQuery`: detects
  HTTP 429 responses, parses `Retry-After`, and applies bounded
  exponential backoff so large fleet sweeps no longer fail at the
  ARG throttling boundary. Two new module-scope diagnostic flags
  reset per call (`$script:LastResourceGraphThrottled`,
  `$script:LastResourceGraphRetryCount`) make the retry behaviour
  inspectable from callers and tests.

### Changed (ARG-first refactor)

- The following cmdlets are now ARG-first single-batch reads, with
  `-ThrottleLimit` removed (it was meaningless against ARG):
  `Get-AzureLocalUpdateSummary`, `Get-AzureLocalAvailableUpdates`,
  `Get-AzureLocalClusterUpdateReadiness`, `Test-AzureLocalClusterHealth`,
  `Get-AzureLocalFleetProgress`, `Get-AzureLocalFleetStatusData`,
  `New-AzureLocalFleetStatusHtmlReport`.
- All shipped pipeline YAMLs no longer pass `-ThrottleLimit`.
- `Get-AzureLocalFleetProgress` no longer silently returns stale state
  when ARG returns zero rows; it now surfaces the empty fleet condition.
- `Invoke-AzResourceGraphQuery` hardened against `az.cmd` CR/LF
  stdout truncation that caused the N-row collapse in consumers.

### Changed (pipeline samples)

- All 16 bundled pipeline YAMLs (GitHub Actions + Azure DevOps) renamed
  with a `Step.X_` ordering prefix so they sort by execution order:
    Step.0_authentication-test.yml   (was auth-smoke-test.yml)
    Step.1_inventory-clusters.yml
    Step.2_manage-updatering-tags.yml
    Step.3_apply-updates-schedule-audit.yml
    Step.4_assess-update-readiness.yml
    Step.5_apply-updates.yml
    Step.6_fleet-update-status.yml
    Step.7_fleet-health-status.yml
- New AZLOCAL-CUSTOMIZE marker pairs (`schedule-triggers` on the 6 main
  pipelines, `itsm-secrets` on Step.5) mark the YAML regions intended
  for operator customisation. Markers are pure YAML comments and have
  no runtime effect. The new `Update-AzureLocalPipelineExample` cmdlet
  consumes them to preserve operator edits inside these regions across
  module upgrades.
- `Read-AzLocalApplyUpdatesYamlCrons` glob expanded to match both
  `Step.5_apply-updates*.yml` and the legacy `apply-updates*.yml` so a
  customer's existing schedule-audit pipeline keeps working until they
  refresh their copies via `Copy-AzureLocalPipelineExample`.

### Migration

If you have copied any of the bundled workflows into your repo, the
recommended refresh path is now the marker-aware merge:

```powershell
Update-AzureLocalPipelineExample -Destination .\.github\workflows -Platform GitHub
Update-AzureLocalPipelineExample -Destination .\.azure-pipelines  -Platform AzureDevOps
```

For a first-time migration from a pre-v0.7.68 copy (no markers in the
destination yet) add `-Force`, then re-apply any operator customisations
once. The clean-overwrite tool (`Copy-AzureLocalPipelineExample -Update`)
remains available for forced refreshes.

For full release notes on this and previous versions, see:
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
