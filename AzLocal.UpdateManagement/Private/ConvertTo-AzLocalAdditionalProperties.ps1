function ConvertTo-AzLocalAdditionalProperties {
    <#
    .SYNOPSIS
        Internal helper that safely parses the 'additionalProperties' field of an update object.
    .DESCRIPTION
        The ARM API returns additionalProperties either as an already-deserialised
        object or as a JSON string. This helper normalises both forms and handles
        malformed JSON without throwing, logging a Verbose warning on failure so
        that a single bad cluster does not abort a fleet-wide operation.
    .PARAMETER InputObject
        The additionalProperties value from an update's properties.
    .OUTPUTS
        PSCustomObject or $null if parsing failed / input was empty.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [AllowNull()]
        $InputObject
    )

    if ($null -eq $InputObject) { return $null }

    if ($InputObject -is [string]) {
        if ([string]::IsNullOrWhiteSpace($InputObject)) { return $null }
        try {
            return ($InputObject | ConvertFrom-Json -ErrorAction Stop)
        }
        catch {
            $snippet = if ($InputObject.Length -gt 200) { $InputObject.Substring(0, 200) + '...' } else { $InputObject }
            Write-Verbose "Failed to parse additionalProperties JSON: $($_.Exception.Message). Raw: $snippet"
            return $null
        }
    }

    # Already an object (PSCustomObject / hashtable) - return as-is
    return $InputObject
}
