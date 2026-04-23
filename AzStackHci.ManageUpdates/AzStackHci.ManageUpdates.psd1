@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'AzStackHci.ManageUpdates.psm1'

    # Version number of this module.
    ModuleVersion = '0.6.5'

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
## Version 0.6.5 - Fix Set-AzureLocalClusterUpdateRingTag to actually set UpdateWindow / UpdateExclusions tags

### Fixed
- FIXED (HIGH): Set-AzureLocalClusterUpdateRingTag silently ignored the UpdateWindow and UpdateExclusions columns from a CSV produced by Get-AzureLocalClusterInventory. Inside the processing loop, four references used an undefined variable ($cluster) instead of the actual loop variable ($clusterEntry), so:
  - Clusters with an existing UpdateRing tag were skipped even when the CSV changed UpdateWindow/UpdateExclusions (the "has new schedule tags" detection always evaluated to false).
  - On new or forced writes the PATCH body only contained UpdateRing; UpdateWindow/UpdateExclusions columns from the CSV were never sent to Azure.
  - Because Set-StrictMode is not enforced at module scope, the typo silently returned $null instead of throwing.

### Added
- NEW: -UpdateWindowValue and -UpdateExclusionsValue optional parameters on Set-AzureLocalClusterUpdateRingTag -ClusterResourceIds. Direct-invocation mode is now symmetrical with CSV mode and can set all three tags (UpdateRing, UpdateWindow, UpdateExclusions) in a single PATCH operation. Both parameters are also written into the CSV operations log.
- NEW: Set-StrictMode -Version 1.0 is now enforced at module scope. Catches references to uninitialized variables (the class of bug above) at runtime instead of silently returning $null. All 239 Pester tests pass unchanged. Latest was deliberately not selected because ARM REST responses legitimately omit optional properties.

### Notes
- No API or JSON schema changes. No breaking changes.
- Round-trip Get-AzureLocalClusterInventory -> edit CSV -> Set-AzureLocalClusterUpdateRingTag now correctly preserves all three tag columns.

For release notes on previous versions (0.6.4 and earlier), see:
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
