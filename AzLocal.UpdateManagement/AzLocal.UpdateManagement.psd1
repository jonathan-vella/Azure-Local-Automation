@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'AzLocal.UpdateManagement.psm1'

    # Version number of this module.
    ModuleVersion = '0.7.67'

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
        'Private/ConvertFrom-AzLocalUpdateSideloaded.ps1',
        'Private/ConvertFrom-AzLocalUpdateWindow.ps1',
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
        'Public/Test-AzureLocalApplyUpdatesScheduleCoverage.ps1',
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
        'Get-AzureLocalFleetHealthFailures',
        # Apply-Updates Schedule Coverage Advisor (v0.7.65) - compares apply-updates YAML cron(s) to UpdateWindow tags
        'Test-AzureLocalApplyUpdatesScheduleCoverage'
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
## Version 0.7.66 - cp1252 stderr leak in fleet health ARG calls + schedule-audit pipeline default path fix

### Fixed (critical)

- Get-AzureLocalFleetHealthFailures (and any other caller of the
  private Invoke-AzResourceGraphQuery helper) failed JSON parsing
  on hosted Windows runners when the Azure CLI Python layer emitted
  a cp1252 encoding warning to stderr ("WARNING: Unable to encode
  the output with cp1252 encoding..."). The captured 2>&1 stream
  prepended the WARNING line to the JSON body, and ConvertFrom-Json
  threw "Unexpected character encountered while parsing value: W."
  THE ACTUAL FIX is the post-capture stream split: stderr lines
  surface as ErrorRecord objects under 2>&1, stdout lines as
  strings, and only the string stream is fed to ConvertFrom-Json.
  (--only-show-errors was already passed since v0.7.2 but the
  cp1252 encode warning still leaks through on some character
  paths.) PYTHONIOENCODING=utf-8 is set as cosmetic defence-in-
  depth only - structural no-op for stock az.cmd which launches
  python -I (forces python to ignore PYTHON* env vars per
  Azure/azure-cli#28497 and the v0.7.2 analysis). Matches the
  existing Invoke-AzRestJson hardening from v0.7.2.
- apply-updates-schedule-audit pipeline samples (GitHub Actions and
  Azure DevOps) shipped with a pipeline_path default of
  'AzLocal.UpdateManagement/Automation-Pipeline-Examples' - a path
  that only exists in this module's source repo, never in a
  consumer repo. Every default-trigger run therefore failed with
  "PipelineYamlPath '...' does not exist on the runner" before the
  schedule advisor could write its JUnit, which then crashed
  dorny/test-reporter with "No test report files were found".
  Defaults now match the standard consumer layout:
  '.github/workflows' on GH, '.azure-pipelines' on ADO. The
  path-missing error message also lists which common pipeline
  folders DO exist in the repo so the operator knows what to
  pass via workflow_dispatch / queue-time override.

### Pipeline migration

If you have copied apply-updates-schedule-audit.yml into your repo,
refresh via:
  Copy-AzureLocalPipelineExample -Destination <path> -Platform GitHub      -Update
  Copy-AzureLocalPipelineExample -Destination <path> -Platform AzureDevOps -Update

### Added (UX + capability)

- Status emojis in the Fleet Update Status summary. Both
  fleet-update-status.yml files now render the Critical Health
  and Primary Status tables with green tick / red cross / refresh
  / yellow circle / info glyphs in place of the legacy
  [ok]/[fail]/[ready]/[running]/[blocked] bracket markers.
- Generation timestamp in the Fleet Update Status H2 heading
  ("## Fleet Update Status Summary  _(generated YYYY-MM-DD
  HH:MM:SS UTC)_") so operators see at a glance when the data
  was collected.
- Failed clusters appear before passing clusters in the
  fleet-update-status JUnit per-cluster block (failed first then
  passed, both alphabetical).
- Every downloadable artifact across all pipelines now carries a
  unique UTC timestamp suffix (azlocal-<purpose>_yyyyMMdd_HHmmss).
  Re-running on the same day no longer clobbers earlier downloads.
  Affected: fleet-status-reports, fleet-health-reports, cluster-
  inventory, updatering-tag-logs, ScheduleCoverageReports,
  readiness-report, readiness-assessment, update-logs, itsm-results.
- Pipeline UpdateRing inputs now accept a single value, a
  semicolon-delimited list (Prod;Ring2), or the literal '***'
  (three stars - deliberate gesture) to match every cluster
  that HAS a non-empty UpdateRing tag. Untagged clusters are
  excluded so the wildcard preserves the existing opt-in gate.
  Single '*' / '**' / '****' / '*Wave1' are REJECTED by the
  cmdlet's [ValidatePattern] so a one-char typo cannot scope
  a fleet-wide write. The 14 cmdlets that take -UpdateRingValue
  and Get-AzureLocalFleetHealthFailures (-UpdateRingTag) now
  share regex ^(\*\*\*|[A-Za-z0-9_-]{1,64}(;[A-Za-z0-9_-]{1,64})*)$.
  The ADO apply-updates.yml lost its closed values: enum so the
  new forms can be used at queue time.
- New private helper ConvertTo-AzLocalUpdateRingKqlFilter centralises
  KQL clause construction for the three forms above. Returns
  '| where isnotempty(tags[''UpdateRing''])' for '***' (matches
  only tagged clusters), a =~ clause for a single ring, and an
  in~ clause for a list. Embedded single quotes are KQL-escaped.
  All 12 ARG-query call sites in the public cmdlets now go
  through this helper.
- Pester regression coverage for every v0.7.66 feature (emoji
  glyphs, generated timestamp heading, failed-first bucketing,
  artifact timestamp suffix on GH + ADO, ValidatePattern accept/
  reject incl. '*'/'**'/'****' rejection cases, ConvertTo-
  AzLocalUpdateRingKqlFilter helper incl. '***' -> isnotempty,
  '***' wildcard doc on every exposed update_ring input).

## Version 0.7.65 - Tag-write RBAC narrowed; fleet status summary fix; new Fleet Health Status + Schedule Coverage Audit pipelines

### Added

- Get-AzureLocalFleetHealthFailures: new cmdlet that surfaces 24h
  health-check failures fleet-wide via Azure Resource Graph.
  -View Detail|Summary, -Severity Critical|Warning|All,
  -UpdateRingTag, -ExportPath. Dedicated entry point for
  fleet-wide health triage that exists outside the update workflow.
- Test-AzureLocalApplyUpdatesScheduleCoverage: new read-only cmdlet
  + apply-updates-schedule-audit.yml pipelines (GH + ADO, weekly
  Mon 05:00 UTC). Flags (UpdateRing,UpdateWindow) tag pairs no
  cron in apply-updates.yml will reach. Three views:
  Audit, Matrix, Recommend. See README section 8.3.
- New Fleet Health Status pipeline samples (GitHub + Azure DevOps):
  fleet-health-status.yml. Daily 07:00 UTC; emits JUnit XML + CSV/
  JSON + markdown summary. Complements fleet-update-status.yml.
- Pester guardrail: GENERATED_AGAINST_MODULE_VERSION in every
  sample YAML must match the manifest.

### Fixed

- Set-AzureLocalClusterUpdateRingTag now PATCHes the dedicated
  Microsoft.Resources/tags/default endpoint (Merge operation)
  instead of PATCH-ing the cluster resource directly. Previously
  routed through microsoft.azurestackhci/clusters/write (full
  cluster Contributor); now routes through
  Microsoft.Resources/tags/write only, so service principals
  scoped to the built-in Tag Contributor role can write update-
  ring tags. Aligns with the v0.7.62 fix for Set-AzLocalCluster-
  TagsMerge.
- Fleet Update Status pipeline summary now reconciles with JUnit
  pass/fail counts. "Up to Date" counts both UpdateState=UpToDate
  and AppliedSuccessfully; status buckets are now mutually
  exclusive via a priority cascade so rows always sum to Total
  Clusters.

## Version 0.7.64 - Security hardening + pipeline-YAML UTF-8 mojibake repair

Sample pipeline YAMLs (10 files) had accumulated cp1252 mojibake
from earlier emoji-edit round-trips, one of which contained YAML
1.2-forbidden C1 control byte U+008F that caused GitHub Actions to
reject manage-updatering-tags.yml as "Invalid workflow file". All
non-ASCII bytes have been stripped from every sample workflow.
Security hardening: seven direct callers of `az rest` /
`az account set` / `az login --service-principal` now route raw
CLI output through ConvertTo-ScrubbedCliOutput before logging or
throwing, closing the Bearer-token leak class that was previously
handled inside Invoke-AzRestJson but missed by the sites that
called `az rest` directly. README and ITSM/README also document
residual exposures.

## Version 0.7.63 - PowerShell 7 ParserError fix in fleet-update-status pipeline samples

fleet-update-status.yml samples (GitHub Actions and Azure DevOps)
failed on the Create Status Summary step under pwsh 7 with
"ParserError: The Unicode escape sequence is not valid". Markdown
code-span backticks before file names like update-summaries.csv
were interpreted as the PS 7 `u{xxxx} Unicode escape (which
expects `{` next); PS 5.1 had silently swallowed the backtick.
All Markdown code-span backticks in the affected blocks have been
doubled to render as literal backticks under both shells.

## Version 0.7.62 and earlier

0.7.62 made apply-updates consume the readiness CSV (gate is now
enforced, not advisory); fixed Start-AzureLocalClusterUpdate's
critical-health gate that was being silently bypassed because
Test-AzureLocalClusterHealth was called without -PassThru;
migrated Set-AzLocalClusterTagsMerge to the
Microsoft.Resources/tags/default endpoint (Tag Contributor only);
fixed Export-ResultsToJUnitXml so NotReady / NotConnected /
NoUpdatesAvailable / NoReadyUpdates render as `<skipped>` and
UpdateNotFound as `<error>`; ensured Get-HealthCheckFailureSummary
emits Critical-severity entries before Warning.
0.7.61 added two readiness gates - ClusterState !=
'ConnectedRecently' and any [Critical] health-check entry now
block ReadyForUpdate, with new BlockingReasons CSV column and a
Step 1b connectivity gate in Start-AzureLocalClusterUpdate;
JUnit Status emission for Ready clusters was fixed.
0.7.60 refreshed all GitHub Actions samples to Node 24 action
majors and granted `checks: write` to the apply-updates GH job.
0.7.50 reshaped Copy-AzureLocalPipelineExample (-Flatten/-Force
removed, -Update added) and introduced Copy-AzureLocalItsmSample;
pipelines now install the module from PSGallery at runtime instead
of importing a vendored copy. 0.7.41 hotfix made parallel fleet
reads work again under -ThrottleLimit > 1 against PSGallery-
installed nested-module layout. 0.7.4 added ITSM ticketing
(ServiceNow phase 1). 0.7.3 renamed module from
AzStackHci.ManageUpdates to AzLocal.UpdateManagement and split
the monolithic .psm1 into Public/Private NestedModules.

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
