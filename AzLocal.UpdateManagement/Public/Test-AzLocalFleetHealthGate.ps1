function Test-AzLocalFleetHealthGate {
    <#
    .SYNOPSIS
        Tests if a fleet meets health criteria to proceed with additional waves.
    
    .DESCRIPTION
        Evaluates the health and update status of a fleet to determine if it's safe
        to proceed with the next wave of updates. This function acts as a "gate"
        in CI/CD pipelines to prevent cascading failures.
        
        Health gate criteria:
        - Maximum failure percentage (default: 5%)
        - Minimum success percentage (default: 90%)
        - No critical health failures
        
        Returns $true if the gate passes, $false otherwise.
    
    .PARAMETER State
        A fleet operation state object to evaluate.
    
    .PARAMETER ScopeByUpdateRingTag
        Evaluate clusters with a specific UpdateRing tag.
    
    .PARAMETER UpdateRingValue
        The UpdateRing tag value to filter by.
    
    .PARAMETER MaxFailurePercent
        Maximum allowed failure percentage. Default: 5.
        If more than this percentage of clusters fail, the gate fails.
    
    .PARAMETER MinSuccessPercent
        Minimum required success percentage. Default: 90.
        If fewer than this percentage succeed, the gate fails.
    
    .PARAMETER WaitForCompletion
        Wait for in-progress updates to complete before evaluating.
    
    .PARAMETER WaitTimeoutMinutes
        Maximum time to wait for completion. Default: 120 (2 hours).
    
    .PARAMETER PollIntervalSeconds
        How often to check status while waiting. Default: 60.
    
    .OUTPUTS
        PSCustomObject with Pass/Fail status and detailed metrics.
    
    .EXAMPLE
        Test-AzLocalFleetHealthGate -ScopeByUpdateRingTag -UpdateRingValue "Canary"
        Tests if the Canary ring meets default health criteria.
    
    .EXAMPLE
        Test-AzLocalFleetHealthGate -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -MaxFailurePercent 2 -WaitForCompletion
        Waits for Wave1 to complete and fails if more than 2% of clusters fail.
    
    .EXAMPLE
        # In CI/CD pipeline
        $gate = Test-AzLocalFleetHealthGate -ScopeByUpdateRingTag -UpdateRingValue "Wave1"
        if (-not $gate.Passed) { exit 1 }
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByTag')]
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
        [ValidateRange(0, 100)]
        [int]$MaxFailurePercent = 5,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 100)]
        [int]$MinSuccessPercent = 90,
        
        [Parameter(Mandatory = $false)]
        [switch]$WaitForCompletion,
        
        [Parameter(Mandatory = $false)]
        [int]$WaitTimeoutMinutes = 120,
        
        [Parameter(Mandatory = $false)]
        [int]$PollIntervalSeconds = 60
    )
    
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Fleet Health Gate Check" -Level Header
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Criteria: MaxFailure=$MaxFailurePercent%, MinSuccess=$MinSuccessPercent%" -Level Info
    
    $startTime = Get-Date
    $timeout = $startTime.AddMinutes($WaitTimeoutMinutes)
    
    do {
        # Get current progress
        $progressParams = @{}
        if ($PSCmdlet.ParameterSetName -eq 'ByState') {
            $progressParams['State'] = $State
        }
        else {
            $progressParams['ScopeByUpdateRingTag'] = $true
            $progressParams['UpdateRingValue'] = $UpdateRingValue
        }
        
        $progress = Get-AzLocalFleetProgress @progressParams -Detailed
        
        if (-not $progress) {
            return [PSCustomObject]@{
                Passed = $false
                Reason = "Unable to get fleet progress"
                Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            }
        }
        
        # Check if we should wait for completion
        if ($WaitForCompletion -and $progress.InProgress -gt 0) {
            $remaining = $timeout - (Get-Date)
            
            if ((Get-Date) -ge $timeout) {
                Write-Log -Message "Timeout reached waiting for completion. $($progress.InProgress) updates still in progress." -Level Warning
                break
            }
            
            Write-Log -Message "Waiting for $($progress.InProgress) in-progress update(s)... (Timeout in $([math]::Round($remaining.TotalMinutes, 0)) min)" -Level Info
            Start-Sleep -Seconds $PollIntervalSeconds
            continue
        }
        
        break
    } while ($true)
    
    # Calculate metrics
    $total = $progress.TotalClusters
    $succeeded = $progress.Succeeded + $progress.UpToDate
    $failed = $progress.Failed
    
    $failurePercent = if ($total -gt 0) { [math]::Round(($failed / $total) * 100, 2) } else { 0 }
    $successPercent = if ($total -gt 0) { [math]::Round(($succeeded / $total) * 100, 2) } else { 0 }
    
    # Evaluate gate criteria
    $reasons = @()
    $passed = $true
    
    if ($failurePercent -gt $MaxFailurePercent) {
        $passed = $false
        $reasons += "Failure rate ($failurePercent%) exceeds maximum ($MaxFailurePercent%)"
    }
    
    if ($successPercent -lt $MinSuccessPercent) {
        $passed = $false
        $reasons += "Success rate ($successPercent%) below minimum ($MinSuccessPercent%)"
    }
    
    # Check for critical health failures if detailed data available
    if ($progress.ClusterStatuses) {
        $criticalHealth = @($progress.ClusterStatuses | Where-Object { $_.HealthState -eq "Failure" })
        if ($criticalHealth.Count -gt 0) {
            $passed = $false
            $reasons += "$($criticalHealth.Count) cluster(s) have critical health failures"
        }
    }
    
    # Build result
    $result = [PSCustomObject]@{
        Passed = $passed
        Reason = if ($reasons.Count -gt 0) { $reasons -join "; " } else { "All criteria met" }
        Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        TotalClusters = $total
        Succeeded = $succeeded
        Failed = $failed
        InProgress = $progress.InProgress
        SuccessPercent = $successPercent
        FailurePercent = $failurePercent
        MaxFailurePercent = $MaxFailurePercent
        MinSuccessPercent = $MinSuccessPercent
    }
    
    # Display result
    Write-Log -Message "" -Level Info
    if ($passed) {
        Write-Log -Message "[OK]HEALTH GATE: PASSED" -Level Success
    }
    else {
        Write-Log -Message "[FAILED]HEALTH GATE: FAILED" -Level Error
        foreach ($reason in $reasons) {
            Write-Log -Message "  - $reason" -Level Error
        }
    }
    Write-Log -Message "  Success Rate: $successPercent% (min: $MinSuccessPercent%)" -Level Info
    Write-Log -Message "  Failure Rate: $failurePercent% (max: $MaxFailurePercent%)" -Level Info
    
    return $result
}
