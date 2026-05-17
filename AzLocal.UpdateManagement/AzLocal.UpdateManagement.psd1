@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'AzLocal.UpdateManagement.psm1'

    # Version number of this module.
    ModuleVersion = '0.7.65'

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
        'Public/Get-AzureLocalFleetHealthFailures.ps1',
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
        'Copy-AzureLocalItsmSample',
        # Fleet Health Failures (v0.7.65) - 24-hour system health-check failures across the fleet
        'Get-AzureLocalFleetHealthFailures'
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
## Version 0.7.65 - Tag-write RBAC narrowed to Tag Contributor; fleet status summary reconciliation; new Fleet Health Status pipeline

### Added

- Get-AzureLocalFleetHealthFailures: new cmdlet that surfaces 24h
  health-check failures fleet-wide via Azure Resource Graph.
  -View Detail|Summary, -Severity Critical|Warning|All,
  -UpdateRingTag, -ExportPath. The 24h health checks run on
  Azure Local clusters even when no update is in flight, so this
  is the dedicated entry point for fleet-wide health triage that
  exists outside the update workflow.
- New Fleet Health Status pipeline samples (GitHub + Azure DevOps):
  fleet-health-status.yml. Daily 07:00 UTC; emits JUnit XML +
  CSV/JSON + markdown summary. Complements fleet-update-status.yml.
- Pester guardrail: GENERATED_AGAINST_MODULE_VERSION in every
  sample YAML that installs the module must match the manifest.
- Automation-Pipeline-Examples README: new "Default triggers and
  schedules" table in Appendix A covering all six pipelines (GH +
  ADO); per-pipeline Trigger row added (A.1 - A.6, incl. new A.6
  Fleet Health Status). Apply Updates (A.4) + Section 8 now carry
  a mandatory-customisation callout: UpdateWindow / UpdateExclusions
  tags only GATE updates while the pipeline runs - they do NOT
  start it. If apply-updates.yml is left at its shipped default
  (workflow_dispatch only / trigger: none) and you rely on
  UpdateWindow tags, no updates will ever apply automatically.
  Section 8 includes worked GH / ADO cron examples.

### Fixed

- Set-AzureLocalClusterUpdateRingTag now uses the dedicated
  Microsoft.Resources/tags/default PATCH endpoint instead of PATCH-ing
  the cluster resource. The previous code issued
  PATCH https://management.azure.com/<clusterId>?api-version=2025-10-01
  with { "tags": {...} }, which Azure RBAC routes through the
  microsoft.azurestackhci/clusters/write action - i.e. full cluster
  Contributor. CI/CD service principals scoped to Tag Contributor (only
  Microsoft.Resources/tags/* actions) therefore failed with
  "AuthorizationFailed: action 'microsoft.azurestackhci/clusters/write'"
  even though they should have been able to write tags. The function
  now PATCHes
  https://management.azure.com/<clusterId>/providers/Microsoft.Resources/tags/default?api-version=2021-04-01
  with { "operation": "Merge", "properties": { "tags": {...} } }, which
  Azure routes through Microsoft.Resources/tags/write only. The Merge
  operation preserves all other existing tags on the cluster without us
  having to re-send them. Aligns with the v0.7.62 fix that already moved
  internal tag writes (Set-AzLocalClusterTagsMerge) to the same
  endpoint.
- "Fleet Update Status" pipeline summary now reconciles with the JUnit
  pass/fail counts. Two related bugs in both fleet-update-status.yml
  samples (GitHub Actions and Azure DevOps) produced summary tables that
  did not add up to Total Clusters:
  1. "Up to Date" only counted UpdateState=UpToDate and missed clusters
     reporting the (equally healthy) AppliedSuccessfully state. Both
     states now count as "Up to Date".
  2. The bucket counters were not mutually exclusive and there was no
     catch-all, so a fleet of 12 healthy + 8 failed clusters could
     render as "Up to Date: 0", "Health Failures: 8", with the
     remaining 12 unaccounted for. Each cluster is now assigned to
     exactly one primary status using a priority cascade (Update Failed,
     Health Failure, SBE Prerequisite Blocked, Update In Progress,
     Ready for Update, Up to Date, Needs Investigation), so the rows
     always sum to Total Clusters.

### Changed

- JUnit pass/fail semantics are now explicit in the summary and in the
  JUnit XML itself. A "Critical Health Status" line (PASSED = healthy +
  no failures + not SBE-blocked; FAILED = HealthState=Failure OR
  UpdateState=Failed OR SBE prerequisite blocked) sits at the top of
  the fleet status summary, and the JUnit <testsuite> carries
  <property name="testCategory" value="CriticalHealthStatus"/> plus a
  description property that spells out what passed and failed mean.
  The failure message attribute is now "Critical Health Status: Failed"
  (was "Cluster has update issues").
- Set-AzureLocalClusterUpdateRingTag help and the
  Automation-Pipeline-Examples RBAC guidance now both recommend the
  built-in Tag Contributor role for tag-management automation.

### Pipeline migration

If you have copied any of these sample workflows into your repo,
refresh them via:
  Copy-AzureLocalPipelineExample -Destination <path> -Platform GitHub      -Update
  Copy-AzureLocalPipelineExample -Destination <path> -Platform AzureDevOps -Update

## Version 0.7.64 - Security hardening + pipeline-YAML UTF-8 mojibake repair

### Fixed (critical)

- Sample pipeline YAMLs (10 files across GitHub Actions and Azure
  DevOps) had accumulated cp1252 mojibake from earlier emoji-edit
  round-trips, one of which contained YAML 1.2-forbidden C1 control
  byte U+008F that caused GitHub Actions to reject
  manage-updatering-tags.yml as "Invalid workflow file". All
  non-ASCII bytes have been stripped from every sample workflow and
  step-summaries restored with plain-ASCII labels.

### Security hardening (medium)

- Seven direct callers of `az rest` / `az account set` /
  `az login --service-principal` now route raw CLI output through
  ConvertTo-ScrubbedCliOutput before logging/throwing, closing the
  Bearer-token leak class that was previously handled inside
  Invoke-AzRestJson but missed by the sites that called `az rest`
  directly. README and ITSM/README also document residual exposures
  (SP+secret command-line, in-memory plaintext during ServiceNow
  OAuth client_credentials).

### Fixed (low)

- Invoke-AzureLocalUpdateApply HTTP 202 detection switched from
  array-filter `-match` to single-string check on
  ($result | Out-String).Trim() + scrubbed Write-Verbose path.
- Invoke-AzLocalItsmHttp throw path now uses $redactedUri to match
  the existing Write-Verbose redaction.
- Two Pester tests that wrote to fixed temp filenames now append a
  per-invocation GUID to remove parallel/back-to-back collision risk.

### Pipeline migration

If you have copied any of these sample workflows into your repo,
refresh them via:
  Copy-AzureLocalPipelineExample -Destination <path> -Platform GitHub      -Update
  Copy-AzureLocalPipelineExample -Destination <path> -Platform AzureDevOps -Update

## Version 0.7.63 - PowerShell 7 ParserError fix in fleet-update-status pipeline samples

### Fixed (critical)

- fleet-update-status.yml samples (GitHub Actions and Azure DevOps)
  failed on the Create Status Summary step under pwsh 7 (default
  shell on GH-hosted Windows runners) with
  "ParserError: The Unicode escape sequence is not valid". Inside
  the PS double-quoted here-string that builds the Markdown summary,
  Markdown code-span backticks before file names like
  update-summaries.csv and update-runs.csv were interpreted as the
  PS 7 `u{xxxx} Unicode escape (which expects `{` next); PS 5.1 had
  silently swallowed the backtick. Other file refs in the same block
  had latent corruption under both shells (`r -> CR, `a -> BEL,
  `c -> dropped backtick). All Markdown code-span backticks in the
  affected blocks have been doubled, which renders as a literal
  backtick in the output string under both PS 5.1 and PS 7. No
  module code paths are affected; only the sample YAMLs.

### Pipeline migration

If you have copied fleet-update-status.yml into your repo, refresh
the samples via:
  Copy-AzureLocalPipelineExample -Destination <path> -Platform GitHub      -Update
  Copy-AzureLocalPipelineExample -Destination <path> -Platform AzureDevOps -Update

## Version 0.7.62 and earlier

0.7.62 made apply-updates consume the readiness CSV (the readiness
gate is now enforced, not advisory); fixed Start-AzureLocalCluster-
Update's critical-health gate that was being silently bypassed
because Test-AzureLocalClusterHealth was called without -PassThru;
migrated Set-AzLocalClusterTagsMerge to the Microsoft.Resources/tags/
default endpoint (Tag Contributor only); fixed Export-ResultsToJUnit-
Xml so NotReady / NotConnected / NoUpdatesAvailable / NoReadyUpdates
render as `<skipped>` and UpdateNotFound as `<error>`; and ensured
Get-HealthCheckFailureSummary emits Critical-severity entries before
Warning.
0.7.61 added two readiness gates - ClusterState !=
'ConnectedRecently' and any [Critical] health-check entry now block
ReadyForUpdate, with new BlockingReasons CSV column and a Step 1b
connectivity gate in Start-AzureLocalClusterUpdate; JUnit Status
emission for Ready clusters was fixed.
0.7.60 refreshed all GitHub Actions samples to Node 24 action majors
and granted `checks: write` to apply-updates GH job.
0.7.50 reshaped Copy-AzureLocalPipelineExample (-Flatten/-Force
removed, -Update added) and introduced Copy-AzureLocalItsmSample;
pipelines now install the module from PSGallery at runtime instead
of importing a vendored copy. 0.7.41 hotfix made parallel fleet
reads work again under -ThrottleLimit > 1 against PSGallery-installed
nested-module layout. 0.7.4 added ITSM ticketing (ServiceNow phase 1).
0.7.3 renamed module from AzStackHci.ManageUpdates to
AzLocal.UpdateManagement and split the monolithic .psm1 into
Public/Private NestedModules. Earlier: EndTime column on
Get-AzureLocalUpdateRuns, UpdateSideloaded auto-reset workflow, ARG
pagination beyond 1000 results, mid-run token refresh, CSV-injection
sanitisation. Full notes in CHANGELOG.md.

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
