function Get-AzLocalFleetProgress {
    <#
    .SYNOPSIS
        Gets real-time progress of a fleet-wide update operation.
    
    .DESCRIPTION
        Queries the current status of all clusters in a fleet operation and returns
        aggregated progress information including:
        - Total, completed, in-progress, failed, pending counts
        - Estimated time remaining (based on average completion time)
        - Per-cluster status details
        
        Can be used with a state object from Invoke-AzLocalFleetOperation or
        by querying clusters directly by tag.
    
    .PARAMETER State
        A fleet operation state object. If provided, only checks clusters in this state.
    
    .PARAMETER ScopeByUpdateRingTag
        Query progress for clusters with a specific UpdateRing tag.
    
    .PARAMETER UpdateRingValue
        The UpdateRing tag value to filter by.
    
    .PARAMETER Detailed
        Include detailed per-cluster status in output.

    .EXAMPLE
        Get-AzLocalFleetProgress -State $fleetState
        Gets progress for clusters in the specified fleet operation.

    .EXAMPLE
        Get-AzLocalFleetProgress -ScopeByUpdateRingTag -UpdateRingValue "Production"
        Gets progress for all Production ring clusters.

    .EXAMPLE
        Get-AzLocalFleetProgress -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Detailed
        Gets detailed progress (returns per-cluster status rows on the output object).
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByState')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false, ParameterSetName = 'ByState')]
        [PSCustomObject]$State,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [switch]$ScopeByUpdateRingTag,

        [ValidatePattern('^(\*\*\*|[A-Za-z0-9_-]{1,64}(;[A-Za-z0-9_-]{1,64})*)$')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [string]$UpdateRingValue,

        [Parameter(Mandatory = $false)]
        [switch]$Detailed
    )
    
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Fleet Update Progress Check" -Level Header
    Write-Log -Message "========================================" -Level Header
    
    # Get list of clusters to check
    $clustersToCheck = @()
    
    if ($PSCmdlet.ParameterSetName -eq 'ByState') {
        $stateToUse = if ($State) { $State } else { $script:FleetOperationState }
        if (-not $stateToUse) {
            Write-Warning "No fleet state available. Use -ScopeByUpdateRingTag or provide a state object."
            return $null
        }
        $clustersToCheck = $stateToUse.Clusters
        Write-Log -Message "Checking progress for Run ID: $($stateToUse.RunId)" -Level Info
    }
    else {
        # Query by tag
        Write-Log -Message "Querying clusters with UpdateRing = '$UpdateRingValue'..." -Level Info
        $inventory = Get-AzLocalClusterInventory -PassThru | Where-Object { $_.UpdateRing -eq $UpdateRingValue }
        if (-not $inventory) {
            Write-Warning "No clusters found with UpdateRing tag = '$UpdateRingValue'"
            return $null
        }
        foreach ($cluster in $inventory) {
            $clustersToCheck += [PSCustomObject]@{
                ClusterName = $cluster.ClusterName
                ResourceId = $cluster.ResourceId
                ResourceGroup = $cluster.ResourceGroup
                SubscriptionId = $cluster.SubscriptionId
            }
        }
    }
    
    Write-Log -Message "Checking status of $($clustersToCheck.Count) cluster(s)..." -Level Info

    # Get current status for each cluster via a single Azure Resource Graph
    # query against extensibilityresources/microsoft.azurestackhci/clusters/updatesummaries.
    # This replaces the previous per-cluster Get-AzLocalUpdateSummary fan-out
    # and removes the ThrottleLimit parameter.
    $clusterStatuses = @()
    $succeeded = 0
    $inProgress = 0
    $failed = 0
    $notStarted = 0
    $upToDate = 0

    $summaryByCluster = @{}
    if ($clustersToCheck.Count -gt 0) {
        Install-AzGraphExtension | Out-Null
        $idListKql = ($clustersToCheck | ForEach-Object { "'$($_.ResourceId.ToLower())'" }) -join ','
        $summariesKql = "extensibilityresources | where type =~ 'microsoft.azurestackhci/clusters/updatesummaries' | extend ids = split(id, '/') | extend ClusterResourceId_ = tolower(strcat('/subscriptions/', tostring(ids[2]), '/resourceGroups/', tostring(ids[4]), '/providers/Microsoft.AzureStackHCI/clusters/', tostring(ids[8]))) | where ClusterResourceId_ in~ ($idListKql) | project properties, ClusterResourceId_"
        $argParams = @{ Query = $summariesKql }
        # Honour the subscription on each cluster if present (mixed-sub fleets).
        $subs = @($clustersToCheck | Where-Object { $_.SubscriptionId } | Select-Object -ExpandProperty SubscriptionId -Unique)
        if ($subs.Count -eq 1) { $argParams['SubscriptionId'] = $subs[0] }
        try {
            $summaryRows = Invoke-AzResourceGraphQuery @argParams
        }
        catch {
            Write-Warning "ARG query for updatesummaries failed: $($_.Exception.Message)"
            $summaryRows = @()
        }
        foreach ($row in @($summaryRows)) {
            $summaryByCluster[[string]$row.ClusterResourceId_] = $row
        }
    }

    foreach ($cluster in $clustersToCheck) {
        $key = $cluster.ResourceId.ToLower()
        $row = $summaryByCluster[$key]
        if ($row) {
            $props = $row.properties
            $status = [PSCustomObject]@{
                ClusterName   = $cluster.ClusterName
                ResourceGroup = $cluster.ResourceGroup
                UpdateState   = $props.state
                HealthState   = $props.healthState
                LastUpdated   = $props.lastUpdated
            }
        }
        else {
            $status = [PSCustomObject]@{
                ClusterName   = $cluster.ClusterName
                ResourceGroup = $cluster.ResourceGroup
                UpdateState   = 'Unknown'
                HealthState   = 'Unknown'
                LastUpdated   = $null
            }
        }
        $clusterStatuses += $status
        switch ($status.UpdateState) {
            # Real ARM/ARG updateSummaries state values.
            'AppliedSuccessfully'   { $succeeded++;  break }
            'UpdateAvailable'       { $notStarted++; break }
            'UpdateInProgress'      { $inProgress++; break }
            'PreparationInProgress' { $inProgress++; break }
            'UpdateFailed'          { $failed++;     break }
            'PreparationFailed'     { $failed++;     break }
            'NeedsAttention'        { $failed++;     break }
            # Legacy / synonym values kept for downstream compatibility.
            'Succeeded'             { $succeeded++;  break }
            'Failed'                { $failed++;     break }
            'UpToDate'              { $upToDate++;   break }
            default                 { $notStarted++ }
        }
    }
    
    # Calculate progress
    $total = $clustersToCheck.Count
    $completed = $succeeded + $upToDate
    $progressPercent = if ($total -gt 0) { [math]::Round(($completed / $total) * 100, 1) } else { 0 }
    
    # Build progress report
    $progress = [PSCustomObject]@{
        Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        TotalClusters = $total
        Completed = $completed
        ProgressPercent = $progressPercent
        Succeeded = $succeeded
        UpToDate = $upToDate
        InProgress = $inProgress
        Failed = $failed
        NotStarted = $notStarted
        ClusterStatuses = if ($Detailed) { $clusterStatuses } else { $null }
    }
    
    # Display summary
    Write-Log -Message "" -Level Info
    Write-Log -Message "Progress Summary:" -Level Header
    Write-Log -Message "  Total Clusters: $total" -Level Info
    Write-Log -Message "  Completed: $completed ($progressPercent%)" -Level $(if ($completed -eq $total) { "Success" } else { "Info" })
    Write-Log -Message "  - Succeeded: $succeeded" -Level $(if ($succeeded -gt 0) { "Success" } else { "Info" })
    Write-Log -Message "  - Up to Date: $upToDate" -Level $(if ($upToDate -gt 0) { "Success" } else { "Info" })
    Write-Log -Message "  In Progress: $inProgress" -Level $(if ($inProgress -gt 0) { "Warning" } else { "Info" })
    Write-Log -Message "  Failed: $failed" -Level $(if ($failed -gt 0) { "Error" } else { "Info" })
    Write-Log -Message "  Not Started: $notStarted" -Level Info
    
    if ($Detailed -and $clusterStatuses.Count -gt 0) {
        Write-Log -Message "" -Level Info
        Write-Log -Message "Per-Cluster Status:" -Level Header
        $clusterStatuses | Format-Table ClusterName, UpdateState, HealthState -AutoSize | Out-String | ForEach-Object { Write-Host $_ }
    }
    
    return $progress
}
