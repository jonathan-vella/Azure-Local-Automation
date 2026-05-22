function Get-AzLocalApplyUpdatesScheduleConfig {
    <#
    .SYNOPSIS
        Reads and validates an apply-updates-schedule.yml file (schema
        v1 or v2), returning a typed config object suitable for
        Resolve-AzLocalCurrentUpdateRing and the audit cmdlet.

    .DESCRIPTION
        Pipeline:
          1. Read raw text (Get-Content -Raw).
          2. Parse via the private ConvertFrom-AzLocalScheduleYaml
             (zero external deps).
          3. Validate shape: schemaVersion must be 1 or 2; cycleWeeks
             1..52; cycleAnchorISOWeek 1..53; cycleAnchorYear 2000..2100;
             schedule entries must each have weeksInCycle, daysOfWeek,
             rings (notes optional). Selectors are sanity-checked by
             expanding them via the same logic the resolver uses.

          v2 adds the optional 'allowedUpdateVersions' field (top-level
          fleet default + per-row override). When present, the value
          must be a non-empty semicolon-separated string; empty tokens
          after split-and-trim are rejected. v1 files that contain the
          field are rejected with a remediation pointing at the schema
          migrator. The validator parses the raw strings into
          $cfg.AllowedUpdateVersions [string[]] (top-level) and
          row.AllowedUpdateVersionsParsed [string[]] (per row) so the
          resolver does not re-split.

        Validation errors throw a single multi-line message listing
        every problem found (not just the first), so the operator can
        fix them all in one edit.

    .PARAMETER Path
        Absolute or relative path to the schedule YAML file.

    .OUTPUTS
        [PSCustomObject] - same shape produced by
        ConvertFrom-AzLocalScheduleYaml, plus SourcePath set to the
        resolved full path and (for v2) AllowedUpdateVersions parsed to
        an array.

    .EXAMPLE
        $cfg = Get-AzLocalApplyUpdatesScheduleConfig -Path .\.github\apply-updates-schedule.yml
        Resolve-AzLocalCurrentUpdateRing -Schedule $cfg
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Get-AzLocalApplyUpdatesScheduleConfig: schedule file not found: '$Path'. Generate a starter via 'New-AzLocalApplyUpdatesScheduleConfig -OutputPath <path>'."
    }

    $full = (Resolve-Path -LiteralPath $Path).Path
    $text = Get-Content -LiteralPath $full -Raw -ErrorAction Stop

    $cfg = ConvertFrom-AzLocalScheduleYaml -Text $text -SourcePath $full

    # ---- Validate top-level scalars ---------------------------------
    $errors = New-Object System.Collections.Generic.List[string]

    if ($null -eq $cfg.SchemaVersion -or $cfg.SchemaVersion -isnot [int]) {
        $errors.Add("Top-level 'schemaVersion' must be present and an integer.") | Out-Null
    } elseif ($cfg.SchemaVersion -ne 1 -and $cfg.SchemaVersion -ne 2) {
        $errors.Add("schemaVersion '$($cfg.SchemaVersion)' is not supported by this module version. Expected: 1 or 2.") | Out-Null
    }

    if ($null -eq $cfg.CycleWeeks -or $cfg.CycleWeeks -isnot [int] -or $cfg.CycleWeeks -lt 1 -or $cfg.CycleWeeks -gt 52) {
        $errors.Add("'cycleWeeks' must be an integer in 1..52. Got: '$($cfg.CycleWeeks)'.") | Out-Null
    }
    if ($null -eq $cfg.CycleAnchorISOWeek -or $cfg.CycleAnchorISOWeek -isnot [int] -or $cfg.CycleAnchorISOWeek -lt 1 -or $cfg.CycleAnchorISOWeek -gt 53) {
        $errors.Add("'cycleAnchorISOWeek' must be an integer in 1..53. Got: '$($cfg.CycleAnchorISOWeek)'.") | Out-Null
    }
    if ($null -eq $cfg.CycleAnchorYear -or $cfg.CycleAnchorYear -isnot [int] -or $cfg.CycleAnchorYear -lt 2000 -or $cfg.CycleAnchorYear -gt 2100) {
        $errors.Add("'cycleAnchorYear' must be an integer in 2000..2100. Got: '$($cfg.CycleAnchorYear)'.") | Out-Null
    }

    if (-not $cfg.Schedule -or @($cfg.Schedule).Count -eq 0) {
        $errors.Add("'schedule:' list is empty - at least one row is required.") | Out-Null
    }

    # ---- Validate top-level 'allowedUpdateVersions' (schema v2 only) -
    # The parser surfaces the raw string as AllowedUpdateVersionsRaw.
    # Always start the parsed array as $null so the resolver can tell
    # "field absent" from "field present with values".
    $cfg | Add-Member -NotePropertyName 'AllowedUpdateVersions' -NotePropertyValue $null -Force
    $topAllowRaw = $null
    if ($cfg.PSObject.Properties.Match('AllowedUpdateVersionsRaw').Count) {
        $topAllowRaw = $cfg.AllowedUpdateVersionsRaw
    }
    if ($null -ne $topAllowRaw) {
        if ($cfg.SchemaVersion -eq 1) {
            $errors.Add("Top-level 'allowedUpdateVersions' requires schemaVersion >= 2. Bump 'schemaVersion: 1' to 'schemaVersion: 2' (this file has no breaking changes - the field is additive). See https://github.com/NeilBird/Azure-Local/tree/main/AzLocal.UpdateManagement#allowedupdateversions for details.") | Out-Null
        }
        $parsedTop = Test-AzLocalAllowedUpdateVersionsString -Raw $topAllowRaw -Location "top-level 'allowedUpdateVersions'" -Errors $errors
        if ($null -ne $parsedTop) {
            $cfg.AllowedUpdateVersions = $parsedTop
        }
    }

    # ---- Validate each schedule row ---------------------------------
    # Cross-checks weeksInCycle / daysOfWeek tokens by attempting to
    # expand them. This will surface bad ranges, out-of-bounds values,
    # and unknown day names at load time rather than at first cron firing.
    if ($cfg.CycleWeeks -and ($cfg.CycleWeeks -is [int]) -and $cfg.CycleWeeks -ge 1 -and $cfg.CycleWeeks -le 52 -and $cfg.Schedule) {
        $i = 0
        foreach ($row in @($cfg.Schedule)) {
            $i++
            $line = if ($row.PSObject.Properties.Match('_LineNumber').Count) { " (line $($row._LineNumber))" } else { '' }
            foreach ($key in @('weeksInCycle', 'daysOfWeek', 'rings')) {
                if (-not $row.PSObject.Properties.Match($key).Count -or [string]::IsNullOrWhiteSpace([string]$row.$key)) {
                    $errors.Add("schedule[$i]$line is missing required field '$key'.") | Out-Null
                }
            }
            # Selector sanity-check via a fake resolver expand. Reuse the
            # same regex patterns instead of dot-sourcing the resolver
            # functions (which are defined inside that function's scope).
            if ($row.weeksInCycle -and $row.weeksInCycle -ne '*') {
                foreach ($tok in (([string]$row.weeksInCycle) -split ',')) {
                    $t = $tok.Trim()
                    if ($t -match '^(\d+)-(\d+)$') {
                        $lo = [int]$Matches[1]; $hi = [int]$Matches[2]
                        if ($lo -lt 1 -or $hi -gt [int]$cfg.CycleWeeks -or $lo -gt $hi) {
                            $errors.Add("schedule[$i]$line weeksInCycle range '$t' is out of 1..$($cfg.CycleWeeks).") | Out-Null
                        }
                    } elseif ($t -match '^\d+$') {
                        $n = [int]$t
                        if ($n -lt 1 -or $n -gt [int]$cfg.CycleWeeks) {
                            $errors.Add("schedule[$i]$line weeksInCycle value '$t' is out of 1..$($cfg.CycleWeeks).") | Out-Null
                        }
                    } elseif ($t -ne '*') {
                        $errors.Add("schedule[$i]$line weeksInCycle token '$t' is not recognised (expected '*', N, N-M, or comma list).") | Out-Null
                    }
                }
            }
            if ($row.daysOfWeek -and $row.daysOfWeek -ne '*') {
                $valid = '^(sun|mon|tue|wed|thu|fri|sat|sunday|monday|tuesday|wednesday|thursday|friday|saturday|\d)$'
                foreach ($tok in (([string]$row.daysOfWeek) -split ',')) {
                    $t = $tok.Trim()
                    $rangeMatch = [regex]::Match($t, '^(.+?)-(.+)$')
                    if ($rangeMatch.Success) {
                        # Capture group values BEFORE running further -match
                        # operations (which would clobber $Matches).
                        $left  = $rangeMatch.Groups[1].Value
                        $right = $rangeMatch.Groups[2].Value
                        if (($left -notmatch $valid) -or ($right -notmatch $valid)) {
                            $errors.Add("schedule[$i]$line daysOfWeek range '$t' contains unknown day name.") | Out-Null
                        }
                    } elseif ($t -notmatch $valid) {
                        $errors.Add("schedule[$i]$line daysOfWeek token '$t' is not recognised (expected 0-6, Sun/Mon/... names, or '*').") | Out-Null
                    }
                }
            }

            # Per-row 'allowedUpdateVersions' (schema v2). The parser
            # passes arbitrary continuation keys through generically -
            # the value will be a string when present. Stamp a
            # uniformly-named AllowedUpdateVersionsParsed property
            # ($null when absent) so the resolver doesn't have to
            # PSObject.Match the camelCase key.
            $rowHasField = $row.PSObject.Properties.Match('allowedUpdateVersions').Count -gt 0
            $row | Add-Member -NotePropertyName 'AllowedUpdateVersionsParsed' -NotePropertyValue $null -Force
            if ($rowHasField) {
                if ($cfg.SchemaVersion -eq 1) {
                    $errors.Add("schedule[$i]$line uses 'allowedUpdateVersions' which requires schemaVersion >= 2. Bump 'schemaVersion: 1' to 'schemaVersion: 2'.") | Out-Null
                }
                $parsedRow = Test-AzLocalAllowedUpdateVersionsString -Raw $row.allowedUpdateVersions -Location "schedule[$i]$line 'allowedUpdateVersions'" -Errors $errors
                if ($null -ne $parsedRow) {
                    $row.AllowedUpdateVersionsParsed = $parsedRow
                }
            }
        }
    }

    if ($errors.Count -gt 0) {
        $body = ($errors | ForEach-Object { "  - $_" }) -join "`n"
        throw "Get-AzLocalApplyUpdatesScheduleConfig: $($errors.Count) validation error(s) in '$full':`n$body"
    }

    return $cfg
}
