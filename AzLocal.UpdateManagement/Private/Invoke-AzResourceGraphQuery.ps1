function Invoke-AzResourceGraphQuery {
    <#
    .SYNOPSIS
        Runs an Azure Resource Graph query via 'az graph query' and transparently
        follows skip_token pagination until all rows are returned.
    .DESCRIPTION
        The Azure CLI returns at most --first rows per call (max 1000). When a
        fleet has more than 1000 clusters the caller was previously receiving
        only a truncated first page. This helper loops on the response's
        skip_token field, aggregating .data across pages and returning the
        merged row array.

        Safety cap: MaxPages (default 100 -> 100,000 rows). Prevents a bug in
        the caller's query from producing an infinite pagination loop. When
        the cap is hit, a Write-Warning is emitted, the module-scope flag
        $script:LastResourceGraphQueryTruncated is set to $true, and the
        partial result is returned. Callers that need to behave differently
        on truncation can read the flag after the call.

        v0.7.68: the Query string is normalised (CR/LF and runs of whitespace
        collapsed to single spaces) BEFORE being passed to 'az graph query -q'.
        On Windows, az is implemented as az.cmd (a batch file), and the CMD
        argument parser truncates command-line arguments at the first CR/LF -
        so a multi-line PowerShell here-string KQL would silently be reduced
        to just its first line on the runner. The pre-v0.7.68 behaviour caused
        Test-AzureLocalApplyUpdatesScheduleCoverage to silently return all
        resources (default schema, no UpdateRing/UpdateWindow columns) instead
        of the projected cluster rows it asked for; the audit then reported
        zero tagged clusters even when clusters were tagged correctly. The
        normalisation here protects every caller, current and future. KQL is
        whitespace-agnostic, so collapsing newlines/tabs is semantically a
        no-op.
    .PARAMETER Query
        KQL query string. Normalised to single-line before being passed to
        'az graph query -q'. See .DESCRIPTION for the Windows az.cmd reason.
    .PARAMETER SubscriptionId
        Optional. If supplied, scopes the query to that subscription via
        --subscriptions. Omit to query across all accessible subscriptions.
    .PARAMETER First
        Page size. Defaults to 1000 (the ARG maximum).
    .PARAMETER MaxPages
        Safety cap. Defaults to 100 (= 100,000 rows). Bumped from 50 in
        v0.7.68 so that fleets up to ~100K clusters paginate without operator
        intervention.
    .OUTPUTS
        [object[]] of rows merged across all pages. Empty array if no rows.
        Throws if the CLI returns a non-zero exit code or the response cannot
        be parsed as JSON.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Query,

        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 1000)]
        [int]$First = 1000,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 500)]
        [int]$MaxPages = 100
    )

    # v0.7.68: collapse CR/LF and runs of whitespace into single spaces so the
    # query survives az.cmd's CMD argument parser on Windows. See .DESCRIPTION.
    # KQL is whitespace-agnostic in its grammar, so this is semantically inert
    # for every well-formed query. Leading/trailing whitespace is also trimmed
    # to keep the eventual command-line clean.
    $Query = ($Query -replace '\s+', ' ').Trim()

    # Reset the truncation flag at the start of every call so a caller checking
    # $script:LastResourceGraphQueryTruncated sees only THIS call's outcome.
    $script:LastResourceGraphQueryTruncated = $false

    $allRows = [System.Collections.Generic.List[object]]::new()
    $skipToken = $null
    $pages = 0

    # Force Azure CLI (Python) to write UTF-8 to stdout/stderr regardless of the
    # host console code page. Without this, any non-cp1252 character in an ARG
    # response (resource IDs from non-en-US tenants, localised update names,
    # cluster property strings, etc.) causes the CLI to emit a stderr warning
    # like "WARNING: Unable to encode the output with cp1252 encoding..." which,
    # when captured via 2>&1, gets prepended to the JSON and breaks
    # ConvertFrom-Json. See the matching hardening in Invoke-AzRestJson.ps1
    # (the v0.7.2 cp1252 fix). NOTE: az.cmd launches python with -I (isolated),
    # which causes python to ignore PYTHONIOENCODING / PYTHONUTF8; the env-var
    # assignment is therefore best-effort. The hard fix is the stderr/stdout
    # split below: stderr lines surface as ErrorRecord objects under 2>&1 and
    # we only feed the stdout strings to ConvertFrom-Json.
    $prevPyEncoding = $env:PYTHONIOENCODING
    try {
        $env:PYTHONIOENCODING = 'utf-8'

        while ($true) {
            $pages++
            if ($pages -gt $MaxPages) {
                $script:LastResourceGraphQueryTruncated = $true
                Write-Warning "Invoke-AzResourceGraphQuery: reached MaxPages=$MaxPages safety cap; returning partial result ($($allRows.Count) rows). Check the query for unbounded output or raise -MaxPages. Callers can detect this via `$script:LastResourceGraphQueryTruncated."
                break
            }

            $azArgs = @('graph', 'query', '-q', $Query, '--first', $First, '--only-show-errors')
            if ($SubscriptionId) { $azArgs += @('--subscriptions', $SubscriptionId) }
            if ($skipToken) { $azArgs += @('--skip-token', $skipToken) }

            $raw = & az @azArgs 2>&1
            $exit = $LASTEXITCODE

            # Split merged stdout+stderr by stream type. Stderr lines (Python
            # warnings, deprecation notices) surface as ErrorRecord objects
            # when using 2>&1; stdout lines surface as strings. We only pass
            # the string stream to ConvertFrom-Json so a stray stderr warning
            # can never corrupt JSON.
            $stderrLines = @($raw | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
            $stdoutLines = @($raw | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })

            if ($exit -ne 0) {
                $errText = ((($stderrLines + $stdoutLines) | Out-String).Trim())
                throw "Azure Resource Graph query failed (exit $exit): $(ConvertTo-ScrubbedCliOutput -Text $errText)"
            }

            $rawText = ($stdoutLines | Out-String).Trim()
            if ([string]::IsNullOrWhiteSpace($rawText)) {
                break
            }
            try {
                $parsed = $rawText | ConvertFrom-Json -ErrorAction Stop
            }
            catch {
                throw "Azure Resource Graph query failed to parse JSON: $($_.Exception.Message); raw: $(ConvertTo-ScrubbedCliOutput -Text $rawText.Substring(0, [Math]::Min(500, $rawText.Length)))"
            }

            # 'az graph query' returns either a top-level array (older CLI) or an
            # object with .data / .skip_token (newer CLI). Normalise.
            $rows = $null
            $nextToken = $null
            if ($parsed -is [System.Array]) {
                $rows = $parsed
            }
            elseif ($parsed.PSObject.Properties.Name -contains 'data') {
                $rows = $parsed.data
                if ($parsed.PSObject.Properties.Name -contains 'skip_token') { $nextToken = $parsed.skip_token }
                elseif ($parsed.PSObject.Properties.Name -contains 'skipToken') { $nextToken = $parsed.skipToken }
            }
            else {
                # Unknown shape - treat as single-row result
                $rows = @($parsed)
            }

            if ($rows) {
                foreach ($row in $rows) { [void]$allRows.Add($row) }
            }

            if (-not $nextToken) { break }
            $skipToken = $nextToken
            Write-Verbose "Invoke-AzResourceGraphQuery: fetched page $pages ($($allRows.Count) rows so far); following skip_token for next page."
        }
    }
    finally {
        $env:PYTHONIOENCODING = $prevPyEncoding
    }

    # IMPORTANT: the leading comma is required to preserve array shape so that
    # callers using `$x = Invoke-AzResourceGraphQuery ...` receive an [object[]]
    # for 0, 1, or N rows (not $null, scalar, or unwrapped enumerable).
    # WARNING: callers MUST NOT wrap this call with @( ... ). The `,`-return
    # plus `@()` combination produces a double-wrapped Object[1] containing the
    # inner array, which silently collapses N rows to 1 row of property-arrays.
    # Use `$x = Invoke-AzResourceGraphQuery ...` directly; the result is always
    # an array.
    return , $allRows.ToArray()
}
