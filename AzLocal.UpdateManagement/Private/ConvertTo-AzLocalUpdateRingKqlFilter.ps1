function ConvertTo-AzLocalUpdateRingKqlFilter {
    <#
    .SYNOPSIS
        Builds a KQL filter clause for an UpdateRing tag value that may be a
        single ring, multiple rings separated by ';', or '***' (match every
        cluster that has a non-empty UpdateRing tag).
    .DESCRIPTION
        v0.7.66 introduced multi-value UpdateRing inputs across all pipelines
        and cmdlets. Callers used to splice a single string into a KQL query
        like:

            | where tags['UpdateRing'] =~ '$UpdateRingValue'

        This helper accepts the relaxed input forms and returns the
        appropriate clause:

          - '***'            => "| where isnotempty(tags['UpdateRing'])"
                                (matches every cluster that HAS the tag set
                                 to a non-empty value; clusters with no
                                 UpdateRing tag are deliberately excluded so
                                 untagged clusters stay opted-out)
          - 'Wave1'          => "| where tags['UpdateRing'] =~ 'Wave1'"
          - 'Prod;Ring2'     => "| where tags['UpdateRing'] in~ ('Prod','Ring2')"

        SAFETY: the wildcard token is three stars ('***'), not one. A single
        '*' is rejected by the upstream [ValidatePattern] on every public
        cmdlet so operators cannot accidentally scope a fleet-wide write
        (Start-AzLocalClusterUpdate, Set-AzLocalClusterUpdateRingTag,
        Reset-AzLocalSideloadedTag, Invoke-AzLocalFleetOperation) by
        typo. Three keystrokes is a deliberate gesture.

        Empty / whitespace segments produced by split are discarded.
        Embedded single quotes are doubled (KQL string-literal escaping) to
        keep the query injection-safe.
    .PARAMETER UpdateRingValue
        The raw UpdateRing value as it arrived from a pipeline parameter or
        cmdlet argument.
    .PARAMETER TagAccessor
        The KQL expression used to read the UpdateRing tag. Defaults to
        "tags['UpdateRing']" which matches direct cluster ARG queries. For
        the fleet health failures path (which goes via updateSummaries -> ARG
        hop on clusters) callers pass "tostring(tags['UpdateRing'])".
    .OUTPUTS
        [string] - the KQL where-clause, INCLUDING the leading '| where' if
        any filter is needed. Returns an empty string only when the input
        itself is null/empty/whitespace (i.e. when no scoping was requested
        at all - which the upstream Mandatory parameter binders normally
        prevent).
    .EXAMPLE
        $clause = ConvertTo-AzLocalUpdateRingKqlFilter -UpdateRingValue 'Prod;Ring2'
        # | where tags['UpdateRing'] in~ ('Prod','Ring2')
    .EXAMPLE
        $clause = ConvertTo-AzLocalUpdateRingKqlFilter -UpdateRingValue '***'
        # | where isnotempty(tags['UpdateRing'])
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$UpdateRingValue,

        [Parameter(Mandatory = $false)]
        [string]$TagAccessor = "tags['UpdateRing']"
    )

    if ([string]::IsNullOrWhiteSpace($UpdateRingValue)) { return '' }

    # '***' (three stars, exactly) is the deliberate fleet-wide token.
    # Single '*' and partial-star forms ('**', '****', '*Wave1') are blocked
    # by [ValidatePattern] on the callers, so they never reach this helper -
    # but we still check exactly '***' here to keep the contract explicit.
    if ($UpdateRingValue.Trim() -eq '***') {
        return "| where isnotempty($TagAccessor)"
    }

    $rings = @($UpdateRingValue -split ';' |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ })

    if (-not $rings -or $rings.Count -eq 0) { return '' }

    # @(...) wraps the pipeline output so we always get an array, even when the
    # caller passed a single ring. Without this, $escaped becomes a bare string
    # and $escaped[0] returns the FIRST CHARACTER ("'") rather than the first
    # element ("'Wave1'"), which silently corrupts the KQL where-clause.
    $escaped = @($rings | ForEach-Object {
        # KQL single-quote escaping: double each embedded quote, then wrap.
        $doubled = $_ -replace "'", "''"
        "'$doubled'"
    })

    if ($escaped.Count -eq 1) {
        return "| where $TagAccessor =~ $($escaped[0])"
    }

    return "| where $TagAccessor in~ ($($escaped -join ','))"
}
