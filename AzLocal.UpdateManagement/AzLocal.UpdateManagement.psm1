#Requires -Version 5.1
<#
.SYNOPSIS
    AzLocal.UpdateManagement module for automating updates on Azure Local (formerly Azure Stack HCI) clusters.

.DESCRIPTION
    This module queries Azure Local clusters by name or resource ID, checks their update status,
    and starts specified updates on clusters that are in "Ready" state with "UpdatesAvailable".

    It uses the Azure REST API directly via az rest to call the Update Manager API.

    Includes comprehensive logging capabilities with timestamped log files,
    transcript support, and result export to JSON/CSV.

    Supports Service Principal authentication for CI/CD automation scenarios
    (GitHub Actions, Azure DevOps Pipelines).

    NOTE: Renamed from AzStackHci.ManageUpdates in v0.7.3. Module GUID is preserved
    across the rename. See CHANGELOG.md and the v0.7.3 release notes in the manifest
    for migration guidance.

.PARAMETER ClusterNames
    An array of Azure Local cluster names to update. Use this OR ClusterResourceIds.

.PARAMETER ClusterResourceIds
    An array of full Azure Resource IDs for the clusters to update. Use this when clusters
    are in different resource groups or subscriptions. Use this OR ClusterNames.
    
    The Resource IDs are validated before processing to ensure:
    - The format is correct (must match Azure Stack HCI cluster resource pattern)
    - The resource exists in Azure
    - You have the required permissions to access the resource
    
    Example: "/subscriptions/xxx/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01"

.PARAMETER ScopeByUpdateRingTag
    Uses the "UpdateRing" tag to find clusters via Azure Resource Graph.
    Must be used together with -UpdateRingValue. This enables updating clusters at scale
    using the UpdateRing tagging strategy. Works across multiple subscriptions.
    
    Requires the Azure CLI 'resource-graph' extension (automatically installed if missing).

.PARAMETER UpdateRingValue
    The value of the UpdateRing tag to match when using -ScopeByUpdateRingTag. Only clusters 
    where the UpdateRing tag equals this value will be selected for updates.
    Common values: "Ring1", "Ring2", "Ring3", "Production"

.PARAMETER ResourceGroupName
    The resource group containing the clusters. If not specified, the function will 
    search for the cluster across all resource groups in the subscription.
    Only used with -ClusterNames parameter.

.PARAMETER SubscriptionId
    The Azure subscription ID. If not specified, uses the current az CLI subscription.
    Only used with -ClusterNames parameter.

.PARAMETER UpdateName
    The specific update name to apply. If not specified, the function will list 
    available updates and prompt for selection or apply the latest available update.

.PARAMETER ApiVersion
    The API version to use. Defaults to "2025-10-01".

.PARAMETER LogFolderPath
    Path to the folder where log files will be created. If not specified, defaults to:
    C:\ProgramData\AzLocal.UpdateManagement\
    
    This default location is accessible across different user profiles.
    The folder is automatically created if it doesn't exist.

.PARAMETER EnableTranscript
    Enables PowerShell transcript recording to capture all console output.

.PARAMETER ExportResultsPath
    Path to export results. Supports multiple formats based on file extension:
    - .json = JSON format with summary statistics
    - .csv  = Standard CSV format
    - .xml  = JUnit XML format for CI/CD pipeline integration
    
    JUnit XML is compatible with:
    - Azure DevOps (Publish Test Results task)
    - GitHub Actions (dorny/test-reporter or similar)
    - Jenkins (JUnit plugin)
    - GitLab CI (native support)
    - TeamCity (built-in)
    
    If no extension is provided, defaults to JSON.

.PARAMETER WhatIf
    Shows what would happen if the cmdlet runs. The cmdlet is not run.

.EXAMPLE
    # Start update on a single cluster with logging
    Start-AzureLocalClusterUpdate -ClusterNames "MyCluster01" -ResourceGroupName "MyRG" -LogPath "C:\Logs\update.log"

.EXAMPLE
    # Start updates on multiple clusters with transcript and JSON export
    Start-AzureLocalClusterUpdate -ClusterNames @("Cluster01", "Cluster02") -EnableTranscript -ExportResultsPath "C:\Logs\results.json"

.EXAMPLE
    # Start a specific update with full logging
    Start-AzureLocalClusterUpdate -ClusterNames "MyCluster01" -UpdateName "Solution12.2601.1002.38" -LogPath "C:\Logs\update.log" -EnableTranscript

.EXAMPLE
    # Start updates on clusters in different resource groups using Resource IDs
    $resourceIds = @(
        "/subscriptions/xxx/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01",
        "/subscriptions/xxx/resourceGroups/RG2/providers/Microsoft.AzureStackHCI/clusters/Cluster02"
    )
    Start-AzureLocalClusterUpdate -ClusterResourceIds $resourceIds -Force

.EXAMPLE
    # Start updates on all clusters tagged with "UpdateRing" = "Ring1" (across all subscriptions)
    Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Ring1" -Force

.EXAMPLE
    # Start updates on production ring clusters
    Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Production" -UpdateName "Solution12.2601.1002.38" -Force

.EXAMPLE
    # Export results to JUnit XML for CI/CD pipeline integration (Azure DevOps, GitHub Actions, Jenkins)
    Start-AzureLocalClusterUpdate -ScopeByUpdateRingTag -UpdateRingValue "Ring1" -Force -ExportResultsPath "C:\Logs\update-results.xml"

.NOTES
    Author: Neil Bird, Microsoft. 
    Requires: Azure CLI (az) installed and authenticated
    API Reference: https://github.com/Azure/azure-rest-api-specs/blob/main/specification/azurestackhci/resource-manager/Microsoft.AzureStackHCI/StackHCI/stable/2026-02-01/hci.json
#>

# Enforce defensive coding at module scope.
# Version 1.0 catches references to uninitialized variables (e.g. $cluster vs $clusterEntry typos).
# Deliberately NOT -Version Latest: Azure ARM REST responses legitimately omit optional
# properties (e.g. additionalProperties.SBEPublisher, tags.UpdateRing), and Latest would
# throw on every such dot-notation access. Hardening those sites is tracked separately.
Set-StrictMode -Version 1.0

# Module constants
$script:ModuleVersion = '0.7.66'
$script:DefaultApiVersion = '2025-10-01'
$script:DefaultLogFolder = Join-Path -Path $env:ProgramData -ChildPath 'AzLocal.UpdateManagement'

# Best-effort default for PYTHONIOENCODING. az.cmd launches python with the -I
# (isolated) flag which implies -E and so causes python to IGNORE all PYTHON*
# environment variables - meaning this assignment alone is NOT sufficient to
# stop the cp1252 encode warning. The actual fixes live in two helpers:
#   1. Invoke-AzRestJson passes --only-show-errors to every az invocation
#      (v0.7.2 hardening) so warning lines stay out of stdout.
#   2. Invoke-AzResourceGraphQuery splits the merged 2>&1 capture by element
#      type after capture (v0.7.66): stderr surfaces as ErrorRecord objects
#      and only the string stdout is fed to ConvertFrom-Json.
# This module-load assignment is retained as harmless defence-in-depth for
# the case where the user has manually patched az.cmd to remove -I, or is
# running in an environment that respects the env var. See:
# https://github.com/Azure/azure-cli/issues/14426 (recommended workaround),
# https://github.com/Azure/azure-cli/issues/28497 (-I behaviour confirmation).
if (-not $env:PYTHONIOENCODING) {
    $env:PYTHONIOENCODING = 'utf-8'
}

# Update state constants aligned with queries in Azure Local LENS workbook
# States that indicate an update is installable (ready to apply)
$script:ReadyStates = @('Ready', 'ReadyToInstall')
# States that indicate an update is blocked by a prerequisite
$script:PrereqStates = @('HasPrerequisite', 'AdditionalContentRequired')
# States that indicate an update failed health validation
$script:HealthCheckFailedStates = @('HealthCheckFailed')
# States that indicate an update is in a transitional phase
$script:TransitionalStates = @('Downloading', 'Preparing', 'HealthChecking')

# Script-level variables for logging
$script:LogFilePath = $null
$script:ErrorLogPath = $null
$script:UpdateSkippedLogPath = $null
$script:UpdateStartedLogPath = $null

# Service Principal authentication state
$script:ServicePrincipalAuthenticated = $false


# ---------------------------------------------------------------------------
# Module-scope state hoisted from between function definitions during refactor.
# These declarations must run BEFORE any function body that references them.
# ---------------------------------------------------------------------------
$script:UpdateWindowTagName = 'UpdateWindow'

$script:UpdateExclusionsTagName = 'UpdateExclusions'

$script:UpdateSideloadedTagName = 'UpdateSideloaded'

$script:UpdateVersionInProgressTagName = 'UpdateVersionInProgress'

$script:DayMap = [ordered]@{
    'Mon' = [DayOfWeek]::Monday
    'Tue' = [DayOfWeek]::Tuesday
    'Wed' = [DayOfWeek]::Wednesday
    'Thu' = [DayOfWeek]::Thursday
    'Fri' = [DayOfWeek]::Friday
    'Sat' = [DayOfWeek]::Saturday
    'Sun' = [DayOfWeek]::Sunday
}

$script:DayAbbreviations = @('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun')

$script:FleetOperationState = $null

# ---------------------------------------------------------------------------
# Dot-source all function files listed in the manifest's NestedModules.
# When loaded via the .psd1, these are already imported by NestedModules; this
# loop is a harmless no-op in that case (PowerShell tolerates redefinition).
# When loaded via the .psm1 directly (e.g. some Pester scenarios), this
# guarantees all functions are present in the module scope.
# ---------------------------------------------------------------------------
$manifestPath = Join-Path -Path $PSScriptRoot -ChildPath 'AzLocal.UpdateManagement.psd1'
if (Test-Path -LiteralPath $manifestPath) {
    $manifestData = Import-PowerShellDataFile -LiteralPath $manifestPath -ErrorAction SilentlyContinue
    if ($manifestData -and $manifestData.NestedModules) {
        foreach ($nestedModule in $manifestData.NestedModules) {
            $nestedPath = Join-Path -Path $PSScriptRoot -ChildPath $nestedModule
            if (Test-Path -LiteralPath $nestedPath) {
                . $nestedPath
            }
        }
    }
}
Export-ModuleMember -Function @(
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
    # Update Schedule Tag Helpers (v0.6.5)
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