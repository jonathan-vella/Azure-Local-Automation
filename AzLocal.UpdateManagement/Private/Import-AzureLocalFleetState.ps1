function Import-AzureLocalFleetState {
    <#
    .SYNOPSIS
        Imports a previously saved fleet operation state from a JSON file.
    
    .DESCRIPTION
        Loads a fleet operation state from a JSON file to enable resuming
        interrupted operations or reviewing past operation status.
    
    .PARAMETER Path
        The file path to load the state from.
    
    .EXAMPLE
        $state = Import-AzureLocalFleetState -Path "C:\Logs\fleet-state.json"
        Resume-AzureLocalFleetUpdate -State $state
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$Path
    )
    
    try {
        $content = Get-Content -Path $Path -Raw | ConvertFrom-Json
        Write-Log -Message "Fleet state imported from: $Path" -Level Info
        Write-Log -Message "  Run ID: $($content.RunId)" -Level Info
        Write-Log -Message "  Started: $($content.StartTime)" -Level Info
        Write-Log -Message "  Total Clusters: $($content.TotalClusters)" -Level Info
        Write-Log -Message "  Completed: $($content.CompletedCount), Failed: $($content.FailedCount), Pending: $($content.PendingCount)" -Level Info
        return $content
    }
    catch {
        Write-Error "Failed to import fleet state from '$Path': $_"
        return $null
    }
}
