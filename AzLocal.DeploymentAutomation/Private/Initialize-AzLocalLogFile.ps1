Function Initialize-AzLocalLogFile {
    <#
    .SYNOPSIS

    Internal helper to initialise the module-scoped log file path.

    .DESCRIPTION

    Sets `$script:AzLocalLogFilePath` and ensures the parent directory exists.
    Called by each exported function when `-LogFilePath` is provided.

    .PARAMETER LogFilePath
    The file path for log output.

    #>

    [OutputType([void])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$LogFilePath
    )

    $script:AzLocalLogFilePath = $LogFilePath
    $logDir = Split-Path $LogFilePath -Parent
    if ($logDir -and -not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    Write-AzLocalLog "Log file initialised: $LogFilePath" -Level Info
}
