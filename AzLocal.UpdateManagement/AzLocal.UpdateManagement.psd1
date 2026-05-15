@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'AzLocal.UpdateManagement.psm1'

    # Version number of this module.
    ModuleVersion = '0.7.60'

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
        'Private/ConvertFrom-AzLocalUpdateExclusion.ps1',
        'Private/ConvertFrom-AzLocalUpdateSideloaded.ps1',
        'Private/ConvertFrom-AzLocalUpdateWindow.ps1',
        'Private/ConvertTo-AzLocalAdditionalProperties.ps1',
        'Private/ConvertTo-SafeCsvCollection.ps1',
        'Private/ConvertTo-SafeCsvField.ps1',
        'Private/ConvertTo-ScrubbedCliOutput.ps1',
        'Private/Export-ResultsToJUnitXml.ps1',
        'Private/Format-AzLocalDurationHuman.ps1',
        'Private/Format-AzLocalIncidentBody.ps1',
        'Private/Format-AzLocalUpdateRun.ps1',
        'Private/Get-AzLocalClusterUpdateRuns.ps1',
        'Private/Get-AzLocalItsmDedupeKey.ps1',
        'Private/Get-AzLocalItsmTriggerDecision.ps1',
        'Private/Get-AzLocalModuleRootManifestPath.ps1',
        'Private/Get-AzLocalRunEndTime.ps1',
        'Private/Get-CurrentStepPath.ps1',
        'Private/Get-ExportFormat.ps1',
        'Private/Get-HealthCheckFailureSummary.ps1',
        'Private/Get-LastUpdateRunErrorSummary.ps1',
        'Private/Get-LatestUpdateByYYMM.ps1',
        'Private/Get-TagValue.ps1',
        'Private/Import-AzureLocalFleetState.ps1',
        'Private/Install-AzGraphExtension.ps1',
        'Private/Invoke-AzLocalSideloadedAutoReset.ps1',
        'Private/Invoke-AzLocalSideloadedAutoResetForCluster.ps1',
        'Private/Invoke-AzLocalItsmHttp.ps1',
        'Private/Invoke-AzLocalServiceNowAdapter.ps1',
        'Private/Invoke-AzResourceGraphQuery.ps1',
        'Private/Invoke-AzRestJson.ps1',
        'Private/Invoke-AzureLocalUpdateApply.ps1',
        'Private/Invoke-FleetJobsInParallel.ps1',
        'Private/Invoke-FleetOpClusterAction.ps1',
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
        'Public/Get-AzureLocalAvailableUpdates.ps1',
        'Public/Get-AzureLocalClusterInfo.ps1',
        'Public/Get-AzureLocalClusterInventory.ps1',
        'Public/Get-AzureLocalClusterUpdateReadiness.ps1',
        'Public/Get-AzureLocalFleetProgress.ps1',
        'Public/Get-AzureLocalFleetStatusData.ps1',
        'Public/Get-AzureLocalItsmConfig.ps1',
        'Public/Get-AzureLocalUpdateRuns.ps1',
        'Public/Get-AzureLocalUpdateSummary.ps1',
        'Public/Invoke-AzureLocalFleetOperation.ps1',
        'Public/New-AzureLocalFleetStatusHtmlReport.ps1',
        'Public/New-AzureLocalIncident.ps1',
        'Public/Reset-AzureLocalSideloadedTag.ps1',
        'Public/Resume-AzureLocalFleetUpdate.ps1',
        'Public/Set-AzureLocalClusterUpdateRingTag.ps1',
        'Public/Start-AzureLocalClusterUpdate.ps1',
        'Public/Stop-AzureLocalFleetUpdate.ps1',
        'Public/Test-AzureLocalClusterHealth.ps1',
        'Public/Test-AzureLocalFleetHealthGate.ps1',
        'Public/Test-AzureLocalItsmConnection.ps1',
        'Public/Test-AzureLocalUpdateScheduleAllowed.ps1'
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
        # Pipeline-Examples Convenience (v0.7.4)
        'Copy-AzureLocalPipelineExample',
        # ITSM Sample Convenience (v0.7.50)
        'Copy-AzureLocalItsmSample'
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
## Version 0.7.60 - GitHub Actions samples refreshed for Node 24 + checks:write fix on apply-updates

### Changed

- All five GitHub Actions sample workflows under
  Automation-Pipeline-Examples/github-actions/ refreshed to use the
  current Node 24-compatible major versions of the third-party actions
  they pin. This removes the "Node.js 20 actions are deprecated" warning
  banner that started appearing on workflow_dispatch runs after the GH
  Actions runner began surfacing the upcoming Sept 2026 Node 20 hard-
  removal. No input/output surface changes for any of the bumped
  actions:
  - actions/checkout         @v4 -> @v5  (Node 24 default since v5.0.0)
  - actions/upload-artifact  @v4 -> @v6  (v6 = Node 24 default; v5 still defaulted to Node 20)
  - azure/login              @v2 -> @v3  (v3.0.0 = Node 24)
  - dorny/test-reporter      @v1 -> @v3  (v3 = Node 24)
  Already-deployed pipelines will keep working on @v4/@v2/@v1 until the
  Sept 16 2026 hard-removal date; running `Copy-AzureLocalPipelineExample
  -Update` after upgrading to v0.7.60 pulls the refreshed YAMLs.

### Fixed

- apply-updates.yml (GitHub Actions sample): both jobs now grant
  `checks: write` in their `permissions:` block. The `dorny/test-reporter`
  step needs that permission to create the Check Run that publishes
  JUnit results; without it the step failed with
  `HttpError: Resource not accessible by integration` on every
  workflow_dispatch run (workflow_dispatch contexts have no PR check
  context to write back to by default). Sibling workflows
  (assess-update-readiness.yml, fleet-update-status.yml) already had
  the permission; only apply-updates.yml was missing it. The run itself
  was unaffected - this only restored the Check Run summary surface.

## Version 0.7.50 - Pipelines install from PSGallery + Copy-AzureLocalPipelineExample gains -Update + new Copy-AzureLocalItsmSample

Summary: pipeline examples (5 GitHub Actions + 5 Azure DevOps YAMLs)
now install the module from PSGallery at runtime instead of importing
a vendored copy (default latest, optional pin via REQUIRED_MODULE_VERSION).
Copy-AzureLocalPipelineExample reshaped: -Flatten and -Force removed
(neither survived first real-world use), replaced by -Update for
controlled refresh with per-file ShouldContinue prompts and
-Confirm:$false bypass for unattended use. New public function
Copy-AzureLocalItsmSample copies the bundled ITSM connector sample
(azurelocal-itsm.yml + templates/incident-body.md) into a user-chosen
destination (default .\.itsm, matching the workflow defaults). Not
flagged as breaking: the v0.7.4 -Flatten/-Force surface had not been
adopted at removal time. Full notes in CHANGELOG.md.

## Version 0.7.41 - Hotfix: parallel fleet reads broken by v0.7.3 NestedModules refactor

### Fixed
- HIGH: every fleet read function that dispatches through
  Invoke-FleetJobsInParallel (Get-AzureLocalUpdateRuns,
  Get-AzureLocalUpdateSummary, Get-AzureLocalClusterUpdateReadiness,
  Get-AzureLocalAvailableUpdates, Get-AzureLocalFleetProgress,
  Invoke-AzureLocalFleetOperation, Test-AzureLocalClusterHealth, and
  Start-AzureLocalClusterUpdate's parallel path) failed for every
  cluster when invoked with -ThrottleLimit > 1 against the PSGallery-
  installed v0.7.4, returning State=Error: "Cannot use '&' to invoke in
  the context of module 'Invoke-FleetJobsInParallel' because it is not
  imported." Inline (-ThrottleLimit 1) was unaffected. Root cause: the
  v0.7.3 NestedModules refactor changed $PSCommandPath inside
  Invoke-FleetJobsInParallel.ps1 to point at the helper's own .ps1, not
  the root manifest. Per-batch Start-Job scriptblocks then imported only
  that .ps1 in the child runspace, so & $mod { ... } against private
  helpers always failed.
- HIGH: New-AzureLocalFleetStatusHtmlReport -ThrottleLimit > 1 (via
  Get-AzureLocalFleetStatusData) threw at start-up: "Parallel collection
  requires module path '...\Public\AzLocal.UpdateManagement.psm1' to be
  reachable by background jobs, but it does not exist." Same class of
  regression but a separate code path: Get-AzureLocalFleetStatusData was
  using Join-Path $PSScriptRoot 'AzLocal.UpdateManagement.psm1', and
  after v0.7.3 $PSScriptRoot resolves to Public/, not the module root.
  New-AzureLocalFleetStatusHtmlReport's footer fallback had the same flaw.
- Centralised the resolution in a new private helper
  Get-AzLocalModuleRootManifestPath, used by all three sites. It prefers
  the loaded module's .Path (.psd1 over .psm1) and falls back to walking
  up from the caller, so it is correct from any Public/ or Private/ file.
- Added Pester regression tests for the helper and for the trailing
  $ModulePath argument that Invoke-FleetJobsInParallel passes to per-
  batch scriptblocks. Existing tests only exercised the inline
  -ThrottleLimit 1 fast-path and silently masked the v0.7.4 regression.

## Version 0.7.4 - ITSM Connector Phase 1 (ServiceNow)

### Added (Phase 1 scaffold)
- New optional ITSM ticketing surface that lets `apply-updates` and
  `fleet-update-status` pipelines open ServiceNow incidents when a cluster
  needs operator action. Disabled by default; opt-in via pipeline input
  `raise_itsm_ticket=true` plus a `./.itsm/azurelocal-itsm.yml` config file.
- New public functions (Phase 1):
  - `Get-AzureLocalItsmConfig`  - load + validate the YAML/JSON trigger matrix
  - `Test-AzureLocalItsmConnection`  - dry-run probe of ITSM endpoint + adapters
  - `New-AzureLocalIncident`  - consume JUnit results, evaluate trigger matrix,
    open / dedupe ServiceNow incidents, return per-cluster Action/TicketId rows
- New internal helpers (Phase 1):
  - `Resolve-AzLocalItsmSecret`, `Get-AzLocalItsmDedupeKey`,
    `Get-AzLocalItsmTriggerDecision`, `Format-AzLocalIncidentBody`,
    `Invoke-AzLocalItsmHttp`, `Invoke-AzLocalServiceNowAdapter`
- New documentation: top-level `ITSM/` folder with `README.md` setup
  walkthrough and `ITSM/ITSM-Config-Reference.md` (full schema
  reference), plus `Automation-Pipeline-Examples/.itsm/` sample config
  + Mustache-style ticket-body templates.
- Phase 2 (`Sync-AzureLocalIncident` lifecycle close-out) and Phase 3
  (Teams / Slack mirror adapters) are **deferred to a future release**;
  the Phase 1 surface is feature-complete on its own.
- Secrets: ITSM credentials are referenced from Azure Key Vault
  (`kv://<vault>/<secret>`) or native CI secrets (`env://<NAME>`). No raw
  secret is ever written to YAML or to disk.

### Added (pipeline-examples convenience)
- New public function `Copy-AzureLocalPipelineExample` copies the bundled
  `Automation-Pipeline-Examples/` folder out of the module install
  location into a user-chosen destination (default: current directory).
  Supports `-Platform GitHub | AzureDevOps | All`, `-Flatten`, `-Force`,
  `-PassThru`, `-WhatIf` and `-Confirm`. Saves users from hunting through
  `$module.ModuleBase` to find the YAML samples.

## Version 0.7.3 - Module renamed to AzLocal.UpdateManagement + internal refactor

Summary: module renamed from `AzStackHci.ManageUpdates` to
`AzLocal.UpdateManagement` to align with the Azure Local product name
(the `Azure Stack HCI` brand was retired in late 2024). Module GUID is
preserved across the rename. Migration:
`Uninstall-Module AzStackHci.ManageUpdates -AllVersions; Install-Module AzLocal.UpdateManagement`.
A transitional `AzStackHci.ManageUpdates` v0.7.3 stub is published once
for users with automation that runs `Install-Module
AzStackHci.ManageUpdates`; importing it emits a warning pointing at the
new name. Default log folder moved to
`C:\ProgramData\AzLocal.UpdateManagement\` (old folder not migrated;
remove manually). Also refactored: monolithic 11,679-line `.psm1` split
into Public/Private dot-sourced files (NestedModules), matching
`AzLocal.DeploymentAutomation`. Full notes in CHANGELOG.md.

## Version 0.7.2 - Fleet read paths fixed under -ThrottleLimit > 1

Summary: fix for Get-AzureLocalUpdateRuns / Get-AzureLocalUpdateSummary /
Get-AzureLocalClusterUpdateReadiness which previously failed under
-ThrottleLimit > 1 because child Start-Job runspaces could not see module-
private helpers; per-cluster scriptblocks now resolve the loaded module
(Import-Module -PassThru) and invoke helpers via `& $module { ... }`.
Inline (-ThrottleLimit 1) execution was unaffected. Also suppresses cp1252
encoding warnings from az rest / az graph query by passing
--only-show-errors at every call site (per azure-cli #14426). See also
v0.7.41 for a related manifestation. Full notes in CHANGELOG.md.

## Version 0.7.1 - EndTime column for update runs + Sideloaded payload workflow

Summary: new optional `UpdateSideloaded` cluster tag and the auto-reset workflow
(Reset-AzureLocalSideloadedTag), EndTime column on Get-AzureLocalUpdateRuns,
CSV-injection sanitisation on intermediate logs, and a switch to
`Generic.List[object]` accumulators for fleet read paths (O(n) instead of
O(n^2)). Fully opt-in; clusters without the tag behave exactly as in v0.7.0.
Full notes in CHANGELOG.md.

## Version 0.7.0 - Fleet-scale correctness, parallelism, and hardening

The jump from 0.6.5 to 0.7.0 reflects the scope of this release: correctness fixes for large
fleets (1500+ clusters), a shift to true parallel execution across all per-cluster read/write
paths, HTML report performance improvements, and a round of bug and security hardening. No
breaking public-surface changes. Highlights: ARG pagination beyond 1000 results, true
parallel fleet execution, ~60% faster HTML render at 1500 clusters, mid-run token refresh,
CSV formula-injection escaping, UpdateWindow tag separator changed to '_'.

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
