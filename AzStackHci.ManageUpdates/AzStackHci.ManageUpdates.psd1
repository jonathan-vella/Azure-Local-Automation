@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'AzStackHci.ManageUpdates.psm1'

    # Version number of this module.
    ModuleVersion = '0.7.0'

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
        'Test-AzureLocalUpdateScheduleAllowed'
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
## Version 0.7.0 - Fleet-scale correctness, parallelism, and hardening

The jump from 0.6.5 to 0.7.0 reflects the scope of this release: correctness fixes for large
fleets (1500+ clusters), a shift to true parallel execution across all per-cluster read/write
paths, HTML report performance improvements, and a round of bug and security hardening driven
by a deep review of the module. No breaking public-surface changes; all new helpers are
private. Az CLI is retained as the ARM transport; a native Invoke-RestMethod port is
deliberately deferred to a future major release.

### Phase 1 - Critical correctness at scale
- Azure Resource Graph pagination: ARG queries now follow the continuation skip-token
  instead of being capped at the first 1000 results, so inventories of more than 1000
  clusters are no longer silently truncated.
- True parallel fleet execution: Invoke-AzureLocalFleetOperation, Get-AzureLocalFleetProgress,
  and Test-AzureLocalFleetHealthGate now use the shared parallel worker pool. -ThrottleLimit
  now controls concurrent API calls, not retry backoff. Default 4, range 1-16.

### Phase 2 - Performance
- Per-cluster read functions (readiness, health, update summary, available updates, tag
  writes) now run in parallel batches.
- HTML report renderer: pre-indexed lookups, encode-at-collection, and deduplicated portal
  URL construction. Roughly 60% faster render at 1500 clusters. UTF-8 output is now written
  without a BOM.
- Opt-in pass-through parameters on state-changing functions to avoid re-fetching data that
  was already collected earlier in the pipeline.

### Phase 3 - Bugs and strict-mode hardening
- All remaining ConvertFrom-Json call sites routed through Invoke-AzRestJson for uniform
  error handling.
- Null/empty guards on health failure and update-run aggregation paths.
- Deterministic secondary sort on update names that lack a parseable YYMM component, with a
  warning emitted instead of silent fallback.
- Per-job CSV logs merged at the end of parallel runs to eliminate line-interleaving under
  Add-Content concurrent writes.
- Robust tag property access for both Hashtable and PSCustomObject tag shapes.
- Unparseable UpdateWindow/UpdateExclusions tags are now treated as blocking unless -Force
  is specified.
- Stop-AzureLocalFleetUpdate and New-AzureLocalFleetStatusHtmlReport now support
  ShouldProcess (-WhatIf / -Confirm). Under -WhatIf, the HTML report still returns the
  composed string to the pipeline so callers can inspect or pipe it without writing to disk.

### Phase 4 - Security
- UpdateRingValue is whitelist-validated before KQL interpolation.
- CSV writer now escapes formula-leader characters (=, +, -, @, tab) and strips embedded
  CR/LF to prevent formula injection when opened in Excel.
- User-supplied output paths are resolved to absolute form, length-capped, and rejected if
  they contain traversal sequences when a relative root was expected.
- Az CLI output is scrubbed before being written to error logs so any accidental password
  or token echo is masked.
- Invoke-AzRestJson now handles mid-run token expiry: on 401 it refreshes the access token
  once and retries.

### Phase 5 - UX and schema refinements
- UpdateWindow tag separator changed from ':' to '_' between the day-spec and time range
  (e.g. "Mon-Fri_22:00-02:00" replaces "Mon-Fri:22:00-02:00"). Breaking for pre-release
  consumers only. Any cluster still on the old tag value will have its updates blocked
  until re-tagged; use Set-AzureLocalClusterUpdateRingTag -UpdateWindowValue to migrate.
- Test-AzureLocalUpdateScheduleAllowed now re-throws parser errors instead of swallowing
  them, so malformed schedule tags correctly reach the caller's fail-closed path.
- Fleet HTML report "Recent Update Run History": one row per cluster (the most recently
  started update), attempts aggregated within that update. New "Update Attempts" column
  (shown only when >1 attempt exists). Duration now uses HH:MM:SS format (survives summed
  multi-day totals) instead of fractional N.N hours.
- Fleet HTML report "Cluster Information" now includes a "Current SBE Version" column,
  propagated through Get-AzureLocalFleetStatusData and both GitHub Actions / Azure DevOps
  fleet-status pipeline YAMLs.
- Start-AzureLocalClusterUpdate -WhatIf output no longer polluted by internal Write-Log /
  CSV / log-folder side effects; only the ARM apply/action call is previewed. -WhatIf runs
  now count as "WouldUpdate" in the final summary.
- New private helper Format-AzLocalDurationHuman (central duration renderer, emits
  "1 hour 23 minutes" style for per-run outputs).

### Notes
- No breaking changes to exported functions or parameter sets.
- Pester suite: 261/261 passing.
- Az CLI remains the ARM transport. Native Invoke-RestMethod migration is explicitly
  out of scope for 0.7.0.

For release notes on previous versions (0.6.5 and earlier), see:
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
