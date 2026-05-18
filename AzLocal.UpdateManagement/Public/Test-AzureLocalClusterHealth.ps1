function Test-AzureLocalClusterHealth {
    <#
    .SYNOPSIS
        Validates cluster health before applying updates by checking for blocking health check failures.
    
    .DESCRIPTION
        Queries the health check results from each cluster's update summary to identify
        Critical, Warning, and Informational failures. Critical failures block updates
        from being applied.
        
        This function can be used as a standalone pre-flight check or is called
        automatically by Start-AzureLocalClusterUpdate before applying updates.
        
        Health check data is stored in ARM on the cluster's updateSummaries resource
        and is refreshed approximately every 24 hours.
    
    .PARAMETER ClusterResourceIds
        An array of full Azure Resource IDs for the clusters to check.
    
    .PARAMETER ClusterNames
        An array of Azure Local cluster names to check.
    
    .PARAMETER ScopeByUpdateRingTag
        Find clusters by their 'UpdateRing' tag value via Azure Resource Graph.
    
    .PARAMETER UpdateRingValue
        The value of the 'UpdateRing' tag to match when using -ScopeByUpdateRingTag.
    
    .PARAMETER ResourceGroupName
        Resource group containing the clusters (only used with -ClusterNames).
    
    .PARAMETER SubscriptionId
        Azure subscription ID (defaults to current subscription).
    
    .PARAMETER BlockingOnly
        Show only Critical severity failures (the ones that block updates).
    
    .PARAMETER ApiVersion
        Azure REST API version to use. Default: "2025-10-01".
    
    .PARAMETER ExportPath
        Export results to CSV (.csv), JSON (.json), or JUnit XML (.xml) file.
    
    .PARAMETER ExportFormat
        Explicit format to use when writing -ExportPath. One of: Auto, Csv, Json, JUnitXml.
        Default: Auto (resolved from the file extension of -ExportPath; unknown extensions fall back to Csv).
        Use this to write a specific format regardless of extension (e.g. a JUnit XML file with a .xml name but CI-picked parser).
    
    .PARAMETER UpdateSummary
        Pre-fetched update summary object from Get-AzureLocalUpdateSummary.
        When provided, skips the internal summary fetch to avoid redundant API calls.
        Only used when checking a single cluster via -ClusterResourceIds with one ID.
    
    .OUTPUTS
        PSCustomObject[] - Array of health check results per cluster.
    
    .EXAMPLE
        Test-AzureLocalClusterHealth -ClusterResourceIds @("/subscriptions/.../clusters/Seattle")
        Checks health for a single cluster by resource ID.
    
    .EXAMPLE
        Test-AzureLocalClusterHealth -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -BlockingOnly
        Shows only Critical (update-blocking) health failures for all Wave1 clusters.
    
    .EXAMPLE
        Test-AzureLocalClusterHealth -ClusterNames "MyCluster" -ExportPath "C:\Reports\health.csv"
        Checks health and exports results to CSV.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByResourceId')]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceId')]
        [string[]]$ClusterResourceIds,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string[]]$ClusterNames,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [switch]$ScopeByUpdateRingTag,

        [ValidatePattern('^(\*\*\*|[A-Za-z0-9_-]{1,64}(;[A-Za-z0-9_-]{1,64})*)$')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [string]$UpdateRingValue,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [switch]$BlockingOnly,

        [Parameter(Mandatory = $false)]
        [string]$ApiVersion = $script:DefaultApiVersion,

        [Parameter(Mandatory = $false)]
        [string]$ExportPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Auto', 'Csv', 'Json', 'JUnitXml')]
        [string]$ExportFormat = 'Auto',

        [Parameter(Mandatory = $false)]
        [object]$UpdateSummary,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 16)]
        [int]$ThrottleLimit = 1
    )

    # Pre-flight: Validate export path is writable before expensive operations
    if ($ExportPath) {
        try { Test-ExportPathWritable -Path $ExportPath | Out-Null }
        catch { Write-Warning $_.Exception.Message; return }
    }

    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Azure Local Cluster Health Validation" -Level Header
    Write-Log -Message "========================================" -Level Header

    # Verify Azure CLI
    Test-AzCliAvailable | Out-Null
    try {
        $null = az account show 2>$null
        if ($LASTEXITCODE -ne 0) { throw "Not logged in" }
        Write-Log -Message "Azure CLI authentication verified" -Level Success
    }
    catch {
        Write-Log -Message "Azure CLI is not logged in. Please run 'az login' first." -Level Error
        return
    }

    # Build cluster list (reuse existing patterns)
    $clustersToCheck = @()

    if ($PSCmdlet.ParameterSetName -eq 'ByTag') {
        if (-not (Install-AzGraphExtension)) {
            Write-Error "Failed to install Azure CLI 'resource-graph' extension."
            return
        }
        $ringFilter = ConvertTo-AzLocalUpdateRingKqlFilter -UpdateRingValue $UpdateRingValue
        $argQuery = "resources | where type =~ 'microsoft.azurestackhci/clusters' $ringFilter | project id, name, resourceGroup, subscriptionId"
        try {
            $clusters = Invoke-AzResourceGraphQuery -Query $argQuery
        }
        catch {
            Write-Log -Message "Azure Resource Graph query failed: $($_.Exception.Message)" -Level Error
            return
        }
        if (-not $clusters -or $clusters.Count -eq 0) {
            Write-Log -Message "No clusters found with UpdateRing = '$UpdateRingValue'" -Level Warning
            return @()
        }
        foreach ($c in $clusters) {
            $clustersToCheck += @{ ResourceId = $c.id; Name = $c.name }
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'ByResourceId') {
        foreach ($rid in $ClusterResourceIds) {
            $clustersToCheck += @{ ResourceId = $rid; Name = ($rid -split '/')[-1] }
        }
    }
    else {
        # ByName - resolve names to resource IDs upfront to avoid per-cluster lookups
        if (-not $SubscriptionId) { $SubscriptionId = (az account show --query id -o tsv) }
        foreach ($name in $ClusterNames) {
            $clusterInfo = Get-AzureLocalClusterInfo -ClusterName $name `
                -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId -ApiVersion $ApiVersion
            if ($clusterInfo) {
                $clustersToCheck += @{ ResourceId = $clusterInfo.id; Name = $clusterInfo.name }
            }
            else {
                Write-Log -Message "Cluster '$name' not found - skipping" -Level Warning
            }
        }
    }

    Write-Log -Message "Checking health for $($clustersToCheck.Count) cluster(s)..." -Level Info

    $results = @()
    $overallPassed = $true

    # Parallel dispatch (v0.7.0+): when -ThrottleLimit > 1, shard clusters across background
    # jobs. Each job re-imports the module and calls this function recursively with
    # -ThrottleLimit 1 on its own subset. Skipped when the caller supplied a pre-fetched
    # $UpdateSummary (single-cluster fast-path) since batches need per-cluster fetches.
    if ($ThrottleLimit -gt 1 -and $clustersToCheck.Count -gt 1 -and -not $UpdateSummary) {
        Write-Log -Message "Dispatching to $ThrottleLimit parallel workers..." -Level Info
        $resourceIds = @($clustersToCheck | ForEach-Object { $_.ResourceId } | Where-Object { $_ })
        $jobScript = {
            param([object[]]$Batch, [string]$ApiVersionArg, [bool]$BlockingOnlyArg, [string]$ModulePath)
            Import-Module $ModulePath -Force
            if ($Batch.Count -eq 0) { return @() }
            $splat = @{ ClusterResourceIds = @($Batch); ApiVersion = $ApiVersionArg; ThrottleLimit = 1; PassThru = $true }
            if ($BlockingOnlyArg) { $splat['BlockingOnly'] = $true }
            Test-AzureLocalClusterHealth @splat
        }
        $batchResults = Invoke-FleetJobsInParallel `
            -InputItems $resourceIds `
            -ScriptBlock $jobScript `
            -ThrottleLimit $ThrottleLimit `
            -ArgumentList @($ApiVersion, [bool]$BlockingOnly) `
            -ActivityName 'ClusterHealth'
        foreach ($br in $batchResults) {
            if ($br.Failed) {
                Write-Log -Message "  Parallel batch $($br.BatchIndex) failed: $($br.Error)" -Level Error
                $overallPassed = $false
                continue
            }
            if ($br.Output) { $results += @($br.Output) }
        }
        if (-not (@($results | Where-Object { $_.Passed -eq $true }).Count -eq $results.Count)) {
            $overallPassed = $false
        }
    }
    else {

    foreach ($cluster in $clustersToCheck) {
        $clusterName = $cluster.Name
        Write-Host "  Checking: $clusterName..." -ForegroundColor Gray -NoNewline

        try {
            # Get resource ID if needed
            $resourceId = $cluster.ResourceId
            if (-not $resourceId) {
                $clusterInfo = Get-AzureLocalClusterInfo -ClusterName $clusterName `
                    -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId -ApiVersion $ApiVersion
                if ($clusterInfo) { $resourceId = $clusterInfo.id }
            }
            if (-not $resourceId) {
                Write-Host " Not Found" -ForegroundColor Red
                $results += [PSCustomObject]@{
                    ClusterName = $clusterName; HealthState = "Not Found"; Passed = $false
                    CriticalCount = 0; WarningCount = 0; Failures = @()
                }
                $overallPassed = $false
                continue
            }

            # Get update summary (contains healthCheckResult)
            # Use pre-fetched summary if provided, otherwise fetch from API
            $summary = $null
            if ($UpdateSummary -and $clustersToCheck.Count -eq 1) {
                $summary = $UpdateSummary
            }
            else {
                $summary = Get-AzureLocalUpdateSummary -ClusterResourceId $resourceId -ApiVersion $ApiVersion
            }
            if (-not $summary -or -not $summary.properties.healthCheckResult) {
                Write-Host " No Health Data" -ForegroundColor Yellow
                $results += [PSCustomObject]@{
                    ClusterName = $clusterName; HealthState = "No Data"; Passed = $true
                    CriticalCount = 0; WarningCount = 0; Failures = @()
                }
                continue
            }

            $healthState = if ($summary.properties.healthState) { $summary.properties.healthState } else { "Unknown" }
            $healthChecks = $summary.properties.healthCheckResult

            # Extract failures (Critical and Warning only; use -BlockingOnly for Critical only)
            $failures = @()
            foreach ($check in $healthChecks) {
                if ($check.status -eq "Failed") {
                    $sev = if ($check.severity) { $check.severity } else { "Unknown" }
                    if ($BlockingOnly -and $sev -ne "Critical") { continue }
                    if ($sev -eq "Informational") { continue }
                    $displayName = if ($check.displayName) { $check.displayName } elseif ($check.name) { ($check.name -split '/')[0] } else { "Unknown" }
                    $failures += [PSCustomObject]@{
                        ClusterName        = $clusterName
                        CheckName          = $displayName
                        Severity           = $sev
                        Description        = if ($check.description) { $check.description } else { "" }
                        Remediation        = if ($check.remediation) { $check.remediation } else { "" }
                        TargetResourceName = if ($check.targetResourceName) { $check.targetResourceName } else { "" }
                        Timestamp          = if ($check.timestamp) { $check.timestamp } else { "" }
                    }
                }
            }

            $critCount = @($failures | Where-Object { $_.Severity -eq "Critical" }).Count
            $warnCount = @($failures | Where-Object { $_.Severity -eq "Warning" }).Count
            $passed = ($critCount -eq 0)
            if (-not $passed) { $overallPassed = $false }

            # Console output
            if ($passed -and $failures.Count -eq 0) {
                Write-Host " Healthy" -ForegroundColor Green
            }
            elseif ($passed) {
                Write-Host " Warnings ($warnCount)" -ForegroundColor Yellow
            }
            else {
                Write-Host " BLOCKED ($critCount critical)" -ForegroundColor Red
            }

            $results += [PSCustomObject]@{
                ClusterName   = $clusterName
                HealthState   = $healthState
                Passed        = $passed
                CriticalCount = $critCount
                WarningCount  = $warnCount
                Failures      = $failures
            }
        }
        catch {
            Write-Host " Error: $($_.Exception.Message)" -ForegroundColor Red
            $results += [PSCustomObject]@{
                ClusterName = $clusterName; HealthState = "Error"; Passed = $false
                CriticalCount = 0; WarningCount = 0; Failures = @()
            }
            $overallPassed = $false
        }
    }
    } # end else (serial path)

    # Summary
    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Health Validation Summary" -Level Header
    Write-Log -Message "========================================" -Level Header

    $totalClusters = $results.Count
    $passedCount = @($results | Where-Object { $_.Passed -eq $true }).Count
    $failedCount = $totalClusters - $passedCount

    Write-Log -Message "Total Clusters:  $totalClusters" -Level Info
    Write-Log -Message "Passed:          $passedCount (no critical failures)" -Level $(if ($passedCount -eq $totalClusters) { "Success" } else { "Info" })
    Write-Log -Message "Blocked:         $failedCount (critical failures present)" -Level $(if ($failedCount -gt 0) { "Error" } else { "Info" })

    # Display failure details
    $allFailures = @($results | ForEach-Object { $_.Failures } | Where-Object { $_ })
    if ($allFailures.Count -gt 0) {
        Write-Log -Message "" -Level Info
        Write-Log -Message "Health Check Failures:" -Level Header
        $allFailures | Format-Table ClusterName, Severity, CheckName, TargetResourceName, Description -AutoSize -Wrap | Out-String -Stream | ForEach-Object {
            if ($_ -ne "") { Write-Log -Message $_ -Level Info }
        }

        # Show remediation for Critical failures
        $criticalFailures = @($allFailures | Where-Object { $_.Severity -eq "Critical" })
        if ($criticalFailures.Count -gt 0) {
            Write-Log -Message "" -Level Info
            Write-Log -Message "Remediation for Critical (Update-Blocking) Failures:" -Level Warning
            foreach ($f in $criticalFailures) {
                if ($f.Remediation) {
                    $nodeInfo = if ($f.TargetResourceName) { " ($($f.TargetResourceName))" } else { "" }
                    Write-Log -Message "  $($f.ClusterName) - $($f.CheckName)$nodeInfo`: $($f.Remediation)" -Level Warning
                }
            }
        }
    }
    else {
        Write-Log -Message "" -Level Info
        Write-Log -Message "No health check failures detected. All clusters are ready for updates." -Level Success
    }

    # Overall result
    Write-Log -Message "" -Level Info
    if ($overallPassed) {
        Write-Log -Message "HEALTH VALIDATION PASSED - All clusters are ready for updates" -Level Success
    }
    else {
        Write-Log -Message "HEALTH VALIDATION FAILED - Critical health issues must be resolved before updates can proceed" -Level Error
    }

    # Export if path specified
    if ($ExportPath -and $allFailures.Count -gt 0) {
        try {
            $ExportPath = Resolve-SafeOutputPath -Path $ExportPath
            $exportDir = Split-Path -Path $ExportPath -Parent
            if ($exportDir -and -not (Test-Path $exportDir)) {
                New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
            }
            # Resolve effective format: explicit -ExportFormat wins; 'Auto' falls back
            # to file-extension detection for backward compatibility.
            $effectiveFormat = $ExportFormat
            if ($effectiveFormat -eq 'Auto') {
                $extension = [System.IO.Path]::GetExtension($ExportPath).ToLower()
                $effectiveFormat = switch ($extension) {
                    '.csv'  { 'Csv' }
                    '.json' { 'Json' }
                    '.xml'  { 'JUnitXml' }
                    default { 'Csv' }
                }
            }
            switch ($effectiveFormat) {
                'Csv' {
                    $allFailures | ConvertTo-SafeCsvCollection | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
                    Write-Log -Message "Results exported to CSV: $ExportPath" -Level Success
                }
                'Json' {
                    $exportData = @{
                        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        OverallPassed = $overallPassed
                        TotalClusters = $totalClusters
                        Passed = $passedCount
                        Blocked = $failedCount
                        Failures = $allFailures
                    }
                    Write-Utf8NoBomFile -Path $ExportPath -Content ($exportData | ConvertTo-Json -Depth 10)
                    Write-Log -Message "Results exported to JSON: $ExportPath" -Level Success
                }
                'JUnitXml' {
                    $junitResults = $allFailures | ForEach-Object {
                        $junitNodeInfo = if ($_.TargetResourceName) { " (Node: $($_.TargetResourceName))" } else { "" }
                        [PSCustomObject]@{
                            ClusterName = $_.ClusterName; Status = "Failed"
                            Message = "$($_.Severity): $($_.CheckName)$junitNodeInfo - $($_.Description)"
                            UpdateName = $_.CheckName; CurrentState = $_.Severity
                        }
                    }
                    Export-ResultsToJUnitXml -Results $junitResults -OutputPath $ExportPath `
                        -TestSuiteName "AzureLocalClusterHealth" -OperationType "HealthCheck"
                    Write-Log -Message "Results exported to JUnit XML: $ExportPath" -Level Success
                }
            }
        }
        catch {
            Write-Log -Message "Failed to export results: $($_.Exception.Message)" -Level Error
        }
    }

    if ($PassThru) {
        return $results
    }
}
