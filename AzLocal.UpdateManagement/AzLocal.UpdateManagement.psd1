@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'AzLocal.UpdateManagement.psm1'

    # Version number of this module.
    ModuleVersion = '0.7.72'

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
## Version 0.7.72 - Pipeline samples hotfix: Step.1/2/5 GitHub Actions Summary panels now render (Write-Host stripped from >> $env:GITHUB_STEP_SUMMARY), AZURE_TENANT_ID secret->variable, pipeline pin bumps to 0.7.72

### Fixed

- **Step.1 / Step.2 / Step.5 GitHub Actions `Summary` panels now render content.**
  Across these three workflows, 62 `Write-Host "<markdown>" >> $env:GITHUB_STEP_SUMMARY`
  lines were silent no-ops because `Write-Host` writes to PowerShell's
  information stream (6), not stdout (1), so the file-redirect operator
  `>>` only ever appended empty content to the summary file. The GitHub
  Actions Summary panel - the canonical post-run report surface -
  rendered blank even though the job log printed the markdown to the
  runner console. All 62 lines now use the bare-string-to-stdout form
  (`"<markdown>" >> $env:GITHUB_STEP_SUMMARY`), so the totals / tables /
  actions-required block surface in the GitHub Actions UI. Affected:
  Step.1 cluster-inventory totals + UpdateRing distribution; Step.2
  UpdateRing tag-management settings + dry-run notice; Step.5
  update-application readiness/results matrix + actions-required block
  + `no-clusters-ready` job summary. ADO pipelines were unaffected
  (they use the `##vso[task.uploadsummary]` mechanism, not stdout
  redirection).

### Changed (pipeline samples)

- **`AZURE_TENANT_ID` Secret -> Variable migration (GitHub Actions only).**
  All 8 GitHub Actions `Step.*.yml` workflows (and the commented-out
  legacy `azure/login@v3` `creds:` JSON in Step.1 / Step.2 / Step.5)
  now read the Entra ID tenant id from `vars.AZURE_TENANT_ID` instead
  of `secrets.AZURE_TENANT_ID`. Matches the v0.7.71 treatment of
  `AZURE_SUBSCRIPTION_ID`: a tenant id is a public ARM/AAD identifier
  (rendered in workflow telemetry on every `azure/login@v3` run,
  present in the OIDC token issuer URL, visible to anyone with read
  access to the App Registration) - not a credential. Consumed in
  exactly one place: the `tenant-id:` input to `azure/login@v3`.
  Steady-state is now one repo-level Secret (`AZURE_CLIENT_ID`) and
  two repo-level Variables (`AZURE_TENANT_ID`,
  `AZURE_SUBSCRIPTION_ID`). Azure DevOps pipelines were already
  authenticating via a service connection and need no change.
- **Pipeline pin bumps.** All 14 `Step.{1..7}.yml` files (7 GitHub
  Actions + 7 Azure DevOps) bump `GENERATED_AGAINST_MODULE_VERSION`
  from `'0.7.71'` to `'0.7.72'`. Refresh existing copies via
  `Update-AzureLocalPipelineExample`.

### Migration

- GitHub Actions operators: add `AZURE_TENANT_ID` as a repository
  Variable (`gh variable set AZURE_TENANT_ID --body <tenantId>`) and
  delete the existing `AZURE_TENANT_ID` Secret to avoid drift.
- No cmdlet signature changes. v0.7.72 is scoped to pipeline-sample
  YAML files and Markdown docs.

## Version 0.7.71 - Step.3 markdown render fix + UnparseableCron action-required section, Step.4 critical-count undercount fix, Step.6 cluster portal link + collapsible Verbose Error, AZURE_SUBSCRIPTION_ID secret->variable

### Fixed

- `Test-AzureLocalApplyUpdatesScheduleCoverage -View Recommend -ExportPath *.md`
  no longer wraps the multi-section snippet inside an outer
  ```yaml ... ``` fence. The snippet already carries its own inner
  ```yaml ... ``` around the cron block, so the outer wrap was causing
  the inner closing ``` to close the outer fence and the outer
  closing ``` to open a new fence that was never closed. Downstream
  consumers (Step.3 pipeline Step Summary) saw every markdown element
  appended after the recommend block (Audit Detail tables, Reports
  Available list, timestamps) rendered as a single grey monospace
  block. Snippet is now emitted verbatim.
- `Step.4_assess-update-readiness.yml` (GH + ADO) Critical health
  failure count under-reported ("0 Critical findings" while JUnit XML
  showed 46). `Test-AzureLocalClusterHealth -PassThru` returns
  per-cluster summary objects with `CriticalCount` / `Failures`, NOT
  flat finding rows with `Severity`. The pipeline now aggregates via
  `Measure-Object -Property CriticalCount -Sum`.

### Added

- `Test-AzureLocalApplyUpdatesScheduleCoverage -View Recommend` emits
  a new `## Action required - simplify unparseable cron expression(s)`
  section between the schedule-fix sections and the cron-coverage
  section when one or more YAML cron lines failed to parse. Lists
  every offending cron with its source file:line and the parser's
  error message so the operator can rewrite the line directly from
  the Step Summary. Sequenced before cron coverage so the operator
  fixes parser-blind crons BEFORE accepting the cron-coverage
  recommendation (which may over-suggest entries duplicating an
  already-correct-but-unparseable line).
- `Get-AzureLocalUpdateRunFailures` projects a new `ClusterPortalUrl`
  property (`https://portal.azure.com/#@/resource{ClusterResourceId}`)
  on every output row, alongside the existing `UpdateRunPortalUrl`.
- `Step.6_fleet-update-status.yml` (GH + ADO) Update Run History
  markdown table renders Cluster Name as a deep link into the Azure
  portal cluster blade (per-row `ClusterPortalUrl` projected by
  `Get-AzureLocalUpdateRunFailures`). Verbose Error Details now
  renders inside an inline `<details><summary>...</summary>...`
  block so the full parser/orchestrator stack is preserved (no more
  250-char truncation) but the table stays scannable - rows expand
  on click. HTML-special chars in error text are escaped to keep the
  renderer honest.

### Changed (pipeline samples)

- All 8 GitHub Actions `Step.*.yml` workflows now read the Azure
  subscription id from `vars.AZURE_SUBSCRIPTION_ID` (Variable) instead
  of `secrets.AZURE_SUBSCRIPTION_ID` (Secret). The value is consumed
  ONLY by `azure/login@v3` to set the default `az account` context
  for cmdlets that REQUIRE a subscription. It is NOT used to scope
  ARG queries (the helpers omit `--subscriptions` so the query runs
  fleet-wide against every subscription the caller can read) and is
  NOT interpolated into portal URLs (each row carries its own
  ARG-projected `subscriptionId` from which deep-links are built per
  row). Treating it as a Variable also means the value appears
  plaintext in workflow logs, which matches its public, non-sensitive
  nature. Azure DevOps pipelines were already authenticating via a
  service connection and need no change.
- `Step.3_apply-updates-schedule-audit.yml` (GH + ADO) drops the
  `(v0.7.69)` suffix from its summary heading - the version pin is
  authoritative.

### Notes

- All v0.7.71 changes are backward compatible. New `ClusterPortalUrl`
  / UnparseableCron section are additive; existing pipeline summaries
  that read only the v0.7.70 schema keep working.
- Pipeline samples bump to `GENERATED_AGAINST_MODULE_VERSION: '0.7.71'`.
  Refresh existing copies with `Update-AzureLocalPipelineExample`.

For full release notes on this and previous versions, see:
https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md

---

## Version 0.7.70 - Step.0 recurring auth audit, Step.6 update run history, Step.3/Step.7 UX + new ARG-first fleet health summary cmdlet

For v0.7.70 details and release notes covering v0.7.69 and earlier, see the CHANGELOG:
https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md

---

## Older releases

For release notes covering v0.7.69 and earlier, see the CHANGELOG:
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
