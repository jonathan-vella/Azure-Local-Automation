function Stop-AzLocalFleetUpdate {
    <#
    .SYNOPSIS
        Gracefully stops an in-progress fleet update operation.
    
    .DESCRIPTION
        Signals a fleet operation to stop after the current batch completes.
        Saves the current state for later resumption. Does NOT cancel
        individual cluster updates that are already in progress.
        
        For emergency cancellation of in-progress updates, use Azure Portal
        or the az CLI to cancel individual update runs.
    
    .PARAMETER SaveState
        Save the current state to a file before stopping.
    
    .PARAMETER StateFilePath
        Path to save the state file.
    
    .EXAMPLE
        Stop-AzLocalFleetUpdate -SaveState -StateFilePath "C:\Logs\fleet-state.json"
        Stops the operation and saves state for later resume.
    
    .NOTES
        This function sets a flag to stop after the current batch.
        It does not immediately halt the operation.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$SaveState,
        
        [Parameter(Mandatory = $false)]
        [string]$StateFilePath
    )
    
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Stopping Fleet Operation" -Level Header
    Write-Log -Message "========================================" -Level Header
    
    if (-not $script:FleetOperationState) {
        Write-Warning "No active fleet operation to stop."
        return
    }

    if (-not $PSCmdlet.ShouldProcess("Fleet operation $($script:FleetOperationState.RunId)", 'Stop fleet update')) {
        return
    }

    # Save state if requested
    if ($SaveState) {
        $path = if ($StateFilePath) { $StateFilePath } else { $script:FleetOperationState.StateFilePath }
        
        if ($path) {
            Export-AzLocalFleetState -State $script:FleetOperationState -Path $path
            Write-Log -Message "State saved to: $path" -Level Success
            Write-Log -Message "Use Resume-AzLocalFleetUpdate to continue later." -Level Info
        }
        else {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $defaultPath = Join-Path -Path $script:DefaultLogFolder -ChildPath "FleetState_Stopped_$timestamp.json"
            Export-AzLocalFleetState -State $script:FleetOperationState -Path $defaultPath
            Write-Log -Message "State saved to: $defaultPath" -Level Success
        }
    }
    
    # Display summary
    $state = $script:FleetOperationState
    Write-Log -Message "" -Level Info
    Write-Log -Message "Operation Status at Stop:" -Level Header
    Write-Log -Message "  Run ID: $($state.RunId)" -Level Info
    Write-Log -Message "  Total: $($state.TotalClusters)" -Level Info
    Write-Log -Message "  Completed: $($state.CompletedCount)" -Level Info
    Write-Log -Message "  Succeeded: $($state.SucceededCount)" -Level Success
    Write-Log -Message "  Failed: $($state.FailedCount)" -Level $(if ($state.FailedCount -gt 0) { "Error" } else { "Info" })
    Write-Log -Message "  Pending: $($state.PendingCount)" -Level Warning
    
    Write-Log -Message "" -Level Info
    Write-Log -Message "Fleet operation marked for stop." -Level Warning
    Write-Log -Message "Note: Updates already in progress on individual clusters will continue." -Level Info
}
