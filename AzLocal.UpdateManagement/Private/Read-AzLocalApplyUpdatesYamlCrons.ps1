function Read-AzLocalApplyUpdatesYamlCrons {
    <#
    .SYNOPSIS
        Extracts cron schedule entries from apply-updates pipeline YAML files
        (GitHub Actions and Azure DevOps).
    .DESCRIPTION
        Pure regex pre-scan; deliberately does NOT take a dependency on
        powershell-yaml. Used by Test-AzureLocalApplyUpdatesScheduleCoverage.

        Discovery rules:
          - If Path is a file, scan that file.
          - If Path is a directory, recursively find files named 'apply-updates*.yml'
            or 'apply-updates*.yaml'.

        Platform is inferred from the parent directory name when the YAML is
        under .../github-actions/ or .../azure-devops/. Falls back to the
        Platform parameter when path-based inference is inconclusive.

        Parsing rules:
          - GitHub Actions:   lines matching   '- cron: "<expr>"'  or  "- cron: '<expr>'"
                              under a `schedule:` map.
          - Azure DevOps:     `cron:` keys inside a `schedules:` list. Same regex
                              works because cron lines look identical.
        Cron expressions wrapped in single or double quotes are both accepted.
    .PARAMETER Path
        File or directory to scan.
    .PARAMETER Platform
        Default platform tag when path inference is inconclusive. One of
        'GitHubActions', 'AzureDevOps', or 'Unknown'.
    .OUTPUTS
        PSCustomObject[] - one per discovered cron, with:
            File           - full path
            RelativePath   - path relative to Path (or basename if Path is a file)
            Platform       - 'GitHubActions' | 'AzureDevOps' | 'Unknown'
            CronExpression - the cron string (quotes stripped)
            LineNumber     - 1-based line in the source file
    .EXAMPLE
        Read-AzLocalApplyUpdatesYamlCrons -Path .\Automation-Pipeline-Examples
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [ValidateSet('GitHubActions', 'AzureDevOps', 'Unknown')]
        [string]$Platform = 'Unknown'
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Path not found: $Path"
    }

    $item = Get-Item -LiteralPath $Path
    $files = if ($item.PSIsContainer) {
        @(Get-ChildItem -LiteralPath $Path -Recurse -File -Include @('apply-updates*.yml', 'apply-updates*.yaml') -ErrorAction SilentlyContinue)
    }
    else {
        @($item)
    }

    $output = New-Object System.Collections.Generic.List[PSCustomObject]
    foreach ($f in $files) {
        $inferred = $Platform
        if ($f.FullName -match '[\\/]github-actions[\\/]') { $inferred = 'GitHubActions' }
        elseif ($f.FullName -match '[\\/]azure-devops[\\/]') { $inferred = 'AzureDevOps' }

        $relative = if ($item.PSIsContainer) {
            $f.FullName.Substring($item.FullName.Length).TrimStart('\','/')
        } else { $f.Name }

        $lineNum = 0
        $lines = Get-Content -LiteralPath $f.FullName -ErrorAction Stop
        foreach ($line in $lines) {
            $lineNum++
            # Match cron lines in both quote styles. Allow leading dash + space for
            # list-style entries (- cron: '...') and bare key style (cron: '...').
            if ($line -match "^\s*-?\s*cron\s*:\s*['""]([^'""]+)['""]") {
                $expr = $matches[1].Trim()
                $output.Add([PSCustomObject]@{
                    File           = $f.FullName
                    RelativePath   = $relative
                    Platform       = $inferred
                    CronExpression = $expr
                    LineNumber     = $lineNum
                })
            }
        }
    }

    return , $output.ToArray()
}
