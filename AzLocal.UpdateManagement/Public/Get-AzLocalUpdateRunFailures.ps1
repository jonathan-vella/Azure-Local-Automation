function Get-AzLocalUpdateRunFailures {
    <#
    .SYNOPSIS
        Returns deep error information for Azure Local cluster update runs by
        walking up to nine levels deep into the `properties.progress` step tree
        in Azure Resource Graph - the "Verbose Error Information" that has
        been missing from update-status pipeline output.

    .DESCRIPTION
        Every Azure Local cluster persists its update-run history on the
        `microsoft.azurestackhci/clusters/updates/updateruns` child resource,
        which is queryable across thousands of clusters via Azure Resource
        Graph's `extensibilityresources` table. The `properties.progress`
        object on each run contains a recursively nested
        `steps[].steps[].steps[]...` tree (often 5 to 8 levels deep on real
        failures) where the actual error message lives several levels below
        the top-level step.

        Today the existing `Get-AzLocalUpdateRuns` cmdlet returns the
        top-level "currentStep" name only and makes one ARM call per cluster.
        On a 9-cluster sub it takes >250 seconds and never surfaces the
        deepest error message.

        This cmdlet replicates the "Update Run Errors" KQL pattern used by
        the Azure Resource Graph cluster updateSummaries extensibility resource:

          - mv-expand the progress tree across s1..s7 (seven explicit levels)
          - reach into s7.steps[0] for the eighth level
          - coalesce the deepest non-empty `errorMessage` field upward
          - fall back to the step `description` when `errorMessage` is empty
          - regex-extract `raised an exception:...` from the raw progressJson
            for stack-trace recovery on rare malformed payloads
          - bucket the result into an ErrorCategory (HealthCheck, SecuredCore,
            CAU, RotateSecrets, ArcPrereqs, Certificates, AdminBlocked,
            PreparationTerminated, Other, Unclassified)

        The entire extraction happens server-side in KQL. The cmdlet returns
        flat PSCustomObject rows with already-resolved scalars - safe to
        JSON-export without `ConvertTo-Json -Depth` games, safe to push
        through CSV, safe to use as JUnit input.

        For investigations that need the original step tree, pass
        `-IncludeRawProgress` and the raw progressJson string is included
        on each row (capped at 200 KB by KQL `substring` so a single huge
        payload cannot bloat the result).

        Two views are supported:

          - 'Detail'  (default): one row per failed update run.
          - 'Summary'          : aggregated by ErrorCategory. Sorted by
                                  ClusterCount desc (most widespread first)
                                  so admins can target the highest-impact
                                  failure pattern first. AffectedClusters
                                  lists every cluster hit by that category.

    .PARAMETER SubscriptionId
        Optional. Limit the query to a specific Azure subscription ID. If
        not specified, queries across all accessible subscriptions (default
        mode) - applies a fleet-wide ARG-first scan.

    .PARAMETER UpdateRingTag
        Optional. When supplied, only update runs from clusters whose
        'UpdateRing' tag value matches this string are returned. Accepts
        the same semicolon-delimited list and `***` wildcard syntax as
        every other ARG-scoped cmdlet in the module.

    .PARAMETER ClusterName
        Optional. Limit results to a single cluster by name (case-insensitive
        exact match on the cluster resource segment of the update-run ID).
        Combinable with -UpdateRingTag for further narrowing.

    .PARAMETER State
        Filter applied server-side. Defaults to 'Failed' (which is the only
        state surfaced by name). Other values include:

          - 'InProgress' - currently-running update runs (useful for live ops)
          - 'Succeeded'  - returns succeeded runs too (deep error fields will
                            be empty)
          - 'All'        - every state

    .PARAMETER Since
        Optional. Only return update runs whose StartTime is on or after this
        UTC timestamp. Defaults to 30 days ago. Pass an earlier `[datetime]`
        for a full-history sweep, or a later one for a recent-only view.

    .PARAMETER OnlyUnresolved
        When specified, filters Failed runs to those that do NOT have a later
        Succeeded run for the same (ClusterResourceId, UpdateName). Useful
        for "what is still broken right now?" reporting. Adds one small ARG
        query for the latest-Succeeded summary.

    .PARAMETER IncludeRawProgress
        When specified, includes the raw `progressJson` string column (the
        full original `properties.progress` blob, KQL-truncated to 200 KB
        per row). Off by default because individual rows can exceed 50 KB.

    .PARAMETER View
        'Detail' (default) or 'Summary'. See DESCRIPTION above.

    .PARAMETER ExportPath
        Optional. Path to export the result. Format auto-detected from the
        file extension (.csv or .json). For JSON exports, the raw
        progressJson string (when -IncludeRawProgress is set) round-trips
        losslessly without `ConvertTo-Json -Depth` truncation.

    .PARAMETER PassThru
        Return objects to the pipeline even when -ExportPath is specified.

    .OUTPUTS
        PSCustomObject[] - Detail view columns:
          ClusterName, ResourceGroup, SubscriptionId, ClusterResourceId,
          UpdateName, RunId, State, StartTime, EndTime, DurationMinutes,
          DeepestStepDepth (1-8 or 0), DeepestStepName, DeepestErrMsg,
          StackTracePreview, ErrorCategory, ProgressJsonBytes,
          IsUnresolved (only when -OnlyUnresolved is used),
          ProgressJson (only when -IncludeRawProgress is used)

        Summary view columns:
          ErrorCategory, ClusterCount, FailureCount, AffectedClusters,
          LatestFailure, SampleErrMsg, SampleStepName

    .EXAMPLE
        # All failed runs in the fleet across every accessible subscription
        Get-AzLocalUpdateRunFailures

    .EXAMPLE
        # "What patterns are biting the most clusters?" - prioritised view
        Get-AzLocalUpdateRunFailures -View Summary

    .EXAMPLE
        # Currently unresolved failures only (no later Succeeded run for
        # the same cluster+update), in the Prod ring, last 90 days
        Get-AzLocalUpdateRunFailures -UpdateRingTag Prod -Since (Get-Date).AddDays(-90) -OnlyUnresolved

    .EXAMPLE
        # Single cluster, raw progress JSON for deep-dive investigation
        Get-AzLocalUpdateRunFailures -ClusterName Arizona -IncludeRawProgress |
            Where-Object { $_.DeepestStepDepth -ge 5 } |
            Select-Object UpdateName, RunId, DeepestStepName, DeepestErrMsg

    .EXAMPLE
        # CI/CD pipeline: detail for JUnit/CSV, summary for the markdown summary
        $detail  = Get-AzLocalUpdateRunFailures -View Detail  -ExportPath .\reports\update-failures-detail.json  -PassThru
        $summary = Get-AzLocalUpdateRunFailures -View Summary -ExportPath .\reports\update-failures-summary.csv  -PassThru

    .NOTES
        Author:  Neil Bird, Microsoft.
        Added:   v0.7.68
        Module:  AzLocal.UpdateManagement

        Architectural reference: this cmdlet treats ARG
        `extensibilityresources` as the single source of truth for update
        run history and pioneered the nine-level mv-expand pattern this
        cmdlet ports to PowerShell.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [ValidatePattern('^(\*\*\*|[A-Za-z0-9_-]{1,64}(;[A-Za-z0-9_-]{1,64})*)$')]
        [string]$UpdateRingTag,

        [Parameter(Mandatory = $false)]
        [ValidatePattern('^[A-Za-z0-9_-]{1,64}$')]
        [string]$ClusterName,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Failed', 'InProgress', 'Succeeded', 'All')]
        [string]$State = 'Failed',

        [Parameter(Mandatory = $false)]
        [datetime]$Since = (Get-Date).ToUniversalTime().AddDays(-30),

        [Parameter(Mandatory = $false)]
        [switch]$OnlyUnresolved,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeRawProgress,

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

    # Verify Azure CLI is installed and logged in
    Test-AzCliAvailable | Out-Null
    try {
        $null = az account show 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Azure CLI is not logged in. Please run 'az login' first."
        }
    }
    catch {
        Write-Log -Message "Azure CLI is not logged in. Please run 'az login' first." -Level Error
        return
    }

    # Resource-graph extension is required for ARG queries
    if (-not (Install-AzGraphExtension)) {
        Write-Log -Message "Failed to install Azure CLI 'resource-graph' extension." -Level Error
        return
    }

    # Build server-side filter clauses. The State filter is applied AFTER the
    # mv-expand projection so we still see the full step tree on Failed runs.
    # The Since filter is pushed down BEFORE mv-expand for efficiency.
    # Note: $State is injected into the projected `State` column via a
    # post-build string replace below (after the `project ... State = state`
    # line) so the filter sees the renamed column.

    # ISO-8601 UTC representation safe for embedding in KQL (no quoting needed
    # inside datetime() literal). Since the helper now normalises multi-line
    # KQL to single-line we can keep the query as a here-string for clarity.
    $sinceUtc = $Since.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

    # ClusterName client-side narrowing is handled server-side as a where
    # filter on the parsed segment so we don't pay for the mv-expand on
    # uninteresting clusters.
    $clusterClause = if ($PSBoundParameters.ContainsKey('ClusterName')) {
        "| where ClusterName =~ '$ClusterName'"
    } else { '' }

    # The KQL: parse identity from id segments, project StartTime/EndTime,
    # capture raw progressJson once (capped), then mv-expand the step tree
    # up to seven explicit levels (s1..s7) plus a synthetic eighth level via
    # s7.steps[0]. The coalesce picks the deepest non-empty errorMessage and
    # records its depth. summarize arg_max ... by id collapses the cartesian
    # explosion back down to one row per update run, keeping the columns
    # from the row that hit the maximum depth.
    $kql = @"
extensibilityresources
| where type =~ 'microsoft.azurestackhci/clusters/updates/updateruns'
| extend segments = split(id, '/')
| extend
    SubscriptionId    = tostring(segments[2]),
    ResourceGroup     = tostring(segments[4]),
    ClusterName       = tostring(segments[8]),
    UpdateName        = tostring(segments[10]),
    RunId             = tostring(segments[12])
| extend ClusterResourceId = strcat('/subscriptions/', SubscriptionId, '/resourceGroups/', ResourceGroup, '/providers/Microsoft.AzureStackHCI/clusters/', ClusterName)
| extend state     = tostring(properties.state)
| extend StartTime = todatetime(properties.timeStarted)
| extend EndTime   = todatetime(properties.lastUpdatedTime)
| extend DurationMinutes = iff(isnotnull(StartTime) and isnotnull(EndTime), toreal(datetime_diff('minute', EndTime, StartTime)), real(null))
| where StartTime >= datetime($sinceUtc)
$clusterClause
| extend progressObj = properties.progress
| extend progressStatus = tostring(progressObj.status)
| extend progressDescription = tostring(progressObj.description)
| extend progressJsonFull = tostring(properties.progress)
| extend ProgressJsonBytes = strlen(progressJsonFull)
| extend progressJsonCapped = substring(progressJsonFull, 0, 204800)
| mv-expand s1 = progressObj.steps
| mv-expand s2 = s1.steps
| mv-expand s3 = s2.steps
| mv-expand s4 = s3.steps
| mv-expand s5 = s4.steps
| mv-expand s6 = iff(array_length(s5.steps) > 0, s5.steps, dynamic([null]))
| mv-expand s7 = iff(isnotnull(s6) and array_length(s6.steps) > 0, s6.steps, dynamic([null]))
| extend e1Msg = tostring(s1.errorMessage), e1Name = tostring(s1.name), e1Desc = tostring(s1.description)
| extend e2Msg = tostring(s2.errorMessage), e2Name = tostring(s2.name)
| extend e3Msg = tostring(s3.errorMessage), e3Name = tostring(s3.name)
| extend e4Msg = tostring(s4.errorMessage), e4Name = tostring(s4.name)
| extend e5Msg = tostring(s5.errorMessage), e5Name = tostring(s5.name)
| extend e6Msg = iff(isnotnull(s6), tostring(s6.errorMessage), ''), e6Name = iff(isnotnull(s6), tostring(s6.name), '')
| extend e7Msg = iff(isnotnull(s7), tostring(s7.errorMessage), ''), e7Name = iff(isnotnull(s7), tostring(s7.name), '')
| extend e8Arr = iff(isnotnull(s7), s7.steps, dynamic(null))
| extend e8First = iff(isnotnull(e8Arr) and array_length(e8Arr) > 0, e8Arr[0], dynamic(null))
| extend e8Msg = tostring(e8First.errorMessage), e8Name = tostring(e8First.name)
| extend mvDepth = case(strlen(e8Msg) > 10, 8, strlen(e7Msg) > 10, 7, strlen(e6Msg) > 10, 6, strlen(e5Msg) > 10, 5, strlen(e4Msg) > 10, 4, strlen(e3Msg) > 10, 3, strlen(e2Msg) > 10, 2, strlen(e1Msg) > 10, 1, 0)
| extend mvDeepest = case(mvDepth == 8, e8Msg, mvDepth == 7, e7Msg, mvDepth == 6, e6Msg, mvDepth == 5, e5Msg, mvDepth == 4, e4Msg, mvDepth == 3, e3Msg, mvDepth == 2, e2Msg, mvDepth == 1, e1Msg, '')
| extend mvStepName = case(mvDepth == 8, e8Name, mvDepth == 7, e7Name, mvDepth == 6, e6Name, mvDepth == 5, e5Name, mvDepth == 4, e4Name, mvDepth == 3, e3Name, mvDepth == 2, e2Name, mvDepth == 1, e1Name, '')
| extend stackTraceMatch = extract(@'raised an exception:[^\r\n]{0,500}', 0, progressJsonFull)
| extend descriptionFallback = iff(strlen(mvDeepest) > 0, '', e1Desc)
| summarize arg_max(mvDepth, *) by id
| extend DeepestErrMsg = iff(strlen(mvDeepest) > 0, mvDeepest, descriptionFallback)
| extend ErrorCategory = case(
    DeepestErrMsg has 'UpdateSecuredCore' or DeepestErrMsg has 'Secured-core', 'SecuredCore',
    DeepestErrMsg has 'health check' or DeepestErrMsg has 'HealthCheck' or DeepestErrMsg has 'Check Update readiness', 'HealthCheck',
    DeepestErrMsg has 'CAU' or DeepestErrMsg has 'Cluster-Aware', 'CAU',
    DeepestErrMsg has 'RotateSecrets' or DeepestErrMsg has 'Rotate Secrets', 'RotateSecrets',
    DeepestErrMsg has 'MocArb' or DeepestErrMsg has 'CliExtensions' or DeepestErrMsg has 'Arc Prereq', 'ArcPrereqs',
    DeepestErrMsg has 'certificate rotation' or DeepestErrMsg has 'Certificate Rotation', 'Certificates',
    DeepestErrMsg has 'preparation was terminated', 'PreparationTerminated',
    DeepestErrMsg has 'administrator operation' or DeepestErrMsg has 'blocked by administrator', 'AdminBlocked',
    strlen(DeepestErrMsg) > 0, 'Other',
    'Unclassified')
| project ClusterName, ResourceGroup, SubscriptionId, ClusterResourceId, UpdateName, RunId, State = state, StartTime, EndTime, DurationMinutes, DeepestStepDepth = mvDepth, DeepestStepName = mvStepName, DeepestErrMsg, StackTracePreview = stackTraceMatch, ErrorCategory, Status = progressStatus, ProgressDescription = progressDescription, ProgressJsonBytes, ProgressJson = progressJsonCapped
| order by StartTime desc, ClusterName asc
"@

    # Append the State filter AFTER the project line so it operates on the
    # renamed `State` (capital S) column. Skipping the filter when State='All'
    # passes every state through.
    if ($State -ne 'All') {
        $kql = $kql -replace '\| order by StartTime desc, ClusterName asc', "| where State =~ '$State'`n| order by StartTime desc, ClusterName asc"
    }

    Write-Log -Message "Querying Azure Resource Graph for update-run failures (State=$State, View=$View, Since=$($sinceUtc)$(if($UpdateRingTag){", UpdateRingTag=$UpdateRingTag"})..." -Level Info

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
    Write-Log -Message "Resource Graph returned $($rows.Count) update-run row(s)." -Level Info

    # Optional UpdateRing tag filter via secondary ARG query. The updateruns
    # resource does NOT carry the cluster's tags, so a second hop is needed.
    if ($UpdateRingTag) {
        $ringFilter = ConvertTo-AzLocalUpdateRingKqlFilter -UpdateRingValue $UpdateRingTag -TagAccessor "tostring(tags['UpdateRing'])"
        $tagKql = @"
resources
| where type =~ 'microsoft.azurestackhci/clusters'
$ringFilter
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
        Write-Log -Message "Filtered to UpdateRing='$UpdateRingTag': $($rows.Count) of $before row(s) retained." -Level Info
    }

    # Always compute the latest-succeeded lookup (cheap second ARG query)
    # so the IsUnresolved column is populated on Detail-view rows even when
    # -OnlyUnresolved is not passed. This is useful information for pipeline
    # output and JSON exports - downstream consumers can filter client-side.
    $latestSucceededMap = @{}
    if ($View -eq 'Detail') {
        $succeededKql = @"
extensibilityresources
| where type =~ 'microsoft.azurestackhci/clusters/updates/updateruns'
| where tostring(properties.state) =~ 'Succeeded'
| extend segments = split(id, '/')
| extend ClusterResourceId = strcat('/subscriptions/', tostring(segments[2]), '/resourceGroups/', tostring(segments[4]), '/providers/Microsoft.AzureStackHCI/clusters/', tostring(segments[8]))
| extend UpdateName = tostring(segments[10])
| extend StartTime = todatetime(properties.timeStarted)
| summarize LatestSucceededStart = max(StartTime) by ClusterResourceId, UpdateName
"@
        try {
            $succeededRows = if ($SubscriptionId) {
                Invoke-AzResourceGraphQuery -Query $succeededKql -SubscriptionId $SubscriptionId
            } else {
                Invoke-AzResourceGraphQuery -Query $succeededKql
            }
        }
        catch {
            Write-Log -Message "Unresolved-check (latest Succeeded) query failed: $($_.Exception.Message)" -Level Warning
            $succeededRows = @()
        }
        $latestSucceededMap = @{}
        foreach ($s in @($succeededRows)) {
            if (-not $s) { continue }
            if (-not $s.ClusterResourceId) { continue }
            if (-not $s.LatestSucceededStart) { continue }
            $key = "$(($s.ClusterResourceId).ToLower())|$($s.UpdateName)"
            try {
                $latestSucceededMap[$key] = [datetime]$s.LatestSucceededStart
            }
            catch {
                Write-Log -Message "Skipping unresolved-check entry with unparseable LatestSucceededStart '$($s.LatestSucceededStart)' for $key" -Level Verbose
            }
        }
        Write-Log -Message "Latest-succeeded lookup loaded $($latestSucceededMap.Count) (cluster, update) entries." -Level Verbose
    }

    # Build the output the caller asked for.
    if ($View -eq 'Summary') {
        # Aggregate by ErrorCategory. ClusterCount desc puts the most-
        # widespread pattern first - the "fix this first" view.
        $output = @($rows |
            Group-Object -Property ErrorCategory |
            ForEach-Object {
                $first       = $_.Group | Select-Object -First 1
                $clusterList = @($_.Group | Select-Object -ExpandProperty ClusterName -Unique | Sort-Object)
                $latest      = ($_.Group | Measure-Object -Property StartTime -Maximum).Maximum
                [PSCustomObject]@{
                    ErrorCategory    = $_.Name
                    ClusterCount     = $clusterList.Count
                    FailureCount     = $_.Group.Count
                    AffectedClusters = ($clusterList -join ';')
                    LatestFailure    = $latest
                    SampleErrMsg     = if ($first.DeepestErrMsg) {
                        if ($first.DeepestErrMsg.Length -gt 400) {
                            $first.DeepestErrMsg.Substring(0, 400) + '...'
                        } else { $first.DeepestErrMsg }
                    } else { '' }
                    SampleStepName   = $first.DeepestStepName
                }
            } |
            Sort-Object @{Expression={$_.ClusterCount};Descending=$true},
                       @{Expression={$_.FailureCount};Descending=$true}
        )
    } else {
        # Detail view. Tag with IsUnresolved (always populated, see comment
        # above) and optionally filter. Drop ProgressJson when -IncludeRawProgress
        # was not supplied so the default output is pipeline-friendly.
        $rowsTagged = foreach ($r in $rows) {
            $key = "$(($r.ClusterResourceId).ToLower())|$($r.UpdateName)"
            $latestSucc = $null
            if ($latestSucceededMap.ContainsKey($key)) { $latestSucc = $latestSucceededMap[$key] }
            $isUnresolved = $true
            if ($null -ne $latestSucc -and $null -ne $r.StartTime -and ([datetime]$latestSucc) -ge ([datetime]$r.StartTime)) {
                $isUnresolved = $false
            }

            # v0.7.70: Fleet-scale failure-detail columns. The Azure portal SingleInstanceHistoryDetails
            # ReactView deep-link requires the cluster resource ID URL-encoded (the same
            # encoding the Azure portal expects). We URL-encode aggressively (every slash)
            # which the portal accepts as-is.
            $portalLink = ''
            if ($r.ClusterResourceId) {
                $encoded = [System.Uri]::EscapeDataString([string]$r.ClusterResourceId)
                $portalLink = "https://portal.azure.com/#view/Microsoft_AzureStackHCI_PortalExtension/SingleInstanceHistoryDetails.ReactView/resourceId/$encoded/updateName~/null/updateRunName~/null/refresh~/false"
            }

            # CurrentStep is a computed column derived from the deepest in-progress step:
            #   Failed -> the deepest failing step name (fall back to ProgressDescription)
            #   else  -> ProgressDescription
            $currentStep = ''
            if ($r.State -eq 'Failed') {
                if ($r.DeepestStepName) { $currentStep = $r.DeepestStepName }
                elseif ($r.ProgressDescription) { $currentStep = $r.ProgressDescription }
            } elseif ($r.ProgressDescription) {
                $currentStep = $r.ProgressDescription
            }

            # Formatted duration string "Xh Ym Zs" computed from StartTime/EndTime
            # (KQL gives us only DurationMinutes rounded). Skip if either bound is null.
            $durationFormatted = ''
            if ($r.StartTime -and $r.EndTime) {
                try {
                    $ts = ([datetime]$r.EndTime) - ([datetime]$r.StartTime)
                    $parts = @()
                    if ($ts.Days -gt 0)    { $parts += "$($ts.Days)d" }
                    if ($ts.Hours -gt 0)   { $parts += "$($ts.Hours)h" }
                    if ($ts.Minutes -gt 0) { $parts += "$($ts.Minutes)m" }
                    if ($ts.Seconds -gt 0 -or $parts.Count -eq 0) { $parts += "$($ts.Seconds)s" }
                    $durationFormatted = $parts -join ' '
                } catch { $durationFormatted = '' }
            }

            $obj = [PSCustomObject]@{
                ClusterName        = $r.ClusterName
                ResourceGroup      = $r.ResourceGroup
                SubscriptionId     = $r.SubscriptionId
                ClusterResourceId  = $r.ClusterResourceId
                ClusterPortalUrl   = if ($r.ClusterResourceId) { "https://portal.azure.com/#@/resource$($r.ClusterResourceId)" } else { '' }
                UpdateName         = $r.UpdateName
                RunId              = $r.RunId
                State              = $r.State
                Status             = $r.Status
                CurrentStep        = $currentStep
                StartTime          = $r.StartTime
                EndTime            = $r.EndTime
                LastUpdated        = $r.EndTime
                Duration           = $durationFormatted
                DurationMinutes    = $r.DurationMinutes
                DeepestStepDepth   = $r.DeepestStepDepth
                DeepestStepName    = $r.DeepestStepName
                DeepestErrMsg      = $r.DeepestErrMsg
                StackTracePreview  = $r.StackTracePreview
                ErrorCategory      = $r.ErrorCategory
                UpdateRunPortalUrl = $portalLink
                ProgressJsonBytes  = $r.ProgressJsonBytes
                IsUnresolved       = $isUnresolved
            }
            if ($IncludeRawProgress) {
                $obj | Add-Member -NotePropertyName 'ProgressJson' -NotePropertyValue $r.ProgressJson
            }
            $obj
        }

        if ($OnlyUnresolved) {
            $before = @($rowsTagged).Count
            $output = @($rowsTagged | Where-Object { $_.IsUnresolved })
            Write-Log -Message "OnlyUnresolved filter: $($output.Count) of $before row(s) retained." -Level Info
        } else {
            $output = @($rowsTagged)
        }
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
                    # Depth 4 is enough for these flat rows; the raw
                    # progressJson is already a string so no nested depth
                    # is consumed by it.
                    Write-Utf8NoBomFile -Path $ExportPath -Content ($output | ConvertTo-Json -Depth 4)
                    Write-Log -Message "Update-run failures ($View) exported to JSON: $ExportPath" -Level Success
                }
                default {
                    # Exclude ProgressJson from CSV - the multi-line string
                    # breaks most CSV readers even with quoting.
                    $csvRows = $output | Select-Object -Property * -ExcludeProperty ProgressJson
                    $csvRows | ConvertTo-SafeCsvCollection | Export-Csv -Path $ExportPath -NoTypeInformation -Force
                    Write-Log -Message "Update-run failures ($View) exported to CSV: $ExportPath" -Level Success
                }
            }
        }
        catch {
            Write-Log -Message "Failed to export update-run failures ($View): $($_.Exception.Message)" -Level Error
        }
    }

    # Summary log to host stream.
    if ($View -eq 'Summary' -and $output.Count -gt 0) {
        Write-Log -Message "" -Level Info
        Write-Log -Message "Top failure categories:" -Level Header
        foreach ($cat in $output | Select-Object -First 5) {
            Write-Log -Message ("  {0,-22} {1,3} clusters, {2,4} failures" -f $cat.ErrorCategory, $cat.ClusterCount, $cat.FailureCount) -Level Info
        }
    }

    # Return objects when -PassThru or when no export was requested.
    if ($PassThru -or -not $ExportPath) {
        return $output
    }
}
