@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'AzStackHci.ManageUpdates.psm1'

    # Version number of this module.
    ModuleVersion = '0.6.2'

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
        # Fleet Status Reporting (v0.6.2)
        'New-AzureLocalFleetStatusHtmlReport'
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
## Version 0.6.2 - Fleet Status HTML Report & Performance
- NEW: `New-AzureLocalFleetStatusHtmlReport` generates self-contained HTML reports for fleet update status
- Collects readiness, update summaries, available updates, health checks, and update run history
- Supports all input methods: -ClusterResourceIds, -ClusterNames, -ScopeByUpdateRingTag, -AllClusters
- -AllClusters switch discovers all clusters via ARG (limited to 100)
- Cluster Information section with name, current version, node count, resource group, resource ID
- Active Update column shows in-progress/failed updates; Recommended Update shows N/A when active update exists
- Recursive update step traversal (up to 8+ levels) with error messages in Current Step column
- Health Check Failures with severity filter checkboxes (Informational hidden by default)
- Collapsible per-cluster health check groups for multi-cluster reports
- Azure Local purple gradient design with embedded instance logo
- Auto-generated title from cluster name for single-cluster reports
- FIXED: RecommendedUpdate now correctly selects latest update by YYMM version sort
- FIXED: -PassThru parameter added to Get-AzureLocalUpdateSummary and Get-AzureLocalAvailableUpdates
- FIXED: CurrentStepDetail property now correctly included in multi-cluster update run output
- PERFORMANCE: All functions resolve -ClusterNames to resource IDs once upfront (eliminates redundant API calls)
- PERFORMANCE: Test-AzureLocalClusterHealth accepts -UpdateSummary to skip redundant fetch
- PERFORMANCE: CI/CD pipelines use -ClusterResourceIds consistently (reduces ~800 to ~300 API calls for 100 clusters)

## Version 0.6.1 - Pre-Update Health Check Validation
- NEW: `Test-AzureLocalClusterHealth` function for pre-update health validation
- IMPROVED: `Start-AzureLocalClusterUpdate` now checks for critical health failures before applying updates
- IMPROVED: `Get-AzureLocalUpdateRuns` shows health check failure details when updates are blocked by health issues

## Version 0.6.0 - Cumulative Update Auto-Selection Fix
- FIXED: Auto-selection now correctly picks the latest cumulative update by YYMM version (was selecting wrong update due to PS 5.1 $Matches scope issue in Sort-Object)
- IMPROVED: Subscription and resource validation with specific error messages for subscription not found, resource group not found, and cluster not found

## Version 0.5.9 - Subscription Validation Enhancement
- IMPROVED: Added explicit subscription validation before resource validation to ensure correct Azure CLI context
- FIXED: Improved error messages for subscription access issues

## Version 0.5.8 - Security Hardening
- Fixed GitHub Actions script injection vulnerability in all workflow examples (apply-updates, fleet-update-status, inventory-clusters, manage-updatering-tags)
- Replaced direct ${{ github.event.inputs.* }} interpolation in run: blocks with env: variable indirection to prevent arbitrary code execution via crafted workflow_dispatch inputs
- Azure DevOps pipeline examples were not affected (compile-time parameter expansion)

## Version 0.5.7
- DOCS: Fixed LICENSE links in module and pipeline READMEs to point to correct URL
- DOCS: Added disclaimer notices to Automation-Pipeline-Examples README

## Version 0.5.6 - Fleet-Scale Operations
- NEW: Invoke-AzureLocalFleetOperation - Orchestrates fleet-wide updates with batching (50 clusters/batch), throttling (10 parallel), and retry logic (3 retries with exponential backoff)
- NEW: Get-AzureLocalFleetProgress - Real-time progress tracking with success/failure percentages and per-cluster status
- NEW: Test-AzureLocalFleetHealthGate - CI/CD health gate with configurable thresholds (max 5% failure, min 90% success) and wait-for-completion
- NEW: Export-AzureLocalFleetState - Save operation state to JSON for resume capability
- NEW: Resume-AzureLocalFleetUpdate - Resume interrupted operations from checkpoint with option to retry failed clusters
- NEW: Stop-AzureLocalFleetUpdate - Graceful stop with state preservation
- ENTERPRISE: Designed for managing 1000-3000+ clusters with checkpoint/resume capability

## Version 0.5.5
- NEW: Get-AzureLocalUpdateSummary now supports multi-cluster queries via -ClusterNames, -ClusterResourceIds, or -ScopeByUpdateRingTag
- NEW: Get-AzureLocalAvailableUpdates now supports multi-cluster queries via -ClusterNames, -ClusterResourceIds, or -ScopeByUpdateRingTag
- NEW: Get-AzureLocalUpdateRuns now supports multi-cluster queries via -ClusterNames, -ClusterResourceIds, or -ScopeByUpdateRingTag
- NEW: All three functions support -ExportPath for CSV, JSON, and JUnit XML export
- NEW: Fleet Update Status CI/CD pipeline for monitoring update status across entire fleet
- NEW: JUnit XML reports for CI/CD dashboard integration
- IMPROVED: Consistent Write-Log output across all functions
- IMPROVED: File logging support when LogFilePath is configured

## Version 0.5.0
- SECURITY: Added comprehensive OpenID Connect (OIDC) documentation for secretless CI/CD authentication
- SECURITY: Documented authentication methods ranked by security (OIDC > Managed Identity > Client Secret)
- IMPROVED: GitHub Actions workflows now default to OIDC with id-token: write permission
- IMPROVED: Added Azure DevOps Workload Identity Federation setup instructions
- DOCS: Added authentication comparison table with security ratings
- DOCS: Updated Quick Start with OIDC examples and federated credential setup links

## Version 0.4.2
- DOCS: Verified and documented all functions work with three authentication methods: Interactive (az login), Service Principal, and Managed Identity (MSI)

## Version 0.4.1
- NEW: Managed Identity (MSI) authentication support via -UseManagedIdentity switch in Connect-AzureLocalServicePrincipal
- NEW: -ManagedIdentityClientId parameter for user-assigned managed identities
- NEW: -PassThru switch for Get-AzureLocalClusterInventory to return objects when exporting to CSV
- FIXED: Azure Resource Graph queries returning incorrect resource types due to HERE-STRING query format
- FIXED: Set-AzureLocalClusterUpdateRingTag JSON deserialization errors (now uses temp file)
- FIXED: PowerShell hashtable internal properties being included in JSON body
- IMPROVED: Get-AzureLocalClusterInventory no longer dumps objects to console when using -ExportPath

## Version 0.4.0
- NEW: Get-AzureLocalClusterInventory function to query all clusters and their UpdateRing tag status
- NEW: CSV-based workflow for managing UpdateRing tags (export inventory, edit in Excel, import back)
- NEW: Set-AzureLocalClusterUpdateRingTag now accepts -InputCsvPath parameter for bulk tag operations
- NEW: JUnit XML export for CI/CD pipeline integration (Azure DevOps, GitHub Actions, Jenkins, GitLab CI)
- IMPROVED: Renamed -ScopeByTagName to -ScopeByUpdateRingTag for clarity (now a switch parameter)
- IMPROVED: Renamed -TagValue to -UpdateRingValue for consistency
- IMPROVED: UpdateRing tag queries now use hardcoded 'UpdateRing' tag name for consistency
- IMPROVED: -ExportResultsPath and -ExportPath now support .xml extension for JUnit format
- FIXED: PSScriptAnalyzer warnings (empty catch blocks, unused variables)

## Version 0.3.0
- NEW: Connect-AzureLocalServicePrincipal function for CI/CD automation (GitHub Actions, Azure DevOps)
- NEW: Service Principal authentication via parameters or environment variables (AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID)
- IMPROVED: All functions now have [OutputType()] attributes for better IntelliSense
- IMPROVED: Centralized API version constant for consistency
- IMPROVED: Renamed internal function to use approved verb (Install-AzGraphExtension)
- IMPROVED: Write-Log is now internal only (not exported)
- IMPROVED: Added #Requires -Version 5.1 statement
- IMPROVED: Added LicenseUri to manifest for PowerShell Gallery compliance
- IMPROVED: Added 'Automation' and 'CICD' tags for discoverability

## Version 0.2.0
- NEW: Set-AzureLocalClusterUpdateRingTag function to manage UpdateRing tags on clusters
- NEW: Auto-install Azure CLI resource-graph extension for pipeline/automation scenarios
- NEW: Tag-based cluster filtering using -ScopeByUpdateRingTag and -UpdateRingValue parameters
- IMPROVED: Health check filtering now shows only Critical and Warning severities (not Informational)
- IMPROVED: Enhanced CSV diagnostics with health check failures and update run error details
- IMPROVED: Get-AzureLocalClusterUpdateReadiness now supports tag-based scoping
- FIX: Corrected API path for querying update run errors
- Added -Force parameter support for tag operations to overwrite existing tags
- Comprehensive logging for all tag operations with CSV output

## Version 0.1.0
- Initial release
- Start-AzureLocalClusterUpdate: Start updates on one or more Azure Local clusters
- Get-AzureLocalClusterUpdateReadiness: Assess update readiness with diagnostics
- Get-AzureLocalClusterInfo: Retrieve cluster information
- Get-AzureLocalUpdateSummary: Get update summary for a cluster
- Get-AzureLocalAvailableUpdates: List available updates for a cluster
- Get-AzureLocalUpdateRuns: Monitor update progress
- Write-Log: Logging utility function
- Comprehensive logging with transcript support
- Export results to JSON/CSV
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
