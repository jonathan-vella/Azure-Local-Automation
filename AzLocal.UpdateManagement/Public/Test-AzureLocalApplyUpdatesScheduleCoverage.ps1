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
                       Output columns: UpdateRing, UpdateWindow, ClusterCount,
                       Status, Issue, Recommendation, MatchingCrons.
          Matrix     - Inventory view: every distinct (UpdateRing, UpdateWindow)
                       pair with cluster count and the cron expression the
                       advisor would generate for it.
          Recommend  - YAML snippet (one per platform) that covers every
                       distinct UpdateWindow value found in the fleet, ready
                       to paste into Step.5_apply-updates.yml.

        Status values (Audit):
          Covered            - at least one cron in the YAML fires during the window
          Uncovered          - no cron in the YAML fires during the window
          PartiallyCovered   - multi-segment window where some segments are covered and others are not
          NoWindowTag        - cluster(s) have no UpdateWindow tag (only emitted when -IncludeUntagged is supplied)
          MalformedTag       - the UpdateWindow tag value failed to parse
          UnparseableCron    - a cron in the YAML used syntax the advisor cannot evaluate
                               (e.g. DayOfMonth restrictions, step values); manual review required
    .PARAMETER SubscriptionId
        Optional subscription scope passed to Resource Graph. If omitted, the
        query runs against every subscription the caller can read.
    .PARAMETER View
        'Audit' (default), 'Matrix', or 'Recommend'.
    .PARAMETER PipelineYamlPath
        Required for -View Audit. Path to a single Step.5_apply-updates.yml file, or to
        a folder that contains apply-updates*.yml files (typically the
        Automation-Pipeline-Examples folder of your forked module).
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

    # Pre-flight: -View Audit requires a YAML path to audit against.
    if ($View -eq 'Audit' -and [string]::IsNullOrWhiteSpace($PipelineYamlPath)) {
        throw "-PipelineYamlPath is required when -View is 'Audit'. Point it at Step.5_apply-updates.yml or the Automation-Pipeline-Examples folder."
    }
    if ($PipelineYamlPath -and -not (Test-Path -LiteralPath $PipelineYamlPath)) {
        throw "PipelineYamlPath not found: $PipelineYamlPath"
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
    $yamlCrons        = @()
    $parsedYamlCrons  = @()
    if ($View -eq 'Audit') {
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

            $sb = New-Object System.Text.StringBuilder
            if ($Platform -in @('GitHubActions','Both')) {
                [void]$sb.AppendLine('# --- GitHub Actions: paste under Step.5_apply-updates.yml `on:` ---')
                [void]$sb.AppendLine('# schedule:')
                foreach ($k in ($byCron.Keys | Sort-Object)) {
                    $entry = $byCron[$k]
                    [void]$sb.AppendLine(("#   - cron: '{0}'   # {1} (rings: {2}, {3} cluster(s))" -f $k, $entry.Segment, (($entry.Rings | Sort-Object -Unique) -join ','), $entry.Clusters))
                }
                [void]$sb.AppendLine()
            }
            if ($Platform -in @('AzureDevOps','Both')) {
                [void]$sb.AppendLine('# --- Azure DevOps: paste at the top level of Step.5_apply-updates.yml ---')
                [void]$sb.AppendLine('# schedules:')
                foreach ($k in ($byCron.Keys | Sort-Object)) {
                    $entry = $byCron[$k]
                    [void]$sb.AppendLine(("#   - cron: '{0}'   # {1} (rings: {2}, {3} cluster(s))" -f $k, $entry.Segment, (($entry.Rings | Sort-Object -Unique) -join ','), $entry.Clusters))
                    [void]$sb.AppendLine('#     displayName: "Apply Updates - covers above window"')
                    [void]$sb.AppendLine('#     branches:')
                    [void]$sb.AppendLine('#       include: [ main ]')
                    [void]$sb.AppendLine('#     always: true')
                }
            }

            $snippet = $sb.ToString()
            Write-Log -Message "Recommended schedule:" -Level Header
            $snippet -split "`r?`n" | ForEach-Object { if ($_) { Write-Log -Message $_ -Level Info } }

            # Emit one PSCustomObject per cron so the pipeline / -PassThru consumer
            # can also act on the data (the Snippet field carries the human-readable form).
            $items = New-Object System.Collections.Generic.List[PSCustomObject]
            foreach ($k in ($byCron.Keys | Sort-Object)) {
                $entry = $byCron[$k]
                $items.Add([PSCustomObject]@{
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
            , @($rows | Sort-Object @{Expression={ switch ($_.Status) { 'Uncovered' {1} 'PartiallyCovered' {2} 'MalformedTag' {3} 'NoWindowTag' {4} 'UnparseableCron' {5} 'Covered' {6} default {7} } }}, UpdateRing, UpdateWindow)
        }
    }

    # 6. Console summary.
    Write-Log -Message "" -Level Info
    Write-Log -Message "Apply-Updates Schedule Coverage ($View view):" -Level Header
    if ($View -eq 'Audit') {
        $uncovered = @($output | Where-Object { $_.Status -in @('Uncovered','PartiallyCovered','MalformedTag') })
        $covered   = @($output | Where-Object { $_.Status -eq 'Covered' })
        Write-Log -Message ("  Covered (Ring,Window) pairs:   {0}" -f $covered.Count)   -Level Info
        Write-Log -Message ("  Uncovered (Ring,Window) pairs: {0}" -f $uncovered.Count) -Level $(if ($uncovered.Count -gt 0) { 'Warning' } else { 'Success' })
        foreach ($u in $uncovered) {
            Write-Log -Message ("    [{0}] {1} / {2} ({3} cluster(s)) -> {4}" -f $u.Status, $u.UpdateRing, $u.UpdateWindow, $u.ClusterCount, $u.Recommendation) -Level Warning
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
                        [void]$md.AppendLine('```yaml')
                        if ($output.Count -gt 0) { [void]$md.AppendLine($output[0].Snippet) }
                        [void]$md.AppendLine('```')
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
