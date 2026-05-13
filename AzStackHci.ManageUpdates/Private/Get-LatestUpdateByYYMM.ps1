function Get-LatestUpdateByYYMM {
    <#
    .SYNOPSIS
        Selects the latest update from a list by YYMM version in the update name.
    .DESCRIPTION
        Update names follow format: SolutionXX.YYMM.<build>.<rev> where YYMM is
        year+month. Sorts primarily by YYMM (descending) with a deterministic
        tie-breaker on the full update name (descending) so that repeated calls
        against the same input always return the same winner. Emits a Warning
        (not just Verbose) when no input matched the expected name shape, since
        in that case the returned item is effectively arbitrary.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Updates
    )

    if (-not $Updates -or $Updates.Count -eq 0) { return $null }

    $sorted = $Updates | Sort-Object -Descending `
        @{ Expression = {
                $yymm = ($_.name -split '\.')[1]
                if ($yymm -match '^\d{4}$') { [int]$yymm } else { 0 }
            }
        }, `
        @{ Expression = { "$($_.name)" } }

    $topName = "$($sorted[0].name)"
    $topYymm = ($topName -split '\.')[1]
    if ($topYymm -notmatch '^\d{4}$') {
        Write-Log -Message "Get-LatestUpdateByYYMM: no update name matched the expected Solution<XX>.<YYMM>.<build>.<rev> format (checked $($Updates.Count) items); result '$topName' is a deterministic name-sort fallback." -Level Warning
    }

    return $sorted | Select-Object -First 1
}
