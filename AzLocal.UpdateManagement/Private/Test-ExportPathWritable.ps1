function Test-ExportPathWritable {
    <#
    .SYNOPSIS
        Pre-flight check: validates an export file path is writable before expensive operations begin.
    .DESCRIPTION
        Checks that the target export file is not locked by another process (e.g., Excel),
        and that the parent directory exists or can be created. Call this early in functions
        that accept -ExportPath/-ExportResultsPath to fail fast before API calls.
    .PARAMETER Path
        The file path to validate.
    .OUTPUTS
        Returns $true if the path is writable. Throws on failure.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Ensure parent directory exists or can be created
    $parentDir = Split-Path -Path $Path -Parent
    if ($parentDir -and -not (Test-Path -Path $parentDir)) {
        try {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        catch {
            throw "Cannot create export directory '$parentDir': $($_.Exception.Message)"
        }
    }

    # If file doesn't exist yet, path is writable
    if (-not (Test-Path -Path $Path)) {
        return $true
    }

    # File exists - test if it's locked by trying to open it for write
    try {
        $fileStream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $fileStream.Close()
        $fileStream.Dispose()
        return $true
    }
    catch [System.IO.IOException] {
        throw "Export file '$Path' is locked by another process (e.g., Excel). Close the file and try again."
    }
    catch {
        throw "Cannot write to export file '$Path': $($_.Exception.Message)"
    }
}
