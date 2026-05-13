function Write-Utf8NoBomFile {
    <#
    .SYNOPSIS
        Writes text content to a file using UTF-8 encoding WITHOUT a byte-order mark.
    .DESCRIPTION
        PowerShell 5.1's `Out-File -Encoding UTF8` emits a UTF-8 BOM (EF BB BF) which
        corrupts the first column of CSVs opened with Import-Csv / Excel on non-Windows
        systems, confuses JUnit-XML parsers (including dorny/test-reporter and Azure
        DevOps PublishTestResults@2), and shows up as "\ufeff" prefixed strings in
        downstream JSON consumers. This helper writes text with an explicit
        `UTF8Encoding($false)` so the BOM is never emitted.

        Used across the module for all CSV / JSON / XML exports that are consumed by
        CI/CD pipelines, Excel, or cross-platform tooling. Use the native
        `[System.IO.File]::WriteAllText` pattern directly only when you need different
        encoding semantics.
    .PARAMETER Path
        Absolute or relative path of the output file. Parent directory must exist.
    .PARAMETER Content
        The text to write. `$null` is coerced to an empty string.
    .PARAMETER Append
        When specified, appends to an existing file instead of overwriting. The BOM
        is still never emitted (appends raw UTF-8 bytes).
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Content,

        [switch]$Append
    )

    process {
        if ($null -eq $Content) { $Content = '' }
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        if ($Append) {
            [System.IO.File]::AppendAllText($Path, $Content, $utf8NoBom)
        }
        else {
            [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
        }
    }
}
