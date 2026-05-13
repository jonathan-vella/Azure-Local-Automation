function Get-TagValue {
    <#
    .SYNOPSIS
        Reads a single tag value from a cluster 'tags' property in a
        container-shape-agnostic way.
    .DESCRIPTION
        ARM returns 'tags' as a PSCustomObject when the response is parsed via
        'ConvertFrom-Json' (the default) but as a Hashtable when parsed with
        'ConvertFrom-Json -AsHashtable' (occasionally used for performance).
        The two shapes require different lookup syntax, and accessing a missing
        key on one of them throws under Set-StrictMode.

        This helper returns the tag value (or $null if absent) for any of:
          - [hashtable] / [System.Collections.IDictionary]
          - [PSCustomObject]
          - $null
        Lookup is ordinal (case-sensitive) to match ARM tag semantics.
    .PARAMETER Tags
        The 'tags' property from a cluster resource.
    .PARAMETER Name
        The tag name to look up.
    .OUTPUTS
        [string] tag value, or $null if the tag is absent or Tags is $null.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $Tags,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    if ($null -eq $Tags) { return $null }

    if ($Tags -is [System.Collections.IDictionary]) {
        if ($Tags.Contains($Name)) { return [string]$Tags[$Name] }
        return $null
    }

    # PSCustomObject / PSObject path.
    try {
        $prop = $Tags.PSObject.Properties[$Name]
        if ($null -ne $prop) { return [string]$prop.Value }
    }
    catch {
        Write-Verbose "Get-TagValue: unexpected tag container shape ($($Tags.GetType().FullName)); treating as empty. $($_.Exception.Message)"
    }
    return $null
}
