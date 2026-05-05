@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'AzStackHci.ManageUpdates.psm1'

    # Version number of this module.
    ModuleVersion = '0.7.2'

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
    Description = 'PowerShell module to manage Azure Local (Azure Stack HCI) cluster updates using Azure Update Manager APIs. Provides functions to start updates, check update status, list available updates, and monitor update runs.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
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
        'Reset-AzureLocalSideloadedTag'
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
            Tags = @('Azure', 'AzureLocal', 'AzureStackHCI', 'Updates', 'UpdateManager', 'HCI', 'Automation', 'CICD')

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/NeilBird/Azure-Local/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/NeilBird/Azure-Local'

            # A URL to an icon representing this module.
            IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
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

### Enterprise-readiness review fixes (v0.7.1)
- Security: Write-UpdateCsvLog (the diagnostic CSV path used during apply runs)
  now sanitises every field through ConvertTo-SafeCsvField before quote-escaping,
  closing a CSV-injection gap in the interim Update_Skipped.csv / Update_Started.csv
  logs (the final exported results path was already protected).
- Operational: parallel Get-AzureLocalFleetStatusData job dispatch now treats
  Stopped and Disconnected job states as failures alongside Failed, so Stop-Job /
  Ctrl-C / remoting-disconnect scenarios are surfaced rather than misdiagnosed as
  "no output".
- Performance: Get-AzureLocalUpdateSummary, Get-AzureLocalClusterUpdateReadiness,
  Start-AzureLocalClusterUpdate, Get-AzureLocalUpdateRuns, and the private
  Get-AzLocalClusterUpdateRuns helper now accumulate per-cluster results in a
  [System.Collections.Generic.List[object]] (O(1) amortised .Add()) instead of an
  Object[] with += (O(n^2) total). Measurable speed-up at fleet scale (1000+
  clusters); no API surface change - the functions still return arrays.

### Sideloaded payload workflow (new)
- New optional cluster tag `UpdateSideloaded` (operator-set: True / False / 1 / 0,
  case-insensitive). When set to False, Start-AzureLocalClusterUpdate blocks the
  update with Status="SideloadedBlocked" and a clear "UpdateSideloaded == False"
  message. Malformed values fail-closed (override with -Force).
- New module-managed cluster tag `UpdateVersionInProgress`. Written by
  Start-AzureLocalClusterUpdate alongside the staged update name (e.g.
  "Solution12.2604.1003.209") to enable the auto-reset match check.
- Fully opt-in: clusters without the `UpdateSideloaded` tag behave exactly as
  in v0.7.0 - updates proceed through the existing schedule / health gates with
  no behavioural change. Start-AzureLocalClusterUpdate still stamps
  `UpdateVersionInProgress` on every started update (used as audit metadata
  and to enable the orphan-tag cleanup path described below); on opted-out
  clusters this tag is removed automatically the next time
  Get-AzureLocalUpdateRuns sees a matching Succeeded run (Action=OrphanCleared).
- Auto-reset in Get-AzureLocalUpdateRuns (default ON, opt-out via
  -SkipSideloadedReset). Returns one of:
  Reset (match success path - both tags flipped/cleared);
  OrphanCleared (UpdateSideloaded absent but stale UpdateVersionInProgress
  matched the latest succeeded run name - orphan tag cleared, UpdateSideloaded
  never written);
  NoTag (cluster fully outside the workflow);
  NoRuns (UpdateSideloaded=True but no run history yet);
  RunNotSucceeded (latest run InProgress / Failed - tag preserved);
  Skipped (already False, malformed, version mismatch, or PATCH failure).
- New public function Reset-AzureLocalSideloadedTag with explicit scope
  (-ClusterNames / -ClusterResourceIds / -ScopeByUpdateRingTag) and -Force escape
  hatch for stuck-tag recovery.
- Set-AzLocalClusterTagsMerge is now idempotent - PATCH is skipped when the
  merge produces no actual change against the cluster's current tags.
- JUnit XML and CSV/HTML reporting recognise the new "SideloadedBlocked" status
  alongside ScheduleBlocked/HealthCheckBlocked.
- RBAC unchanged: relies on existing Microsoft.Resources/tags/read +
  Microsoft.Resources/tags/write permissions already required by the
  UpdateRing/UpdateWindow tag features.

### EndTime column for update runs

- New "EndTime" column on Get-AzureLocalUpdateRuns table output, sourced from the run's
  properties.progress.endTimeUtc (most accurate "work finished" timestamp), falling back
  to properties.lastUpdatedTime for older runs. Blank for InProgress runs.
- Per-run Duration now prefers properties.duration (ARM-reported ISO-8601 timespan) when
  present, falling back to EndTime - StartTime. Authoritative and immune to clock skew.
- Fleet HTML report "Recent Update Run History" now includes End Time column. For the
  aggregated multi-attempt row, EndTime reflects the latest attempt's end time.
- JUnit XML test bodies now include Start Time and End Time lines for each cluster
  testcase (the JUnit time= attribute is unchanged - still seconds).
- New private helper Get-AzLocalRunEndTime centralises the EndTime resolution rule so
  the per-run formatter and the fleet aggregator never drift.

## Version 0.7.0 - Fleet-scale correctness, parallelism, and hardening

The jump from 0.6.5 to 0.7.0 reflects the scope of this release: correctness fixes for large
fleets (1500+ clusters), a shift to true parallel execution across all per-cluster read/write
paths, HTML report performance improvements, and a round of bug and security hardening. No
breaking public-surface changes. Highlights: ARG pagination beyond 1000 results, true
parallel fleet execution, ~60% faster HTML render at 1500 clusters, mid-run token refresh,
CSV formula-injection escaping, UpdateWindow tag separator changed to '_'.

For full release notes on this and previous versions, see:
https://github.com/NeilBird/Azure-Local/blob/main/AzStackHci.ManageUpdates/CHANGELOG.md
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
