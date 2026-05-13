function Format-AzLocalDurationHuman {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        $Value
    )

    if ($null -eq $Value) { return "" }

    $ts = $null
    if ($Value -is [TimeSpan]) {
        $ts = $Value
    }
    elseif ($Value -is [double] -or $Value -is [int] -or $Value -is [long] -or $Value -is [decimal]) {
        try { $ts = [TimeSpan]::FromSeconds([double]$Value) } catch { return "" }
    }
    elseif ($Value -is [string]) {
        $s = $Value.Trim()
        if ([string]::IsNullOrEmpty($s)) { return "" }
        [TimeSpan]$parsed = [TimeSpan]::Zero
        if ([TimeSpan]::TryParse($s, [ref]$parsed)) {
            $ts = $parsed
        }
        else {
            return $s
        }
    }
    else {
        return ""
    }

    if (-not $ts -or $ts.TotalSeconds -lt 1) { return "0 seconds" }

    $days    = [int][Math]::Floor($ts.TotalDays)
    $hours   = $ts.Hours
    $minutes = $ts.Minutes
    $seconds = $ts.Seconds

    $parts = @()
    if ($days -gt 0)    { $parts += "$days day$(if ($days -ne 1) { 's' } else { '' })" }
    if ($hours -gt 0)   { $parts += "$hours hour$(if ($hours -ne 1) { 's' } else { '' })" }
    if ($minutes -gt 0) { $parts += "$minutes minute$(if ($minutes -ne 1) { 's' } else { '' })" }
    if ($seconds -gt 0) { $parts += "$seconds second$(if ($seconds -ne 1) { 's' } else { '' })" }

    if ($parts.Count -eq 0) { return "0 seconds" }
    return ($parts -join ' ')
}
