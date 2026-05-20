#requires -Version 5.1
<#
.SYNOPSIS
    Batch extracts top-level README sections into AzLocal.UpdateManagement/docs/*.md.
.DESCRIPTION
    Reads README.md, finds the literal '## <Section>' heading for each entry in
    $sections, and moves all content from that heading up to (but not including)
    the next '## ' heading into a new file in docs/. The section in the README is
    replaced with a short redirect pointer.
.NOTES
    One-shot script used during the v0.7.76 documentation split (Finding 5).
    NOT idempotent: re-running after the README is trimmed would extract the
    redirect-only stubs. The script checks for that condition and aborts safely.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$ReadmePath,
    [Parameter(Mandatory = $true)] [string]$DocsDir
)

$utf8 = [Text.UTF8Encoding]::new($false)
$content = ([IO.File]::ReadAllText($ReadmePath, $utf8)) -replace "`r`n", "`n"

# Sections to extract. The order does not matter because we operate on
# the live string and re-find the marker after each replacement.
$sections = @(
    [PSCustomObject]@{
        StartMarker = '## RBAC Requirements'
        OutFile     = 'rbac.md'
        Title       = 'AzLocal.UpdateManagement RBAC Reference'
        Intro       = @'
> **What you will find here:** Every Azure RBAC role and scope the module needs, broken down by cmdlet group (read-only, planning, executing updates, hybrid runners). Use this when granting an automation principal the least-privilege set of roles before wiring up a pipeline.
>
> **Cross-reference:** The main [README.md](../README.md) only summarises the role list. This file is the canonical reference.
'@
    },
    [PSCustomObject]@{
        StartMarker = '## Available Functions'
        OutFile     = 'cmdlet-reference.md'
        Title       = 'AzLocal.UpdateManagement Cmdlet Reference'
        Intro       = @'
> **What you will find here:** Every exported cmdlet, organised first by single-cluster operations and then by fleet-scale (Get-AzLocalFleet*) operations, followed by an API-version reference. Each cmdlet entry shows the supported parameters, the ARM surface it calls, and a minimum-RBAC reminder.
>
> **Cross-reference:** The main [README.md](../README.md) shows only a single-line summary per cmdlet so it stays printable. Open this file for full signatures and examples.
'@
        EndBeforeMarker = '## Update States'  # Capture three sub-sections in one slice: Available Functions + Fleet-Scale Operations + API Reference
    },
    [PSCustomObject]@{
        StartMarker = '## Update States'
        OutFile     = 'concepts.md'
        Title       = 'AzLocal.UpdateManagement Concepts and Background'
        Intro       = @'
> **What you will find here:** Background on the update lifecycle (states, ARM-direct vs. PowerShell wrappers, Az.StackHCI parity), and the CI/CD automation pattern this module is built for. Useful when first onboarding to the module, or when you need to explain to a colleague why a particular update is "stuck" in a given state.
>
> **Cross-reference:** Operational guidance for individual cmdlets lives in [cmdlet-reference.md](cmdlet-reference.md). Troubleshooting recipes live in [troubleshooting.md](troubleshooting.md).
'@
        EndBeforeMarker = '## Troubleshooting'  # Capture Update States + Using Azure CLI Directly + Alternative: Az.StackHCI + CI/CD Automation
    },
    [PSCustomObject]@{
        StartMarker = '## Troubleshooting'
        OutFile     = 'troubleshooting.md'
        Title       = 'AzLocal.UpdateManagement Troubleshooting'
        Intro       = @'
> **What you will find here:** Symptom-to-fix table for common failure modes (auth errors, RBAC gaps, ARM polling timeouts, KQL `ParserFailure: token=<EOF>`, healthCheckResult duplicates, etc.) plus a handful of "did you forget X" reminders. Look here first when a pipeline step fails.
>
> **Cross-reference:** Recurring fixes that change behaviour are also written up in [release-history.md](release-history.md) under the version that shipped them.
'@
    }
)

foreach ($sec in $sections) {
    $startMarker = "`n$($sec.StartMarker)`n"
    $idx = $content.IndexOf($startMarker)
    if ($idx -lt 0) { throw "Start marker '$($sec.StartMarker)' not found" }

    # Find the end of the section. Either the explicit EndBeforeMarker (when the
    # extracted block spans multiple sibling H2s) or the next H2 in the document.
    $endIdx = -1
    if ($sec.PSObject.Properties.Match('EndBeforeMarker').Count -gt 0 -and $sec.EndBeforeMarker) {
        $endMarker = "`n$($sec.EndBeforeMarker)`n"
        $endIdx = $content.IndexOf($endMarker)
        if ($endIdx -lt 0) { throw "End marker '$($sec.EndBeforeMarker)' not found for section '$($sec.StartMarker)'" }
    }
    else {
        # Next sibling H2 anywhere after the start.
        $searchFrom = $idx + $startMarker.Length
        $rx = [regex]'\n## [^\n]+\n'
        $m = $rx.Match($content, $searchFrom)
        if (-not $m.Success) { throw "No next H2 found after '$($sec.StartMarker)'" }
        $endIdx = $m.Index
    }

    $sectionBody = $content.Substring($idx + 1, $endIdx - $idx - 1)  # strip leading newline, keep trailing newline before next H2
    $sectionBytes = [Text.Encoding]::UTF8.GetByteCount($sectionBody)
    if ($sectionBytes -lt 400) {
        Write-Host "Section '$($sec.StartMarker)' is already < 400 bytes ($sectionBytes) - looks redirect-only. Skipping."
        continue
    }

    # Build new docs file.
    $docContent = "# $($sec.Title)`n`n$($sec.Intro)`n`n---`n`n$sectionBody`n"
    $outPath = Join-Path $DocsDir $sec.OutFile
    [IO.File]::WriteAllText($outPath, $docContent, $utf8)

    # Build redirect that replaces the section in the README. The first line is
    # the original section heading so anchors like #troubleshooting still work.
    $shortName = ($sec.OutFile -replace '\.md$', '')
    $redirect = "$($sec.StartMarker)`n`nMoved to [docs/$($sec.OutFile)](docs/$($sec.OutFile)) to keep this README focused. See the linked file for the full reference.`n"

    $content = $content.Substring(0, $idx + 1) + $redirect + $content.Substring($endIdx + 1)
    Write-Host "Extracted '$($sec.StartMarker)' -> docs/$($sec.OutFile) ($((Get-Content $outPath).Length) lines)"
}

[IO.File]::WriteAllText($ReadmePath, $content, $utf8)
Write-Host ""
Write-Host "README.md trimmed to $((Get-Content $ReadmePath).Length) lines"
