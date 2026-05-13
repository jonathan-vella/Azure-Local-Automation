function Get-AzLocalItsmDedupeKey {
    <#
    .SYNOPSIS
        Builds the deterministic SHA256-based dedupe key for an ITSM ticket.

    .DESCRIPTION
        Computes SHA256 over a lowercase, pipe-delimited tuple of
        ClusterResourceId | UpdateName | TriggerCategory and returns
        the lowercase hex digest (64 chars). This is the stable
        idempotency key written to ServiceNow's u_azlocal_dedupe_key
        custom field; the same inputs always produce the same key,
        across module versions and across hosts.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$ClusterResourceId,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$UpdateName,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$TriggerCategory
    )

    $raw   = '{0}|{1}|{2}' -f $ClusterResourceId.Trim().ToLowerInvariant(),
                              $UpdateName.Trim().ToLowerInvariant(),
                              $TriggerCategory.Trim().ToLowerInvariant()
    $bytes = [Text.Encoding]::UTF8.GetBytes($raw)
    $sha   = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($bytes)
    }
    finally {
        $sha.Dispose()
    }

    return ([BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
}
