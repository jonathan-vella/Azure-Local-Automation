function New-AzLocalApplyUpdatesScheduleConfig {
    <#
    .SYNOPSIS
        Generates a starter apply-updates-schedule.yml (schema v1) from
        either the live fleet's UpdateRing tag values or an explicit
        list of rings.

    .DESCRIPTION
        v0.7.69 onboarding helper. Run this once after tagging your
        fleet with Set-AzureLocalClusterUpdateRingTag - it discovers
        every distinct UpdateRing tag value via Azure Resource Graph,
        sorts them into a safe-by-default order (canary-like names
        first, prod-like names last), and writes a schedule file that
        allocates each ring to its own week in the cycle on Mon-Thu.
        Commit the result to source control and edit as needed.

        Default behaviour:
          * Discovery: Azure Resource Graph query (same shape as
            Test-AzureLocalApplyUpdatesScheduleCoverage uses) over the
            current subscription (or -SubscriptionId).
          * Ordering: rings whose name starts with 'canary', 'dev', or
            'test' (case-insensitive) sort first; rings whose name
            starts with 'prod' sort last; the rest sort lexically in
            the middle. Tie-breakers are alphabetical.
          * CycleWeeks: max(N rings, 4) so adding a 5th ring later
            doesn't immediately force a cycle bump.
          * CycleAnchor: the current ISO week / year (UTC). Operators
            can edit afterwards.
          * Schedule rows: one per discovered ring, on Mon-Thu, with a
            generated 'notes' line documenting the heuristic.

        The output is intentionally a STARTING POINT, not a finished
        schedule. Run Get-AzLocalApplyUpdatesScheduleNextFirings against
        the result before committing to review what each day in the
        first cycle will do.

    .PARAMETER OutputPath
        Where to write the generated file. Default: '.\apply-updates-schedule.yml'.

    .PARAMETER SubscriptionId
        Optional. Subscription scope for the discovery query. Default:
        current az context subscription.

    .PARAMETER Rings
        Optional explicit list of UpdateRing values. If supplied, the
        Resource Graph query is skipped entirely (offline mode, useful
        for tests and air-gapped bootstrapping).

    .PARAMETER CycleWeeks
        Optional override for the generated cycleWeeks value. Default:
        max(N rings, 4). Must be 1..52.

    .PARAMETER Force
        Overwrite -OutputPath if it already exists. Without this switch
        the cmdlet refuses to overwrite (so an operator who edited the
        file and then re-ran the generator by mistake does not lose
        their work).

    .OUTPUTS
        [System.IO.FileInfo] of the written file.

    .EXAMPLE
        New-AzLocalApplyUpdatesScheduleConfig -OutputPath .\apply-updates-schedule.yml

    .EXAMPLE
        New-AzLocalApplyUpdatesScheduleConfig -Rings 'Canary','Ring1','Ring2','Prod' -OutputPath .\schedule.yml
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath = '.\apply-updates-schedule.yml',

        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [string[]]$Rings,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 52)]
        [int]$CycleWeeks = 0,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    # ---- 1. Resolve OutputPath + overwrite guard ----------------------
    $resolvedOut = if ([IO.Path]::IsPathRooted($OutputPath)) {
        $OutputPath
    } else {
        Join-Path (Get-Location).Path $OutputPath
    }
    if ((Test-Path -LiteralPath $resolvedOut) -and -not $Force) {
        throw "New-AzLocalApplyUpdatesScheduleConfig: '$resolvedOut' already exists. Pass -Force to overwrite, or pick a different -OutputPath."
    }

    # ---- 2. Discover (or accept) the ring list ----------------------
    if (-not $Rings -or @($Rings).Count -eq 0) {
        $kql = @"
resources
| where type =~ 'microsoft.azurestackhci/clusters'
| project UpdateRing = tostring(tags['UpdateRing'])
| where isnotempty(UpdateRing)
| distinct UpdateRing
"@
        Write-Log -Message "Discovering UpdateRing tag values via Azure Resource Graph..." -Level Info
        $rows = if ($SubscriptionId) {
            Invoke-AzResourceGraphQuery -Query $kql -SubscriptionId $SubscriptionId
        } else {
            Invoke-AzResourceGraphQuery -Query $kql
        }
        $Rings = @($rows | ForEach-Object { $_.UpdateRing } | Where-Object { $_ } | Select-Object -Unique)
        if (@($Rings).Count -eq 0) {
            throw "No clusters with an UpdateRing tag were found. Tag the fleet first via Set-AzureLocalClusterUpdateRingTag, then re-run."
        }
        Write-Log -Message "Discovered $($Rings.Count) distinct UpdateRing value(s): $($Rings -join ', ')." -Level Info
    } else {
        Write-Log -Message "Using $($Rings.Count) explicit ring value(s) from -Rings parameter (skipping Resource Graph discovery)." -Level Info
    }

    # ---- 3. Sort: canary-like first, prod-like last, rest in middle ---
    function Get-AzLocalRingSortKey([string]$ring) {
        $low = $ring.ToLowerInvariant()
        # 0 = canary/dev/test (first), 1 = middle, 2 = prod (last)
        if ($low -match '^(canary|dev|test)') { return 0 }
        if ($low -match '^prod')              { return 2 }
        return 1
    }
    $sorted = @($Rings | Sort-Object @{Expression = { Get-AzLocalRingSortKey $_ } }, @{Expression = { $_ }})

    # ---- 4. CycleWeeks default = max(N rings, 4) -----------------------
    if ($CycleWeeks -eq 0) {
        $CycleWeeks = [Math]::Max($sorted.Count, 4)
    }
    if ($sorted.Count -gt $CycleWeeks) {
        throw "New-AzLocalApplyUpdatesScheduleConfig: -CycleWeeks ($CycleWeeks) is smaller than the discovered ring count ($($sorted.Count)). Increase -CycleWeeks or use the union row pattern (edit by hand after generation)."
    }

    # ---- 5. Compute anchor (this week, this ISO year) ------------------
    function Get-AzLocalCurrentISOWeek {
        $d = [datetime]::UtcNow.Date
        $dayIso = ((($d.DayOfWeek.value__ + 6) % 7))
        $thu = $d.AddDays(3 - $dayIso)
        $yr = $thu.Year
        $jan4 = [datetime]::new($yr, 1, 4, 0, 0, 0, [DateTimeKind]::Utc)
        $jan4Iso = ((($jan4.DayOfWeek.value__ + 6) % 7))
        $w1Mon = $jan4.AddDays(-1 * $jan4Iso)
        $wk = [int]([math]::Floor(($thu - $w1Mon).TotalDays / 7)) + 1
        [pscustomobject]@{ Year = $yr; Week = $wk }
    }
    $iso = Get-AzLocalCurrentISOWeek

    # ---- 6. Emit YAML text --------------------------------------------
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('# =====================================================================')
    [void]$sb.AppendLine('# apply-updates-schedule.yml - schema v1')
    [void]$sb.AppendLine("# Generated by New-AzLocalApplyUpdatesScheduleConfig on $([datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) UTC.")
    [void]$sb.AppendLine('#')
    [void]$sb.AppendLine('# Edit freely. Every row in the schedule list is preserved verbatim by')
    [void]$sb.AppendLine('# Update-AzureLocalPipelineExample during module upgrades; only the')
    [void]$sb.AppendLine("# schemaVersion field and newly-introduced top-level fields are modified.")
    [void]$sb.AppendLine('# Run "Get-AzLocalApplyUpdatesScheduleNextFirings -Schedule (Get-AzLocalApplyUpdatesScheduleConfig -Path .\apply-updates-schedule.yml)"')
    [void]$sb.AppendLine('# to preview the next cycle BEFORE committing.')
    [void]$sb.AppendLine('# =====================================================================')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('schemaVersion:        1')
    [void]$sb.AppendLine("cycleWeeks:           $CycleWeeks")
    [void]$sb.AppendLine("cycleAnchorISOWeek:   $($iso.Week)")
    [void]$sb.AppendLine("cycleAnchorYear:      $($iso.Year)")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('schedule:')
    for ($i = 0; $i -lt $sorted.Count; $i++) {
        $ring = $sorted[$i]
        $weekN = $i + 1
        $note = if ((Get-AzLocalRingSortKey $ring) -eq 0) {
            "Auto-generated row: [$ring] looks like a canary/dev/test ring - allocated to week $weekN (first soak)."
        } elseif ((Get-AzLocalRingSortKey $ring) -eq 2) {
            "Auto-generated row: [$ring] looks like a production ring - allocated to week $weekN (last in cycle)."
        } else {
            "Auto-generated row: [$ring] - allocated to week $weekN. Adjust as needed."
        }
        [void]$sb.AppendLine("  - weeksInCycle: '$weekN'")
        [void]$sb.AppendLine("    daysOfWeek:   'Mon-Thu'")
        [void]$sb.AppendLine("    rings:        '$ring'")
        [void]$sb.AppendLine("    notes:        '$note'")
    }

    $text = $sb.ToString()

    # ---- 7. Write (ShouldProcess gate) ---------------------------------
    if (-not $PSCmdlet.ShouldProcess($resolvedOut, "Write schedule file ($($sorted.Count) ring(s), cycleWeeks=$CycleWeeks, anchor=ISO-W$($iso.Week)/$($iso.Year))")) {
        return
    }
    # Split-Path -LiteralPath is in a different parameter set than -Parent
    # on PS 5.1 (works on PS 7). Use .NET directly for cross-version safety.
    $parent = [System.IO.Path]::GetDirectoryName($resolvedOut)
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    # UTF-8 NO BOM to match other YAML conventions in the bundle.
    [System.IO.File]::WriteAllText($resolvedOut, $text, [System.Text.UTF8Encoding]::new($false))

    Write-Log -Message "Wrote $resolvedOut ($($sorted.Count) row(s), cycleWeeks=$CycleWeeks, anchor=ISO-W$($iso.Week)/$($iso.Year))." -Level Success
    Write-Log -Message "Next step: 'Get-AzLocalApplyUpdatesScheduleNextFirings -Schedule (Get-AzLocalApplyUpdatesScheduleConfig -Path ''$resolvedOut'')' to preview the cycle." -Level Info

    return (Get-Item -LiteralPath $resolvedOut)
}
