function ConvertFrom-AzLocalUpdateSideloaded {
    <#
    .SYNOPSIS
        Parses an UpdateSideloaded tag value into a strict boolean.
    .DESCRIPTION
        Strict, case-insensitive parser for the UpdateSideloaded tag. Accepted values
        are 'True', 'False', '1', '0' only. Anything else (including empty string,
        'Yes', 'No', 'Enabled', '2', etc.) throws so the caller can fail-closed on
        a malformed tag rather than silently treating it as one value or the other.

        Mapping:
            'True'  / 'true'  / 'TRUE'  -> $true
            '1'                          -> $true
            'False' / 'false' / 'FALSE' -> $false
            '0'                          -> $false
    .PARAMETER Value
        The raw tag value to parse.
    .OUTPUTS
        [bool]
    .EXAMPLE
        ConvertFrom-AzLocalUpdateSideloaded -Value 'True'   # returns $true
        ConvertFrom-AzLocalUpdateSideloaded -Value '0'      # returns $false
        ConvertFrom-AzLocalUpdateSideloaded -Value 'Yes'    # throws
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "UpdateSideloaded tag value cannot be empty. Accepted values: 'True', 'False', '1', '0' (case-insensitive)."
    }

    $trimmed = $Value.Trim()
    switch -Regex ($trimmed) {
        '^(?i:true|1)$'  { return $true }
        '^(?i:false|0)$' { return $false }
        default {
            throw "Invalid UpdateSideloaded tag value '$Value'. Accepted values: 'True', 'False', '1', '0' (case-insensitive)."
        }
    }
}
