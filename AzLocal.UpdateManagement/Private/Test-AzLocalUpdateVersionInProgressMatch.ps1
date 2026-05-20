function Test-AzLocalUpdateVersionInProgressMatch {
    <#
    .SYNOPSIS
        Compares an UpdateVersionInProgress tag value to a run's update name.
    .DESCRIPTION
        Case-insensitive exact equality (after trim). Used by the auto-reset path
        in Get-AzLocalUpdateRuns and by Reset-AzLocalSideloadedTag to decide
        whether a Succeeded run actually corresponds to the staged sideloaded payload.
    .PARAMETER TagValue
        The current value of the UpdateVersionInProgress tag.
    .PARAMETER RunUpdateName
        The update.name (or run.UpdateName) reported by ARM for the Succeeded run.
    .OUTPUTS
        [bool] - $true when the tag matches the run name, $false otherwise (including
        when either side is null/empty).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$TagValue,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$RunUpdateName
    )

    if ([string]::IsNullOrWhiteSpace($TagValue) -or [string]::IsNullOrWhiteSpace($RunUpdateName)) {
        return $false
    }
    return ([string]::Equals($TagValue.Trim(), $RunUpdateName.Trim(), [System.StringComparison]::OrdinalIgnoreCase))
}
