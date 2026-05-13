function Get-AzLocalRunEndTime {
    [CmdletBinding()]
    [OutputType([Nullable[datetime]])]
    param($props)

    if (-not $props) { return $null }

    if ($props.PSObject.Properties['progress'] -and $props.progress -and
        $props.progress.PSObject.Properties['endTimeUtc'] -and $props.progress.endTimeUtc) {
        try { return [datetime]$props.progress.endTimeUtc } catch {}
    }

    $state = if ($props.PSObject.Properties['state']) { $props.state } else { $null }
    if ($state -in @('Succeeded', 'Failed') -and
        $props.PSObject.Properties['lastUpdatedTime'] -and $props.lastUpdatedTime) {
        try { return [datetime]$props.lastUpdatedTime } catch {}
    }

    return $null
}
