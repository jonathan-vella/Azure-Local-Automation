# Test the existing Get-AzLocalUpdateRunFailures cmdlet (uses
# Invoke-AzResourceGraphQuery which handles multi-line KQL via a temp file).
# Goal: confirm the cmdlet returns Failed rows with ClusterName, UpdateName,
# State, DeepestStepName, DeepestErrMsg, then identify which extra fleet-scale
# failure-detail columns we still need to add (Status, PortalLink, FormattedDuration,
# LastUpdated rendered as 'CurrentStep' label).
$ErrorActionPreference = 'Stop'

Import-Module 'C:\Users\nebird\Repos\Azure-Local\AzLocal.UpdateManagement\AzLocal.UpdateManagement.psd1' -Force

Write-Host "=== Detail view, Failed state, last 60 days ===" -ForegroundColor Cyan
$rows = Get-AzLocalUpdateRunFailures -State Failed -Since (Get-Date).AddDays(-60)
Write-Host ("Rows: {0}" -f $rows.Count) -ForegroundColor Yellow
Write-Host ""
Write-Host "Columns currently emitted:" -ForegroundColor Cyan
$rows[0].PSObject.Properties.Name | Sort-Object | Format-Wide -Column 4 | Out-String | Write-Host
Write-Host ""
Write-Host "First 6 rows summary (existing cmdlet output):" -ForegroundColor Cyan
$rows | Select-Object -First 6 ClusterName, UpdateName, State, DeepestStepName, ErrorCategory, DurationMinutes | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
Write-Host ""
Write-Host "First row DeepestErrMsg (truncated 600 chars):" -ForegroundColor Cyan
$first = $rows[0]
if ($first.DeepestErrMsg) {
    $msg = $first.DeepestErrMsg
    if ($msg.Length -gt 600) { Write-Host ($msg.Substring(0,600) + ' ... (truncated)') } else { Write-Host $msg }
} else { Write-Host '(empty)' }
Write-Host ""
Write-Host "First row PSObject dump (relevant cols):" -ForegroundColor Cyan
$first | Select-Object ClusterName, UpdateName, RunId, State, StartTime, EndTime, DurationMinutes, DeepestStepDepth, DeepestStepName, ErrorCategory, ClusterResourceId | Format-List | Out-String -Width 200 | Write-Host
