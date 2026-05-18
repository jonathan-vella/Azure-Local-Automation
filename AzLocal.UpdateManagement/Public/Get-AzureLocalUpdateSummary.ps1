function Get-AzureLocalUpdateSummary {
    <#
    .SYNOPSIS
        Gets the update summary for one or more Azure Local clusters.
    .DESCRIPTION
        Retrieves the update summary for Azure Local (Azure Stack HCI) clusters.
        The summary includes the current update state, available updates count,
        health check results, and other update-related status information.
        
        Supports multiple input methods:
        - Single cluster by resource ID (original behavior, returns raw API object)
        - Multiple clusters by name or resource ID
        - All clusters matching an UpdateRing tag value
        
        When querying multiple clusters, returns formatted results with export options.
    .PARAMETER ClusterResourceId
        The full Azure Resource ID of a single cluster (original behavior).
        Example: "/subscriptions/xxx/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01"
    .PARAMETER ClusterNames
        An array of Azure Local cluster names to query.
    .PARAMETER ClusterResourceIds
        An array of full Azure Resource IDs for the clusters to query.
    .PARAMETER ScopeByUpdateRingTag
        When specified, finds clusters by the 'UpdateRing' tag via Azure Resource Graph.
        Must be used together with -UpdateRingValue.
    .PARAMETER UpdateRingValue
        The value of the 'UpdateRing' tag to match when using -ScopeByUpdateRingTag.
    .PARAMETER ResourceGroupName
        The resource group containing the clusters (only used with -ClusterNames).
    .PARAMETER SubscriptionId
        The Azure subscription ID. If not specified, uses the current az CLI subscription.
    .PARAMETER ApiVersion
        The Azure REST API version to use. Default is the module's default API version.
    .PARAMETER ExportPath
        Path to export the results. Supports .csv, .json, and .xml (JUnit format) extensions.
    .OUTPUTS
        PSCustomObject - Single update summary when using -ClusterResourceId
        PSCustomObject[] - Array of formatted summaries when using multi-cluster parameters
    .EXAMPLE
        # Single cluster (original behavior)
        $summary = Get-AzureLocalUpdateSummary -ClusterResourceId $cluster.id
        Write-Host "Update State: $($summary.properties.state)"
    .EXAMPLE
        # Multiple clusters by tag
        Get-AzureLocalUpdateSummary -ScopeByUpdateRingTag -UpdateRingValue "Wave1"
    .EXAMPLE
        # Export to CSV
        Get-AzureLocalUpdateSummary -ScopeByUpdateRingTag -UpdateRingValue "Production" -ExportPath "C:\Reports\summaries.csv"
    #>
    [CmdletBinding(DefaultParameterSetName = 'SingleCluster')]
    [OutputType([PSCustomObject], [PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'SingleCluster')]
        [string]$ClusterResourceId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string[]]$ClusterNames,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceId')]
        [string[]]$ClusterResourceIds,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [switch]$ScopeByUpdateRingTag,

        [ValidatePattern('^(\*\*\*|[A-Za-z0-9_-]{1,64}(;[A-Za-z0-9_-]{1,64})*)$')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [string]$UpdateRingValue,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByResourceId')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByTag')]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [string]$ApiVersion = $script:DefaultApiVersion,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByResourceId')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByTag')]
        [string]$ExportPath,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByResourceId')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByTag')]
        [ValidateSet('Auto', 'Csv', 'Json', 'JUnitXml')]
        [string]$ExportFormat = 'Auto',

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByResourceId')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByTag')]
        [ValidateRange(1, 32)]
        [int]$ThrottleLimit = 1,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    # Pre-flight: Validate export path is writable before expensive operations
    if ($ExportPath) {
        try { Test-ExportPathWritable -Path $ExportPath | Out-Null }
        catch { Write-Warning $_.Exception.Message; return }
    }

    # Original single-cluster behavior
    if ($PSCmdlet.ParameterSetName -eq 'SingleCluster') {
        Test-AzCliAvailable | Out-Null
        $uri = "https://management.azure.com$ClusterResourceId/updateSummaries/default?api-version=$ApiVersion"
        
        Write-Verbose "Getting update summary from: $uri"
        
        $result = (Invoke-AzRestJson -Uri $uri).Data
        if ($LASTEXITCODE -eq 0) {
            return $result
        }
        return $null
    }

    # Multi-cluster mode
    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Azure Local Cluster Update Summaries" -Level Header
    Write-Log -Message "========================================" -Level Header

    # Verify Azure CLI is installed and logged in
    Test-AzCliAvailable | Out-Null
    try {
        $null = az account show 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Azure CLI is not logged in. Please run 'az login' first."
        }
        Write-Log -Message "Azure CLI authentication verified" -Level Success
    }
    catch {
        Write-Log -Message "Azure CLI is not logged in. Please run 'az login' first." -Level Error
        return
    }

    # Build list of clusters to process
    $clustersToProcess = @()
    
    if ($PSCmdlet.ParameterSetName -eq 'ByTag') {
        if (-not (Install-AzGraphExtension)) {
            Write-Error "Failed to install Azure CLI 'resource-graph' extension."
            return
        }
        
        Write-Log -Message "Querying Azure Resource Graph for clusters with tag 'UpdateRing' = '$UpdateRingValue'..." -Level Info
        
        $ringFilter = ConvertTo-AzLocalUpdateRingKqlFilter -UpdateRingValue $UpdateRingValue
        $argQuery = "resources | where type =~ 'microsoft.azurestackhci/clusters' $ringFilter | project id, name, resourceGroup, subscriptionId, tags"
        
        try {
            $clusterRows = Invoke-AzResourceGraphQuery -Query $argQuery

            if (-not $clusterRows -or $clusterRows.Count -eq 0) {
                Write-Log -Message "No clusters found with tag 'UpdateRing' = '$UpdateRingValue'" -Level Warning
                return @()
            }
            
            Write-Log -Message "Found $($clusterRows.Count) cluster(s) matching tag criteria" -Level Success
            foreach ($cluster in $clusterRows) {
                $clustersToProcess += @{ 
                    ResourceId = $cluster.id
                    Name = $cluster.name 
                    ResourceGroup = $cluster.resourceGroup
                    SubscriptionId = $cluster.subscriptionId
                }
            }
        }
        catch {
            Write-Log -Message "Error querying Azure Resource Graph: $_" -Level Error
            return
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'ByResourceId') {
        foreach ($resourceId in $ClusterResourceIds) {
            $clusterRgName = ($resourceId -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
            $clusterSubId = ($resourceId -split '/subscriptions/')[1] -split '/' | Select-Object -First 1
            $clustersToProcess += @{ 
                ResourceId = $resourceId
                Name = ($resourceId -split '/')[-1]
                ResourceGroup = $clusterRgName
                SubscriptionId = $clusterSubId
            }
        }
    }
    else {
        # ByName - resolve names to resource IDs upfront to avoid per-cluster lookups
        if (-not $SubscriptionId) {
            $SubscriptionId = (az account show --query id -o tsv)
        }
        foreach ($name in $ClusterNames) {
            $clusterInfo = Get-AzureLocalClusterInfo -ClusterName $name `
                -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId -ApiVersion $ApiVersion
            if ($clusterInfo) {
                $clustersToProcess += @{ 
                    ResourceId = $clusterInfo.id
                    Name = $clusterInfo.name
                    ResourceGroup = ($clusterInfo.id -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
                    SubscriptionId = ($clusterInfo.id -split '/subscriptions/')[1] -split '/' | Select-Object -First 1
                }
            }
            else {
                Write-Log -Message "Cluster '$name' not found - skipping" -Level Warning
            }
        }
    }

    Write-Log -Message "" -Level Info
    Write-Log -Message "Querying update summaries for $($clustersToProcess.Count) cluster(s)..." -Level Info

    # Per-cluster scriptblock - runs inline (ThrottleLimit=1) or inside
    # Start-Job (ThrottleLimit>1). Returns an array of PSCustomObject rows.
    # Note: Write-Host lives in the parent process after aggregation so
    # coloured terminal output is deterministic regardless of job ordering.
    # Private helpers (Invoke-AzRestJson) are filtered out by Export-ModuleMember,
    # so in a child Start-Job runspace they are NOT visible at script scope after
    # Import-Module. We resolve the module reference and call private helpers via
    # & $mod { ... } so they execute against the module's own session state. The
    # inline path picks up the already-loaded module via Get-Module.
    $summaryJob = {
        param(
            [object[]]$Shard,
            [string]$ApiVer,
            [string]$ModulePath
        )
        $mod = Get-Module -Name AzLocal.UpdateManagement | Select-Object -First 1
        if (-not $mod) {
            $mod = Import-Module $ModulePath -Force -PassThru -ErrorAction Stop
        }
        $shardRows = foreach ($cluster in $Shard) {
            $clusterName = $cluster.Name
            try {
                $resourceId = $cluster.ResourceId
                if (-not $resourceId) {
                    $clusterInfo = Get-AzureLocalClusterInfo -ClusterName $clusterName `
                        -ResourceGroupName $cluster.ResourceGroup `
                        -SubscriptionId $cluster.SubscriptionId `
                        -ApiVersion $ApiVer
                    if ($clusterInfo) { $resourceId = $clusterInfo.id }
                }

                if (-not $resourceId) {
                    [PSCustomObject]@{
                        ClusterName           = $clusterName
                        ResourceGroup         = $cluster.ResourceGroup
                        SubscriptionId        = $cluster.SubscriptionId
                        UpdateState           = 'Not Found'
                        HealthState           = 'N/A'
                        CurrentVersion        = ''
                        LastUpdated           = ''
                        LastChecked           = ''
                        AvailableUpdatesCount = 0
                        __DisplayTag          = 'NotFound'
                    }
                    continue
                }

                $uri = "https://management.azure.com$resourceId/updateSummaries/default?api-version=$ApiVer"
                $summary = (& $mod {
                        param($u)
                        Invoke-AzRestJson -Uri $u
                    } $uri).Data

                if ($LASTEXITCODE -eq 0 -and $summary) {
                    $props = $summary.properties
                    $state = if ($props.state) { $props.state } else { 'Unknown' }
                    $healthState = if ($props.healthState) { $props.healthState } else { 'Unknown' }
                    [PSCustomObject]@{
                        ClusterName           = $clusterName
                        ResourceGroup         = $cluster.ResourceGroup
                        SubscriptionId        = $cluster.SubscriptionId
                        UpdateState           = $state
                        HealthState           = $healthState
                        CurrentVersion        = if ($props.currentVersion) { $props.currentVersion } else { '' }
                        LastUpdated           = if ($props.lastUpdatedTime) { ([datetime]$props.lastUpdatedTime).ToString('yyyy-MM-dd HH:mm') } else { '' }
                        LastChecked           = if ($props.lastCheckedTime) { ([datetime]$props.lastCheckedTime).ToString('yyyy-MM-dd HH:mm') } else { '' }
                        AvailableUpdatesCount = if ($props.updateStateProperties -and $props.updateStateProperties.availableUpdates) { $props.updateStateProperties.availableUpdates } else { 0 }
                        __DisplayTag          = 'Summary'
                    }
                }
                else {
                    [PSCustomObject]@{
                        ClusterName           = $clusterName
                        ResourceGroup         = $cluster.ResourceGroup
                        SubscriptionId        = $cluster.SubscriptionId
                        UpdateState           = 'No Summary'
                        HealthState           = 'Unknown'
                        CurrentVersion        = ''
                        LastUpdated           = ''
                        LastChecked           = ''
                        AvailableUpdatesCount = 0
                        __DisplayTag          = 'NoSummary'
                    }
                }
            }
            catch {
                [PSCustomObject]@{
                    ClusterName           = $clusterName
                    ResourceGroup         = $cluster.ResourceGroup
                    SubscriptionId        = $cluster.SubscriptionId
                    UpdateState           = 'Error'
                    HealthState           = 'Error'
                    CurrentVersion        = ''
                    LastUpdated           = ''
                    LastChecked           = ''
                    AvailableUpdatesCount = 0
                    __DisplayTag          = "Error:$($_.Exception.Message)"
                }
            }
        }
        return , @($shardRows)
    }

    # Normalise cluster hashtables to PSCustomObjects so Start-Job
    # serialisation preserves .ResourceId/.ResourceGroup/.SubscriptionId/.Name.
    $shardInputs = @($clustersToProcess | ForEach-Object {
        [PSCustomObject]@{
            ResourceId     = $_.ResourceId
            Name           = $_.Name
            ResourceGroup  = $_.ResourceGroup
            SubscriptionId = $_.SubscriptionId
        }
    })

    $jobResults = Invoke-FleetJobsInParallel `
        -InputItems $shardInputs `
        -ScriptBlock $summaryJob `
        -ThrottleLimit $ThrottleLimit `
        -ArgumentList @($ApiVersion) `
        -ActivityName 'UpdateSummary'

    # Merge shard outputs; preserve input ordering for deterministic display.
    $resultsByName = @{}
    foreach ($jr in $jobResults) {
        if ($jr.Failed) {
            foreach ($item in @($jr.Items)) {
                $resultsByName[$item.Name] = [PSCustomObject]@{
                    ClusterName           = $item.Name
                    ResourceGroup         = $item.ResourceGroup
                    SubscriptionId        = $item.SubscriptionId
                    UpdateState           = 'Error'
                    HealthState           = 'Error'
                    CurrentVersion        = ''
                    LastUpdated           = ''
                    LastChecked           = ''
                    AvailableUpdatesCount = 0
                    __DisplayTag          = "Error:Batch job failed: $($jr.Error)"
                }
            }
            continue
        }
        foreach ($row in @($jr.Output)) {
            if (-not $row -or -not $row.ClusterName) { continue }
            $resultsByName[$row.ClusterName] = $row
        }
    }

    # Emit the same colourised per-cluster output the pre-parallel code
    # produced, now driven by structured tags so ordering matches input.
    # Use Generic.List to avoid the O(n^2) cost of += array growth at fleet scale.
    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($cluster in $clustersToProcess) {
        $row = $resultsByName[$cluster.Name]
        if (-not $row) { continue }
        Write-Host "  Checking: $($cluster.Name)..." -ForegroundColor Gray -NoNewline
        $tag = if ($row.PSObject.Properties['__DisplayTag']) { $row.__DisplayTag } else { 'Summary' }
        switch -Regex ($tag) {
            '^NotFound$'  { Write-Host ' Not Found' -ForegroundColor Red }
            '^NoSummary$' { Write-Host ' No Summary' -ForegroundColor Gray }
            '^Error:(.*)' { Write-Host " Error: $($matches[1])" -ForegroundColor Red }
            default {
                if ($row.UpdateState -eq 'UpdateAvailable' -or $row.UpdateState -eq 'Ready') {
                    Write-Host " $($row.UpdateState)" -ForegroundColor Green
                }
                elseif ($row.UpdateState -eq 'UpdateInProgress') {
                    Write-Host " $($row.UpdateState)" -ForegroundColor Yellow
                }
                elseif ($row.HealthState -eq 'Failure') {
                    Write-Host " $($row.UpdateState) ($($row.HealthState))" -ForegroundColor Red
                }
                else {
                    Write-Host " $($row.UpdateState)" -ForegroundColor Gray
                }
            }
        }
        # Drop the internal __DisplayTag from the result we return to the caller.
        $results.Add(($row | Select-Object -Property * -ExcludeProperty __DisplayTag)) | Out-Null
    }

    # Display Summary
    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Summary" -Level Header
    Write-Log -Message "========================================" -Level Header
    
    $totalClusters = $results.Count
    $upToDate = @($results | Where-Object { $_.UpdateState -in @("UpToDate", "AppliedSuccessfully") }).Count
    $updateAvailable = @($results | Where-Object { $_.UpdateState -in (@("UpdateAvailable") + $script:ReadyStates) }).Count
    $inProgress = @($results | Where-Object { $_.UpdateState -eq "UpdateInProgress" }).Count
    $healthFailures = @($results | Where-Object { $_.HealthState -eq "Failure" }).Count

    Write-Log -Message "" -Level Info
    Write-Log -Message "Total Clusters:       $totalClusters" -Level Info
    Write-Log -Message "Up to Date:           $upToDate" -Level $(if ($upToDate -gt 0) { "Success" } else { "Info" })
    Write-Log -Message "Update Available:     $updateAvailable" -Level $(if ($updateAvailable -gt 0) { "Warning" } else { "Info" })
    Write-Log -Message "Update In Progress:   $inProgress" -Level $(if ($inProgress -gt 0) { "Warning" } else { "Info" })
    Write-Log -Message "Health Failures:      $healthFailures" -Level $(if ($healthFailures -gt 0) { "Error" } else { "Info" })

    # Display results table
    Write-Log -Message "" -Level Info
    Write-Log -Message "Detailed Results:" -Level Header
    $results | Format-Table ClusterName, ResourceGroup, UpdateState, HealthState, CurrentVersion, AvailableUpdatesCount -AutoSize | Out-Host

    # Export if path specified
    if ($ExportPath) {
        try {
            $ExportPath = Resolve-SafeOutputPath -Path $ExportPath
            $exportDir = Split-Path -Path $ExportPath -Parent
            if ($exportDir -and -not (Test-Path $exportDir)) {
                New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
            }
            
            $format = Get-ExportFormat -Path $ExportPath -ExportFormat $ExportFormat
            
            switch ($format) {
                'Csv' {
                    $results | ConvertTo-SafeCsvCollection | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
                    Write-Log -Message "Results exported to CSV: $ExportPath" -Level Success
                }
                'Json' {
                    $exportData = @{
                        Timestamp     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        TotalClusters = $totalClusters
                        Summary       = @{
                            UpToDate        = $upToDate
                            UpdateAvailable = $updateAvailable
                            InProgress      = $inProgress
                            HealthFailures  = $healthFailures
                        }
                        Results       = $results
                    }
                    Write-Utf8NoBomFile -Path $ExportPath -Content ($exportData | ConvertTo-Json -Depth 10)
                    Write-Log -Message "Results exported to JSON: $ExportPath" -Level Success
                }
                'JUnitXml' {
                    $junitResults = $results | ForEach-Object {
                        [PSCustomObject]@{
                            ClusterName  = $_.ClusterName
                            Status       = if ($_.HealthState -eq "Failure") { "Failed" } elseif ($_.UpdateState -in @("UpToDate", "AppliedSuccessfully")) { "Passed" } else { "Skipped" }
                            Message      = "UpdateState: $($_.UpdateState), HealthState: $($_.HealthState), CurrentVersion: $($_.CurrentVersion)"
                            UpdateName   = $_.CurrentVersion
                            CurrentState = $_.UpdateState
                        }
                    }
                    Export-ResultsToJUnitXml -Results $junitResults -OutputPath $ExportPath `
                        -TestSuiteName "AzureLocalUpdateSummary" -OperationType "UpdateSummary"
                    Write-Log -Message "Results exported to JUnit XML: $ExportPath" -Level Success
                }
            }
        }
        catch {
            Write-Log -Message "Failed to export results: $($_.Exception.Message)" -Level Error
        }
    }

    Write-Log -Message "" -Level Info
    if ($PassThru) {
        return $results
    }
}
