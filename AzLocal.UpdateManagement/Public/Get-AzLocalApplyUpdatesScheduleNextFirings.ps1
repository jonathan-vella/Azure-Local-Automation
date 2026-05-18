function Get-AzLocalApplyUpdatesScheduleNextFirings {
    <#
    .SYNOPSIS
        Projects the apply-updates schedule forward N days and emits one
        row per day showing the resolved UpdateRing(s).

    .DESCRIPTION
        Sanity-check helper for operators editing apply-updates-schedule.yml:
        before committing a schema change, run this locally to see exactly
        what the resolver will do on each upcoming day. Useful for change-
        control reviews and onboarding.

        Each output row corresponds to one UTC calendar day in the window
        [StartDate, StartDate + Days). The cycle math is performed by
        Resolve-AzLocalCurrentUpdateRing on the midnight UTC moment of
        that day, so the result is what Step.5 will see for any cron
        firing during that 24h period.

        Days where no schedule row matches are still emitted (with
        Rings=@() and a 'No match' note) so operators can spot accidental
        gaps in their calendar.

    .PARAMETER Schedule
        Parsed config object from Get-AzLocalApplyUpdatesScheduleConfig.

    .PARAMETER StartDate
        First UTC day to project. Default: today (UTC).

    .PARAMETER Days
        Number of consecutive days to project. Default: one full cycle
        ($Schedule.CycleWeeks * 7). Range: 1..366.

    .OUTPUTS
        [PSCustomObject[]] - one per day, with:
          DateUtc           [datetime] - midnight UTC of the day
          DayOfWeekName     [string]   - 'Sun' .. 'Sat'
          CycleWeek         [int]
          Rings             [string[]]
          UpdateRingValue   [string]   - ';'-joined for display
          MatchedRowCount   [int]
          Note              [string]   - 'No match' if Rings is empty

    .EXAMPLE
        $cfg = Get-AzLocalApplyUpdatesScheduleConfig -Path .\apply-updates-schedule.yml
        Get-AzLocalApplyUpdatesScheduleNextFirings -Schedule $cfg | Format-Table -AutoSize

    .EXAMPLE
        Get-AzLocalApplyUpdatesScheduleNextFirings -Schedule $cfg -Days 7 |
            Where-Object Rings | Format-Table DateUtc, DayOfWeekName, UpdateRingValue
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Schedule,

        [Parameter(Mandatory = $false)]
        [datetime]$StartDate = ([datetime]::UtcNow.Date),

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 366)]
        [int]$Days = 0
    )

    if ($Days -eq 0) {
        $Days = [int]$Schedule.CycleWeeks * 7
        if ($Days -lt 1) { $Days = 7 }
    }

    $start = [datetime]::SpecifyKind($StartDate.Date, [DateTimeKind]::Utc)
    $out = New-Object System.Collections.Generic.List[psobject]
    for ($i = 0; $i -lt $Days; $i++) {
        $day = $start.AddDays($i)
        # Use midday UTC to avoid any DST-adjacent edge case (we are UTC-
        # only, but this makes the intent explicit).
        $moment = $day.AddHours(12)
        $d = Resolve-AzLocalCurrentUpdateRing -Schedule $Schedule -Now $moment
        $out.Add([pscustomobject]@{
            DateUtc         = $day
            DayOfWeekName   = $d.DayOfWeekName
            CycleWeek       = $d.CycleWeek
            Rings           = $d.Rings
            UpdateRingValue = $d.UpdateRingValue
            MatchedRowCount = $d.MatchedRows.Count
            Note            = if ($d.Rings.Count -eq 0) { 'No match' } else { '' }
        }) | Out-Null
    }
    return $out.ToArray()
}
