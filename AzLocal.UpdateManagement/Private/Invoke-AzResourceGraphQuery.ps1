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

        Safety cap: MaxPages (default 50 -> 50,000 rows) prevents a bug in the
        caller's query from producing an infinite pagination loop. A warning
        is emitted via Write-Warning and the partial result is returned if the
        cap is hit.
    .PARAMETER Query
        KQL query string. Passed verbatim to 'az graph query -q'.
    .PARAMETER SubscriptionId
        Optional. If supplied, scopes the query to that subscription via
        --subscriptions. Omit to query across all accessible subscriptions.
    .PARAMETER First
        Page size. Defaults to 1000 (the ARG maximum).
    .PARAMETER MaxPages
        Safety cap. Defaults to 50.
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
        [int]$MaxPages = 50
    )

    $allRows = [System.Collections.Generic.List[object]]::new()
    $skipToken = $null
    $pages = 0

    while ($true) {
        $pages++
        if ($pages -gt $MaxPages) {
            Write-Warning "Invoke-AzResourceGraphQuery: reached MaxPages=$MaxPages safety cap; returning partial result ($($allRows.Count) rows). Check the query for unbounded output or raise -MaxPages."
            break
        }

        $azArgs = @('graph', 'query', '-q', $Query, '--first', $First, '--only-show-errors')
        if ($SubscriptionId) { $azArgs += @('--subscriptions', $SubscriptionId) }
        if ($skipToken) { $azArgs += @('--skip-token', $skipToken) }

        $raw = & az @azArgs 2>&1
        $exit = $LASTEXITCODE
        if ($exit -ne 0) {
            throw "Azure Resource Graph query failed (exit $exit): $(ConvertTo-ScrubbedCliOutput -Text (($raw | Out-String).Trim()))"
        }

        $rawText = ($raw | Out-String).Trim()
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

    return , $allRows.ToArray()
}
