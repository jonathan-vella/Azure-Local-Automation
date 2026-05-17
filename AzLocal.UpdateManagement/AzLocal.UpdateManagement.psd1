@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'AzLocal.UpdateManagement.psm1'

    # Version number of this module.
    ModuleVersion = '0.7.64'

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
## Version 0.7.64 - Security hardening + pipeline-YAML UTF-8 mojibake repair

### Fixed (critical)

- Sample pipeline YAMLs (10 files across GitHub Actions and Azure
  DevOps) had accumulated cp1252 mojibake from previous emoji-edit
  round-trips. One of the multi-byte sequences contained a YAML 1.2
  forbidden C1 control character (U+008F) which caused GitHub Actions
  to reject manage-updatering-tags.yml at recent commits with
  "Invalid workflow file" / YAML syntax error. All non-ASCII bytes
  have been stripped from every sample workflow and the affected
  Markdown step-summaries restored with plain-ASCII labels
  ([info], [ok], [running], [ready], [blocked], [fail]). No module
  code paths are affected; only the sample YAMLs.

### Security hardening (medium)

- Connect-AzureLocalServicePrincipal now scrubs `$loginResult` through
  ConvertTo-ScrubbedCliOutput before writing the failure message to
  Write-Error, so a stray refresh_token / access_token / cookie that
  the az CLI might emit on a failed `az login --service-principal`
  call can no longer reach the host logs verbatim.
- Six additional direct callers of `az rest` / `az account set`
  (Set-AzLocalClusterTagsMerge, Invoke-AzLocalSideloadedAutoResetForCluster,
  Invoke-AzureLocalUpdateApply, Set-AzureLocalClusterUpdateRingTag,
  Start-AzureLocalClusterUpdate x2) now route raw CLI output through
  ConvertTo-ScrubbedCliOutput before logging/throwing. This closes the
  same Bearer-token leak class that was previously handled inside
  Invoke-AzRestJson but missed by the seven sites that call `az rest`
  directly.
- README and ITSM/README now carry explicit security notes about
  (a) the `az login --service-principal --password` command-line
  exposure on the SP+secret authentication path, and (b) the
  unavoidable plaintext [string] residency of ITSM secrets in memory
  during ServiceNow OAuth client_credentials grants.

### Fixed (low)

- Invoke-AzureLocalUpdateApply previously evaluated `$result -match
  "202"` against the string ARRAY returned by `az rest`, which is
  array-filter semantics, not regex-match semantics. The comparison
  is now done against `($result | Out-String).Trim()` and the Write-
  Verbose path is scrubbed.
- Invoke-AzLocalItsmHttp throw on non-retryable HTTP failure now uses
  $redactedUri instead of $Uri, matching the redaction already
  applied to the Write-Verbose log line.
- Two Pester tests that wrote to fixed temp filenames
  (pester-junit-schedule-test.xml and pester-junit-sideloaded-test.xml)
  now append a per-invocation GUID, removing the collision risk when
  the test suite is run in parallel or back-to-back.

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
- Get-HealthCheckFailureSummary now emits Critical-severity entries
  before Warning before the top-5 truncation; previously a Critical
  hidden behind 5+ Warnings was dropped, and the readiness gate
  silently failed to downgrade ReadyForUpdate. Informational entries
  remain excluded.

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

## Version 0.7.61 and earlier

Highlights: 0.7.61 added two readiness gates - ClusterState !=
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
