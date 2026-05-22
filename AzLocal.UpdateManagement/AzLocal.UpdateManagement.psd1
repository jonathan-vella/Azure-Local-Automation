@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'AzLocal.UpdateManagement.psm1'

    # Version number of this module.
    ModuleVersion = '0.7.85'

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
        'Public/Update-AzLocalPipelineExample.ps1',
        'Public/Get-AzLocalFleetConnectivityStatus.ps1'
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
        'Get-AzLocalLatestSolutionVersion',
        # Fleet Connectivity Status (v0.7.79) - 4-scope connectivity audit: cluster, Arc agent, physical NIC, ARB
        'Get-AzLocalFleetConnectivityStatus'
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
## Version 0.7.85 - Step.4 reconciliation table: bidirectional interpretation + actionable guidance

### Changed

- **Step.4 `Node + ARB Coverage Reconciliation` table** in both bundled YAMLs (GitHub Actions + Azure DevOps): renames `Arc-joined physical nodes` -> `Arc-tagged physical nodes` (the count was never a join against `cluster.reportedProperties.nodes` - it is a raw count of `microsoft.hybridcompute/machines` tagged `provider=AzSHCI`, so legitimate disagreement in EITHER direction is now documented). Fixes stale `Cluster-reported node count (sum)` Notes that still referenced the pre-v0.7.84 non-existent `nodeCount` property; now correctly says `array_length(properties.reportedProperties.nodes)`. Rewrites `Node coverage delta` Notes with BIDIRECTIONAL semantics (positive = clusters claim more nodes than Arc has; negative = Arc has more AzSHCI-tagged machines than clusters claim) + likely causes for each direction.
- **New `### How to interpret + act on a non-zero reconciliation` subsection** appended to the Step.4 step-summary. Concrete remediation steps for `Node coverage delta` (positive + negative), `Clusters without an ARB > 0`, and `Orphan ARBs > 0`, plus an inline Resource Graph query template to enumerate the specific Arc machines causing a NEGATIVE delta. Operators no longer need external context to act on the numbers.

### Pipeline pin bumps

- All 18 bundled `Step.{0..8}.yml` templates: `'0.7.84'` -> `'0.7.85'`. No other inline-script changes outside Step.4.

### Migration

No action required for the module. Run `Copy-AzLocalPipelineExample -Destination <path> -Update` to refresh bundled YAMLs and pick up the enhanced Step.4 step-summary.

## Version 0.7.84 - HOTFIX: Get-AzLocalFleetConnectivityStatus correctness (3 bugs) + cross-call ARG throttle cooldown

### Fixed (Step.4 summary)

- Cluster `Nodes` column = 0 for every cluster (code read non-existent `properties.reportedProperties.nodeCount` instead of the `properties.reportedProperties.nodes` array). All clusters reported 0 nodes; node coverage delta therefore equalled `-(Arc-joined nodes)`.
- `Non-Connected Machines` table `ClusterName` corrupted to a single character (`Mobile` -> `e`) via a `[string](array)[-1]` scalar-collapse bug (same class as the v0.7.82/v0.7.83 `[char].Trim()` bug).
- `Azure Resource Bridges` table `DaysSinceLastModified` = -1 for EVERY ARB - ARG's default response stripped `systemData`; KQL now extends `lastModifiedAt` explicitly and the Running-short-circuit-to-`-1` UX wart is gone (real days shown for all ARBs; `-1` reserved only for genuinely missing timestamps).

### Added

- Cross-call ARG throttle cooldown in `Invoke-AzResourceGraphQuery` - voluntary entry-side sleep when a prior call observed throttling; counter decays on clean calls. `-DisableCrossCallCooldown` switch + `$script:LastResourceGraphCrossCallCooldownSeconds` diagnostic. Pester `Cross-call throttle coordination (v0.7.84)` Context (4 tests).
- Pester `Regression v0.7.84` Describe (10 tests across 3 contexts). v0.7.79 cluster fixture corrected from the wrong-named scalar `nodeCount = 2` to a realistic `nodes = @(...)` array (it had been silently masking Bug A in unit tests for multiple releases).

### Pipeline pin bumps

- All 18 bundled `Step.{0..8}.yml` templates: `'0.7.83'` -> `'0.7.84'`.

See `CHANGELOG.md` for the full v0.7.84 entry.

## Version 0.7.83 - HOTFIX: Step.4 ARB [char].Trim() bug on single-cluster ClusterId

- Step.4 ARB JUnit-XML generation crashed with `[System.Char] does not contain a method named 'Trim'` whenever a failing ARB had a single (non-comma-separated) `ClusterId`. PowerShell's collection-unwrap silently undid an `@()` wrap when `Where-Object` returned a single scalar, collapsing the array to a `[string]`; `[0]` then returned a `[char]`. Fixed in both Step.4 YAMLs via `[string[]]$clusterIdList = ...` + `([string]$clusterIdList[0]).Trim()` belt-and-braces casts. The same shape existed twice more per file in the orphan-ARB reconciliation block - both call sites are also `[string[]]`-cast now. Pester `Regression v0.7.83` block (9 tests) covers static + dynamic + negative-control checks. All 18 bundled `Step.{0..8}.yml` templates: `'0.7.82'` -> `'0.7.83'`. See `CHANGELOG.md` for the full v0.7.83 entry.

## Version 0.7.82 - Bundled custom-role JSON artifact

- New file `Automation-Pipeline-Examples/azlocal-update-management-custom-role.json`
  bundled with the module. Content matches the canonical role definition
  in `docs/rbac.md` verbatim (13 actions). Replace the
  `<your-subscription-id>` placeholder in `AssignableScopes` before
  `az role definition create`.
- New callout in `Automation-Pipeline-Examples/README.md` Section 4.1
  and `docs/rbac.md` flagging (a) the CLI/PowerShell vs Azure-portal
  ARM-`properties`-wrapped JSON shape difference and (b) the UTF-8 BOM
  gotcha that breaks `az`'s Python JSON parser. The shipped file is
  BOM-free. YAML pin bumps `0.7.81` -> `0.7.82`.

## Version 0.7.81 - Pipeline RBAC guidance: custom role first

- `Automation-Pipeline-Examples/README.md` permission guidance now leads
  with the least-privilege `Azure Stack HCI Update Operator` custom role
  for every environment; the built-in `Azure Stack HCI Administrator`
  role is demoted to a fallback. YAML pin bump only (`0.7.80` -> `0.7.81`).

## Version 0.7.80 - RBAC custom role: fleet-connectivity reads

- The documented custom role in `docs/rbac.md` was missing three reads
  required by `Get-AzLocalFleetConnectivityStatus` (introduced in v0.7.79):
  `Microsoft.HybridCompute/machines/read`,
  `Microsoft.AzureStackHCI/edgeDevices/read`,
  `Microsoft.ResourceConnector/appliances/read`. Pipelines using the
  pre-v0.7.80 role saw 0 Arc agents/NICs/ARBs (ARG returns empty `.data`
  for resource types the caller cannot read).
- **Migration:** refresh the role JSON and run
  `az role definition update --role-definition <file>`. GUID stays stable -
  no re-assignment. Bundled YAML pin bumps `0.7.79` -> `0.7.80`.

## Version 0.7.79 - Step.5 default schedule enabled

For full v0.7.79 release notes see:
https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md

## Version 0.7.78 - Step.4 blank-field regression fix

For full v0.7.78 release notes see:
https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md

## Version 0.7.77 - Step.4 fleet-connectivity hotfix (ARG JSON parse hardening)

For full v0.7.77 release notes see:
https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md

## Version 0.7.76 - Renamed to -AzLocal* + quality hardening

- Exported/public cmdlets and internal helpers renamed from `-AzureLocal*`
  to `-AzLocal*` to align with the module name. **Migration:** search-
  and-replace `-AzureLocal` with `-AzLocal` in your scripts after
  `Install-Module AzLocal.UpdateManagement -Force`. Module GUID unchanged.
- Includes targeted hardening from the module review cycle (row-shape
  safety, health-check dedup, test coverage, docs cleanup, publish
  hygiene) plus Step.0 pipeline pin parity (drift warning now fires from
  the first job rather than Step.1). All 18 `Step.{0..8}.yml` templates
  bump `GENERATED_AGAINST_MODULE_VERSION` `0.7.75` -> `0.7.76`.
- See `CHANGELOG.md` for the full per-cmdlet rename map and detailed notes.

## Version 0.7.75 - Hardening: Test-AzLocalApplyUpdatesScheduleCoverage auto-detects CI host platform

For full v0.7.75 release notes see:
https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md

## Version 0.7.74 - Bug fix: Get-AzLocalFleetHealthOverview KQL regression (ParserFailure at char 2757) + Step.3 recommendation UX rewrite

For full v0.7.74 release notes see:
https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md

## Version 0.7.73 - Bug fix: Get-AzLocalFleetHealthOverview normalises ARG HealthState values so Step.7 "Healthy Clusters" count is correct (was 0 against any fleet)

For full v0.7.73 release notes see:
https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md

## Version 0.7.72 - Pipeline samples hotfix: Step.1/2/5 GitHub Actions Summary panels now render, AZURE_TENANT_ID secret->variable, pipeline pin bumps

For full v0.7.72 release notes see:
https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md

## Older releases

For release notes covering v0.7.71 and earlier, see the CHANGELOG:
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
