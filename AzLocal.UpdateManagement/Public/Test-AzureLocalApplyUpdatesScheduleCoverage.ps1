function Test-AzureLocalApplyUpdatesScheduleCoverage {
    <#
    .SYNOPSIS
        Read-only advisor that compares the cron schedule(s) in your
        apply-updates pipeline YAML to the maintenance windows encoded in your
        clusters' UpdateWindow tags, and reports any rings whose windows would
        never be reached by the pipeline.
    .DESCRIPTION
        Apply Updates pipelines ship with no default schedule on purpose
        (manual workflow_dispatch / trigger:none) so customers must consciously
        choose when updates fire. This cmdlet helps the operator turn an
        UpdateWindow tag strategy into the *correct* set of cron entries, and
        catches drift later (e.g. a new ring tagged with a Saturday window when
        the pipeline only fires Monday).

        The cmdlet is read-only. It never edits cluster tags, never writes to
        YAML files, and never starts updates. It calls Azure Resource Graph
        through the module's existing Invoke-AzResourceGraphQuery helper and
        optionally parses one or more pipeline YAML files locally.

        Views:
          Audit      - Default. For each distinct (UpdateRing, UpdateWindow) pair
                       in the fleet, report whether the supplied pipeline YAML
                       has at least one cron that would fire during the window.
                       Output columns: Section ('Schedule' for schedule-file gap
                       rows or 'Cron' for cron-coverage rows), UpdateRing,
                       UpdateWindow, ClusterCount, Status, Issue, Recommendation,
                       MatchingCrons, RequiredCronUTC. Rows are pre-sorted with
                       Section='Schedule' first (higher blast radius - a missing
                       ring means apply-updates NEVER fires for those clusters),
                       then Section='Cron'. Within each section, the
                       most-actionable Status sorts to the top.
          Matrix     - Inventory view: every distinct (UpdateRing, UpdateWindow)
                       pair with cluster count and the cron expression the
                       advisor would generate for it.
          Recommend  - Markdown action-required output for an operator. When
                       -SchedulePath surfaces missing rings (the v1 schedule
                       file does not list a ring that is tagged on at least
                       one cluster) or orphaned rings (the schedule lists a
                       ring nothing in the fleet carries), the snippet leads
                       with the schedule fix(es) - blast radius is higher
                       because apply-updates will never run on the missing
                       ring(s). If any YAML cron line uses syntax the advisor
                       cannot evaluate, a `## Action required - simplify
                       unparseable cron expression(s)` section follows next so
                       the operator can rewrite those lines BEFORE accepting
                       the cron-coverage snippet (which may otherwise
                       over-suggest entries that duplicate an
                       already-correct-but-unparseable line). The YAML cron
                       snippet (one per platform) follows in a `## Action
                       required - cron coverage` section. When only one
                       action applies the numbering prefix is dropped.

        Status values (Audit):
          Covered                  - at least one cron in the YAML fires during the window
          Uncovered                - no cron in the YAML fires during the window
          PartiallyCovered         - multi-segment window where some segments are covered and others are not
          NoWindowTag              - cluster(s) have no UpdateWindow tag (only emitted when -IncludeUntagged is supplied)
          MalformedTag             - the UpdateWindow tag value failed to parse
          UnparseableCron          - a cron in the YAML used syntax the advisor cannot evaluate
                                     (e.g. DayOfMonth restrictions, step values); manual review required
          RingMissingFromSchedule  - a ring on at least one cluster's UpdateRing tag has no matching
                                     row in the v1 schedule file (only emitted when -SchedulePath is supplied)
          RingOrphanedInSchedule   - a ring listed in the v1 schedule file's `rings` column does NOT
                                     appear on any cluster's UpdateRing tag (only emitted when -SchedulePath is supplied)
    .PARAMETER SubscriptionId
        Optional subscription scope passed to Resource Graph. If omitted, the
        query runs against every subscription the caller can read.
    .PARAMETER View
        'Audit' (default), 'Matrix', or 'Recommend'.
    .PARAMETER PipelineYamlPath
        Optional for -View Audit. Path to a single Step.5_apply-updates.yml file, or to
        a folder that contains apply-updates*.yml files (typically the
        Automation-Pipeline-Examples folder of your forked module). Drives the
        cron-vs-UpdateWindow coverage check. May be supplied together with
        -SchedulePath; at least one of the two is required for -View Audit.
    .PARAMETER SchedulePath
        Optional for -View Audit. Path to a v1 apply-updates-schedule.yml
        (the file consumed by Resolve-AzLocalCurrentUpdateRing). When supplied,
        the advisor performs a two-way ring diff between the schedule's `rings`
        column and the fleet's UpdateRing tag values and emits one extra row
        per discrepancy (RingMissingFromSchedule / RingOrphanedInSchedule).
        Generate a starter schedule from the live fleet via:
          New-AzLocalApplyUpdatesScheduleConfig -OutputPath .\apply-updates-schedule.yml
        Migrate an existing schedule to the current schema via:
          Update-AzLocalApplyUpdatesScheduleConfig -Path .\apply-updates-schedule.yml -SchemaMigrate
    .PARAMETER Platform
        Which platform's recommendation to emit (-View Recommend). Default 'Both'.
    .PARAMETER LeadTimeMinutes
        How many minutes before each window opens the pipeline should fire so
        that the first cluster's apply step starts inside the window. Default 5.
    .PARAMETER UpdateRingTag
        Optional filter: only evaluate clusters whose UpdateRing tag matches one
        of these values. Repeat or comma-separate for multiple rings.
    .PARAMETER IncludeUntagged
        Include clusters with no UpdateWindow tag as their own 'NoWindowTag' row.
        Off by default to keep the report focused on tagged rings.
    .PARAMETER ExportPath
        Optional output file. Format inferred from extension: .csv, .json, .md.
        For .md the cmdlet renders a markdown table per view. Audit + Matrix
        export the table; Recommend exports the YAML snippet.
    .PARAMETER PassThru
        Emit objects to the pipeline even when -ExportPath was supplied.
    .OUTPUTS
        PSCustomObject[] - shape depends on -View (see Status values above).
    .EXAMPLE
        Test-AzureLocalApplyUpdatesScheduleCoverage -PipelineYamlPath .\Automation-Pipeline-Examples
        # Audit every ring against the in-repo apply-updates pipelines.
    .EXAMPLE
        Test-AzureLocalApplyUpdatesScheduleCoverage -View Recommend -Platform GitHubActions
        # Generate a copy-paste schedule: block covering every fleet window.
    .EXAMPLE
        Test-AzureLocalApplyUpdatesScheduleCoverage -View Matrix -ExportPath .\windows.csv
        # Inventory all (Ring, Window) pairs and dump to CSV.
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
        [ValidateSet('Audit', 'Matrix', 'Recommend')]
        [string]$View = 'Audit',

        [Parameter(Mandatory = $false)]
        [string]$PipelineYamlPath,

        [Parameter(Mandatory = $false)]
        [string]$SchedulePath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('GitHubActions', 'AzureDevOps', 'Both')]
        [string]$Platform = 'Both',

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 60)]
        [int]$LeadTimeMinutes = 5,

        [Parameter(Mandatory = $false)]
        [string[]]$UpdateRingTag,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeUntagged,

        [Parameter(Mandatory = $false)]
        [string]$ExportPath,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    # Pre-flight: -View Audit requires AT LEAST ONE of -PipelineYamlPath or -SchedulePath.
    if ($View -eq 'Audit' -and
        [string]::IsNullOrWhiteSpace($PipelineYamlPath) -and
        [string]::IsNullOrWhiteSpace($SchedulePath)) {
        throw "-View 'Audit' requires at least one of -PipelineYamlPath or -SchedulePath. Point -PipelineYamlPath at Step.5_apply-updates.yml (or the Automation-Pipeline-Examples folder) and/or -SchedulePath at your apply-updates-schedule.yml."
    }
    if ($PipelineYamlPath -and -not (Test-Path -LiteralPath $PipelineYamlPath)) {
        throw "PipelineYamlPath not found: $PipelineYamlPath"
    }
    if ($SchedulePath) {
        if (-not (Test-Path -LiteralPath $SchedulePath)) {
            throw "SchedulePath not found: $SchedulePath"
        }
        if ((Get-Item -LiteralPath $SchedulePath).PSIsContainer) {
            throw "SchedulePath must point at a single apply-updates-schedule.yml file, not a folder: $SchedulePath"
        }
    }
    if ($ExportPath) {
        try { Test-ExportPathWritable -Path $ExportPath | Out-Null }
        catch { throw "ExportPath is not writable: $($_.Exception.Message)" }
    }

    # 1. Pull every cluster's UpdateRing + UpdateWindow tags via Resource Graph.
    # NOTE on multi-line KQL: a here-string with embedded newlines used to be
    # silently truncated to its first line on Windows because az.cmd's CMD
    # argument parser stops at the first CR/LF. That caused this audit to
    # report "No tagged clusters found" even when clusters were tagged
    # correctly. Fixed in v0.7.68 by normalising the query string inside
    # Invoke-AzResourceGraphQuery (collapses any whitespace into single spaces
    # before invoking az). KQL is whitespace-agnostic so the projection,
    # filtering and ordering semantics are preserved.
    $kql = @"
resources
| where type =~ 'microsoft.azurestackhci/clusters'
| project
    ClusterName       = name,
    ResourceGroup     = resourceGroup,
    SubscriptionId    = subscriptionId,
    ClusterResourceId = id,
    UpdateRing        = tostring(tags['UpdateRing']),
    UpdateWindow      = tostring(tags['UpdateWindow'])
"@

    Write-Log -Message "Querying Azure Resource Graph for UpdateRing + UpdateWindow tags across the fleet (View=$View)..." -Level Info
    try {
        $clusters = if ($SubscriptionId) {
            Invoke-AzResourceGraphQuery -Query $kql -SubscriptionId $SubscriptionId
        } else {
            Invoke-AzResourceGraphQuery -Query $kql
        }
    }
    catch {
        Write-Log -Message "Resource Graph query failed: $($_.Exception.Message)" -Level Error
        throw
    }
    if (-not $clusters) { $clusters = @() }
    Write-Log -Message "Resource Graph returned $($clusters.Count) cluster(s)." -Level Info

    # Snapshot every distinct fleet UpdateRing BEFORE the optional -UpdateRingTag
    # filter. The two-way ring diff (when -SchedulePath is supplied) compares
    # the schedule file against the FULL fleet, not just the rings the operator
    # chose to focus this run on.
    $allFleetRings = @(
        $clusters |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_.UpdateRing) } |
            ForEach-Object { $_.UpdateRing.Trim() } |
            Sort-Object -Unique
    )

    # Optional UpdateRing filter.
    if ($UpdateRingTag) {
        $allowed = @{}
        foreach ($r in $UpdateRingTag) { $allowed[$r.ToLower()] = $true }
        $before = $clusters.Count
        $clusters = @($clusters | Where-Object { $_.UpdateRing -and $allowed.ContainsKey($_.UpdateRing.ToLower()) })
        Write-Log -Message "Filtered to UpdateRing in {$($UpdateRingTag -join ',')}: $($clusters.Count) of $before clusters retained." -Level Info
    }

    # 2. Bucket clusters by (UpdateRing, UpdateWindow).
    $taggedClusters   = @($clusters | Where-Object { -not [string]::IsNullOrWhiteSpace($_.UpdateWindow) })
    $untaggedClusters = @($clusters | Where-Object {     [string]::IsNullOrWhiteSpace($_.UpdateWindow) })

    # 2a. Two-way ring diff: schedule.rings vs fleet UpdateRing tags.
    #     Computed BEFORE the switch ($View) so both -View Audit (row emission)
    #     and -View Recommend (action-required markdown) can reference the
    #     results without re-loading the schedule file. Compares $allFleetRings
    #     (pre-filter snapshot) against the schedule so the diff reflects the
    #     whole fleet, not just the rings the operator scoped this run to via
    #     -UpdateRingTag.
    $scheduleRings        = @()
    $missingFromSchedule  = @()
    $orphanedInSchedule   = @()
    $scheduleDiffComputed = $false
    if (-not [string]::IsNullOrWhiteSpace($SchedulePath)) {
        try {
            $scheduleCfg = Get-AzLocalApplyUpdatesScheduleConfig -Path $SchedulePath
        }
        catch {
            Write-Log -Message "Failed to load schedule from '$SchedulePath': $($_.Exception.Message)" -Level Error
            throw
        }

        # Collect distinct rings referenced by the schedule. Each row's
        # `rings` cell is a ';'-separated string (same convention used
        # by Resolve-AzLocalCurrentUpdateRing).
        $scheduleRingSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($srow in @($scheduleCfg.Schedule)) {
            foreach ($r in ($srow.rings -split ';')) {
                $tr = $r.Trim()
                if (-not [string]::IsNullOrWhiteSpace($tr)) { [void]$scheduleRingSet.Add($tr) }
            }
        }
        $scheduleRings = @($scheduleRingSet)
        Write-Log -Message "Schedule '$SchedulePath' references $($scheduleRings.Count) distinct ring(s): $($scheduleRings -join ', ')." -Level Info
        Write-Log -Message "Fleet has $($allFleetRings.Count) distinct UpdateRing tag value(s): $($allFleetRings -join ', ')." -Level Info

        # Wildcard handling: the example.yml mentions '***' (every cluster
        # carrying an UpdateRing tag). The current resolver treats it as a
        # literal string, so the audit also treats it as a literal - if you
        # put '***' in your schedule, it shows up as an orphan ring unless
        # your fleet has a cluster tagged literally '***'. This is
        # intentional: it keeps the audit and the resolver in sync. When the
        # resolver gains wildcard support, update this block accordingly.
        $fleetSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($fr in $allFleetRings) { [void]$fleetSet.Add($fr) }

        # Rings on at least one cluster but absent from the schedule.
        $missingFromSchedule = @($allFleetRings | Where-Object { -not $scheduleRingSet.Contains($_) })
        # Rings in the schedule file but absent from the fleet.
        $orphanedInSchedule  = @($scheduleRings  | Where-Object { -not $fleetSet.Contains($_) })
        $scheduleDiffComputed = $true

        if ($missingFromSchedule.Count -eq 0 -and $orphanedInSchedule.Count -eq 0) {
            Write-Log -Message "Two-way ring diff: schedule and fleet ring sets match." -Level Success
        }
    }

    $groups = @($taggedClusters | Group-Object -Property @{Expression={ "$($_.UpdateRing)|$($_.UpdateWindow)" }})

    # 3. Resolve each distinct (Ring, Window): parse window, derive required cron.
    $coverageRows = New-Object System.Collections.Generic.List[PSCustomObject]
    foreach ($g in $groups) {
        $first  = $g.Group | Select-Object -First 1
        $ring   = $first.UpdateRing
        $window = $first.UpdateWindow

        $row = [PSCustomObject]@{
            UpdateRing      = if ($ring) { $ring } else { '(none)' }
            UpdateWindow    = $window
            ClusterCount    = $g.Count
            ParsedSegments  = $null
            RequiredCrons   = @()
            ParseError      = $null
        }
        try {
            $row.RequiredCrons = @(Convert-AzLocalUpdateWindowToCron -UpdateWindow $window -LeadTimeMinutes $LeadTimeMinutes)
        }
        catch {
            $row.ParseError = $_.Exception.Message
        }
        $coverageRows.Add($row)
    }

    # 4. If Audit: load YAML crons and check coverage.
    #    -PipelineYamlPath is optional now (it can be omitted when only the
    #    -SchedulePath two-way ring diff is wanted), so the YAML read is
    #    guarded.
    $yamlCrons        = @()
    $parsedYamlCrons  = @()
    if ($View -eq 'Audit' -and -not [string]::IsNullOrWhiteSpace($PipelineYamlPath)) {
        $yamlCrons = @(Read-AzLocalApplyUpdatesYamlCrons -Path $PipelineYamlPath)
        Write-Log -Message "Discovered $($yamlCrons.Count) cron entry(ies) across apply-updates YAML file(s)." -Level Info
        $parsedYamlCrons = @($yamlCrons | ForEach-Object {
            # Defense-in-depth: the reader strips whitespace-only captures and
            # ConvertFrom-AzLocalCronExpression now accepts [AllowEmptyString()],
            # but explicitly handling empty/null here keeps the audit alive even
            # if a future reader regression leaks one through. Surfaces as an
            # invalid row rather than throwing 'Cannot bind argument to parameter
            # Expression because it is an empty string' at the binder.
            if ([string]::IsNullOrWhiteSpace($_.CronExpression)) {
                $parsed = [PSCustomObject]@{
                    Raw          = $_.CronExpression
                    IsValid      = $false
                    IsComplex    = $false
                    ErrorMessage = 'Cron expression is empty or whitespace.'
                    FireTimes    = @()
                }
            }
            else {
                $parsed = ConvertFrom-AzLocalCronExpression -Expression $_.CronExpression
            }
            [PSCustomObject]@{
                Source     = $_
                Parsed     = $parsed
            }
        })
        $unparseable = @($parsedYamlCrons | Where-Object { -not $_.Parsed.IsValid -or $_.Parsed.IsComplex })
        if ($unparseable.Count -gt 0) {
            foreach ($u in $unparseable) {
                Write-Log -Message "Cron '$($u.Source.CronExpression)' in $($u.Source.RelativePath):$($u.Source.LineNumber) - $($u.Parsed.ErrorMessage)" -Level Warning
            }
        }
    }

    # 5. Render the requested view.
    $output = switch ($View) {

        'Matrix' {
            $rows = New-Object System.Collections.Generic.List[PSCustomObject]
            foreach ($r in $coverageRows) {
                $cronStr = if ($r.ParseError) { '(unparseable)' }
                           else { ($r.RequiredCrons | ForEach-Object { $_.CronExpression }) -join '; ' }
                $rows.Add([PSCustomObject]@{
                    UpdateRing      = $r.UpdateRing
                    UpdateWindow    = $r.UpdateWindow
                    ClusterCount    = $r.ClusterCount
                    RequiredCronUTC = $cronStr
                    ParseError      = $r.ParseError
                })
            }
            if ($IncludeUntagged -and $untaggedClusters.Count -gt 0) {
                # Group untagged by ring for visibility.
                $untaggedByRing = $untaggedClusters | Group-Object -Property @{Expression={ if ($_.UpdateRing) { $_.UpdateRing } else { '(none)' } }}
                foreach ($ug in $untaggedByRing) {
                    $rows.Add([PSCustomObject]@{
                        UpdateRing      = $ug.Name
                        UpdateWindow    = ''
                        ClusterCount    = $ug.Count
                        RequiredCronUTC = '(no UpdateWindow tag)'
                        ParseError      = $null
                    })
                }
            }
            , @($rows | Sort-Object UpdateRing, UpdateWindow)
        }

        'Recommend' {
            # Dedupe required crons across rings; preserve a comment that
            # records which ring(s) drove each cron.
            $byCron = @{}
            foreach ($r in $coverageRows) {
                if ($r.ParseError) { continue }
                foreach ($c in $r.RequiredCrons) {
                    $key = $c.CronExpression
                    if (-not $byCron.ContainsKey($key)) {
                        $byCron[$key] = @{ Rings = @(); Clusters = 0; Segment = $c.Segment }
                    }
                    $byCron[$key].Rings += $r.UpdateRing
                    $byCron[$key].Clusters += $r.ClusterCount
                }
            }

            # Build the cron-coverage YAML snippet (existing behaviour).
            $cronSb = New-Object System.Text.StringBuilder
            if ($Platform -in @('GitHubActions','Both')) {
                [void]$cronSb.AppendLine('# --- GitHub Actions: paste under Step.5_apply-updates.yml `on:` ---')
                [void]$cronSb.AppendLine('# schedule:')
                foreach ($k in ($byCron.Keys | Sort-Object)) {
                    $entry = $byCron[$k]
                    [void]$cronSb.AppendLine(("#   - cron: '{0}'   # {1} (rings: {2}, {3} cluster(s))" -f $k, $entry.Segment, (($entry.Rings | Sort-Object -Unique) -join ','), $entry.Clusters))
                }
                [void]$cronSb.AppendLine()
            }
            if ($Platform -in @('AzureDevOps','Both')) {
                [void]$cronSb.AppendLine('# --- Azure DevOps: paste at the top level of Step.5_apply-updates.yml ---')
                [void]$cronSb.AppendLine('# schedules:')
                foreach ($k in ($byCron.Keys | Sort-Object)) {
                    $entry = $byCron[$k]
                    [void]$cronSb.AppendLine(("#   - cron: '{0}'   # {1} (rings: {2}, {3} cluster(s))" -f $k, $entry.Segment, (($entry.Rings | Sort-Object -Unique) -join ','), $entry.Clusters))
                    [void]$cronSb.AppendLine('#     displayName: "Apply Updates - covers above window"')
                    [void]$cronSb.AppendLine('#     branches:')
                    [void]$cronSb.AppendLine('#       include: [ main ]')
                    [void]$cronSb.AppendLine('#     always: true')
                }
            }
            $cronSnippetBody = $cronSb.ToString()

            # Build the full multi-section Snippet. When -SchedulePath supplies
            # schedule-file gaps, prepend a markdown section for each gap kind.
            # Schedule sections come FIRST (higher blast radius - a missing
            # ring means apply-updates NEVER fires for those clusters); the
            # UnparseableCron section comes next so reviewers fix syntax the
            # advisor cannot reason about BEFORE accepting the cron coverage
            # recommendation (which may otherwise over-suggest crons that
            # duplicate an already-correct-but-unparseable line); the cron
            # coverage section comes last.
            # v0.7.71: $unparseableCrons surfaces each YAML cron whose syntax
            # the advisor could not evaluate (DayOfMonth restrictions, step
            # values, etc), with file:line + the parser's error message, so
            # the operator can fix the source line directly from the Step
            # Summary instead of cross-referencing the Audit Detail table.
            $hasMissing       = $scheduleDiffComputed -and $missingFromSchedule.Count -gt 0
            $hasOrphaned      = $scheduleDiffComputed -and $orphanedInSchedule.Count  -gt 0
            $unparseableCrons = @($parsedYamlCrons | Where-Object { -not $_.Parsed.IsValid -or $_.Parsed.IsComplex })
            $hasUnparseable   = $unparseableCrons.Count -gt 0
            $actionCount      = @($hasMissing, $hasOrphaned, $hasUnparseable, ($byCron.Count -gt 0)) | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
            $actionIdx        = 0

            $fullSb = New-Object System.Text.StringBuilder

            if ($hasMissing) {
                $actionIdx++
                $prefix = if ($actionCount -gt 1) { " ($actionIdx of $actionCount)" } else { '' }
                [void]$fullSb.AppendLine("## Action required$prefix - add these rings to your apply-updates-schedule.yml")
                [void]$fullSb.AppendLine()
                [void]$fullSb.AppendLine("These ring(s) are tagged on at least one cluster but do not appear in any row of ``$SchedulePath``. Resolve-AzLocalCurrentUpdateRing will never return them, so Step.5 apply-updates will NEVER fire on those clusters until you either add the ring to the schedule or retag those clusters onto an existing scheduled ring.")
                [void]$fullSb.AppendLine()
                [void]$fullSb.AppendLine('| UpdateRing | Clusters | Fix |')
                [void]$fullSb.AppendLine('|---|---|---|')
                foreach ($ring in ($missingFromSchedule | Sort-Object)) {
                    $clusterCount = @($clusters | Where-Object { $_.UpdateRing -and ($_.UpdateRing.Trim() -ieq $ring) }).Count
                    [void]$fullSb.AppendLine("| $ring | $clusterCount | Add ``$ring`` to an existing schedule row's ``rings`` column (semicolon-separated), or retag the cluster(s) onto an existing scheduled ring. The advisor does NOT auto-suggest a row (weeksInCycle / daysOfWeek / startTime are deliberate ring-cadence decisions for the operator). |")
                }
                [void]$fullSb.AppendLine()
            }

            if ($hasOrphaned) {
                $actionIdx++
                $prefix = if ($actionCount -gt 1) { " ($actionIdx of $actionCount)" } else { '' }
                [void]$fullSb.AppendLine("## Action required$prefix - prune orphaned rings from your apply-updates-schedule.yml")
                [void]$fullSb.AppendLine()
                [void]$fullSb.AppendLine("These ring(s) are listed in ``$SchedulePath`` but no cluster in the fleet carries an UpdateRing tag matching them. The schedule row(s) that reference them will resolve to a ring that matches nothing, so the schedule entry is dead weight.")
                [void]$fullSb.AppendLine()
                [void]$fullSb.AppendLine('| UpdateRing | Fix |')
                [void]$fullSb.AppendLine('|---|---|')
                foreach ($ring in ($orphanedInSchedule | Sort-Object)) {
                    [void]$fullSb.AppendLine("| $ring | Either tag at least one cluster with ``UpdateRing=$ring`` (e.g. Set-AzureLocalClusterUpdateRingTag), or remove ``$ring`` from the schedule file's ``rings`` column(s). |")
                }
                [void]$fullSb.AppendLine()
            }

            if ($hasUnparseable) {
                $actionIdx++
                $prefix = if ($actionCount -gt 1) { " ($actionIdx of $actionCount)" } else { '' }
                [void]$fullSb.AppendLine("## Action required$prefix - simplify unparseable cron expression(s)")
                [void]$fullSb.AppendLine()
                [void]$fullSb.AppendLine("The advisor could not reason about the following cron line(s). UpdateWindow coverage for these crons was NOT evaluated, so the cron-coverage recommendation below may over-suggest entries that duplicate what an already-correct-but-unparseable line is doing. Resolve these first.")
                [void]$fullSb.AppendLine()
                [void]$fullSb.AppendLine('Supported syntax: ``minute`` and ``hour`` may be a literal value, a comma-list, or a range (``a-b``); ``day-of-month`` and ``month`` must be ``*``; ``day-of-week`` may be ``*``, a literal value, a comma-list, or a range. Step values (``*/n``), lists/ranges in ``day-of-month`` or ``month``, and names (``MON``, ``JAN``) are not yet supported.')
                [void]$fullSb.AppendLine()
                [void]$fullSb.AppendLine('| Source (file:line) | Cron | Parser error | Fix |')
                [void]$fullSb.AppendLine('|---|---|---|---|')
                foreach ($pc in ($unparseableCrons | Sort-Object { $_.Source.RelativePath }, { [int]$_.Source.LineNumber })) {
                    $src  = "$($pc.Source.RelativePath):$($pc.Source.LineNumber)"
                    $cron = ($pc.Source.CronExpression -replace '\|','\|')
                    $err  = (($pc.Parsed.ErrorMessage) -replace '\|','\|')
                    [void]$fullSb.AppendLine("| ``$src`` | ``$cron`` | $err | Rewrite the expression using only the supported subset above (split a complex cron into multiple simpler crons if needed), or remove the line if the cluster(s) it targets are now covered by another cron. |")
                }
                [void]$fullSb.AppendLine()
            }

            if ($byCron.Count -gt 0) {
                $actionIdx++
                $prefix = if ($actionCount -gt 1) { " ($actionIdx of $actionCount)" } else { '' }
                [void]$fullSb.AppendLine("## Action required$prefix - cron coverage")
                [void]$fullSb.AppendLine()
                [void]$fullSb.AppendLine('Paste the following cron snippet into Step.5_apply-updates.yml so the pipeline fires inside every UpdateWindow currently tagged on the fleet:')
                [void]$fullSb.AppendLine()
                [void]$fullSb.AppendLine('```yaml')
                foreach ($line in ($cronSnippetBody -split "`r?`n")) {
                    [void]$fullSb.AppendLine($line)
                }
                [void]$fullSb.AppendLine('```')
            }

            $snippet = $fullSb.ToString()
            Write-Log -Message "Recommended schedule:" -Level Header
            $snippet -split "`r?`n" | ForEach-Object { if ($_) { Write-Log -Message $_ -Level Info } }

            # Emit objects so -PassThru consumers can also act on the data.
            # Schedule-gap rows come first (higher blast radius); cron rows
            # follow. Every row carries the full Snippet so legacy callers
            # that read $result[0].Snippet keep working.
            $items = New-Object System.Collections.Generic.List[PSCustomObject]
            if ($hasMissing) {
                foreach ($ring in ($missingFromSchedule | Sort-Object)) {
                    $clusterCount = @($clusters | Where-Object { $_.UpdateRing -and ($_.UpdateRing.Trim() -ieq $ring) }).Count
                    $items.Add([PSCustomObject]@{
                        Section        = 'Schedule'
                        Status         = 'RingMissingFromSchedule'
                        UpdateRing     = $ring
                        CronExpression = $null
                        Segment        = $null
                        Rings          = @($ring)
                        ClusterCount   = $clusterCount
                        Snippet        = $snippet
                    })
                }
            }
            if ($hasOrphaned) {
                foreach ($ring in ($orphanedInSchedule | Sort-Object)) {
                    $items.Add([PSCustomObject]@{
                        Section        = 'Schedule'
                        Status         = 'RingOrphanedInSchedule'
                        UpdateRing     = $ring
                        CronExpression = $null
                        Segment        = $null
                        Rings          = @($ring)
                        ClusterCount   = 0
                        Snippet        = $snippet
                    })
                }
            }
            foreach ($k in ($byCron.Keys | Sort-Object)) {
                $entry = $byCron[$k]
                $items.Add([PSCustomObject]@{
                    Section        = 'Cron'
                    Status         = $null
                    UpdateRing     = $null
                    CronExpression = $k
                    Segment        = $entry.Segment
                    Rings          = ($entry.Rings | Sort-Object -Unique)
                    ClusterCount   = $entry.Clusters
                    Snippet        = $snippet
                })
            }
            , @($items)
        }

        'Audit' {
            $rows = New-Object System.Collections.Generic.List[PSCustomObject]
            foreach ($r in $coverageRows) {
                if ($r.ParseError) {
                    $rows.Add([PSCustomObject]@{
                        Section         = 'Cron'
                        UpdateRing      = $r.UpdateRing
                        UpdateWindow    = $r.UpdateWindow
                        ClusterCount    = $r.ClusterCount
                        Status          = 'MalformedTag'
                        Issue           = "UpdateWindow tag failed to parse: $($r.ParseError)"
                        Recommendation  = 'Fix the UpdateWindow tag value. Syntax: <days>_<HH:MM>-<HH:MM>[;...]'
                        MatchingCrons   = @()
                        RequiredCronUTC = ''
                    })
                    continue
                }

                # For each required cron (one per window segment), find YAML
                # crons whose fire times intersect the window opening.
                $segmentStatuses = @()
                foreach ($req in $r.RequiredCrons) {
                    # Window times in the reference week: convert the segment back to a
                    # (firingDate, windowStart, windowEnd) tuple per firing day.
                    $parsed = ConvertFrom-AzLocalUpdateWindow -WindowString $r.UpdateWindow |
                              Where-Object { $_.Raw -eq $req.Segment } | Select-Object -First 1
                    $covered = $false
                    $matched = New-Object System.Collections.Generic.List[string]
                    $dowToInt = @{
                        [System.DayOfWeek]::Sunday=0; [System.DayOfWeek]::Monday=1;
                        [System.DayOfWeek]::Tuesday=2; [System.DayOfWeek]::Wednesday=3;
                        [System.DayOfWeek]::Thursday=4; [System.DayOfWeek]::Friday=5;
                        [System.DayOfWeek]::Saturday=6
                    }
                    $weekStart = [datetime]::new(2024, 1, 7, 0, 0, 0, [DateTimeKind]::Utc)
                    foreach ($d in $parsed.Days) {
                        $dayIdx    = $dowToInt[$d]
                        $dayDate   = $weekStart.AddDays($dayIdx)
                        $winOpen   = $dayDate.Add($parsed.StartTime)
                        $winClose  = if ($parsed.Overnight) {
                            $dayDate.AddDays(1).Add($parsed.EndTime)
                        } else {
                            $dayDate.Add($parsed.EndTime)
                        }
                        # Cron is considered covering when it fires in
                        # [winOpen - 60min, winOpen + 15min] - the leading 60min slack
                        # allows for module install + ARG warmup before the first
                        # apply call inside the gate; the trailing 15min tolerates
                        # cron + runner-startup jitter. We deliberately do NOT count
                        # crons that fire deeper inside the window (or in the
                        # overnight tail that bleeds into the next day) as "Covered" -
                        # the audit's job is to ensure a cron fires close to the
                        # window OPENING so the pipeline starts when the operator
                        # intends it to, not by accident from a different ring's
                        # cron landing in the tail of an overnight window.
                        $earliest = $winOpen.AddMinutes(-60)
                        $latest   = $winOpen.AddMinutes(15)
                        foreach ($pc in $parsedYamlCrons) {
                            if (-not $pc.Parsed.IsValid -or $pc.Parsed.IsComplex) { continue }
                            foreach ($ft in $pc.Parsed.FireTimes) {
                                if ($ft -ge $earliest -and $ft -le $latest) {
                                    $covered = $true
                                    $label = "$($pc.Source.RelativePath):$($pc.Source.LineNumber) '$($pc.Source.CronExpression)'"
                                    if (-not $matched.Contains($label)) { $matched.Add($label) }
                                    break
                                }
                            }
                        }
                    }
                    $segmentStatuses += [PSCustomObject]@{
                        Segment       = $req.Segment
                        Covered       = $covered
                        MatchingCrons = $matched.ToArray()
                        RequiredCron  = $req.CronExpression
                    }
                }

                # Roll segments into a single status row.
                $coveredCount = @($segmentStatuses | Where-Object { $_.Covered }).Count
                $status = if ($coveredCount -eq 0) { 'Uncovered' }
                          elseif ($coveredCount -eq $segmentStatuses.Count) { 'Covered' }
                          else { 'PartiallyCovered' }
                $allMatched = @($segmentStatuses.MatchingCrons | Select-Object -Unique)
                $allRequired = ($segmentStatuses | ForEach-Object { $_.RequiredCron }) -join '; '
                $issue = switch ($status) {
                    'Covered'          { '' }
                    'Uncovered'        { "No cron in '$PipelineYamlPath' fires during $($r.UpdateWindow) for ring '$($r.UpdateRing)' ($($r.ClusterCount) cluster(s))." }
                    'PartiallyCovered' {
                        $missing = ($segmentStatuses | Where-Object { -not $_.Covered } | ForEach-Object { $_.Segment }) -join '; '
                        "Some window segment(s) are not covered: $missing"
                    }
                }
                $reco = switch ($status) {
                    'Covered'          { 'OK - keep the current schedule.' }
                    default            { "Add: $allRequired" }
                }
                $rows.Add([PSCustomObject]@{
                    Section         = 'Cron'
                    UpdateRing      = $r.UpdateRing
                    UpdateWindow    = $r.UpdateWindow
                    ClusterCount    = $r.ClusterCount
                    Status          = $status
                    Issue           = $issue
                    Recommendation  = $reco
                    MatchingCrons   = $allMatched
                    RequiredCronUTC = $allRequired
                })
            }
            if ($IncludeUntagged -and $untaggedClusters.Count -gt 0) {
                $rows.Add([PSCustomObject]@{
                    Section         = 'Cron'
                    UpdateRing      = '(any)'
                    UpdateWindow    = ''
                    ClusterCount    = $untaggedClusters.Count
                    Status          = 'NoWindowTag'
                    Issue           = "$($untaggedClusters.Count) cluster(s) have no UpdateWindow tag and will be updated whenever the pipeline runs."
                    Recommendation  = 'Tag clusters with UpdateWindow=<days>_<HH:MM>-<HH:MM> so the runtime gate (Test-AzureLocalUpdateScheduleAllowed) can enforce a maintenance window.'
                    MatchingCrons   = @()
                    RequiredCronUTC = ''
                })
            }
            # Surface unparseable crons as their own row(s) so reviewers know
            # the advisor could not reason about that schedule line.
            foreach ($pc in $parsedYamlCrons) {
                if (-not $pc.Parsed.IsValid -or $pc.Parsed.IsComplex) {
                    $rows.Add([PSCustomObject]@{
                        Section         = 'Cron'
                        UpdateRing      = '(yaml)'
                        UpdateWindow    = ''
                        ClusterCount    = 0
                        Status          = 'UnparseableCron'
                        Issue           = "$($pc.Source.RelativePath):$($pc.Source.LineNumber) '$($pc.Source.CronExpression)' - $($pc.Parsed.ErrorMessage)"
                        Recommendation  = 'Simplify the cron (use only minute, hour, *, *, day-of-week subset) or audit manually.'
                        MatchingCrons   = @()
                        RequiredCronUTC = ''
                    })
                }
            }

            # Two-way ring diff rows (results were computed before the
            # switch ($View) so the Recommend view can reference them too).
            # Only emitted when -SchedulePath was supplied.
            if ($scheduleDiffComputed) {
                foreach ($ring in $missingFromSchedule) {
                    $clusterCount = @($clusters | Where-Object { $_.UpdateRing -and ($_.UpdateRing.Trim() -ieq $ring) }).Count
                    $rows.Add([PSCustomObject]@{
                        Section         = 'Schedule'
                        UpdateRing      = $ring
                        UpdateWindow    = ''
                        ClusterCount    = $clusterCount
                        Status          = 'RingMissingFromSchedule'
                        Issue           = "Ring '$ring' is tagged on $clusterCount cluster(s) but no row in '$SchedulePath' lists it in its `rings` column. Resolve-AzLocalCurrentUpdateRing will NEVER return this ring, so apply-updates will never fire for these cluster(s)."
                        Recommendation  = "Either add '$ring' to an existing schedule row's rings column (semicolon-separated) or run Update-AzLocalApplyUpdatesScheduleConfig (when a v1->vN migration recipe ships) to regenerate. Alternatively, retag the cluster(s) onto an existing scheduled ring."
                        MatchingCrons   = @()
                        RequiredCronUTC = ''
                    })
                }
                foreach ($ring in $orphanedInSchedule) {
                    $rows.Add([PSCustomObject]@{
                        Section         = 'Schedule'
                        UpdateRing      = $ring
                        UpdateWindow    = ''
                        ClusterCount    = 0
                        Status          = 'RingOrphanedInSchedule'
                        Issue           = "Ring '$ring' is listed in '$SchedulePath' but no cluster in the fleet carries an UpdateRing='$ring' tag. The schedule row(s) that reference it will resolve to a ring nothing will match."
                        Recommendation  = "Either tag at least one cluster with UpdateRing='$ring' (e.g. Set-AzureLocalClusterUpdateRingTag) or remove '$ring' from the schedule file's rings column(s)."
                        MatchingCrons   = @()
                        RequiredCronUTC = ''
                    })
                }
            }
            # Sort with Section primary (Schedule first, then Cron) so the
            # two sub-tables come out pre-grouped for renderers that read the
            # collection top-to-bottom. Within each section, ordering keeps the
            # existing severity precedence (most-actionable rows first).
            , @($rows | Sort-Object `
                @{Expression={ if ($_.Section -eq 'Schedule') {1} else {2} }},
                @{Expression={ switch ($_.Status) { 'RingMissingFromSchedule' {1} 'RingOrphanedInSchedule' {2} 'Uncovered' {3} 'PartiallyCovered' {4} 'MalformedTag' {5} 'NoWindowTag' {6} 'UnparseableCron' {7} 'Covered' {8} default {9} } }},
                UpdateRing, UpdateWindow)
        }
    }

    # 6. Console summary.
    Write-Log -Message "" -Level Info
    Write-Log -Message "Apply-Updates Schedule Coverage ($View view):" -Level Header
    if ($View -eq 'Audit') {
        $uncovered = @($output | Where-Object { $_.Status -in @('Uncovered','PartiallyCovered','MalformedTag') })
        $covered   = @($output | Where-Object { $_.Status -eq 'Covered' })
        $missing   = @($output | Where-Object { $_.Status -eq 'RingMissingFromSchedule' })
        $orphans   = @($output | Where-Object { $_.Status -eq 'RingOrphanedInSchedule' })
        Write-Log -Message ("  Covered (Ring,Window) pairs:   {0}" -f $covered.Count)   -Level Info
        Write-Log -Message ("  Uncovered (Ring,Window) pairs: {0}" -f $uncovered.Count) -Level $(if ($uncovered.Count -gt 0) { 'Warning' } else { 'Success' })
        if (-not [string]::IsNullOrWhiteSpace($SchedulePath)) {
            Write-Log -Message ("  Rings missing from schedule:   {0}" -f $missing.Count) -Level $(if ($missing.Count -gt 0) { 'Warning' } else { 'Success' })
            Write-Log -Message ("  Rings orphaned in schedule:    {0}" -f $orphans.Count) -Level $(if ($orphans.Count -gt 0) { 'Warning' } else { 'Success' })
        }
        foreach ($u in $uncovered) {
            Write-Log -Message ("    [{0}] {1} / {2} ({3} cluster(s)) -> {4}" -f $u.Status, $u.UpdateRing, $u.UpdateWindow, $u.ClusterCount, $u.Recommendation) -Level Warning
        }
        foreach ($m in $missing) {
            Write-Log -Message ("    [{0}] {1} ({2} cluster(s)) -> {3}" -f $m.Status, $m.UpdateRing, $m.ClusterCount, $m.Recommendation) -Level Warning
        }
        foreach ($o in $orphans) {
            Write-Log -Message ("    [{0}] {1} -> {2}" -f $o.Status, $o.UpdateRing, $o.Recommendation) -Level Warning
        }
    }
    elseif ($View -eq 'Matrix') {
        foreach ($m in $output) {
            Write-Log -Message ("  {0,-16} {1,-30} {2,5} cluster(s) -> {3}" -f $m.UpdateRing, $m.UpdateWindow, $m.ClusterCount, $m.RequiredCronUTC) -Level Info
        }
    }

    # 7. Export.
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
                }
                '.md' {
                    $md = New-Object System.Text.StringBuilder
                    [void]$md.AppendLine("# Apply-Updates Schedule Coverage ($View)")
                    [void]$md.AppendLine("")
                    if ($View -eq 'Recommend') {
                        # v0.7.71: emit the Snippet verbatim. From v0.7.69 onwards
                        # the snippet is self-contained markdown - it carries its
                        # own '## Action required - ...' H2 headings and an INNER
                        # ```yaml ... ``` fence around just the cron block. The
                        # previous outer ```yaml ... ``` wrap caused the inner
                        # closing ``` to close the OUTER fence and the outer
                        # closing ``` to OPEN a new fence that was never closed,
                        # which silently swallowed every markdown element a
                        # downstream consumer appended to the file (Step Summary
                        # tables, Reports Available list, etc rendered as a
                        # single grey monospace block in GH Actions / ADO).
                        if ($output.Count -gt 0) { [void]$md.AppendLine($output[0].Snippet) }
                    }
                    else {
                        $cols = $output | Select-Object -First 1 | ForEach-Object { $_.PSObject.Properties.Name }
                        if ($cols) {
                            [void]$md.AppendLine('| ' + ($cols -join ' | ') + ' |')
                            [void]$md.AppendLine('| ' + (($cols | ForEach-Object { '---' }) -join ' | ') + ' |')
                            foreach ($row in $output) {
                                $cells = foreach ($c in $cols) {
                                    $v = $row.$c
                                    if ($v -is [array]) { ($v -join '; ') } else { "$v" }
                                }
                                [void]$md.AppendLine('| ' + (($cells | ForEach-Object { $_ -replace '\|','\|' }) -join ' | ') + ' |')
                            }
                        }
                    }
                    Write-Utf8NoBomFile -Path $ExportPath -Content $md.ToString()
                }
                default {
                    $output | Export-Csv -Path $ExportPath -NoTypeInformation -Force
                }
            }
            Write-Log -Message "Schedule coverage ($View) exported to: $ExportPath" -Level Success
        }
        catch {
            Write-Log -Message "Failed to export schedule coverage: $($_.Exception.Message)" -Level Error
        }
    }

    if (-not $ExportPath -or $PassThru) {
        return , $output
    }
}
