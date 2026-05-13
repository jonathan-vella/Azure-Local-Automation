function Resolve-WildcardDate {
    <#
    .SYNOPSIS
        Resolves a single date pattern with wildcards by substituting year digits.
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter(Mandatory = $true)]
        [string]$YearDigits
    )

    # Replace * characters in the year portion with digits from YearDigits
    $resolved = $Pattern.ToCharArray()
    $yearChars = $YearDigits.ToCharArray()

    # Pattern is YYYY-MM-DD (10 chars). Year is chars 0-3.
    for ($i = 0; $i -lt 4; $i++) {
        if ($resolved[$i] -eq '*') {
            $resolved[$i] = $yearChars[$i]
        }
    }
    # Month/day wildcards: substitute with reference digits (less common, but support it)
    # For month (chars 5-6) and day (chars 8-9), wildcards don't make semantic sense
    # for date ranges, so we reject them
    $resolvedStr = [string]::new($resolved)
    if ($resolvedStr -match '\*') {
        # Wildcards remain in month/day - this is not valid for date ranges
        return $null
    }

    try {
        return [datetime]::ParseExact($resolvedStr, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        return $null
    }
}
