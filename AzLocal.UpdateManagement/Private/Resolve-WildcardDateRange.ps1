function Resolve-WildcardDateRange {
    <#
    .SYNOPSIS
        Resolves wildcard date patterns to concrete date ranges relative to a reference date.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StartPattern,

        [Parameter(Mandatory = $true)]
        [string]$EndPattern,

        [Parameter(Mandatory = $true)]
        [datetime]$ReferenceDate
    )

    $results = @()
    $refYear = $ReferenceDate.Year

    # Try resolving for current year, previous year, and next year
    foreach ($yearOffset in @(-1, 0, 1)) {
        $tryYear = $refYear + $yearOffset
        $yearStr = $tryYear.ToString('D4')

        $resolvedStart = Resolve-WildcardDate -Pattern $StartPattern -YearDigits $yearStr
        $resolvedEnd = Resolve-WildcardDate -Pattern $EndPattern -YearDigits $yearStr

        if (-not $resolvedStart -or -not $resolvedEnd) { continue }

        # Handle cross-year ranges (Dec start -> Jan end)
        if ($resolvedEnd -lt $resolvedStart) {
            # Try end date with next year
            $nextYearStr = ($tryYear + 1).ToString('D4')
            $resolvedEnd = Resolve-WildcardDate -Pattern $EndPattern -YearDigits $nextYearStr
            if (-not $resolvedEnd) { continue }
        }

        if ($resolvedEnd -lt $resolvedStart) { continue }

        # Only include ranges that overlap with a reasonable window around reference date
        # (exclude ranges entirely more than 1 year in the past or future)
        $windowStart = $ReferenceDate.AddYears(-1)
        $windowEnd = $ReferenceDate.AddYears(1)
        if ($resolvedEnd -ge $windowStart -and $resolvedStart -le $windowEnd) {
            # Avoid duplicates
            $isDuplicate = $false
            foreach ($existing in $results) {
                if ($existing.StartDate -eq $resolvedStart -and $existing.EndDate -eq $resolvedEnd) {
                    $isDuplicate = $true
                    break
                }
            }
            if (-not $isDuplicate) {
                $results += [PSCustomObject]@{
                    StartDate = $resolvedStart
                    EndDate   = $resolvedEnd
                }
            }
        }
    }

    return $results
}
