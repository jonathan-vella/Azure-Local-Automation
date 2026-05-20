function Invoke-AzLocalSideloadedAutoReset {
    <#
    .SYNOPSIS
        Runs the sideloaded auto-reset evaluation across an array of formatted update-run objects.
    .DESCRIPTION
        Internal driver used by Get-AzLocalUpdateRuns. Groups the supplied update-run
        objects by ClusterName, picks the latest run per cluster (by StartTime), and
        invokes Invoke-AzLocalSideloadedAutoResetForCluster for each. Results are logged
        via Write-Log so the operator sees what happened.
    .PARAMETER FormattedRuns
        Array of update-run objects (must contain ClusterName, ClusterResourceId or
        ClusterId, State, UpdateName, StartTime).
    .PARAMETER ApiVersion
        ARM api-version for cluster GET/PATCH.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$FormattedRuns,

        [Parameter(Mandatory = $false)]
        [string]$ApiVersion = $script:DefaultApiVersion
    )

    if (-not $FormattedRuns -or $FormattedRuns.Count -eq 0) { return @() }

    $results = New-Object System.Collections.Generic.List[object]
    $byCluster = $FormattedRuns | Where-Object { $_.ClusterName } | Group-Object ClusterName

    foreach ($g in $byCluster) {
        $latest = $g.Group | Sort-Object StartTime -Descending | Select-Object -First 1
        if (-not $latest) { continue }

        # If the run-fetch step itself failed for this cluster (e.g. a transient
        # ARM error during Get-AzLocalUpdateRuns), there is no reliable run
        # state to evaluate against. Skip the auto-reset rather than risk
        # PATCHing tags off the back of incomplete data. This is informational,
        # not a bug.
        if ($latest.State -eq 'Error') {
            Write-Log -Message "Sideloaded auto-reset [$($g.Name)]: latest run could not be fetched (State=Error) - skipping reset evaluation." -Level Verbose
            continue
        }

        # Resolve cluster resource ID from the run object (multiple property names possible)
        $rid = $null
        foreach ($propName in @('ClusterResourceId', 'ClusterId', 'ResourceId')) {
            if ($latest.PSObject.Properties[$propName] -and $latest.$propName) {
                $rid = $latest.$propName
                break
            }
        }
        if (-not $rid) {
            # Defensive: every code path that builds the run rows now plumbs
            # ClusterResourceId through, so reaching this branch means the
            # caller passed a hand-built object without one. Not a bug in the
            # module's own paths.
            Write-Log -Message "Sideloaded auto-reset [$($g.Name)]: run object has no ClusterResourceId - skipping (cannot PATCH cluster tags without resource ID)." -Level Verbose
            continue
        }

        $r = Invoke-AzLocalSideloadedAutoResetForCluster `
            -ClusterName $g.Name `
            -ClusterResourceId $rid `
            -LatestRunState ($latest.State) `
            -LatestRunUpdateName ($latest.UpdateName) `
            -ApiVersion $ApiVersion

        switch ($r.Action) {
            'Reset'           { Write-Log -Message "Sideloaded auto-reset [$($g.Name)]: $($r.Message)" -Level Success }
            'OrphanCleared'   { Write-Log -Message "Sideloaded auto-reset [$($g.Name)]: $($r.Message)" -Level Info }
            'NoTag'           { Write-Log -Message "Sideloaded auto-reset [$($g.Name)]: $($r.Message)" -Level Verbose }
            'RunNotSucceeded' { Write-Log -Message "Sideloaded auto-reset [$($g.Name)]: $($r.Message)" -Level Verbose }
            default           { Write-Log -Message "Sideloaded auto-reset [$($g.Name)]: $($r.Message)" -Level Warning }
        }

        $results.Add($r) | Out-Null
    }

    return $results.ToArray()
}
