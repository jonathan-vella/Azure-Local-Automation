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
        # v0.7.67: cap input size before reading the whole file into memory.
        # Fleet-state JSONs produced by Export-AzureLocalFleetState are tens
        # of KB at most (one PSCustomObject per cluster). A 50 MB ceiling is
        # ~3 orders of magnitude above the upper plausible bound for any real
        # fleet and protects against an accidentally-pointed-at large file
        # (or an attacker-controlled path) OOMing the runner.
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        $maxBytes = 50MB
        if ($item.Length -gt $maxBytes) {
            throw "Fleet state file '$Path' is $([math]::Round($item.Length / 1MB, 1)) MB which exceeds the $($maxBytes / 1MB) MB safety cap. Refusing to load; verify the path points at a fleet-state JSON produced by Export-AzureLocalFleetState."
        }
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
