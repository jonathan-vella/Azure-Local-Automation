@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'AzLocal.UpdateManagement.psm1'

    # Version number of this module.
    ModuleVersion = '0.7.74'

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
## Version 0.7.74 - Bug fix: Get-AzLocalFleetHealthOverview KQL regression (ParserFailure at char 2757) + Step.3 recommendation UX rewrite (step-by-step remediation, before/after YAML, platform-pinned snippet)

### Fixed

- **`Get-AzLocalFleetHealthOverview` no longer fails with KQL
  `ParserFailure: token=<EOF>`.** The v0.7.73 change added a `case()`
  mapping plus a six-line `//` KQL comment block that grew the wire
  query from ~2400 chars (v0.7.72 baseline) to 3115 chars. On Windows,
  `az graph query -q <query>` truncates very long single-arg payloads
  around 2.8 KB; the truncated query landed mid-projection so ARG
  returned `BadRequest / InvalidQuery / ParserFailure` with
  `characterPositionInLine=2757, token=<EOF>`. Symptom: Step.7 Fleet
  Health Status failed with exit 1 the moment the cmdlet was invoked,
  even though Step.7's separate "Detail" ARG query (shorter) succeeded.
  Fix: the six `//` KQL comment lines are removed from the here-string
  and re-expressed as PowerShell `#` comments above the assignment
  (documentation for the source reader, no wire-side bytes); the
  `case()` projection is compacted to one line (semantically
  identical). Wire query length is back to 2396 chars. A new inline
  `IMPORTANT` source comment above `$kql` flags the constraint so
  future contributors do not re-introduce it. Verified end-to-end
  against the same live 20-cluster fleet: 20 cluster rows returned,
  `HealthStatus` distribution preserved
  (`10 Healthy / 7 Critical / 2 Warning / 1 In progress`).
- **Step.3 pipeline scripts no longer emit cross-platform noise.**
  `Test-AzureLocalApplyUpdatesScheduleCoverage` defaults to
  `-Platform Both`, so every Step.3 run surfaced both the GitHub
  Actions `schedule:` block AND the Azure DevOps `schedules:` block
  regardless of which CI platform was running it. Both Step.3 yml
  files now pin `-Platform GitHubActions` (GH) / `-Platform
  AzureDevOps` (ADO) on both `-View Audit` and `-View Recommend`
  calls.

### Changed

- **Step.3 Apply-Updates Schedule Coverage recommendation block is
  now a true step-by-step remediation guide.** Operators reported the
  v0.7.73 output was "very hard to follow and understand what to do".
  v0.7.74 adds:
  - **Top-of-block "Fix-in-this-order checklist"** when 2+ action
    sections are emitted. Names the file to edit and the consequence
    of skipping each step (e.g. `Resolve-AzLocalCurrentUpdateRing`
    silently returns nothing for missing rings;
    `Test-AzureLocalUpdateScheduleAllowed` never opens the gate for
    uncovered UpdateWindows).
  - **`**Why this matters.**` paragraph in every section** that names
    the specific runtime cmdlet that depends on the configuration
    being fixed and spells out the silent-skip failure mode.
  - **"How to fix" subsection in the missing-rings section** with a
    full `apply-updates-schedule.yml` skeleton snippet showing the
    existing `schedule:` block AND a placeholder row PER missing ring
    with `TODO:` markers on `weeksInCycle`, `daysOfWeek`, `notes`.
    The snippet carries an `AzLocal.UpdateManagement v<version>
    advisor: add row(s) like these <<<` header so it is unambiguous
    where the operator-edited content begins.
  - **Ready-to-paste (uncommented) cron block** in the cron-coverage
    section. Replaces the prior `# commented` form (which operators
    were copy-pasting verbatim including the `# ` prefixes). The
    snippet is now a real `on:` (GH) / `schedules:` (ADO) block, with
    one cron line per UpdateWindow plus a yaml-`#` annotation showing
    the rings and cluster count served by each cron.
  - **Platform-aware file labels.** When `-Platform` is pinned to a
    single platform, the text names the exact pipeline file
    (`.github/workflows/Step.5_apply-updates.yml` vs
    `.azuredevops/Step.5_apply-updates.yml`) and the exact schedule
    file (`.github/apply-updates-schedule.yml` vs
    `.azuredevops/apply-updates-schedule.yml`).
  - **Two-choice fix tables for orphaned rings** spell out both
    options - retag a cluster onto the ring (via
    `Set-AzureLocalClusterUpdateRingTag`) OR remove the ring from the
    schedule file - so operators do not default to deletion when they
    actually wanted to add a cluster onto the ring.

### Pipeline pin bumps

- All 14 `Step.{1..7}.yml` files (7 GitHub Actions + 7 Azure DevOps)
  bump `GENERATED_AGAINST_MODULE_VERSION` from `'0.7.73'` to `'0.7.74'`.

### Migration

- No cmdlet signature changes. `Get-AzLocalFleetHealthOverview`
  returns the same shape and the same normalised `HealthStatus`
  vocabulary it returned in v0.7.73 - only the underlying wire query
  is shorter.
- The v0.7.74 Step.3 yml changes (adding `-Platform GitHubActions` /
  `-Platform AzureDevOps`) are recommended-but-not-required - the
  cmdlet still works against the v0.7.73 yml; you just continue to
  see the cross-platform noise until the yml is refreshed.

## Version 0.7.73 - Bug fix: Get-AzLocalFleetHealthOverview normalises ARG HealthState values so Step.7 "Healthy Clusters" count is correct (was 0 against any fleet)

For full v0.7.73 release notes see:
https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md

## Version 0.7.72 - Pipeline samples hotfix: Step.1/2/5 GitHub Actions Summary panels now render, AZURE_TENANT_ID secret->variable, pipeline pin bumps

For full v0.7.72 release notes see:
https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.UpdateManagement/CHANGELOG.md

## Version 0.7.71 - Step.3 markdown render fix + UnparseableCron action-required section, Step.4 critical-count undercount fix, Step.6 cluster portal link + collapsible Verbose Error, AZURE_SUBSCRIPTION_ID secret->variable

For full v0.7.71 release notes see:
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
