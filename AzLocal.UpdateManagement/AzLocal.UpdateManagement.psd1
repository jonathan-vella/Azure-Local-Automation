@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'AzLocal.UpdateManagement.psm1'

    # Version number of this module.
    ModuleVersion = '0.7.4'

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
        'Copy-AzureLocalPipelineExample'
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

### Renamed
- The module has been renamed from `AzStackHci.ManageUpdates` to `AzLocal.UpdateManagement`
  to align with the Azure Local product name (Microsoft retired the `Azure Stack HCI`
  brand in late 2024). The module GUID is preserved across the rename so anyone who has
  the previous version installed will see this as the same module identity.
  - **Migration**: `Uninstall-Module AzStackHci.ManageUpdates -AllVersions; Install-Module AzLocal.UpdateManagement`
  - All previously-published `AzStackHci.ManageUpdates` versions have been unlisted from PSGallery.
  - A transitional `AzStackHci.ManageUpdates` v0.7.3 stub is published once for users who
    have automation that runs `Install-Module AzStackHci.ManageUpdates`; importing it
    emits a warning pointing to the new name and exports no functions.
  - Default log folder path moved from `C:\ProgramData\AzStackHci.ManageUpdates\` to
    `C:\ProgramData\AzLocal.UpdateManagement\`. The old folder is not migrated; remove
    it manually after upgrading if desired.
  - Repository folder renamed `AzStackHci.ManageUpdates/` to `AzLocal.UpdateManagement/`;
    pipeline YAML examples and `Import-Module` paths updated accordingly.

### Refactored
- The monolithic 11,679-line `.psm1` is split into Public/Private dot-sourced files,
  matching the layout of `AzLocal.DeploymentAutomation` in this repo. 20 exported
  functions live under `Public/`, 40 internal helpers under `Private/`. The manifest
  enumerates every file in `NestedModules` (Private first, then Public, alphabetical
  within each). No functional change; the full Pester suite (299 tests) remains green.

## Version 0.7.2 - Fleet read paths fixed under -ThrottleLimit > 1

### Bug fixes
- Get-AzureLocalUpdateRuns / Get-AzureLocalUpdateSummary /
  Get-AzureLocalClusterUpdateReadiness no longer fail when invoked with
  -ThrottleLimit greater than 1. Previously the per-cluster scriptblock
  dispatched via Start-Job called module-private helpers
  (Invoke-AzRestJson, Get-AzLocalClusterUpdateRuns, Format-AzLocalUpdateRun,
  Get-LatestUpdateByYYMM, ConvertTo-AzLocalAdditionalProperties,
  Get-HealthCheckFailureSummary, Get-TagValue) directly. Because those
  helpers are filtered out by Export-ModuleMember, after Import-Module in
  the child runspace they were not visible at script command-resolution
  scope, so every cluster reported
  "The term 'Get-AzLocalClusterUpdateRuns' is not recognized..." (or the
  equivalent for the other helper). Inline (-ThrottleLimit 1) execution
  was unaffected because that path runs in the parent module's session
  state. Fix: each affected scriptblock now resolves the loaded module
  reference (Import-Module -PassThru when needed) and either invokes the
  helper via & $module { ... } or rebinds the helper's bound scriptblock
  into the local function scope, so calls execute against the module's
  own session state and resolve all transitive private references.
  Reported against a 9-cluster Prod fleet.

- cp1252 encoding warnings no longer leak into JSON parsing on the inline
  (-ThrottleLimit 1) path. On Windows hosts where the console code page is
  cp1252 (the English-US default), az rest and az graph query emitted
  "WARNING: Unable to encode the output with cp1252 encoding. Unsupported
  characters are discarded." whenever ARM responses contained non-cp1252
  characters (smart quotes, accented cluster tags, localised health-check
  messages, etc.). Captured via 2>&1, that warning was being prepended to
  the JSON body and breaking ConvertFrom-Json, silently dropping update
  runs and available updates for affected clusters. Invoke-AzRestJson set
  PYTHONIOENCODING=utf-8 transiently per-call (v0.7.0+), but this is
  structurally ineffective: az.cmd launches python with the -I (isolated)
  flag, which implies -E and so causes python to IGNORE all PYTHON*
  environment variables. The actual fix is to pass --only-show-errors to
  every az rest and az graph query invocation (Azure CLI maintainer's
  recommended workaround per github.com/Azure/azure-cli/issues/14426).
  This suppresses the encode warning at source. Applied to
  Invoke-AzRestJson, Invoke-AzResourceGraphQuery, and all five direct
  az rest call sites (resource validation, Start-AzureLocalClusterUpdate
  POST, Set-AzLocalClusterTagsMerge GET+PATCH, sideloaded-tag reset
  GET+PATCH). The module-load PYTHONIOENCODING assignment is retained as
  harmless defence-in-depth for environments that have manually patched
  az.cmd to remove -I.

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
