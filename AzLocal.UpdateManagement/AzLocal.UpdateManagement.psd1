@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'AzLocal.UpdateManagement.psm1'

    # Version number of this module.
    ModuleVersion = '0.7.84'

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
## Version 0.7.84 - HOTFIX: Get-AzLocalFleetConnectivityStatus correctness (4 bugs in Step.4 summary)

### Fixed

- **Cluster `Nodes` column = 0 for every cluster (and `Node coverage delta` = -(Arc-joined nodes)).** Root cause: the code read `properties.reportedProperties.nodeCount` which does NOT exist in the Azure Local cluster ARG schema. The correct property is `properties.reportedProperties.nodes` (an array of node objects). All clusters reported 0 nodes regardless of actual size; the delta math then attributed every Arc-joined node as missing cluster coverage. Fix: count `@($nodes).Count` from the array.
- **`Non-Connected Machines` table `ClusterName` column corrupted to a single character** (cluster `Mobile` -> `e`, `alrs-cc` -> `c`). Root cause: `CoerceStr (([string]($clusterId -split '/'))[-1])` applied the `[string]` cast to the WHOLE split ARRAY (joining the elements with spaces), then `[-1]` returned the last CHARACTER of the joined string instead of the last array element. This is the SAME bug class as the v0.7.82/v0.7.83 `[char].Trim()` scalar-collapse bug. Fix: drop the `[string]` cast so `[-1]` indexes the array directly.
- **`Azure Resource Bridges` table `DaysSinceLastModified` = -1 for EVERY ARB (both Running and Offline).** Root cause: (1) the default ARG `resources` response often omitted/stripped `systemData` so `Get-NestedProp $a 'systemData.lastModifiedAt'` returned `$null`, and (2) Running ARBs were short-circuited to `-1` as an opaque sentinel. Fix: ARB KQL now explicitly extends the column with `| extend lastModifiedAt = tostring(systemData.lastModifiedAt)`, and the Running short-circuit is dropped so real days is shown for ALL ARBs. `-1` is now reserved only for genuinely missing/unparseable timestamps.

### Added

- Pester `Regression v0.7.84` Describe block (10 tests across 3 contexts): static regex guards on the source file detect regression of any of the three fixes; execution tests mock realistic ARG payloads (3-node `Mobile` cluster, Disconnected Arc machine with real ARM-ID `parentClusterResourceId`, Running + Offline ARBs with `systemData.lastModifiedAt` set 5/10 days ago) and assert the row values. Negative-control test re-executes the pre-fix `[string](array)[-1]` shape and proves it still returns `'e'` for cluster `Mobile`.
- The existing v0.7.79 cluster fixture (`reportedProperties = @{ nodeCount = 2 }`) used the WRONG property name and silently masked Bug A in unit tests for multiple releases. Fixture corrected to use the realistic `nodes = @(...)` array shape so future schema-shape regressions are caught.

### Pipeline pin bumps

- All 18 bundled `Step.{0..8}.yml` templates bump `GENERATED_AGAINST_MODULE_VERSION` from `'0.7.83'` to `'0.7.84'`.

### Migration

No action required. `Install-Module AzLocal.UpdateManagement -Force` picks up the fix. Refresh bundled Step.4 / Step.6 YAMLs (which call `Get-AzLocalFleetConnectivityStatus`) with `Copy-AzLocalPipelineExample -Destination <path> -Update` to silence the pipeline drift warning.

## Version 0.7.83 - HOTFIX: Step.4 ARB [char].Trim() bug on single-cluster ClusterId

### Fixed

- **Step.4 ARB JUnit-XML generation crashed with `[System.Char] does not contain a method named 'Trim'`** whenever an Azure Resource Bridge failure case had a single (non-comma-separated) `ClusterId`. The pattern `$clusterIdList = if (...) { @(... | Where-Object {...}) } else { @() }; $clusterIdList[0].Trim()` looks safe but is NOT: PowerShell's collection-unwrap silently undoes the `@()` wrap when `Where-Object` yields a single scalar, so `$clusterIdList` collapses to a bare `[string]`, indexing returns `[char]`, and `.Trim()` throws. Multi-cluster RG ARBs (comma-separated `ClusterId`) were unaffected, which is why string-match smoke tests missed it.
- Fixed in both Step.4 YAMLs via `[string[]]$clusterIdList = ...` (forces array shape) + `([string]$clusterIdList[0]).Trim()` (defence-in-depth cast at the indexing site). The same `if-@-else` shape existed twice more per file in the orphan-ARB reconciliation block (currently safe-by-accident due to `foreach` scalar iteration, but brittle); both call sites are now also `[string[]]`-cast.

### Added

- Pester regression block `Regression v0.7.83: Step.4 ARB inline script handles single-cluster ClusterId without [char].Trim() bug` (9 tests). Static checks (regex on YAML content) ensure the casts are present in shipped YAML; dynamic checks re-execute the exact two-line pattern against single-cluster, comma-separated, null, and empty `ClusterId` payloads. Negative-control test proves the pre-fix shape still throws.

### Pipeline pin bumps

- All 18 bundled `Step.{0..8}.yml` templates bump `GENERATED_AGAINST_MODULE_VERSION` from `'0.7.82'` to `'0.7.83'`.

### Migration

No action required. `Install-Module AzLocal.UpdateManagement -Force` picks up the fix; bundled Step.4 YAMLs refreshed via `Copy-AzLocalPipelineExample -Destination <path> -Update`.

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
