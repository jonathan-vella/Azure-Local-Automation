# ---------------------------------------------------------------------------
# Smoke test for the Step.4 fleet-connectivity-status pipeline.
#
# v0.7.79: Step.4 was migrated from inline `az graph query` blocks to the
# module cmdlet `Get-AzLocalFleetConnectivityStatus`. This smoke test
# therefore validates THE CMDLET'S OUTPUT - which is exactly what the
# Step.4 GH/ADO pipelines now consume to render the per-cluster /
# per-node / per-NIC / per-ARB markdown tables in the job summary.
#
# History: The pre-v0.7.79 version of this script re-executed each KQL
# query directly via `az graph query -q $here-string`. On Windows PS 5.1
# the multi-line here-strings were silently truncated by az.cmd's CMD
# argument parser (everything after the first newline was dropped), so
# every query degraded to plain `resources | take 100` and the schema
# check FAILed against a column set that didn't exist in the truncated
# response. The cmdlet's internal helper (Invoke-AzResourceGraphQuery)
# normalises CR/LF to single spaces before calling az.cmd, so calling
# the cmdlet here both fixes the smoke test AND validates the real
# transport that Step.4 uses end to end.
#
# Sections validated (matches the 7 PSCustomObject properties returned
# by Get-AzLocalFleetConnectivityStatus -PassThru):
#   1. ClusterRows          - one row per HCI cluster
#   2. ArcSummary           - one row per distinct Arc agent status
#   3. NonConnectedMachines - one row per machine != Connected
#   4. NicIssues            - Physical NICs Disconnected with a non-APIPA IP
#   5. NicAll               - full unfiltered NIC inventory
#   6. NicStats             - NicType + NicStatus histogram
#   7. ArbRows              - one row per ARB appliance (multi-cluster-safe)
#
# Per section we emit PASS / PASS-EMPTY / FAIL-SCHEMA / ERROR and a
# final results table. Exit code is non-zero if any section FAILs or
# ERRORs so the script is safe to wire into a CI matrix.
#
# Requires: `az login`; signed-in identity has Reader on the target
# subscription(s). The cmdlet handles ARG pagination + retry/backoff.
# ---------------------------------------------------------------------------

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SubscriptionId,

    [Parameter()]
    [string]$ModulePath
)

$ErrorActionPreference = 'Stop'

# Resolve module path (default: parent of Tools folder).
if (-not $ModulePath) {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\AzLocal.UpdateManagement.psd1'
}
if (-not (Test-Path $ModulePath)) {
    throw "Module manifest not found at: $ModulePath"
}

Write-Host "Importing module: $ModulePath" -ForegroundColor Cyan
Get-Module AzLocal.UpdateManagement -All | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module $ModulePath -Force -ErrorAction Stop
$moduleVersion = (Get-Module AzLocal.UpdateManagement | Sort-Object Version -Descending | Select-Object -First 1).Version
Write-Host "Module version: $moduleVersion" -ForegroundColor Cyan

# Verify az is available and logged in (the cmdlet would also fail, but a
# clearer message here helps operators running the smoke test locally).
try {
    $null = Get-Command az -ErrorAction Stop
} catch {
    throw 'az CLI is not on PATH. Install Azure CLI and run `az login` before running this smoke test.'
}
$accountJson = & az account show -o json 2>$null
if ($LASTEXITCODE -ne 0 -or -not $accountJson) {
    throw 'az account show failed. Run `az login` and try again.'
}
$account = $accountJson | ConvertFrom-Json
Write-Host "Signed-in subscription: $($account.name) ($($account.id))" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Section definitions: expected required columns per output property.
# Pulled from the Get-AzLocalFleetConnectivityStatus cmdlet projections so
# any schema regression in the cmdlet is caught here (and in the matching
# Live-Integration.Tests.ps1 Describe block).
# ---------------------------------------------------------------------------
$sections = @(
    @{ Name = 'ClusterRows';          RequiredColumns = @('ClusterName','ClusterId','ConnectivityStatus','ClusterStatus','NodeCount','Location','ResourceGroup','SubscriptionId') }
    @{ Name = 'ArcSummary';           RequiredColumns = @('AgentStatus','Count') }
    @{ Name = 'NonConnectedMachines'; RequiredColumns = @('NodeName','MachineId','ClusterName','ClusterId','AgentStatus','OsSku','OsVersion','ClusterVersion','AgentVersion','LastStatusChange','ResourceGroup','SubscriptionId') }
    @{ Name = 'NicIssues';            RequiredColumns = @('NodeName','ClusterName','NicName','NicStatus','DriverVersion','Ip4Address','InterfaceDescription','MachineId','ResourceGroup','SubscriptionId') }
    @{ Name = 'NicAll';               RequiredColumns = @('NodeName','MachineId','ClusterName','ClusterId','MachineConnectivity','NicName','NicType','NicStatus','DriverVersion','InterfaceDescription','Ip4Address','SubnetMask','DefaultGateway','DnsServers','MacAddress','ResourceGroup','SubscriptionId') }
    @{ Name = 'NicStats';             RequiredColumns = @('NicType','NicStatus','Count') }
    @{ Name = 'ArbRows';              RequiredColumns = @('ArbName','ArbStatus','ClusterName','ClusterId','ClusterStatus','LastModified','DaysSinceLastModified','ArbId','ResourceGroup','SubscriptionId') }
)

# ---------------------------------------------------------------------------
# Run the cmdlet ONCE - this is the same call path Step.4 uses.
# ---------------------------------------------------------------------------
$invokeParams = @{ PassThru = $true }
if ($SubscriptionId) { $invokeParams.SubscriptionId = $SubscriptionId }

Write-Host "`nInvoking Get-AzLocalFleetConnectivityStatus ..." -ForegroundColor Cyan
$cmdletStart = Get-Date
try {
    $data = Get-AzLocalFleetConnectivityStatus @invokeParams
} catch {
    Write-Host "Cmdlet threw: $($_.Exception.Message)" -ForegroundColor Red
    throw
}
$cmdletDuration = (Get-Date) - $cmdletStart
Write-Host "Cmdlet completed in $([math]::Round($cmdletDuration.TotalSeconds,2))s" -ForegroundColor Yellow

if ($null -eq $data) {
    throw 'Get-AzLocalFleetConnectivityStatus returned $null - cannot validate sections.'
}

# ---------------------------------------------------------------------------
# Validate each section.
# ---------------------------------------------------------------------------
$results = [System.Collections.Generic.List[object]]::new()

foreach ($section in $sections) {
    $name = $section.Name
    $required = $section.RequiredColumns

    Write-Host "`n=== $name ===" -ForegroundColor Cyan

    if (-not $data.PSObject.Properties.Name -contains $name) {
        Write-Host "ERROR: property '$name' is missing from cmdlet output" -ForegroundColor Red
        $results.Add([PSCustomObject]@{ Section=$name; Status='ERROR'; Rows=0; Missing=''; Error="Property '$name' missing" })
        continue
    }

    $rows = @($data.$name)
    $rowCount = $rows.Count
    Write-Host "Returned $rowCount row(s)" -ForegroundColor Yellow

    if ($rowCount -eq 0) {
        Write-Host "PASS-EMPTY (property present, no rows - acceptable for $name)" -ForegroundColor DarkYellow
        $results.Add([PSCustomObject]@{ Section=$name; Status='PASS-EMPTY'; Rows=0; Missing=''; Error='' })
        continue
    }

    $firstRow = $rows[0]
    $cols = $firstRow.PSObject.Properties.Name
    $missing = @($required | Where-Object { $cols -notcontains $_ })

    if ($missing.Count -eq 0) {
        Write-Host "PASS - all required columns present ($($required.Count))" -ForegroundColor Green
        $results.Add([PSCustomObject]@{ Section=$name; Status='PASS'; Rows=$rowCount; Missing=''; Error='' })
    } else {
        Write-Host "FAIL-SCHEMA - missing: $($missing -join ', ')" -ForegroundColor Red
        Write-Host "  Actual columns: $($cols -join ', ')" -ForegroundColor DarkGray
        $results.Add([PSCustomObject]@{ Section=$name; Status='FAIL-SCHEMA'; Rows=$rowCount; Missing=($missing -join ','); Error='' })
    }
}

# ---------------------------------------------------------------------------
# Extra invariants: catch the v0.7.79 client-side-grouping regression.
# If ArcSummary row count == sum of all Count values, that means the cmdlet
# is emitting raw machine rows instead of grouping by AgentStatus (the bug
# fixed in v0.7.79 commit 5b76e2f).
# ---------------------------------------------------------------------------
if ($data.PSObject.Properties.Name -contains 'ArcSummary') {
    $arc = @($data.ArcSummary)
    if ($arc.Count -gt 0) {
        $totalMachines = ($arc | Measure-Object -Property Count -Sum).Sum
        Write-Host "`n=== Invariant: ArcSummary grouped client-side ===" -ForegroundColor Cyan
        Write-Host "ArcSummary distinct AgentStatus values: $($arc.Count)  total machines: $totalMachines" -ForegroundColor Yellow
        if ($arc.Count -ge $totalMachines) {
            Write-Host "FAIL - ArcSummary appears NOT grouped (rows >= total machines)" -ForegroundColor Red
            $results.Add([PSCustomObject]@{ Section='ArcSummary-Grouped'; Status='FAIL-SCHEMA'; Rows=$arc.Count; Missing='grouping-invariant'; Error="rows ($($arc.Count)) >= totalMachines ($totalMachines)" })
        } else {
            Write-Host "PASS - ArcSummary is grouped (rows < total machines)" -ForegroundColor Green
            $results.Add([PSCustomObject]@{ Section='ArcSummary-Grouped'; Status='PASS'; Rows=$arc.Count; Missing=''; Error='' })
        }
    }
}

# ---------------------------------------------------------------------------
# Final report.
# ---------------------------------------------------------------------------
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Smoke Test Results - Get-AzLocalFleetConnectivityStatus" -ForegroundColor Cyan
Write-Host "Module version: $moduleVersion" -ForegroundColor Cyan
Write-Host "Subscription: $($account.name) ($($account.id))" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
$results | Format-Table -AutoSize Section, Status, Rows, Missing, Error

$fail = @($results | Where-Object { $_.Status -in @('FAIL-SCHEMA','ERROR') })
if ($fail.Count -gt 0) {
    Write-Host "FAILED: $($fail.Count) section(s) did not pass." -ForegroundColor Red
    exit 1
} else {
    Write-Host "All sections passed." -ForegroundColor Green
    exit 0
}
