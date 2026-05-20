#requires -Version 5.1
<#
.SYNOPSIS
    Rewrites README.md TOC + inline anchor links after the v0.7.76 doc split.
.DESCRIPTION
    One-shot script. Replaces the auto-generated TOC block in the main README
    (between '<details>' and '</details>') with a shorter, accurate TOC pointing
    to the new docs/*.md files, and rewrites all body cross-references like
    '(#get-azlocalclusterinventory)' to point at the new cmdlet-reference page.
.NOTES
    Run AFTER Split-Readme-Batch.ps1.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$ReadmePath
)

$utf8 = [Text.UTF8Encoding]::new($false)
$content = ([IO.File]::ReadAllText($ReadmePath, $utf8)) -replace "`r`n", "`n"

# ============================================================================
# 1. Replace the TOC <details>...</details> block.
# ============================================================================
$tocOpen  = "<details>`n<summary><strong>"
$tocClose = "</details>"
$openIdx  = $content.IndexOf($tocOpen)
$closeIdx = $content.IndexOf($tocClose, $openIdx)
if ($openIdx -lt 0 -or $closeIdx -lt 0) { throw "TOC details block not found" }
$tocEnd = $closeIdx + $tocClose.Length

$newToc = @'
<details>
<summary><strong>📑 Table of Contents</strong> (click to expand)</summary>

**This README (overview + most-recent release notes):**

- [Where to Start](#where-to-start)
- [What's New in v0.7.75](#whats-new-in-v0775)
- [Files](#files)
- [Prerequisites](#prerequisites)
- [RBAC Requirements](#rbac-requirements) (summary; full reference in [docs/rbac.md](docs/rbac.md))
- [Quick Start](#quick-start)
- [Available Functions](#available-functions) (summary; full reference in [docs/cmdlet-reference.md](docs/cmdlet-reference.md))
- [Update States](#update-states) (summary; full reference in [docs/concepts.md](docs/concepts.md))
- [Troubleshooting](#troubleshooting) (summary; full reference in [docs/troubleshooting.md](docs/troubleshooting.md))
- [License](#license)
- [Release History](#release-history) (most recent only; full history in [docs/release-history.md](docs/release-history.md))

**Detailed references (in `docs/`):**

- [docs/cmdlet-reference.md](docs/cmdlet-reference.md) - every exported cmdlet (single-cluster + fleet-scale + API version reference)
- [docs/rbac.md](docs/rbac.md) - full RBAC role map, custom least-privilege role, role-assignment recipes
- [docs/concepts.md](docs/concepts.md) - update lifecycle states, Azure CLI direct usage, Az.StackHCI parity, CI/CD background
- [docs/troubleshooting.md](docs/troubleshooting.md) - symptom-to-fix table for common failure modes
- [docs/release-history.md](docs/release-history.md) - v0.7.74 and earlier What's-New entries
- [docs/RELEASE-PROCESS.md](docs/RELEASE-PROCESS.md) - how to cut a release (maintainer-facing)
- [Automation-Pipeline-Examples/README.md](./Automation-Pipeline-Examples/README.md) - end-to-end CI/CD pipeline runbook

</details>
'@

$content = $content.Substring(0, $openIdx) + $newToc + $content.Substring($tocEnd)

# ============================================================================
# 2. Rewrite inline cmdlet/section anchors that were extracted into docs/*.md.
#    Order matters: longer / more specific anchors first so we do not double-
#    rewrite (e.g. don't let '(#troubleshooting)' get rewritten twice).
# ============================================================================

# Cmdlet anchors -> docs/cmdlet-reference.md
$cmdletAnchors = @(
    'connect-azlocalserviceprincipal',
    'start-azlocalclusterupdate',
    'get-azlocalclusterupdatereadiness',
    'get-azlocalclusterinfo',
    'get-azlocalupdatesummary',
    'get-azlocalavailableupdates',
    'get-azlocalupdateruns',
    'test-azlocalclusterhealth',
    'get-azlocalclusterinventory',
    'set-azlocalclusterupdateringtag',
    'invoke-azlocalfleetoperation',
    'get-azlocalfleetprogress',
    'test-azlocalfleethealthgate',
    'export-azlocalfleetstate',
    'resume-azlocalfleetupdate',
    'stop-azlocalfleetupdate',
    'test-azlocalupdatescheduleallowed',
    'reset-azlocalsideloadedtag',
    'get-azlocalfleetstatusdata',
    'new-azlocalfleetstatushtmlreport',
    'get-azlocalfleethealthfailures',
    'test-azlocalapplyupdatesschedulecoverage',
    'cmdlet-inventory--design-reads-vs-writes'
)
foreach ($a in $cmdletAnchors) {
    $content = $content -replace [regex]::Escape("](#$a)"), "](docs/cmdlet-reference.md#$a)"
}

# Concept/update-states anchors -> docs/concepts.md
$conceptAnchors = @(
    'update-states',
    'cluster-update-summary-states',
    'individual-update-states',
    'using-azure-cli-directly',
    'alternative-azstackhci-powershell-module',
    'cicd-automation'
)
foreach ($a in $conceptAnchors) {
    # Skip the same-page TOC entry; we want the in-README anchor to keep its same-page
    # short-form link in the TOC. Only rewrite body-text occurrences. We achieve this by
    # only rewriting links whose surrounding context is a non-TOC marker like '. See ['
    # or 'see [' or inside a table cell, leaving the leading-bullet TOC entries alone.
    # In practice the rewrite is harmless either way because the new README still has the
    # short anchor, so leave the rewrite in for now.
    if ($a -in @('update-states')) {
        # Keep the TOC short link to #update-states alive (it points at the summary section).
        continue
    }
    $content = $content -replace [regex]::Escape("](#$a)"), "](docs/concepts.md#$a)"
}

# RBAC sub-anchors -> docs/rbac.md
$rbacAnchors = @(
    'recommended-built-in-roles',
    'specific-permissions-required',
    'roles-that-do-not-have-update-permissions',
    'custom-azure-stack-hci-update-operator-role-definition-least-privilege',
    'assigning-a-role'
)
foreach ($a in $rbacAnchors) {
    $content = $content -replace [regex]::Escape("](#$a)"), "](docs/rbac.md#$a)"
}

# Troubleshooting sub-anchors -> docs/troubleshooting.md
$tsAnchors = @(
    'common-issues',
    'warning-unable-to-encode-the-output-with-cp1252-encoding',
    'arm-is-stale---readiness-recommends-an-already-installed-update',
    'verbose-logging'
)
foreach ($a in $tsAnchors) {
    $content = $content -replace [regex]::Escape("](#$a)"), "](docs/troubleshooting.md#$a)"
}

[IO.File]::WriteAllText($ReadmePath, $content, $utf8)
Write-Host "README.md anchors rewritten ($((Get-Content $ReadmePath).Length) lines)"
