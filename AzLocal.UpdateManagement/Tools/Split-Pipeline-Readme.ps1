#requires -Version 5.1
<#
.SYNOPSIS
    Extracts the two appendices from Automation-Pipeline-Examples/README.md.
.DESCRIPTION
    Moves '## Appendix A: Pipeline reference' and '## Appendix B: Release history'
    into docs/appendix-pipelines.md and docs/appendix-release-history.md so the
    main pipeline README focuses on the runbook + per-section guidance.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$ReadmePath,
    [Parameter(Mandatory = $true)] [string]$DocsDir
)

$utf8 = [Text.UTF8Encoding]::new($false)
$content = ([IO.File]::ReadAllText($ReadmePath, $utf8)) -replace "`r`n", "`n"

if (-not (Test-Path $DocsDir)) { New-Item -ItemType Directory -Path $DocsDir | Out-Null }

$appendices = @(
    [PSCustomObject]@{
        StartMarker = '## Appendix A: Pipeline reference'
        EndBeforeMarker = '## Appendix B: Release history'
        OutFile     = 'appendix-pipelines.md'
        Title       = 'Pipeline reference (Appendix A)'
        Intro       = @'
> **What you will find here:** A one-row-per-pipeline reference index for every bundled `Step.*.yml` workflow (GitHub Actions + Azure DevOps twins), with a one-line summary of the job, its triggers, the cmdlets it invokes, and the artefacts it produces. Use this as the at-a-glance index after you have read the per-step runbook in the main pipeline [README.md](../README.md).
'@
    },
    [PSCustomObject]@{
        StartMarker = '## Appendix B: Release history'
        EndBeforeMarker = '## 16. Related documentation'
        OutFile     = 'appendix-release-history.md'
        Title       = 'Pipeline release history (Appendix B)'
        Intro       = @'
> **What you will find here:** A pipeline-focused history of every release that changed the bundled `Step.*.yml` templates, the `Step.*_<job>` job names, or the `Update-AzLocalPipelineExample` upgrade behaviour. For the module's full release history (cmdlet behaviour, KQL fixes, ARM dedup, ...), see [../../docs/release-history.md](../../docs/release-history.md).
'@
    }
)

foreach ($app in $appendices) {
    $startMarker = "`n$($app.StartMarker)`n"
    $idx = $content.IndexOf($startMarker)
    if ($idx -lt 0) { throw "Start marker '$($app.StartMarker)' not found" }

    $endMarker = "`n$($app.EndBeforeMarker)`n"
    $endIdx = $content.IndexOf($endMarker)
    if ($endIdx -lt 0) { throw "End marker '$($app.EndBeforeMarker)' not found" }

    $body = $content.Substring($idx + 1, $endIdx - $idx - 1).TrimEnd()
    $doc = "# $($app.Title)`n`n$($app.Intro)`n`n---`n`n$body`n"
    $outPath = Join-Path $DocsDir $app.OutFile
    [IO.File]::WriteAllText($outPath, $doc, $utf8)
    Write-Host "Extracted '$($app.StartMarker)' -> docs/$($app.OutFile) ($((Get-Content $outPath).Length) lines)"

    # Replace with short redirect.
    $redirect = "$($app.StartMarker)`n`nMoved to [docs/$($app.OutFile)](docs/$($app.OutFile)) to keep this README focused on the runbook.`n"
    $content = $content.Substring(0, $idx + 1) + $redirect + $content.Substring($endIdx + 1)
}

[IO.File]::WriteAllText($ReadmePath, $content, $utf8)
Write-Host "Pipeline README trimmed to $((Get-Content $ReadmePath).Length) lines"
