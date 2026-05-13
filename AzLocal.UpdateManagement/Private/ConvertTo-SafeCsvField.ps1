function ConvertTo-SafeCsvField {
    <#
    .SYNOPSIS
        Neutralises a single string value so it cannot trigger formula
        evaluation when the containing CSV is opened in Excel / Calc.
    .DESCRIPTION
        Implements the OWASP CSV-injection guidance:
        - If the value begins with one of the spreadsheet formula leaders
          ('=', '+', '-', '@') or a CR/LF/TAB, prepend a single quote so the
          cell is interpreted as literal text.
        - Replace embedded CR and LF characters with spaces so they cannot
          terminate the logical record early.
        Non-string values are returned unchanged. Null / empty values are
        returned unchanged.
    .PARAMETER Value
        The value to sanitise. Only [string] values are mutated.
    .OUTPUTS
        Same type as input; sanitised when input was a non-empty string.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [AllowNull()]
        $Value
    )

    process {
        if ($null -eq $Value) { return $null }
        if ($Value -isnot [string]) { return $Value }
        if ($Value.Length -eq 0) { return $Value }

        # Strip embedded CR/LF first so leader-check sees the real first visible char.
        $s = $Value -replace "`r?`n", ' '

        $first = $s[0]
        if ($first -eq '=' -or $first -eq '+' -or $first -eq '-' -or $first -eq '@' -or $first -eq "`t") {
            return "'" + $s
        }
        return $s
    }
}
