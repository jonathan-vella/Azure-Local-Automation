function Test-AzLocalAllowedUpdateVersionsString {
    <#
    .SYNOPSIS
        Validates and parses a semicolon-separated 'allowedUpdateVersions'
        string. Returns the deduplicated [string[]] on success, or $null
        when validation fails (errors appended to the supplied list).

    .DESCRIPTION
        Shared between the top-level and per-row validation paths in
        Get-AzLocalApplyUpdatesScheduleConfig. Rules:
          - Value must be a non-empty string. Empty / whitespace-only =
            error (operators almost always mean "don't filter" by
            omitting the field entirely).
          - Tokens are ';'-separated. Each token is trimmed.
          - Empty tokens after trim are rejected ('a;;b' is a typo).
          - Whitespace inside a token is rejected (Azure Local solution
            update names + versions do not contain spaces).
          - 'Latest' (case-insensitive) is a RESERVED SENTINEL meaning
            "no constraint - install the latest Ready update on each
            cluster" (the historic v0.7.88 default behaviour). It is
            canonicalised to 'Latest' (PascalCase) in the returned
            array.
          - 'Latest' MUST appear alone. Mixing 'Latest' with explicit
            update names / versions in the same field is rejected with
            a clear error - the operator's intent is ambiguous.
            (Cross-row UNION with 'Latest' is handled by the resolver,
            not here; this helper only validates a single field.)
          - Single quotes wrapping the whole string come from YAML and
            are stripped by the parser already - this helper does not
            try to re-strip them.

        Returns a deduplicated array preserving first-occurrence order
        so logs / audit reports show the operator's authored order.

    .PARAMETER Raw
        The raw value from the parser. May be $null / non-string when
        callers pass through an unusual YAML node; treated as error.

    .PARAMETER Location
        Human-readable location string used in error messages
        (e.g. "top-level 'allowedUpdateVersions'" or
        "schedule[3] (line 42) 'allowedUpdateVersions'").

    .PARAMETER Errors
        System.Collections.Generic.List[string] - errors collected by
        the caller. New errors are appended in place; no return value
        is used to signal failure beyond the $null return.

    .OUTPUTS
        [string[]] on success; $null on failure.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $Raw,

        [Parameter(Mandatory = $true)]
        [string]$Location,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Errors
    )

    if ($null -eq $Raw -or $Raw -isnot [string]) {
        $Errors.Add("$Location must be a non-empty semicolon-separated string. Use 'Latest' (no constraint - install latest Ready update) or a list of Azure Local solution-update names / version strings (e.g. '10.2604.0.123;10.2610.0.456'). Got: $(if ($null -eq $Raw) { '<null>' } else { $Raw.GetType().FullName })") | Out-Null
        return $null
    }

    $raw = [string]$Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        $Errors.Add("$Location is empty or whitespace-only. Set to 'Latest' to keep the default 'install the latest Ready update' behaviour, or to a non-empty semicolon-separated list of update versions to install (e.g. '10.2604.0.123;10.2610.0.456').") | Out-Null
        return $null
    }

    $tokens         = $raw -split ';'
    $seen           = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)
    $result         = New-Object System.Collections.Generic.List[string]
    $bad            = $false
    $hasLatest      = $false
    $hasExplicit    = $false
    foreach ($tok in $tokens) {
        $t = $tok.Trim()
        if ([string]::IsNullOrEmpty($t)) {
            $Errors.Add("$Location contains an empty token (likely a stray ';' - e.g. '...;;...' or trailing ';'). Got: '$raw'.") | Out-Null
            $bad = $true
            continue
        }
        if ($t -match '\s') {
            $Errors.Add("$Location token '$t' contains whitespace. Azure Local solution-update names and version strings do not contain spaces. Got: '$raw'.") | Out-Null
            $bad = $true
            continue
        }
        # Canonicalise the reserved 'Latest' sentinel to PascalCase so
        # downstream consumers can do a simple ordinal compare.
        if ([string]::Equals($t, 'Latest', [System.StringComparison]::OrdinalIgnoreCase)) {
            $t          = 'Latest'
            $hasLatest  = $true
        }
        else {
            $hasExplicit = $true
        }
        if ($seen.Add($t)) {
            $result.Add($t) | Out-Null
        }
    }

    if ($bad) { return $null }
    if ($result.Count -eq 0) {
        # Defensive: split + trim consumed everything. Treat as empty.
        $Errors.Add("$Location resolved to zero tokens after split-and-trim. Got: '$raw'.") | Out-Null
        return $null
    }
    if ($hasLatest -and $hasExplicit) {
        $Errors.Add("$Location mixes the reserved sentinel 'Latest' with explicit update names / version strings. 'Latest' must appear alone (it already means 'no constraint - install the latest Ready update'). Either set to 'Latest', or list only explicit versions (e.g. '10.2604.0.123;10.2610.0.456'). Got: '$raw'.") | Out-Null
        return $null
    }
    return ,$result.ToArray()
}

