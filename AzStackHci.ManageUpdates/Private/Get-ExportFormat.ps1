function Get-ExportFormat {
    <#
    .SYNOPSIS
        Determines the export format based on the file path extension or explicit format parameter.
    .DESCRIPTION
        Helper function used by export operations to determine the output format.
        If ExportFormat is 'Auto', detects from file extension. Otherwise uses the specified format.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Auto', 'Csv', 'Json', 'JUnitXml')]
        [string]$ExportFormat = 'Auto'
    )

    if ($ExportFormat -ne 'Auto') {
        return $ExportFormat
    }

    # Auto-detect from extension
    $extension = [System.IO.Path]::GetExtension($Path).ToLower()
    switch ($extension) {
        '.csv'  { return 'Csv' }
        '.json' { return 'Json' }
        '.xml'  { return 'JUnitXml' }
        default { return 'Csv' }  # Default to CSV for unknown extensions
    }
}
