#requires -Version 5.1
<#
.SYNOPSIS
    Migrates orphan v0.7.71 content from the trimmed README into release-history.md.
.DESCRIPTION
    Finding 4 of v0.7.76 (the README demote) moved older What's-New blocks to the
    bottom of the README under '## Release History', but the v0.7.71 sub-feature
    bullets ended up retained inline under '## What's New in v0.7.75' (no parent
    H3 heading). After Phase 1 of Finding 5 extracted '## Release History' out
    into docs/release-history.md, the v0.7.71 H3 + one-line summary moved with
    it, but the sub-feature bullets stayed in the README, orphaned.

    This script:
      1. Extracts the orphan content (the block between the v0.7.75 redirect
         blockquote and the next H2 marker '## Files') from the README.
      2. Appends it to the v0.7.71 release-history.md entry, immediately after
         the one-line summary paragraph.
      3. Trims the orphan content from the README.

    One-shot. Run AFTER Split-Readme.ps1, Split-Readme-Batch.ps1, and Fix-
    Readme-Anchors.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$ReadmePath,
    [Parameter(Mandatory = $true)] [string]$ReleaseHistoryPath
)

$utf8 = [Text.UTF8Encoding]::new($false)

# Read both files (CRLF -> LF normalized).
$readme = ([IO.File]::ReadAllText($ReadmePath, $utf8)) -replace "`r`n", "`n"
$rel    = ([IO.File]::ReadAllText($ReleaseHistoryPath, $utf8)) -replace "`r`n", "`n"

# Locate the orphan block in the README. It sits between the v0.7.75 redirect
# blockquote line and the next H2 boundary ('\n## Files\n').
$redirectLine = "> Previous release notes have moved into the [Release History](#release-history) appendix at the bottom of this document."
$rIdx = $readme.IndexOf($redirectLine)
if ($rIdx -lt 0) { throw "Redirect blockquote not found - cannot locate orphan boundary" }

# Start of orphan: line after the redirect blockquote.
$orphanStart = $readme.IndexOf("`n", $rIdx) + 1
# Skip exactly ONE blank line that separates the blockquote from the orphan.
if ($readme.Substring($orphanStart, 1) -eq "`n") { $orphanStart++ }

# End of orphan: the '\n## ' marker that follows.
$rxNextH2 = [regex]'\n## [^\n]+\n'
$m = $rxNextH2.Match($readme, $orphanStart)
if (-not $m.Success) { throw "Next H2 marker not found - cannot locate orphan end" }
$orphanEnd = $m.Index

$orphan = $readme.Substring($orphanStart, $orphanEnd - $orphanStart).TrimEnd()
if ($orphan -notmatch '^### Step\.3 markdown render fix') {
    Write-Host "Orphan does NOT start with the expected '### Step.3 markdown render fix' heading - aborting to avoid moving the wrong block."
    Write-Host "Orphan starts with:"
    Write-Host ($orphan.Substring(0, [Math]::Min(120, $orphan.Length)))
    throw "Orphan boundary mismatch"
}

# Find insertion point in release-history.md. Insert AFTER the v0.7.71 one-line
# summary paragraph (i.e. before the next '### ' or '## ' heading after
# '### What's New in v0.7.71').
$v071Heading = "### What's New in v0.7.71`n"
$v071Idx = $rel.IndexOf($v071Heading)
if ($v071Idx -lt 0) { throw "'### What's New in v0.7.71' heading not found in release history" }

$searchFrom = $v071Idx + $v071Heading.Length
$rxNextHeading = [regex]'\n(##|###) [^\n]+\n'
$next = $rxNextHeading.Match($rel, $searchFrom)
if (-not $next.Success) { throw "No next heading after v0.7.71 - cannot locate insertion point" }
$insertAt = $next.Index

# Build the new release-history.md content: [pre-v0.7.71-content] + orphan + "\n\n" + [rest]
$pre  = $rel.Substring(0, $insertAt)
$post = $rel.Substring($insertAt)
$newRel = $pre.TrimEnd() + "`n`n" + $orphan + "`n" + $post

[IO.File]::WriteAllText($ReleaseHistoryPath, $newRel, $utf8)
Write-Host "Appended orphan v0.7.71 bullets to release-history.md (now $((Get-Content $ReleaseHistoryPath).Length) lines)"

# Now strip the orphan from the README. Keep the redirect blockquote.
$readmeNew = $readme.Substring(0, $orphanStart).TrimEnd() + "`n`n" + $readme.Substring($orphanEnd).TrimStart("`n")
$readmeNew = "$readmeNew"  # no-op to keep $null avoidance explicit
[IO.File]::WriteAllText($ReadmePath, $readmeNew, $utf8)
Write-Host "Trimmed README to $((Get-Content $ReadmePath).Length) lines"
