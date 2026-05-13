function Format-AzLocalIncidentBody {
    <#
    .SYNOPSIS
        Renders a Mustache-style template against an ITSM context hashtable.

    .DESCRIPTION
        Supports {{path.to.value}} substitution against a nested hashtable
        (e.g. -Context @{ cluster = @{ name = 'C1' }; run = @{ id = 1 } }
        with template '{{cluster.name}} run {{run.id}}' -> 'C1 run 1').

        All substituted values are HTML-escaped by default; pass -NoHtmlEscape
        to disable (e.g. when rendering plain-text work-notes). Tokens that
        resolve to $null or a missing path render as an empty string, with
        the unresolved path logged via Write-Verbose.

        Templates may be supplied as -Template <string> or -TemplatePath <file>.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Inline')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Inline')]
        [AllowEmptyString()]
        [string]$Template,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [ValidateNotNullOrEmpty()]
        [string]$TemplatePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable]$Context,

        [Parameter(Mandatory = $false)]
        [switch]$NoHtmlEscape
    )

    if ($PSCmdlet.ParameterSetName -eq 'File') {
        if (-not (Test-Path -Path $TemplatePath -PathType Leaf)) {
            throw "Incident template file not found: $TemplatePath"
        }
        $Template = Get-Content -Path $TemplatePath -Raw
    }

    if ([string]::IsNullOrEmpty($Template)) { return '' }

    $regex = [regex]'\{\{\s*([A-Za-z0-9_.]+)\s*\}\}'
    $result = $regex.Replace($Template, {
        param($m)
        $path = $m.Groups[1].Value
        $value = Resolve-AzLocalTemplatePath -Context $Context -Path $path
        if ($null -eq $value) {
            Write-Verbose "Format-AzLocalIncidentBody: token '{{$path}}' resolved to null."
            return ''
        }
        $text = [string]$value
        if (-not $NoHtmlEscape) {
            $text = [System.Net.WebUtility]::HtmlEncode($text)
        }
        return $text
    })

    return $result
}

function Resolve-AzLocalTemplatePath {
    <#
    .SYNOPSIS
        Walks a dotted path against a nested hashtable / pscustomobject.

    .DESCRIPTION
        Returns the resolved value or $null if any segment is missing.
        Internal helper for Format-AzLocalIncidentBody.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Context,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $current = $Context
    foreach ($segment in $Path.Split('.')) {
        if ($null -eq $current) { return $null }

        if ($current -is [hashtable] -or $current -is [System.Collections.IDictionary]) {
            if (-not $current.Contains($segment)) { return $null }
            $current = $current[$segment]
            continue
        }

        $prop = $current.PSObject.Properties[$segment]
        if (-not $prop) { return $null }
        $current = $prop.Value
    }
    return $current
}
