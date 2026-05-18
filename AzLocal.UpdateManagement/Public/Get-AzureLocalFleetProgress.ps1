function Get-AzureLocalFleetProgress {
    <#
    .SYNOPSIS
        Gets real-time progress of a fleet-wide update operation.
    
    .DESCRIPTION
        Queries the current status of all clusters in a fleet operation and returns
        aggregated progress information including:
        - Total, completed, in-progress, failed, pending counts
        - Estimated time remaining (based on average completion time)
        - Per-cluster status details
        
        Can be used with a state object from Invoke-AzureLocalFleetOperation or
        by querying clusters directly by tag.
    
    .PARAMETER State
        A fleet operation state object. If provided, only checks clusters in this state.
    
    .PARAMETER ScopeByUpdateRingTag
        Query progress for clusters with a specific UpdateRing tag.
    
    .PARAMETER UpdateRingValue
        The UpdateRing tag value to filter by.
    
    .PARAMETER Detailed
        Include detailed per-cluster status in output.

    .PARAMETER ThrottleLimit
        Maximum number of parallel background jobs used to query cluster status.
        Default is 1 (inline, sequential - identical to previous behaviour).
        Set >1 to fan out per-cluster Get-AzureLocalUpdateSummary calls across
        background jobs via Invoke-FleetJobsInParallel. Recommended values for
        large fleets: 4-8.

    .EXAMPLE
        Get-AzureLocalFleetProgress -State $fleetState
        Gets progress for clusters in the specified fleet operation.

    .EXAMPLE
        Get-AzureLocalFleetProgress -ScopeByUpdateRingTag -UpdateRingValue "Production"
        Gets progress for all Production ring clusters.

    .EXAMPLE
        Get-AzureLocalFleetProgress -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Detailed -ThrottleLimit 8
        Gets detailed progress using 8 parallel jobs for large fleets.
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
        [switch]$Detailed,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 32)]
        [int]$ThrottleLimit = 1
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
        $inventory = Get-AzureLocalClusterInventory -PassThru | Where-Object { $_.UpdateRing -eq $UpdateRingValue }
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
    
    # Get current status for each cluster.
    # ThrottleLimit=1 uses the inline fast-path in Invoke-FleetJobsInParallel
    # (no Start-Job cost) so behaviour is identical to the pre-parallel code.
    $clusterStatuses = @()
    $succeeded = 0
    $inProgress = 0
    $failed = 0
    $notStarted = 0
    $upToDate = 0

    # Normalise inputs for the job scriptblock: only the fields it reads.
    $checkInputs = @($clustersToCheck | ForEach-Object {
        [PSCustomObject]@{
            ClusterName   = $_.ClusterName
            ResourceId    = $_.ResourceId
            ResourceGroup = $_.ResourceGroup
        }
    })

    $progressJob = {
        param(
            [object[]]$Shard,
            [string]$ModulePath
        )
        # Only import when not already loaded (see note in perBatchJob above).
        if (-not (Get-Command -Name Get-AzureLocalUpdateSummary -ErrorAction SilentlyContinue)) {
            Import-Module $ModulePath -Force -ErrorAction Stop
        }
        $shardOut = foreach ($c in $Shard) {
            try {
                $summary = Get-AzureLocalUpdateSummary -ClusterResourceId $c.ResourceId -ErrorAction SilentlyContinue
                [PSCustomObject]@{
                    ClusterName   = $c.ClusterName
                    ResourceGroup = $c.ResourceGroup
                    UpdateState   = $summary.State
                    HealthState   = $summary.HealthState
                    LastUpdated   = $summary.LastUpdatedTime
                }
            }
            catch {
                [PSCustomObject]@{
                    ClusterName   = $c.ClusterName
                    ResourceGroup = $c.ResourceGroup
                    UpdateState   = 'Unknown'
                    HealthState   = 'Unknown'
                    LastUpdated   = $null
                }
            }
        }
        return , @($shardOut)
    }

    $jobResults = Invoke-FleetJobsInParallel `
        -InputItems $checkInputs `
        -ScriptBlock $progressJob `
        -ThrottleLimit $ThrottleLimit `
        -ActivityName 'FleetProgress'

    foreach ($jr in $jobResults) {
        if ($jr.Failed) {
            # Treat the whole shard as Unknown so counters are still produced.
            foreach ($item in @($jr.Items)) {
                $clusterStatuses += [PSCustomObject]@{
                    ClusterName   = $item.ClusterName
                    ResourceGroup = $item.ResourceGroup
                    UpdateState   = 'Unknown'
                    HealthState   = 'Unknown'
                    LastUpdated   = $null
                }
                $notStarted++
            }
            continue
        }
        foreach ($status in @($jr.Output)) {
            if (-not $status) { continue }
            $clusterStatuses += $status
            switch ($status.UpdateState) {
                'Succeeded'         { $succeeded++;  break }
                'UpdateInProgress'  { $inProgress++; break }
                'Failed'            { $failed++;     break }
                'UpToDate'          { $upToDate++;   break }
                default             { $notStarted++ }
            }
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
