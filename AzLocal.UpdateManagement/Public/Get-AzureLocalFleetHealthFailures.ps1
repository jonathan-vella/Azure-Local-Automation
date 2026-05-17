function Get-AzureLocalFleetHealthFailures {
    <#
    .SYNOPSIS
        Returns the in-flight 24-hour system health-check failures for an Azure
        Local fleet, either as per-(cluster, failure) detail rows or aggregated
        by failure reason so administrators can prioritise remediation at scale.

    .DESCRIPTION
        Health-check data for every Azure Local cluster is persisted on the
        cluster's `updateSummaries/default` resource under
        `properties.healthCheckResult[]`. Each entry carries a status, severity
        (Critical | Warning | Informational), display name, description,
        remediation, and timestamp. The 24-hour system health checks continue to
        run on the cluster even when no updates are available, which means
        clusters can be "up to date" yet still surface Critical or Warning
        health issues that administrators need to triage.

        This function executes a single Azure Resource Graph query against the
        `extensibilityresources` table for every accessible cluster (paging
        transparently for fleets larger than 1000 entries) and returns the
        failing health-check entries (status == 'Failed'). Two views are
        supported:

          - 'Detail'  (default): one row per (cluster, failing health check).
                       Useful for the per-cluster drill-down view and for
                       JUnit XML emission so failures are visible per node
                       on the pipeline run.
          - 'Summary'         : grouped by FailureReason and Severity. Rows
                                are ordered by ClusterCount desc (most
                                widespread issue first) so administrators can
                                target the highest-impact fixes first. The
                                AffectedClusters column lists every cluster
                                hit by that failure reason.

        Critical-severity entries are emitted before Warning. Informational
        entries are excluded.

        The function reuses the module's existing `Invoke-AzResourceGraphQuery`
        helper, which means it inherits the same skip-token pagination, error
        scrubbing, and CLI shell-out behaviour as every other fleet-wide query
        in the module.

    .PARAMETER SubscriptionId
        Optional. Limit the query to a specific Azure subscription ID. If not
        specified, queries across all accessible subscriptions (default mode).

    .PARAMETER Severity
        Severity filter applied at the ARG side. Accepts 'Critical', 'Warning',
        or 'All' (default). 'All' returns both Critical and Warning rows;
        Informational health checks are always excluded.

    .PARAMETER UpdateRingTag
        Optional. When supplied, only clusters whose 'UpdateRing' tag value
        matches this string are returned. Useful for narrowing fleet-health
        reporting to a specific wave (e.g. 'Wave1', 'Production') and for
        producing focussed reports per ring.

    .PARAMETER View
        'Detail' (default) or 'Summary'. See DESCRIPTION above.

    .PARAMETER ExportPath
        Optional. Path to export the result. Format is auto-detected from the
        file extension (.csv or .json). CSV is useful for spreadsheets and the
        JUnit emitter; JSON is useful for downstream automation.

    .PARAMETER PassThru
        Return objects to the pipeline even when -ExportPath is specified.

    .EXAMPLE
        # Per-cluster detail across the entire fleet (default view)
        Get-AzureLocalFleetHealthFailures

    .EXAMPLE
        # Pivot by failure reason - "what should we fix first?" - and export
        Get-AzureLocalFleetHealthFailures -View Summary -ExportPath .\fleet-health-summary.csv

    .EXAMPLE
        # Critical issues only, narrowed to one ring, for a focussed report
        Get-AzureLocalFleetHealthFailures -Severity Critical -UpdateRingTag 'Wave1'

    .EXAMPLE
        # CI/CD pipeline: detail for JUnit emission, summary for the markdown summary
        $detail  = Get-AzureLocalFleetHealthFailures -View Detail  -ExportPath .\reports\fleet-health-detail.csv  -PassThru
        $summary = Get-AzureLocalFleetHealthFailures -View Summary -ExportPath .\reports\fleet-health-summary.csv -PassThru
        # ...emit JUnit XML from $detail, write GITHUB_STEP_SUMMARY from $summary...

    .NOTES
        Author:  Neil Bird, Microsoft.
        Added:   v0.7.65
        Module:  AzLocal.UpdateManagement
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Critical', 'Warning', 'All')]
        [string]$Severity = 'All',

        [Parameter(Mandatory = $false)]
        [ValidatePattern('^[A-Za-z0-9_-]{1,64}$')]
        [string]$UpdateRingTag,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Detail', 'Summary')]
        [string]$View = 'Detail',

        [Parameter(Mandatory = $false)]
        [string]$ExportPath,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    # Pre-flight: validate export path before issuing the ARG query
    if ($ExportPath) {
        try { Test-ExportPathWritable -Path $ExportPath | Out-Null }
        catch { throw "ExportPath is not writable: $($_.Exception.Message)" }
    }

    # Build the severity filter clause for the ARG query. Informational
    # entries are excluded in every case - this function only surfaces
    # actionable health issues (Critical / Warning).
    $severityClause = switch ($Severity) {
        'Critical' { "| where tostring(hc.severity) =~ 'Critical'" }
        'Warning'  { "| where tostring(hc.severity) =~ 'Warning'" }
        default    { "| where tostring(hc.severity) in~ ('Critical','Warning')" }
    }

    # ARG query: one row per (cluster, failing health-check entry).
    # The `extensibilityresources` table holds the `updateSummaries` child
    # resource for every Azure Local cluster the caller can read. The
    # `properties.healthCheckResult` array is mv-expanded so each failing
    # check becomes its own row, then projected to the output schema.
    # Cluster identity (name, RG, subscription) is parsed from the
    # `/subscriptions/{}/resourceGroups/{}/providers/Microsoft.AzureStackHCI/clusters/{}/updateSummaries/default`
    # resource ID so the function does not need to issue a separate
    # cluster-resource query.
    $kql = @"
extensibilityresources
| where type =~ 'microsoft.azurestackhci/clusters/updatesummaries'
| extend segments = split(id, '/')
| extend
    SubscriptionId    = tostring(segments[2]),
    ResourceGroup     = tostring(segments[4]),
    ClusterName       = tostring(segments[8])
| extend ClusterResourceId = strcat('/subscriptions/', SubscriptionId, '/resourceGroups/', ResourceGroup, '/providers/Microsoft.AzureStackHCI/clusters/', ClusterName)
| extend checks = properties.healthCheckResult
| mv-expand hc = checks
| where tostring(hc.status) =~ 'Failed'
$severityClause
| project
    ClusterName,
    ResourceGroup,
    SubscriptionId,
    ClusterResourceId,
    Severity         = tostring(hc.severity),
    FailureName      = tostring(hc.name),
    FailureReason    = tostring(hc.displayName),
    Description      = tostring(hc.description),
    Remediation      = tostring(hc.remediation),
    LastOccurrence   = todatetime(hc.timestamp)
| extend SeverityOrder = case(Severity =~ 'Critical', 1, Severity =~ 'Warning', 2, 3)
| order by SeverityOrder asc, ClusterName asc, FailureReason asc
| project-away SeverityOrder
"@

    Write-Log -Message "Querying Azure Resource Graph for fleet health-check failures (View=$View, Severity=$Severity$(if($UpdateRingTag){", UpdateRingTag=$UpdateRingTag"})..." -Level Info

    try {
        $rows = if ($SubscriptionId) {
            Invoke-AzResourceGraphQuery -Query $kql -SubscriptionId $SubscriptionId
        } else {
            Invoke-AzResourceGraphQuery -Query $kql
        }
    }
    catch {
        Write-Log -Message "Resource Graph query failed: $($_.Exception.Message)" -Level Error
        throw
    }

    if (-not $rows) { $rows = @() }
    Write-Log -Message "Resource Graph returned $($rows.Count) failing health-check entries across the fleet." -Level Info

    # Optional UpdateRing tag filter. We do this client-side rather than
    # joining inside KQL because the updateSummaries resource does NOT carry
    # the cluster's tags - tags live on the cluster resource itself. A
    # separate ARG hop is required to map ResourceId -> UpdateRing.
    if ($UpdateRingTag) {
        $tagKql = @"
resources
| where type =~ 'microsoft.azurestackhci/clusters'
| where tostring(tags['UpdateRing']) =~ '$UpdateRingTag'
| project id = tolower(id)
"@
        try {
            $tagRows = if ($SubscriptionId) {
                Invoke-AzResourceGraphQuery -Query $tagKql -SubscriptionId $SubscriptionId
            } else {
                Invoke-AzResourceGraphQuery -Query $tagKql
            }
        }
        catch {
            Write-Log -Message "UpdateRing tag filter query failed: $($_.Exception.Message)" -Level Error
            throw
        }
        $allowed = @{}
        foreach ($r in @($tagRows)) { $allowed[$r.id] = $true }
        $before = $rows.Count
        $rows   = @($rows | Where-Object { $allowed.ContainsKey(($_.ClusterResourceId).ToLower()) })
        Write-Log -Message "Filtered to UpdateRing='$UpdateRingTag': $($rows.Count) of $before rows retained." -Level Info
    }

    # Build the output the caller asked for.
    if ($View -eq 'Summary') {
        # Aggregate: one row per (FailureReason, Severity). Most widespread
        # issue first (ClusterCount desc), then Critical before Warning, then
        # most-frequent first within a tie.
        $output = @($rows |
            Group-Object -Property FailureReason, Severity |
            ForEach-Object {
                $first       = $_.Group | Select-Object -First 1
                $clusterList = @($_.Group | Select-Object -ExpandProperty ClusterName -Unique | Sort-Object)
                $latest      = ($_.Group | Measure-Object -Property LastOccurrence -Maximum).Maximum
                [PSCustomObject]@{
                    FailureReason    = $first.FailureReason
                    Severity         = $first.Severity
                    ClusterCount     = $clusterList.Count
                    FailureCount     = $_.Group.Count
                    AffectedClusters = ($clusterList -join ';')
                    LatestOccurrence = $latest
                    Description      = $first.Description
                    Remediation      = $first.Remediation
                }
            } |
            Sort-Object @{Expression={$_.ClusterCount};Descending=$true},
                       @{Expression={ if($_.Severity -eq 'Critical'){1}elseif($_.Severity -eq 'Warning'){2}else{3} };Descending=$false},
                       @{Expression={$_.FailureCount};Descending=$true}
        )
    } else {
        # Detail view: pass-through after surfacing severity ordering so that
        # JUnit and CSV consumers see Critical rows before Warning rows.
        $output = @($rows | Select-Object ClusterName, ResourceGroup, SubscriptionId, Severity, FailureReason, FailureName, Description, Remediation, LastOccurrence, ClusterResourceId)
    }

    # Export if requested.
    if ($ExportPath) {
        try {
            $ExportPath = Resolve-SafeOutputPath -Path $ExportPath
            $exportDir  = Split-Path -Path $ExportPath -Parent
            if ($exportDir -and -not (Test-Path -Path $exportDir)) {
                $null = New-Item -ItemType Directory -Path $exportDir -Force
            }
            $ext = [System.IO.Path]::GetExtension($ExportPath).ToLower()
            switch ($ext) {
                '.json' {
                    Write-Utf8NoBomFile -Path $ExportPath -Content ($output | ConvertTo-Json -Depth 6)
                    Write-Log -Message "Fleet health $View exported to JSON: $ExportPath" -Level Success
                }
                default {
                    $output | ConvertTo-SafeCsvCollection | Export-Csv -Path $ExportPath -NoTypeInformation -Force
                    Write-Log -Message "Fleet health $View exported to CSV: $ExportPath" -Level Success
                }
            }
        }
        catch {
            Write-Log -Message "Failed to export fleet health $($View): $($_.Exception.Message)" -Level Error
        }
    }

    # Summary log to host stream.
    if ($View -eq 'Summary') {
        Write-Log -Message "" -Level Info
        Write-Log -Message "Fleet Health Failures Summary (top reasons by cluster impact):" -Level Header
        foreach ($r in ($output | Select-Object -First 10)) {
            $tag = if ($r.Severity -eq 'Critical') { 'Critical' } else { 'Warning ' }
            Write-Log -Message ("  [{0}] {1} - {2} cluster(s), {3} failure(s)" -f $tag, $r.FailureReason, $r.ClusterCount, $r.FailureCount) -Level $(if ($r.Severity -eq 'Critical') { 'Error' } else { 'Warning' })
        }
        if ($output.Count -gt 10) {
            Write-Log -Message "  (... and $($output.Count - 10) more failure reason(s); see ExportPath for the full list)" -Level Info
        }
    } else {
        $clusterCount = @($output | Select-Object -ExpandProperty ClusterName -Unique).Count
        Write-Log -Message ("Fleet Health Detail: {0} failing check(s) across {1} cluster(s)." -f $output.Count, $clusterCount) -Level Info
    }

    # Honour PassThru semantics: emit objects unless ExportPath was used and
    # the caller did not ask for them.
    if (-not $ExportPath -or $PassThru) {
        return , $output
    }
}
