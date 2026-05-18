function Get-AzLocalPipelineCustomiseMarkers {
    <#
    .SYNOPSIS
        Parses BEGIN/END-AZLOCAL-CUSTOMIZE marker pairs out of a pipeline YAML
        text blob.

    .DESCRIPTION
        Private helper supporting Update-AzureLocalPipelineExample. The marker
        convention is:

            <indent>#[<more #s>] BEGIN-AZLOCAL-CUSTOMIZE:<section>
            <body lines>
            <indent>#[<more #s>] END-AZLOCAL-CUSTOMIZE:<section>

        Both markers are plain YAML comments and therefore have zero runtime
        effect on either GitHub Actions or Azure DevOps. The <section> name
        is an identifier consisting of letters, digits, hyphens and
        underscores (regex: [A-Za-z0-9_-]+). It is expected to be unique per
        file; only the FIRST occurrence of a given <section> is kept if a
        file accidentally repeats it (a Write-Warning is emitted).

        The returned hashtable is keyed by <section> name. Each value is a
        PSCustomObject with:
            Name      - <section>
            BeginLine - full text of the BEGIN line (no trailing newline)
            EndLine   - full text of the END line (no trailing newline)
            Body      - everything between BeginLine and EndLine, INCLUDING
                        the leading newline after BeginLine and the trailing
                        newline before EndLine, so reassembling
                        ($BeginLine + $Body + $EndLine) reconstructs the
                        original span verbatim.
            Index     - 0-based start offset (start of BeginLine) into the
                        input text
            Length    - total character length of the matched block
                        (BeginLine + Body + EndLine)

    .PARAMETER Text
        The full YAML text to scan. Use Get-Content -Raw or
        [IO.File]::ReadAllText to obtain it; line endings are preserved.

    .OUTPUTS
        [hashtable] keyed by section name (case-sensitive). Empty hashtable
        if no markers are found.

    .NOTES
        Added in v0.7.68.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text
    )

    $result = @{}

    if ([string]::IsNullOrEmpty($Text)) {
        return $result
    }

    # The (?ms) flags enable multi-line mode (^/$ match line boundaries) and
    # single-line mode (. matches newlines) so the body capture can span
    # multiple lines.
    #
    # CRLF NOTE: in .NET regex, $ in multi-line mode matches "immediately
    # before \n" - which is BETWEEN the \r and \n in a \r\n line ending.
    # The character class [^\r\n]* therefore stops at \r, leaving the
    # engine positioned ON \r when it needs to match $ (which expects to be
    # AT the position right before \n). The explicit \r? makes the carriage
    # return optional but consumed, so the pattern matches both LF-only
    # files (what the bundled samples ship as) and CRLF files (what
    # Windows-checked-out copies often become after a git autocrlf
    # checkout). Without the \r? the parser silently returned zero markers
    # for every CRLF file - which would have silently broken
    # Update-AzureLocalPipelineExample's entire marker-preservation feature
    # for any operator on a Windows checkout.
    #
    # Group 1 : full BEGIN line (everything from start of line up to and
    #           including the section name and any trailing text, but NOT
    #           the trailing \r or \n)
    # Group 2 : section name (back-referenced as \2 in the END line)
    # Group 3 : body (lazy - so adjacent marker blocks parse independently)
    # Group 4 : full END line
    $pattern = '(?ms)(^[^\r\n]*?BEGIN-AZLOCAL-CUSTOMIZE:([A-Za-z0-9_-]+)[^\r\n]*\r?)$(.*?)(^[^\r\n]*?END-AZLOCAL-CUSTOMIZE:\2[^\r\n]*\r?)$'
    $rx      = [regex]$pattern

    foreach ($m in $rx.Matches($Text)) {
        $name = $m.Groups[2].Value
        if ($result.ContainsKey($name)) {
            Write-Warning "Get-AzLocalPipelineCustomiseMarkers: duplicate AZLOCAL-CUSTOMIZE marker '$name' encountered; keeping the first occurrence at index $($result[$name].Index)."
            continue
        }
        $result[$name] = [PSCustomObject]@{
            Name      = $name
            BeginLine = $m.Groups[1].Value
            EndLine   = $m.Groups[4].Value
            Body      = $m.Groups[3].Value
            Index     = $m.Index
            Length    = $m.Length
        }
    }

    return $result
}
