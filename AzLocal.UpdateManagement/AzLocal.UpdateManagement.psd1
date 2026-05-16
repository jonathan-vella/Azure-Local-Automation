@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'AzLocal.UpdateManagement.psm1'

    # Version number of this module.
    ModuleVersion = '0.7.62'

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
## Version 0.7.62 - Apply-updates pipeline now consumes the readiness CSV; health gate, JUnit Status mapping, tag-write RBAC fixes

### Fixed (critical)

- Start-AzureLocalClusterUpdate Step 3b critical-health gate was being
  silently bypassed. The caller invoked Test-AzureLocalClusterHealth
  without -PassThru; the function logs to the host stream only and
  returns $null without -PassThru, so the predicate
  `$healthResults[0].CriticalCount -gt 0` always evaluated false even
  when the function had just logged "BLOCKED (N critical)". Apply
  would then write "No critical health issues found - cluster is
  eligible for update" and proceed to PATCH the update despite
  critical health failures. Two additional call sites in
  Get-AzureLocalUpdateRuns had the same omission. All three now pass
  -PassThru.
- Set-AzLocalClusterTagsMerge (used by Start-AzureLocalClusterUpdate to
  stamp UpdateVersionInProgress, by Reset-AzureLocalSideloadedTag, and
  by the sideloaded auto-reset path) now writes tags via the ARM tags
  subresource (PATCH .../providers/Microsoft.Resources/tags/default,
  api-version=2021-04-01) instead of the full cluster resource. This
  narrows the required RBAC from `microsoft.azurestackhci/clusters/write`
  to `Microsoft.Resources/tags/write` (built-in Tag Contributor),
  matching the documented behaviour. Two PATCHes are emitted when
  needed: operation=Merge for keys being set, operation=Delete for
  keys whose input value is $null. Idempotent: skips keys whose value
  already matches and Delete keys that are not present.
- Export-ResultsToJUnitXml previously rendered Status values NotReady,
  NotConnected, NoUpdatesAvailable, NoReadyUpdates as <system-out>
  (passed) instead of <skipped>, producing misleading "all green" CI
  summaries when apply had actually skipped clusters. UpdateNotFound
  now renders as <error type="UpdateNotFound"> instead of <system-out>.
  The summary <testsuite tests/failures/errors/skipped/> counts and
  the per-testcase element now agree with the apply-updates reality.

### Changed

- apply-updates pipeline samples (GitHub Actions + Azure DevOps) now
  consume the readiness CSV from the check-readiness job instead of
  re-discovering clusters by UpdateRing tag. The apply step downloads
  the readiness-report artifact, filters rows where
  ReadyForUpdate=True, and invokes Start-AzureLocalClusterUpdate
  -ClusterResourceIds @(...) against that exact list. Apply still
  re-validates each cluster (Step 1b connectivity, Step 3b health,
  Step 3c schedule, Step 3b1 sideloaded) as defence in depth.
  This guarantees the readiness gate's decision is ENFORCED rather
  than advisory: a cluster flagged Blocked in readiness will not be
  touched by apply even if its tag still matches the ring.
- Get-AzureLocalClusterUpdateReadiness output (and the readiness CSV)
  gains a ClusterResourceId column - the full ARM resource ID - so
  the apply step can pass it straight to
  Start-AzureLocalClusterUpdate -ClusterResourceIds without a second
  Resource Graph query. Populated on every row, including NotFound/
  Error rows (set from the input cluster's ResourceId where known).

### Pipeline migration

If you have copied apply-updates.yml into your repo, refresh it via:
  Copy-AzureLocalPipelineExample -Destination <path> -Platform GitHub -Update
  Copy-AzureLocalPipelineExample -Destination <path> -Platform AzureDevOps -Update
The install step's drift detector will also emit a ::notice/warning
log pointing at this once you bump REQUIRED_MODULE_VERSION to 0.7.62.

## Version 0.7.61 - Readiness gates: ClusterState + Critical health checks now block ReadyForUpdate

### Changed

- Get-AzureLocalClusterUpdateReadiness and Get-AzureLocalFleetStatusData
  now downgrade ReadyForUpdate to $false when either of these is true,
  even if ARM otherwise reports a Ready update:
  - ClusterState is not 'ConnectedRecently' (e.g. NotConnectedRecently,
    Disconnected) - ARM cannot reliably push an update to a cluster it
    has not heard from recently.
  - HealthCheckFailures contains at least one [Critical] severity entry.
  Both functions emit a new BlockingReasons CSV column listing the
  reason(s) (e.g. "NotConnectedRecently", "CriticalHealthCheck",
  "CriticalHealthCheck; NotConnectedRecently") so operators can see why
  an otherwise-ready cluster was held back.
- Start-AzureLocalClusterUpdate gains a connectivity gate (Step 1b)
  immediately after cluster lookup: clusters whose properties.status is
  not 'ConnectedRecently' are skipped with Status='NotConnected' and a
  row written to Update_Skipped.csv before any update is attempted.
  Complements the existing Step 3b critical-health gate.
- Console summary on Get-AzureLocalClusterUpdateReadiness now reports
  "Blocked by Readiness Gate: N" alongside SBE-prereq blocks. The
  per-cluster console line shows "Blocked (<reason>)" in red.

### Fixed

- Get-AzureLocalClusterUpdateReadiness JUnit XML export was emitting
  Status='Skipped' for every Ready cluster due to a boolean/string
  comparison bug (`$_.ReadyForUpdate -eq 'Yes'` against a [bool]).
  Status now correctly reports 'Ready' / 'Blocked' / 'Failed' / 'Skipped'.

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

Summary: hotfix for every fleet read/write function that dispatched
through Invoke-FleetJobsInParallel (and for
New-AzureLocalFleetStatusHtmlReport / Get-AzureLocalFleetStatusData).
Under -ThrottleLimit > 1 against PSGallery-installed v0.7.4, per-batch
Start-Job scriptblocks could not see module-private helpers, returning
State=Error: "Cannot use '&' to invoke in the context of module ...
because it is not imported." Inline (-ThrottleLimit 1) was unaffected.
Centralised resolution in a new private helper
Get-AzLocalModuleRootManifestPath; added regression Pester tests for
the parallel path. Full notes in CHANGELOG.md.

## Version 0.7.4 - ITSM Connector Phase 1 (ServiceNow)

Summary: new optional ITSM ticketing surface that lets apply-updates and
fleet-update-status pipelines open ServiceNow incidents when a cluster
needs operator action. Disabled by default; opt-in via pipeline input
raise_itsm_ticket=true plus a ./.itsm/azurelocal-itsm.yml config file.

## Versions 0.7.3 and earlier

Module renamed from AzStackHci.ManageUpdates to AzLocal.UpdateManagement
in v0.7.3, monolithic .psm1 split into Public/Private NestedModules,
parallel fleet read paths fixed for -ThrottleLimit > 1, EndTime column
on Get-AzureLocalUpdateRuns, UpdateSideloaded auto-reset workflow, ARG
pagination beyond 1000 results, mid-run token refresh, CSV-injection
sanitisation. Full notes for every release in CHANGELOG.md.

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
