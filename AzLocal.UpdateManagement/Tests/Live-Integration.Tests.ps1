#Requires -Module Pester
<#
.SYNOPSIS
    Durable LIVE-AZURE integration tests for the AzLocal.UpdateManagement module.

.DESCRIPTION
    These tests run against the real AdaptiveCloudLab subscription
    (fbaf508b-cb61-4383-9cda-a42bfa0c7bc9) via the Azure CLI ARG transport
    used by Get-AzLocalFleetHealthOverview / Get-AzureLocalFleetHealthFailures /
    Get-AzureLocalUpdateRunFailures.

    All Describe blocks are tagged 'Live'. The default Invoke-Tests.ps1 entry
    point excludes this tag so the standard 565-test unit suite stays hermetic.
    To opt in:

        .\Tests\Invoke-Tests.ps1 -IncludeLive
        # or
        Invoke-Pester -Path .\Tests\Live-Integration.Tests.ps1 -Tag Live

    Each Describe additionally Skips itself when:
        - az CLI is not on PATH, OR
        - az is not logged in, OR
        - The signed-in subscription is not the expected AdaptiveCloudLab id.

    These guards mean the suite is safe to leave permanently in the repo and
    safe to run on any developer machine - it auto-skips when the live
    pre-conditions aren't met.

    The expected subscription id is hard-coded (not a secret - a subscription
    id alone is not a credential; an RBAC grant on the signed-in identity is
    what makes it actionable).

    Implementation notes:
    - Every It block calls the cmdlet directly. Pester 5 BeforeAll-scope
      variables do not reliably preserve array-of-PSCustomObject semantics
      inside It blocks (one full ARG round-trip per It is cheap enough).
    - Get-AzLocalFleetHealthOverview and Get-AzureLocalFleetHealthFailures
      return their result with the `return , $output` idiom to preserve
      array-ness across the cmdlet boundary. The downside is that wrapping
      the call in `@(...)` produces a single-element array containing the
      inner array. Tests therefore use the `@() + (cmdlet ...)` normalizer
      which works for all three return-shape patterns (zero, scalar, array,
      , $output-array) without double-wrapping.

.NOTES
    Author:   Neil Bird, Microsoft.
    Added:    v0.7.70
    Module:   AzLocal.UpdateManagement
    Run with: Invoke-Pester -Path .\Tests\Live-Integration.Tests.ps1 -Tag Live -Output Detailed
#>

BeforeDiscovery {
    # Expected live subscription. AdaptiveCloudLab tenant - 20 clusters under
    # management as of v0.7.70. Hard-coded in the repo source because (a) a
    # subscription id alone is not a credential and (b) it makes the durable
    # safety gate "are we pointed at the right tenant?" trivially auditable.
    $ExpectedSubscriptionId = 'fbaf508b-cb61-4383-9cda-a42bfa0c7bc9'

    # Probe the environment ONCE so each Describe -Skip decision is consistent.
    $LiveGateReason = $null
    try {
        $azCmd = Get-Command az -ErrorAction Stop
        $null = $azCmd
    } catch {
        $LiveGateReason = 'az CLI is not available on PATH'
    }

    if (-not $LiveGateReason) {
        $accountJson = $null
        try {
            $accountJson = & az account show -o json 2>$null
        } catch {
            $LiveGateReason = "az account show threw: $($_.Exception.Message)"
        }
        if (-not $LiveGateReason -and $LASTEXITCODE -ne 0) {
            $LiveGateReason = "az is not logged in (az account show exit $LASTEXITCODE)"
        }
        if (-not $LiveGateReason -and -not $accountJson) {
            $LiveGateReason = 'az account show returned empty output'
        }
        if (-not $LiveGateReason) {
            try {
                $account = $accountJson | ConvertFrom-Json
                if ($account.id -ne $ExpectedSubscriptionId) {
                    $LiveGateReason = "az signed-in subscription is $($account.id) (name=$($account.name)); expected $ExpectedSubscriptionId. Run 'az account set --subscription $ExpectedSubscriptionId' to opt in."
                }
            } catch {
                $LiveGateReason = "Failed to parse az account show output: $($_.Exception.Message)"
            }
        }
    }

    $SkipLive = [bool]$LiveGateReason
}

BeforeAll {
    # Import the module under test.
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\AzLocal.UpdateManagement.psd1'
    Import-Module $modulePath -Force -ErrorAction Stop
    Write-Host "[Live-Integration] Module $(Get-Module AzLocal.UpdateManagement | Select-Object -ExpandProperty Version) loaded against subscription fbaf508b-cb61-4383-9cda-a42bfa0c7bc9." -ForegroundColor Cyan
}

AfterAll {
    Remove-Module AzLocal.UpdateManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Live-Integration: Authentication and ARG transport pre-conditions' -Tag 'Live' -Skip:$SkipLive {

    It 'az CLI is logged in and points at the expected subscription' {
        $expected = 'fbaf508b-cb61-4383-9cda-a42bfa0c7bc9'
        $account = & az account show -o json | ConvertFrom-Json
        $account.id | Should -Be $expected
    }

    It 'az graph subcommand is reachable (Invoke-AzResourceGraphQuery transport pre-req)' {
        $help = & az graph --help 2>&1 | Out-String
        $help | Should -Match 'query' -Because '`az graph query` must be reachable for ARG transport to work'
    }

    It 'Resource Graph is reachable: at least one Azure Local cluster is visible to the signed-in identity' {
        $kql = "resources | where type =~ 'microsoft.azurestackhci/clusters' | summarize count()"
        $resp = & az graph query -q $kql --first 1 -o json | ConvertFrom-Json
        $count = 0
        if ($resp -is [System.Collections.IEnumerable] -and -not ($resp -is [string])) {
            $count = $resp[0].count_
        } elseif ($resp.data) {
            $count = $resp.data[0].count_
        }
        $count | Should -BeGreaterThan 0 -Because 'Live tests require at least one cluster in the signed-in subscription'
    }
}

Describe 'Live-Integration: Get-AzLocalFleetHealthOverview' -Tag 'Live' -Skip:$SkipLive {

    It 'Returns at least one cluster row' {
        $rows = @() + (Get-AzLocalFleetHealthOverview -PassThru -ErrorAction Stop)
        $rows.Count | Should -BeGreaterThan 0
    }

    It 'Every row exposes the v0.7.70 ARG-first projection columns' {
        $expected = @(
            'ClusterName'
            'ClusterPortalUrl'
            'HealthStatus'
            'UpdateStatus'
            'CurrentVersion'
            'SbeVersion'
            'AzureConnection'
            'LastChecked'
            'HealthResultsAgeDays'
        )
        $rows = @() + (Get-AzLocalFleetHealthOverview -PassThru -ErrorAction Stop)
        foreach ($row in $rows) {
            $present = @($row.PSObject.Properties.Name)
            $missing = @($expected | Where-Object { $present -notcontains $_ })
            $missing | Should -BeNullOrEmpty -Because "row for $($row.ClusterName) must expose every v0.7.70 column"
        }
    }

    It 'ClusterPortalUrl points at https://portal.azure.com/#@/resource/...' {
        $rows = @() + (Get-AzLocalFleetHealthOverview -PassThru -ErrorAction Stop)
        foreach ($row in $rows) {
            if ([string]::IsNullOrEmpty($row.ClusterPortalUrl)) { continue }
            $row.ClusterPortalUrl | Should -Match '^https://portal\.azure\.com/#@/resource/' -Because "ClusterPortalUrl on $($row.ClusterName) must be a portal deep-link"
        }
    }

    It 'HealthResultsAgeDays is either null or a non-negative integer' {
        $rows = @() + (Get-AzLocalFleetHealthOverview -PassThru -ErrorAction Stop)
        foreach ($row in $rows) {
            if ($null -eq $row.HealthResultsAgeDays) { continue }
            [int]$row.HealthResultsAgeDays | Should -BeGreaterOrEqual 0
        }
    }

    It 'AzureConnection is one of the documented connectivity-status values' {
        $allowed = @('Connected', 'Disconnected', 'NotYetRegistered', 'NotSpecified', 'PartiallyConnected', '', $null)
        $rows = @() + (Get-AzLocalFleetHealthOverview -PassThru -ErrorAction Stop)
        foreach ($row in $rows) {
            $row.AzureConnection | Should -BeIn $allowed -Because "AzureConnection on $($row.ClusterName) must be one of the documented Azure Arc connectivity-status enum values"
        }
    }
}

Describe 'Live-Integration: Get-AzureLocalFleetHealthFailures' -Tag 'Live' -Skip:$SkipLive {

    It 'Detail view returns rows (fleet has known unresolved failures)' {
        $detail = @() + (Get-AzureLocalFleetHealthFailures -View Detail -PassThru -ErrorAction Stop)
        $detail.Count | Should -BeGreaterThan 0
    }

    It 'Detail rows expose the documented v0.7.70 columns' {
        $expected = @('ClusterName', 'ClusterPortalUrl', 'Severity', 'FailureReason', 'Description', 'Remediation')
        $detail = @() + (Get-AzureLocalFleetHealthFailures -View Detail -PassThru -ErrorAction Stop)
        $sample = if ($detail.Count -gt 5) { 5 } else { $detail.Count }
        for ($i = 0; $i -lt $sample; $i++) {
            $row = $detail[$i]
            $present = @($row.PSObject.Properties.Name)
            $missing = @($expected | Where-Object { $present -notcontains $_ })
            $missing | Should -BeNullOrEmpty -Because "detail row must include every v0.7.70 column"
        }
    }

    It 'Summary view rolls up by FailureReason x Severity' {
        $summary = @() + (Get-AzureLocalFleetHealthFailures -View Summary -PassThru -ErrorAction Stop)
        $summary.Count | Should -BeGreaterThan 0
        $first = $summary[0]
        $present = @($first.PSObject.Properties.Name)
        $present | Should -Contain 'FailureReason'
        $present | Should -Contain 'Severity'
        $present | Should -Contain 'ClusterCount'
        $present | Should -Contain 'FailureCount'
        $present | Should -Contain 'AffectedClusterPortalUrls'
    }

    It 'Severity=Critical filter returns only Critical rows' {
        $critical = @() + (Get-AzureLocalFleetHealthFailures -Severity Critical -View Detail -PassThru -ErrorAction Stop)
        foreach ($row in $critical) {
            $row.Severity | Should -Be 'Critical'
        }
    }
}

Describe 'Live-Integration: Get-AzureLocalUpdateRunFailures' -Tag 'Live' -Skip:$SkipLive {

    It 'Returns at least one Failed unresolved row (fleet has known unresolved runs)' {
        $rows = @() + (Get-AzureLocalUpdateRunFailures -State Failed -OnlyUnresolved -Since (Get-Date).ToUniversalTime().AddDays(-30) -ErrorAction Stop)
        $rows.Count | Should -BeGreaterThan 0
    }

    It 'Every row exposes the v0.7.70 update-history columns' {
        $expected = @(
            'ClusterName'
            'Status'
            'CurrentStep'
            'Duration'
            'LastUpdated'
            'UpdateRunPortalUrl'
            'DeepestErrMsg'
            'ErrorCategory'
        )
        $rows = @() + (Get-AzureLocalUpdateRunFailures -State Failed -OnlyUnresolved -Since (Get-Date).ToUniversalTime().AddDays(-30) -ErrorAction Stop)
        $sample = if ($rows.Count -gt 5) { 5 } else { $rows.Count }
        for ($i = 0; $i -lt $sample; $i++) {
            $row = $rows[$i]
            $present = @($row.PSObject.Properties.Name)
            $missing = @($expected | Where-Object { $present -notcontains $_ })
            $missing | Should -BeNullOrEmpty -Because "update-failure row must include every v0.7.70 column"
        }
    }

    It 'UpdateRunPortalUrl is a SingleInstanceHistoryDetails portal deep-link with an URL-encoded ClusterResourceId' {
        $rows = @() + (Get-AzureLocalUpdateRunFailures -State Failed -OnlyUnresolved -Since (Get-Date).ToUniversalTime().AddDays(-30) -ErrorAction Stop)
        foreach ($row in $rows) {
            if ([string]::IsNullOrEmpty($row.UpdateRunPortalUrl)) { continue }
            $row.UpdateRunPortalUrl | Should -Match 'SingleInstanceHistoryDetails' -Because "Step.6 testcases rely on this deep-link shape"
            $row.UpdateRunPortalUrl | Should -Match '%2Fsubscriptions%2F'        -Because "ClusterResourceId must be URL-encoded inside the ReactView fragment"
        }
    }

    It 'OnlyUnresolved limits results to Status != Succeeded' {
        $rows = @() + (Get-AzureLocalUpdateRunFailures -State Failed -OnlyUnresolved -Since (Get-Date).ToUniversalTime().AddDays(-30) -ErrorAction Stop)
        foreach ($row in $rows) {
            $row.Status | Should -Not -Be 'Succeeded' -Because '-OnlyUnresolved must exclude rows where the next attempt succeeded'
        }
    }
}
