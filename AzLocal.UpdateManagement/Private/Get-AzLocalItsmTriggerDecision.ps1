function Get-AzLocalItsmTriggerDecision {
    <#
    .SYNOPSIS
        Applies an ITSM trigger matrix to a single cluster-row Status.

    .DESCRIPTION
        Returns a decision object indicating whether a ticket should be
        raised for this Status, plus the resolved Severity, Category,
        and MirrorTargets. The matrix typically comes from
        Get-AzureLocalItsmConfig (-Config.Triggers / -Config.Defaults).

        Decision object properties:
          ShouldTicket    [bool]   - whether to raise a ticket
          Severity        [int]    - 1..5 (matrix value, defaults to 3)
          Category        [string] - matrix value or 'Cluster update issue'
          MirrorTargets   [string[]] - resolved mirror list (trigger override falls back to defaults)
          Reason          [string] - human-readable explanation (used in logs)

        See AzLocal.UpdateManagement/Docs/ITSM-Connector-Plan.md Section 5.2.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Status,
        [Parameter(Mandatory = $true)][ValidateNotNull()][hashtable]$Triggers,
        [Parameter(Mandatory = $false)][hashtable]$Defaults
    )

    $defaultMirrors = @()
    if ($Defaults -and $Defaults.ContainsKey('MirrorTo') -and $Defaults['MirrorTo']) {
        $defaultMirrors = @($Defaults['MirrorTo'])
    }

    if (-not $Triggers.ContainsKey($Status)) {
        return [pscustomobject]@{
            ShouldTicket  = $false
            Severity      = 0
            Category      = $null
            MirrorTargets = @()
            Reason        = "Status '$Status' is not in the trigger matrix; ignored."
        }
    }

    $entry = $Triggers[$Status]
    if (-not $entry) {
        return [pscustomobject]@{
            ShouldTicket  = $false
            Severity      = 0
            Category      = $null
            MirrorTargets = @()
            Reason        = "Trigger entry for '$Status' is empty; ignored."
        }
    }

    $raise = $false
    if ($entry.ContainsKey('RaiseTicket')) {
        $raise = [bool]$entry['RaiseTicket']
    }

    if (-not $raise) {
        return [pscustomobject]@{
            ShouldTicket  = $false
            Severity      = 0
            Category      = $null
            MirrorTargets = @()
            Reason        = "Trigger '$Status' explicitly suppressed (raiseTicket=false)."
        }
    }

    $severity = 3
    if ($entry.ContainsKey('Severity')) { $severity = [int]$entry['Severity'] }
    if ($severity -lt 1 -or $severity -gt 5) {
        throw "Trigger '$Status' has invalid severity '$severity'. Must be 1..5."
    }

    $category = 'Cluster update issue'
    if ($entry.ContainsKey('Category') -and -not [string]::IsNullOrWhiteSpace($entry['Category'])) {
        $category = [string]$entry['Category']
    }

    $mirrors = $defaultMirrors
    if ($entry.ContainsKey('MirrorTo')) {
        # Explicit empty array means "no mirror for this trigger" -- honour it.
        $mirrors = @($entry['MirrorTo'])
    }

    return [pscustomobject]@{
        ShouldTicket  = $true
        Severity      = $severity
        Category      = $category
        MirrorTargets = $mirrors
        Reason        = "Trigger '$Status' matched (severity=$severity, mirrors=$($mirrors -join ','))."
    }
}
