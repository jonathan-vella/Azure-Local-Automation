function ConvertTo-SafeCsvCollection {
    <#
    .SYNOPSIS
        Projects a collection of objects into new PSCustomObjects whose string
        properties have been sanitised via ConvertTo-SafeCsvField.
    .DESCRIPTION
        Wrap pipelines as '$rows | ConvertTo-SafeCsvCollection | Export-Csv ...'
        to neutralise CSV formula injection without mutating the caller's
        original objects. Property order is preserved. Non-string property
        values (int, datetime, bool, nested objects) are passed through
        unchanged so downstream tooling retains type information.
    .PARAMETER InputObject
        The object(s) to sanitise. Accepts pipeline input.
    .OUTPUTS
        [PSCustomObject] per input row.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowNull()]
        $InputObject
    )

    process {
        if ($null -eq $InputObject) { return }
        $ordered = [ordered]@{}
        foreach ($p in $InputObject.PSObject.Properties) {
            $ordered[$p.Name] = ConvertTo-SafeCsvField -Value $p.Value
        }
        [PSCustomObject]$ordered
    }
}
