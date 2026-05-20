# Smoke test for the Step.4 fleet-connectivity-status pipeline ARG queries.
#
# Runs each of the 5 KQL queries that the GH / ADO Step.4 YAMLs execute via
# `az graph query`, verifies the query parses + executes cleanly, and asserts
# the documented required-column set is present on the first returned row.
#
# Mirrors the validate-arg-queries.ps1 reporting shape (PASS / PASS-EMPTY /
# FAIL-SCHEMA / ERROR rows in a final results table) so the two harnesses can
# be wired into the same CI matrix later.
#
# Requires: `az login` already done, `az extension add --name resource-graph`,
# and the federated identity / signed-in user has Reader on the target
# subscriptions. Queries are paged ONCE (no $skipToken loop) - matches the
# pipeline behaviour and its known 1000-row ceiling per query.
$ErrorActionPreference = 'Stop'

$results = [System.Collections.Generic.List[object]]::new()

function Invoke-ArgQuery {
    param(
        [Parameter(Mandatory)][string]$Query,
        [string[]]$ExtraArgs = @()
    )
    $argList = @('graph','query','-q',$Query,'--first','1000','--output','json') + $ExtraArgs
    $raw = & az @argList 2>&1
    if ($LASTEXITCODE -ne 0) { throw "az graph query failed (exit=$LASTEXITCODE): $raw" }
    $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
    if ($null -eq $parsed -or -not $parsed.PSObject.Properties.Match('data').Count) { return @() }
    return @($parsed.data)
}

function Test-Query {
    param(
        [string]$Name,
        [string]$Query,
        [string[]]$RequiredColumns
    )
    Write-Host "`n=== $Name ===" -ForegroundColor Cyan
    try {
        $rows = Invoke-ArgQuery -Query $Query
        $rowCount = @($rows).Count
        Write-Host "Returned $rowCount row(s)" -ForegroundColor Yellow
        if ($rowCount -gt 0) {
            $cols = $rows[0].PSObject.Properties.Name
            $missing = @($RequiredColumns | Where-Object { $cols -notcontains $_ })
            if ($missing.Count -eq 0) {
                Write-Host "All required columns present" -ForegroundColor Green
                $results.Add([PSCustomObject]@{ Query=$Name; Status='PASS'; Rows=$rowCount; Missing=''; Error='' })
            } else {
                Write-Host "MISSING columns: $($missing -join ', ')" -ForegroundColor Red
                $results.Add([PSCustomObject]@{ Query=$Name; Status='FAIL-SCHEMA'; Rows=$rowCount; Missing=($missing -join ','); Error='' })
            }
        } else {
            Write-Host "Returned 0 rows (still validates query parse + execution)" -ForegroundColor Yellow
            $results.Add([PSCustomObject]@{ Query=$Name; Status='PASS-EMPTY'; Rows=0; Missing=''; Error='' })
        }
    }
    catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $results.Add([PSCustomObject]@{ Query=$Name; Status='ERROR'; Rows=0; Missing=''; Error=$_.Exception.Message })
    }
}

# ---------------------------------------------------------------------------
# 1. Cluster connectivity
# ---------------------------------------------------------------------------
$clusterKql = @"
resources
| where type =~ "microsoft.azurestackhci/clusters"
| extend ConnectivityStatus = tostring(properties.connectivityStatus)
| extend ClusterStatus = tostring(properties.status)
| extend NodeCount = tolong(properties.reportedProperties.nodeCount)
| project ClusterName=name, ClusterId=id, ResourceGroup=resourceGroup, SubscriptionId=subscriptionId,
          ConnectivityStatus, ClusterStatus, NodeCount, Location=location
| order by ConnectivityStatus asc, ClusterName asc
"@
Test-Query -Name 'Cluster Connectivity' -Query $clusterKql -RequiredColumns @(
    'ClusterName','ClusterId','ResourceGroup','SubscriptionId','ConnectivityStatus','ClusterStatus','NodeCount','Location'
)

# ---------------------------------------------------------------------------
# 2a. Arc agent status summary (histogram)
# ---------------------------------------------------------------------------
$arcSummaryKql = @"
resources
| where type =~ "microsoft.azurestackhci/clusters"
| extend nodes = todynamic(properties.reportedProperties.nodes)
| mv-expand node = nodes
| extend reportedNodeName = tolower(tostring(node.name))
| where isnotempty(reportedNodeName)
| project reportedNodeName
| join kind=inner (
    resources
    | where type =~ "microsoft.hybridcompute/machines"
    | where tostring(properties.cloudMetadata.provider) =~ "AzSHCI"
    | where tostring(kind) !~ "HCI"
    | extend nodeNameLower = tolower(name)
  ) on `$left.reportedNodeName == `$right.nodeNameLower
| extend AgentStatus = tostring(properties.status)
| summarize Count = count() by AgentStatus
| order by Count desc
"@
Test-Query -Name 'Arc Agent Status Summary' -Query $arcSummaryKql -RequiredColumns @('AgentStatus','Count')

# ---------------------------------------------------------------------------
# 2b. Non-connected machines (detail)
# ---------------------------------------------------------------------------
$arcKql = @"
resources
| where type =~ "microsoft.azurestackhci/clusters"
| extend nodes = todynamic(properties.reportedProperties.nodes)
| mv-expand node = nodes
| extend reportedNodeName = tolower(tostring(node.name))
| where isnotempty(reportedNodeName)
| project reportedNodeName, clusterName = name, clusterResourceGroup = resourceGroup, clusterId = id
| join kind=leftouter (
    extensibilityresources
    | where type =~ "microsoft.azurestackhci/clusters/updateSummaries"
    | extend cId = substring(id, 0, indexof(id, "/updateSummaries/"))
    | project cId, currentVersion = tostring(properties.currentVersion)
  ) on `$left.clusterId == `$right.cId
| join kind=inner (
    resources
    | where type =~ "microsoft.hybridcompute/machines"
    | where tostring(properties.cloudMetadata.provider) =~ "AzSHCI"
    | where tostring(kind) !~ "HCI"
    | extend nodeNameLower = tolower(name)
  ) on `$left.reportedNodeName == `$right.nodeNameLower
| where tostring(properties.status) != "Connected"
| extend AgentStatus    = tostring(properties.status)
| extend AgentVersion   = tostring(properties.agentVersion)
| extend OsSku          = tostring(properties.osSku)
| extend OsVersion      = tostring(properties.osVersion)
| extend LastStatusChange = tostring(properties.lastStatusChange)
| project NodeName=name, MachineId=id, ClusterName=clusterName, ClusterId=clusterId,
          AgentStatus, OsSku, OsVersion, ClusterVersion=coalesce(currentVersion, ""),
          AgentVersion, LastStatusChange,
          ResourceGroup=resourceGroup, SubscriptionId=subscriptionId
| order by LastStatusChange asc, ClusterName asc, NodeName asc
"@
Test-Query -Name 'Non-Connected Arc Machines' -Query $arcKql -RequiredColumns @(
    'NodeName','MachineId','ClusterName','ClusterId','AgentStatus','OsSku','OsVersion','ClusterVersion','AgentVersion','LastStatusChange','ResourceGroup','SubscriptionId'
)

# ---------------------------------------------------------------------------
# 3a. Physical NIC issues (filtered)
# ---------------------------------------------------------------------------
$nicKql = @"
extensibilityresources
| where type =~ "microsoft.azurestackhci/edgedevices"
| extend nicDetails = todynamic(properties.reportedProperties.networkProfile.nicDetails)
| extend edgeMachineName = tolower(tostring(split(id, '/')[8]))
| mv-expand nic = nicDetails
| extend NicName = tostring(nic.adapterName)
| extend NicStatus = tostring(nic.nicStatus)
| extend DriverVersion = tostring(nic.driverVersion)
| extend InterfaceDescription = tostring(nic.interfaceDescription)
| extend Ip4Address = tostring(nic.ip4Address)
| extend NicType = case(InterfaceDescription contains "Hyper-V", "Virtual", InterfaceDescription contains "Virtual", "Virtual", "Physical")
| where NicType == "Physical"
| where NicStatus =~ "Disconnected"
| where isnotempty(Ip4Address) and not(Ip4Address startswith "169.254.")
| join kind=inner (
    resources
    | where type =~ "microsoft.hybridcompute/machines"
    | where tostring(properties.cloudMetadata.provider) =~ "AzSHCI"
    | where tostring(kind) !~ "HCI"
    | extend ClusterName = tostring(split(tostring(properties.parentClusterResourceId), '/')[8])
    | extend nodeNameLower = tolower(name)
    | project nodeNameLower, ClusterName, MachineId=id, ResourceGroup=resourceGroup, SubscriptionId=subscriptionId
  ) on `$left.edgeMachineName == `$right.nodeNameLower
| project NodeName=edgeMachineName, ClusterName, NicName, NicStatus, DriverVersion, Ip4Address,
          InterfaceDescription, MachineId, ResourceGroup, SubscriptionId
| order by ClusterName asc, NodeName asc, NicName asc
"@
Test-Query -Name 'Physical NIC Issues (filtered)' -Query $nicKql -RequiredColumns @(
    'NodeName','ClusterName','NicName','NicStatus','DriverVersion','Ip4Address','InterfaceDescription','MachineId','ResourceGroup','SubscriptionId'
)

# ---------------------------------------------------------------------------
# 3b. All Network Adapters (full unfiltered NIC inventory)
# ---------------------------------------------------------------------------
$nicAllKql = @"
extensibilityresources
| where type =~ "microsoft.azurestackhci/edgedevices"
| extend edgeMachineName = tolower(tostring(split(id, '/')[8]))
| extend edgeDeviceRG = resourceGroup
| extend nicDetails = todynamic(properties.reportedProperties.networkProfile.nicDetails)
| mv-expand nic = nicDetails
| extend NicName = tostring(nic.adapterName)
| extend NicStatus = tostring(nic.nicStatus)
| extend DriverVersion = tostring(nic.driverVersion)
| extend InterfaceDescription = tostring(nic.interfaceDescription)
| extend NicType = case(InterfaceDescription contains "Hyper-V", "Virtual", InterfaceDescription contains "Virtual", "Virtual", "Physical")
| extend Ip4Address = tostring(nic.ip4Address)
| extend SubnetMask = tostring(nic.subnetMask)
| extend DefaultGateway = tostring(nic.defaultGateway)
| extend DnsServers = strcat_array(nic.dnsServers, ', ')
| extend MacAddress = tostring(nic.macAddress)
| join kind=inner (
    resources
    | where type =~ "microsoft.hybridcompute/machines"
    | where tostring(properties.cloudMetadata.provider) =~ "AzSHCI"
    | where tostring(kind) !~ "HCI"
    | extend parentClusterId = tostring(properties.parentClusterResourceId)
    | extend ClusterName = tostring(split(parentClusterId, '/')[8])
    | extend MachineStatus = tostring(properties.status)
    | extend nodeNameLower = tolower(name)
    | project machineName=name, nodeNameLower, MachineId=id, ClusterId=parentClusterId, ClusterName, MachineStatus, SubscriptionId=subscriptionId
  ) on `$left.edgeMachineName == `$right.nodeNameLower
| project NodeName=machineName, MachineId, ClusterName, ClusterId, MachineConnectivity=MachineStatus,
          NicName, NicType, NicStatus, DriverVersion, InterfaceDescription,
          Ip4Address, SubnetMask, DefaultGateway, DnsServers, MacAddress,
          ResourceGroup=edgeDeviceRG, SubscriptionId
| order by NodeName asc, NicType asc, NicName asc
"@
Test-Query -Name 'All Network Adapters (unfiltered)' -Query $nicAllKql -RequiredColumns @(
    'NodeName','MachineId','ClusterName','ClusterId','MachineConnectivity','NicName','NicType','NicStatus',
    'DriverVersion','InterfaceDescription','Ip4Address','SubnetMask','DefaultGateway','DnsServers','MacAddress',
    'ResourceGroup','SubscriptionId'
)

# ---------------------------------------------------------------------------
# 4. ARB status (multi-cluster-per-RG safe via summarize/make_set)
# ---------------------------------------------------------------------------
$arbKql = @"
resources
| where type =~ "microsoft.resourceconnector/appliances"
| extend ArbStatus = tostring(properties.status)
| extend LastModified = tostring(systemData.lastModifiedAt)
| extend DaysSinceLastModified = iff(ArbStatus =~ "Running", toint(-1), datetime_diff('day', now(), todatetime(systemData.lastModifiedAt)))
| project ArbName=name, ArbId=id, ArbResourceGroup=resourceGroup, ArbSubscriptionId=subscriptionId,
          ArbStatus, LastModified, DaysSinceLastModified
| join kind=leftouter (
    resources
    | where type =~ "microsoft.azurestackhci/clusters"
    | extend ClusterStatus = tostring(properties.status)
    | project HciName=name, HciId=id, HciResourceGroup=resourceGroup, HciClusterStatus=ClusterStatus
  ) on `$left.ArbResourceGroup == `$right.HciResourceGroup
| summarize
    ClusterName = strcat_array(make_set(coalesce(HciName, '(no cluster)')), ', '),
    ClusterId = strcat_array(make_set(coalesce(HciId, '')), ', '),
    ClusterStatus = strcat_array(make_set(coalesce(HciClusterStatus, '')), ', ')
    by ArbName, ArbId, ArbResourceGroup, ArbSubscriptionId, ArbStatus, LastModified, DaysSinceLastModified
| project ArbName, ArbStatus, ClusterName, ClusterId, ClusterStatus, LastModified, DaysSinceLastModified,
          ArbId, ResourceGroup=ArbResourceGroup, SubscriptionId=ArbSubscriptionId
| order by ArbStatus asc, ClusterName asc
"@
Test-Query -Name 'ARB Status (multi-cluster-safe)' -Query $arbKql -RequiredColumns @(
    'ArbName','ArbStatus','ClusterName','ClusterId','ClusterStatus','LastModified','DaysSinceLastModified','ArbId','ResourceGroup','SubscriptionId'
)

# ---------------------------------------------------------------------------
# Final report
# ---------------------------------------------------------------------------
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Smoke Test Results - Step.4 Connectivity ARG Queries" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
$results | Format-Table -AutoSize Query, Status, Rows, Missing, Error

$fail = @($results | Where-Object { $_.Status -in @('FAIL-SCHEMA','ERROR') })
if ($fail.Count -gt 0) {
    Write-Host "FAILED: $($fail.Count) query/queries did not pass." -ForegroundColor Red
    exit 1
} else {
    Write-Host "All queries passed." -ForegroundColor Green
}
