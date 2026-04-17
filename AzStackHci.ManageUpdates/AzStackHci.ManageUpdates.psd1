@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'AzStackHci.ManageUpdates.psm1'

    # Version number of this module.
    ModuleVersion = '0.6.4'

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
## Version 0.6.4 - Improved update readiness checks: HasPrerequisite, Az CLI Check & Fleet Status Data

### Security & Code Quality (2026-04-17 revision)
- SECURITY: Connect-AzureLocalServicePrincipal now accepts -ServicePrincipalSecret as [SecureString] (preferred) or [string] with a security warning. Plaintext secret memory is scrubbed after az login returns.
- NEW: Invoke-AzRestJson internal helper centralises az rest invocation with safe LASTEXITCODE checks and ConvertFrom-Json error handling.
- NEW: ConvertTo-AzLocalAdditionalProperties internal helper safely parses ARM additionalProperties (all 5 SBE-parse call sites now use it).
- FIXED: Get-AzureLocalFleetStatusData parallel Start-Job path - module path validated, accumulators use List[object] instead of O(n squared) += pattern, and failed jobs surface affected clusters via new FailedClusters result property.
- IMPROVED: Auth/Az CLI installer functions use Write-Log instead of Write-Host for CI-friendly logging.
- IMPROVED: Test-AzCliAvailable MSI install uses 30-minute timeout to prevent indefinite hangs.
- FIXED: Test-AzureLocalUpdateScheduleAllowed ExclusionActive return simplified (behaviour-preserving clarity fix).

### Inter-Function & Fleet-Scale Fixes (2026-04-17 revision)
- FIXED: Test-AzureLocalUpdateScheduleAllowed and Test-AzLocalUpdateWindow normalise non-UTC -TestTime (Local/Unspecified DateTimeKind) to UTC with a Verbose note. Previously callers passing Get-Date (local time) could silently evaluate the wrong maintenance-window hour/day.
- FIXED: Get-LatestUpdateByYYMM now emits a Verbose warning when no input name matches Solution<XX>.<YYMM>.<build>.<rev>. Previously, when every input failed to parse, all entries mapped to YYMM=0 and the arbitrary first element of a stable sort was returned.
- IMPROVED: Get-AzureLocalAvailableUpdates -ClusterResourceId (SingleCluster) now prints banner + Summary + Format-Table, matching multi-cluster UX. Passing -Raw preserves the legacy silent behaviour for internal callers.

### Original 0.6.4 content
- NEW: Test-AzCliAvailable internal helper checks if Azure CLI (az) is installed before any az invocation
- NEW: Get-AzureLocalFleetStatusData function for efficient single-pass fleet data collection with parallel Start-Job support
- NEW: -ThrottleLimit parameter (default: 4, max: 8) splits cluster list into parallel batches via Start-Job
- NEW: -ExportPath exports fleet data as JSON artifact for CI/CD pipeline job passing
- NEW: -StatusData parameter on New-AzureLocalFleetStatusHtmlReport accepts pre-collected data to skip API calls
- NEW: Stable JSON schema (v1.0) with SchemaVersion, Timestamp, ModuleVersion, Scope, Readiness, ClusterDetails, LatestRuns, HealthResults
- IMPROVED: All per-update state filters now use module-level constants aligned with LENS workbook v0.8.6 states
- IMPROVED: ReadyToInstall state recognized alongside Ready across all functions
- IMPROVED: HasPrerequisite/SBE dependency awareness across Get-AzureLocalAvailableUpdates, Start-AzureLocalClusterUpdate, Get-AzureLocalClusterUpdateReadiness, Get-AzureLocalFleetStatusData
- PERF: New-AzureLocalFleetStatusHtmlReport uses single-pass data collection (~63% API call reduction)
- FIXED: Az CLI availability check prevents unhelpful CommandNotFoundException errors
- FIXED: 'Up to Date' counter now recognizes 'AppliedSuccessfully' state from ARM API
- FIXED: Recommended Update no longer shows the version a cluster is already on when state is AppliedSuccessfully/UpToDate

For release notes on previous versions (0.6.3 and earlier), see:
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
