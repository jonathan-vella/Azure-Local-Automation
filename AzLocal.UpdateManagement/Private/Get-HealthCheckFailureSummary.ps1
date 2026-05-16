function Get-HealthCheckFailureSummary {
    <#
    .SYNOPSIS
        Extracts health check failure reasons from an update summary object.
    .DESCRIPTION
        Analyzes the healthCheckResult property from an Azure Local update summary
        to extract critical and warning health check failures. Returns a summary
        string suitable for CSV logging.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object]$UpdateSummary
    )

    if (-not $UpdateSummary -or -not $UpdateSummary.properties.healthCheckResult) {
        return ""
    }

    # Bucket failures by severity so Critical entries are always emitted first.
    # The readiness gate in Get-AzureLocalClusterUpdateReadiness runs
    # -match '\[Critical\]' on the truncated summary; without this ordering,
    # a Critical failure could be hidden behind 5+ Warning failures returned
    # earlier by ARM and the gate would silently miss it.
    $criticals = @()
    $warnings  = @()
    $healthChecks = $UpdateSummary.properties.healthCheckResult

    foreach ($check in $healthChecks) {
        if ($check.status -eq "Failed") {
            $severity = if ($check.severity) { $check.severity } else { "Unknown" }
            # Only include Critical and Warning severities (skip Informational)
            if ($severity -notin @("Critical", "Warning")) {
                continue
            }
            $displayName = if ($check.displayName) { $check.displayName } elseif ($check.name) { ($check.name -split '/')[0] } else { "Unknown Check" }
            $targetNode = if ($check.targetResourceName) { " ($($check.targetResourceName))" } else { "" }
            $entry = "[$severity] $displayName$targetNode"
            if ($severity -eq "Critical") {
                $criticals += $entry
            }
            else {
                $warnings += $entry
            }
        }
    }

    # Critical-first, then Warning (insertion order preserved within each bucket).
    $failures = @($criticals) + @($warnings)

    if ($failures.Count -gt 0) {
        # Limit to top 5 failures to keep CSV readable
        $topFailures = $failures | Select-Object -First 5
        $summary = $topFailures -join "; "
        if ($failures.Count -gt 5) {
            $summary += " (+$($failures.Count - 5) more)"
        }
        return $summary
    }

    return ""
}
