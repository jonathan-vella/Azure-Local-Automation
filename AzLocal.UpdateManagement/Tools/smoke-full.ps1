$outFile = "$env:TEMP\pester-full.txt"
Remove-Item $outFile -ErrorAction SilentlyContinue
Get-Module AzLocal.UpdateManagement -All | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\..\AzLocal.UpdateManagement.psd1" -Force
$config = New-PesterConfiguration
$config.Run.Path = "$PSScriptRoot\..\Tests\AzLocal.UpdateManagement.Tests.ps1"
$config.Output.Verbosity = 'None'
$config.Run.PassThru = $true
$r = Invoke-Pester -Configuration $config 6>$null
"Passed=$($r.PassedCount) Failed=$($r.FailedCount) Skipped=$($r.SkippedCount) Duration=$($r.Duration)" | Out-File $outFile
$r.Failed | ForEach-Object { "FAIL: $($_.ExpandedPath) :: $($_.ErrorRecord.Exception.Message)" } | Out-File $outFile -Append
Get-Content $outFile
