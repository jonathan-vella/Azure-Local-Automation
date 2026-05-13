function Write-Log {
    <#
    .SYNOPSIS
        Writes a timestamped log entry to console and optionally to file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Message = "",

        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Verbose', 'Header')]
        [string]$Level = 'Info',

        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    # Determine color based on level if not specified
    if (-not $ForegroundColor) {
        $ForegroundColor = switch ($Level) {
            'Info'    { 'White' }
            'Warning' { 'Yellow' }
            'Error'   { 'Red' }
            'Success' { 'Green' }
            'Verbose' { 'Gray' }
            'Header'  { 'Cyan' }
            default   { 'White' }
        }
    }

    # Write to console
    Write-Host $logEntry -ForegroundColor $ForegroundColor

    # Write to log file if path is set
    if ($script:LogFilePath) {
        try {
            # -WhatIf:$false -- log writes are internal side effects, must run
            # even when the caller invokes a cmdlet with -WhatIf.
            Add-Content -Path $script:LogFilePath -Value $logEntry -ErrorAction SilentlyContinue -WhatIf:$false
        }
        catch {
            # Log file write failure is non-critical - continue silently to not disrupt main operation
            Write-Verbose "Failed to write to log file: $($_.Exception.Message)"
        }
    }

    # Write errors to separate error log
    if ($Level -eq 'Error' -and $script:ErrorLogPath) {
        try {
            Add-Content -Path $script:ErrorLogPath -Value $logEntry -ErrorAction SilentlyContinue -WhatIf:$false
        }
        catch {
            # Error log write failure is non-critical - continue silently
            Write-Verbose "Failed to write to error log file: $($_.Exception.Message)"
        }
    }
}
