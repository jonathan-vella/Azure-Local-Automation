function Resume-AzureLocalFleetUpdate {
    <#
    .SYNOPSIS
        Resumes a previously interrupted fleet update operation.
    
    .DESCRIPTION
        Loads a saved fleet operation state and continues processing any
        pending or failed clusters. This enables recovery from:
        - Pipeline timeouts
        - Network interruptions  
        - Manual cancellations
        - Transient failures
    
    .PARAMETER StateFilePath
        Path to the saved state file from a previous operation.
    
    .PARAMETER State
        A state object loaded via Import-AzureLocalFleetState.
    
    .PARAMETER RetryFailed
        Also retry clusters that previously failed (not just pending).
    
    .PARAMETER MaxRetries
        Maximum additional retry attempts for failed clusters.
    
    .PARAMETER Force
        Skip confirmation prompts.
    
    .PARAMETER PassThru
        Return the updated state object.
    
    .EXAMPLE
        Resume-AzureLocalFleetUpdate -StateFilePath "C:\Logs\fleet-state.json" -Force
        Resumes pending clusters from the saved state.
    
    .EXAMPLE
        Resume-AzureLocalFleetUpdate -StateFilePath "C:\Logs\fleet-state.json" -RetryFailed -Force
        Resumes pending clusters and retries failed ones.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByPath')]
        [ValidateScript({ Test-Path $_ })]
        [string]$StateFilePath,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'ByState')]
        [PSCustomObject]$State,
        
        [Parameter(Mandatory = $false)]
        [switch]$RetryFailed,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 10)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force,
        
        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )
    
    # Load state
    $resumeState = if ($State) { $State } else { Import-AzureLocalFleetState -Path $StateFilePath }
    
    if (-not $resumeState) {
        Write-Error "Failed to load fleet state."
        return $null
    }
    
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Resuming Fleet Operation" -Level Header
    Write-Log -Message "Original Run ID: $($resumeState.RunId)" -Level Header
    Write-Log -Message "========================================" -Level Header
    
    # Identify clusters to process
    $pendingClusters = @($resumeState.Clusters | Where-Object { $_.Status -eq "Pending" })
    $failedClusters = @($resumeState.Clusters | Where-Object { $_.Status -eq "Failed" })
    
    Write-Log -Message "State Summary:" -Level Info
    Write-Log -Message "  Pending: $($pendingClusters.Count)" -Level Info
    Write-Log -Message "  Failed: $($failedClusters.Count)" -Level Info
    Write-Log -Message "  Succeeded: $($resumeState.SucceededCount)" -Level Info
    
    $clustersToProcess = $pendingClusters
    if ($RetryFailed) {
        $clustersToProcess += $failedClusters
        # Reset failed clusters to pending
        foreach ($cluster in $failedClusters) {
            $cluster.Status = "Pending"
            $cluster.Attempts = 0
            $cluster.LastError = $null
        }
        $resumeState.FailedCount = 0
    }
    
    if ($clustersToProcess.Count -eq 0) {
        Write-Log -Message "No clusters to process. All clusters have succeeded." -Level Success
        return $resumeState
    }
    
    Write-Log -Message "Clusters to process: $($clustersToProcess.Count)" -Level Info
    
    # Confirmation
    if (-not $Force) {
        $confirmation = Read-Host "Resume operation on $($clustersToProcess.Count) cluster(s)? (y/n)"
        if ($confirmation -ne 'y') {
            Write-Log -Message "Resume cancelled by user." -Level Warning
            return $resumeState
        }
    }
    
    # Collect resource IDs for processing
    $resourceIds = $clustersToProcess | ForEach-Object { $_.ResourceId }
    
    # Use Invoke-AzureLocalFleetOperation with the specific clusters
    $params = @{
        ClusterResourceIds = $resourceIds
        Operation = $resumeState.Operation
        BatchSize = $resumeState.BatchSize
        ThrottleLimit = $resumeState.ThrottleLimit
        MaxRetries = $MaxRetries
        Force = $true
        PassThru = $true
    }
    
    if ($resumeState.UpdateName) {
        $params['UpdateName'] = $resumeState.UpdateName
    }
    
    if ($resumeState.StateFilePath) {
        $params['StateFilePath'] = $resumeState.StateFilePath
    }
    
    $result = Invoke-AzureLocalFleetOperation @params
    
    if ($PassThru) {
        return $result
    }
}
