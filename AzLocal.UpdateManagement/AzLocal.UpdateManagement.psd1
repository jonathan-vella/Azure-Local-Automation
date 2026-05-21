@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'AzLocal.UpdateManagement.psm1'

    # Version number of this module.
    ModuleVersion = '0.7.83'

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

### Added

- New file `Automation-Pipeline-Examples/azlocal-update-management-custom-role.json`
  bundled with the module. Operators can download it directly from the
  repo (`curl` / `Invoke-WebRequest` against the raw.githubusercontent.com
  URL), or run `Copy-AzLocalPipelineExample -Destination ...` which copies
  the entire pipeline-examples folder including this file into a target
  repo. Content matches the canonical role definition in `docs/rbac.md`
  verbatim (13 actions including the three Step.4 reads added in v0.7.80
  plus `Microsoft.HybridCompute/machines/extensions/read` reserved for
  future Arc-machine extension reporting). Replace the
  `<your-subscription-id>` placeholder in `AssignableScopes` before
  running `az role definition create`.

### Changed (documentation)

- `Automation-Pipeline-Examples/README.md` Section 4.1 now points to the
  bundled JSON file as the first install path. The inline JSON copy and
  the inline here-string remain for readers who prefer copy-paste over
  download.
- New callout in Section 4.1 and `docs/rbac.md` flagging the JSON-shape
  difference between the bundled file (CLI/PowerShell format) and the
  Azure portal `Edit a custom role` JSON tab (ARM `properties`-wrapped
  shape) - prevents `Malformed JSON: "properties" property not present`
  in the portal.
- Same callout also flags a UTF-8 BOM gotcha: `az`'s Python JSON parser
  rejects BOM-prefixed files with `Expecting value: line 1 column 1
  (char 0)`. The shipped file is BOM-free.

### Pipeline pin bumps

- All 18 bundled `Step.{0..8}.yml` templates bump
  `GENERATED_AGAINST_MODULE_VERSION` from `'0.7.81'` to `'0.7.82'`.
  No code changes in the YAMLs.

## Version 0.7.81 - Pipeline RBAC guidance: custom role first

### Changed (documentation)

- `Automation-Pipeline-Examples/README.md` permission guidance now leads
  with the least-privilege `Azure Stack HCI Update Operator` custom role
  for every environment (labs, PoCs, production). The built-in
  `Azure Stack HCI Administrator` role is demoted to a fallback for
  tenants where the operator cannot create custom roles, hidden behind
  `<details>` / commented-out alternatives. Sections 3.1, 3.2, 3.3, 3.4,
  4, 4.2 and 11 reframed accordingly; section 4.1 gained an expanded
  `Migration tip (built-in -> custom role, no downtime)` block.

### Pipeline pin bumps

- All 18 bundled `Step.{0..8}.yml` templates bump
  `GENERATED_AGAINST_MODULE_VERSION` from `'0.7.80'` to `'0.7.81'`.
  No code changes in the YAMLs.

## Version 0.7.80 - RBAC custom role: fleet-connectivity reads

### Fixed (documentation)

- The documented "Azure Stack HCI Update Operator" custom role in
  [`docs/rbac.md`](https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/docs/rbac.md)
  was missing three reads required by `Get-AzLocalFleetConnectivityStatus`
  (introduced in v0.7.79). Pipelines using a SP with the v0.7.79-or-earlier
  role saw 20 clusters but 0 Arc agents, 0 NICs, and 0 ARBs because ARG
  returns an empty `.data` array for resource types the caller cannot read.
  Added to the role:
    - `Microsoft.HybridCompute/machines/read`
    - `Microsoft.AzureStackHCI/edgeDevices/read`
    - `Microsoft.ResourceConnector/appliances/read`
- Added an "Updating an existing custom role" sub-section walking through
  `az role definition update` so existing assignments are preserved (role
  GUID stays stable - no re-assignment required).

### Pipeline pin bumps

- Bundled `Step.{0..8}.yml` templates bump
  `GENERATED_AGAINST_MODULE_VERSION` from `'0.7.79'` to `'0.7.80'`.

### Migration

If you created the custom role against the v0.7.79-or-earlier definition,
refresh the JSON to the v0.7.80 definition in `docs/rbac.md` and run
`az role definition update --role-definition ./azlocal-update-management-custom-role.json`.
Permission changes propagate within minutes. No code changes - just the role
definition and the bundled YAML pin.

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

- Exported/public cmdlets and internal helpers were renamed from
  `-AzureLocal*` to `-AzLocal*` to align with the module name.
- Included targeted hardening and cleanup from the module review cycle
  (row-shape safety, health-check dedup, test coverage, docs cleanup,
  and publish hygiene). See `CHANGELOG.md` for full detail.
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
