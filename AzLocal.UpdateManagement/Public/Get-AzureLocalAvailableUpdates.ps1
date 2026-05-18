function Get-AzureLocalAvailableUpdates {
    <#
    .SYNOPSIS
        Gets the list of available updates for one or more Azure Local clusters.
    
    .DESCRIPTION
        Retrieves all updates that are available to install on the specified Azure Local cluster(s).
        Returns update objects containing details such as update name, version, 
        description, and state.
        
        Supports multiple input methods:
        - Single cluster by resource ID (original behavior, returns raw API objects)
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
        The API version to use. Defaults to "2025-10-01".
    
    .PARAMETER ExportPath
        Path to export the results. Format is auto-detected from extension (.csv, .json, .xml) unless -ExportFormat is specified.
    
    .PARAMETER ExportFormat
        Export format: Auto (default - detect from extension), Csv, Json, or JUnitXml.
    
    .OUTPUTS
        Returns an array of PSCustomObjects representing available updates.
    
    .EXAMPLE
        # Single cluster (original behavior)
        Get-AzureLocalAvailableUpdates -ClusterResourceId "/subscriptions/xxx/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01"
    
    .EXAMPLE
        # Multiple clusters by tag
        Get-AzureLocalAvailableUpdates -ScopeByUpdateRingTag -UpdateRingValue "Wave1"
    
    .EXAMPLE
        # Export to CSV
        Get-AzureLocalAvailableUpdates -ScopeByUpdateRingTag -UpdateRingValue "Production" -ExportPath "C:\Reports\updates.csv"
    #>
    [CmdletBinding(DefaultParameterSetName = 'SingleCluster')]
    [OutputType([PSCustomObject[]])]
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

        [Parameter(Mandatory = $false)]
        [switch]$PassThru,

        [Parameter(Mandatory = $false, ParameterSetName = 'SingleCluster')]
        [switch]$Raw,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByResourceId')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByTag')]
        [ValidateRange(1, 16)]
        [int]$ThrottleLimit = 1
    )

    # Pre-flight: Validate export path is writable before expensive operations
    if ($ExportPath) {
        try { Test-ExportPathWritable -Path $ExportPath | Out-Null }
        catch { Write-Warning $_.Exception.Message; return }
    }

    # Original single-cluster behavior
    if ($PSCmdlet.ParameterSetName -eq 'SingleCluster') {
        Test-AzCliAvailable | Out-Null
        $uri = "https://management.azure.com$ClusterResourceId/updates?api-version=$ApiVersion"
        
        Write-Verbose "Getting available updates from: $uri"
        
        $result = (Invoke-AzRestJson -Uri $uri).Data
        if ($LASTEXITCODE -ne 0 -or -not $result.value) {
            if (-not $Raw) {
                Write-Log -Message "No updates returned for cluster '$(($ClusterResourceId -split '/')[-1])'." -Level Warning
            }
            return @()
        }

        # -Raw returns the unprocessed ARM API objects (used by internal callers)
        if ($Raw) {
            return $result.value
        }

        # Default: return enriched objects with SBE dependency info
        $clusterName = ($ClusterResourceId -split '/')[-1]
        $rgName = ($ClusterResourceId -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
        $subId = ($ClusterResourceId -split '/subscriptions/')[1] -split '/' | Select-Object -First 1

        # Header banner (matches multi-cluster output style)
        Write-Log -Message "" -Level Info
        Write-Log -Message "========================================" -Level Header
        Write-Log -Message "Azure Local Available Updates" -Level Header
        Write-Log -Message "========================================" -Level Header
        Write-Log -Message "Cluster:        $clusterName" -Level Info
        Write-Log -Message "Resource Group: $rgName" -Level Info
        Write-Log -Message "Subscription:   $subId" -Level Info

        $enriched = @()
        foreach ($update in $result.value) {
            $props = $update.properties
            $state = if ($props.state) { $props.state } else { "Unknown" }
            $packageType = if ($props.packageType) { $props.packageType } else { "" }
            $sbeDependency = ""
            if ($state -in @("HasPrerequisite", "AdditionalContentRequired") -and $packageType -eq "SBE") {
                $additionalProps = ConvertTo-AzLocalAdditionalProperties -InputObject $props.additionalProperties
                $sbeParts = @()
                if ($additionalProps -and $additionalProps.SBEPublisher) { $sbeParts += "Publisher: $($additionalProps.SBEPublisher)" }
                if ($additionalProps -and $additionalProps.SBEFamily) { $sbeParts += "Family: $($additionalProps.SBEFamily)" }
                if ($additionalProps -and $additionalProps.SBEReleaseLink) { $sbeParts += "ReleaseNotes: $($additionalProps.SBEReleaseLink)" }
                if ($sbeParts.Count -gt 0) { $sbeDependency = $sbeParts -join '; ' }
            }
            $enriched += [PSCustomObject]@{
                ClusterName      = $clusterName
                ResourceGroup    = $rgName
                SubscriptionId   = $subId
                UpdateName       = $update.name
                UpdateState      = $state
                Version          = if ($props.version) { $props.version } else { "" }
                PackageType      = $packageType
                SBEDependency    = $sbeDependency
                Description      = if ($props.description) { $props.description.Substring(0, [Math]::Min(100, $props.description.Length)) } else { "" }
            }
        }

        # Summary block (matches multi-cluster output style)
        $readyCount = @($enriched | Where-Object { $_.UpdateState -in $script:ReadyStates }).Count
        $prereqCount = @($enriched | Where-Object { $_.UpdateState -in $script:PrereqStates }).Count
        $otherCount = $enriched.Count - $readyCount - $prereqCount

        Write-Log -Message "" -Level Info
        Write-Log -Message "========================================" -Level Header
        Write-Log -Message "Summary" -Level Header
        Write-Log -Message "========================================" -Level Header
        Write-Log -Message "Total Updates:           $($enriched.Count)" -Level Info
        Write-Log -Message "Ready to Install:        $readyCount" -Level $(if ($readyCount -gt 0) { "Success" } else { "Info" })
        Write-Log -Message "Has Prerequisite (SBE):  $prereqCount" -Level $(if ($prereqCount -gt 0) { "Warning" } else { "Info" })
        if ($otherCount -gt 0) {
            Write-Log -Message "Other States:            $otherCount" -Level Info
        }

        if ($prereqCount -gt 0) {
            Write-Log -Message "" -Level Info
            Write-Log -Message "Updates blocked by SBE prerequisites:" -Level Warning
            foreach ($u in ($enriched | Where-Object { $_.UpdateState -in $script:PrereqStates })) {
                $msg = "  - $($u.UpdateName): $($u.UpdateState)"
                if ($u.SBEDependency) { $msg += " ($($u.SBEDependency))" }
                Write-Log -Message $msg -Level Warning
            }
            Write-Log -Message "Install the required SBE (Solution Builder Extension) update from your hardware vendor before these updates can proceed." -Level Warning
        }

        Write-Log -Message "" -Level Info
        Write-Log -Message "Detailed Results:" -Level Header
        $enriched | Format-Table UpdateName, UpdateState, Version, PackageType, SBEDependency -AutoSize | Out-String | Write-Host

        return $enriched
    }

    # Multi-cluster mode
    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Azure Local Available Updates" -Level Header
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
    Write-Log -Message "Querying available updates for $($clustersToProcess.Count) cluster(s)..." -Level Info

    # Collect results
    $results = @()
    $updateVersionCounts = @{}

    # Parallel dispatch (v0.7.0+): when -ThrottleLimit > 1 and we have multiple clusters,
    # shard them across background jobs. Each job re-imports the module and calls this
    # function recursively with -ThrottleLimit 1 on its own subset, then returns the
    # flattened per-cluster rows. This avoids parallelising shared state (Write-Host
    # progress, $results accumulation, $updateVersionCounts hashtable) inside a single
    # runspace while still giving an N-way speedup on large fleets.
    if ($ThrottleLimit -gt 1 -and $clustersToProcess.Count -gt 1) {
        Write-Log -Message "Dispatching to $ThrottleLimit parallel workers..." -Level Info
        $jobScript = {
            param([object[]]$Batch, [string]$ApiVersionArg, [string]$ModulePath)
            Import-Module $ModulePath -Force
            $resourceIds = @($Batch | ForEach-Object { $_.ResourceId } | Where-Object { $_ })
            if ($resourceIds.Count -eq 0) { return @() }
            Get-AzureLocalAvailableUpdates -ClusterResourceIds $resourceIds `
                -ApiVersion $ApiVersionArg -ThrottleLimit 1 -PassThru
        }
        $batchResults = Invoke-FleetJobsInParallel `
            -InputItems $clustersToProcess `
            -ScriptBlock $jobScript `
            -ThrottleLimit $ThrottleLimit `
            -ArgumentList @($ApiVersion) `
            -ActivityName 'AvailableUpdates'
        foreach ($br in $batchResults) {
            if ($br.Failed) {
                Write-Log -Message "  Parallel batch $($br.BatchIndex) failed: $($br.Error)" -Level Error
                continue
            }
            if ($br.Output) { $results += @($br.Output) }
        }
        # Re-build version counts from the merged results
        foreach ($row in $results) {
            if ($row.UpdateState -in $script:ReadyStates -and $row.UpdateName) {
                if ($updateVersionCounts.ContainsKey($row.UpdateName)) { $updateVersionCounts[$row.UpdateName]++ }
                else { $updateVersionCounts[$row.UpdateName] = 1 }
            }
        }
    }
    else {

    foreach ($cluster in $clustersToProcess) {
        $clusterName = $cluster.Name
        Write-Host "  Checking: $clusterName..." -ForegroundColor Gray -NoNewline

        try {
            # Get cluster info if we don't have ResourceId
            $resourceId = $cluster.ResourceId
            if (-not $resourceId) {
                $clusterInfo = Get-AzureLocalClusterInfo -ClusterName $clusterName `
                    -ResourceGroupName $cluster.ResourceGroup `
                    -SubscriptionId $cluster.SubscriptionId `
                    -ApiVersion $ApiVersion
                if ($clusterInfo) {
                    $resourceId = $clusterInfo.id
                }
            }

            if (-not $resourceId) {
                Write-Host " Not Found" -ForegroundColor Red
                $results += [PSCustomObject]@{
                    ClusterName      = $clusterName
                    ResourceGroup    = $cluster.ResourceGroup
                    SubscriptionId   = $cluster.SubscriptionId
                    UpdateName       = "N/A"
                    UpdateState      = "Cluster Not Found"
                    Version          = ""
                    PackageType      = ""
                    SBEDependency    = ""
                    Description      = ""
                }
                continue
            }

            # Get available updates
            $uri = "https://management.azure.com$resourceId/updates?api-version=$ApiVersion"
            $response = (Invoke-AzRestJson -Uri $uri).Data

            if ($LASTEXITCODE -eq 0 -and $response.value -and $response.value.Count -gt 0) {
                $updates = $response.value
                $readyCount = @($updates | Where-Object { $_.properties.state -in $script:ReadyStates }).Count
                $prereqCount = @($updates | Where-Object { $_.properties.state -in $script:PrereqStates }).Count
                
                $statusParts = @("$readyCount ready")
                if ($prereqCount -gt 0) { $statusParts += "$prereqCount has prerequisite" }
                $statusText = $statusParts -join ', '
                $statusColor = if ($readyCount -gt 0) { "Green" } elseif ($prereqCount -gt 0) { "Yellow" } else { "Yellow" }
                Write-Host " $($updates.Count) update(s) ($statusText)" -ForegroundColor $statusColor
                
                foreach ($update in $updates) {
                    $props = $update.properties
                    $state = if ($props.state) { $props.state } else { "Unknown" }
                    
                    # Track update versions
                    if ($state -in $script:ReadyStates) {
                        if ($updateVersionCounts.ContainsKey($update.name)) {
                            $updateVersionCounts[$update.name]++
                        }
                        else {
                            $updateVersionCounts[$update.name] = 1
                        }
                    }

                    # Extract SBE dependency info for HasPrerequisite/AdditionalContentRequired updates
                    $packageType = if ($props.packageType) { $props.packageType } else { "" }
                    $sbeDependency = ""
                    if ($state -in @("HasPrerequisite", "AdditionalContentRequired") -and $packageType -eq "SBE") {
                        $additionalProps = ConvertTo-AzLocalAdditionalProperties -InputObject $props.additionalProperties
                        $sbePublisher = if ($additionalProps -and $additionalProps.SBEPublisher) { $additionalProps.SBEPublisher } else { "" }
                        $sbeFamily = if ($additionalProps -and $additionalProps.SBEFamily) { $additionalProps.SBEFamily } else { "" }
                        $sbeReleaseLink = if ($additionalProps -and $additionalProps.SBEReleaseLink) { $additionalProps.SBEReleaseLink } else { "" }
                        $sbeParts = @()
                        if ($sbePublisher) { $sbeParts += "Publisher: $sbePublisher" }
                        if ($sbeFamily) { $sbeParts += "Family: $sbeFamily" }
                        if ($sbeReleaseLink) { $sbeParts += "ReleaseNotes: $sbeReleaseLink" }
                        if ($sbeParts.Count -gt 0) { $sbeDependency = $sbeParts -join '; ' }
                    }
                    
                    $results += [PSCustomObject]@{
                        ClusterName      = $clusterName
                        ResourceGroup    = $cluster.ResourceGroup
                        SubscriptionId   = $cluster.SubscriptionId
                        UpdateName       = $update.name
                        UpdateState      = $state
                        Version          = if ($props.version) { $props.version } else { "" }
                        PackageType      = $packageType
                        SBEDependency    = $sbeDependency
                        Description      = if ($props.description) { $props.description.Substring(0, [Math]::Min(100, $props.description.Length)) } else { "" }
                    }
                }
            }
            else {
                Write-Host " No updates available" -ForegroundColor Gray
                $results += [PSCustomObject]@{
                    ClusterName      = $clusterName
                    ResourceGroup    = $cluster.ResourceGroup
                    SubscriptionId   = $cluster.SubscriptionId
                    UpdateName       = "None"
                    UpdateState      = "No Updates"
                    Version          = ""
                    PackageType      = ""
                    SBEDependency    = ""
                    Description      = ""
                }
            }
        }
        catch {
            Write-Host " Error: $($_.Exception.Message)" -ForegroundColor Red
            $results += [PSCustomObject]@{
                ClusterName      = $clusterName
                ResourceGroup    = $cluster.ResourceGroup
                SubscriptionId   = $cluster.SubscriptionId
                UpdateName       = "Error"
                UpdateState      = "Error"
                Version          = ""
                PackageType      = ""
                SBEDependency    = ""
                Description      = $_.Exception.Message
            }
        }
    }
    } # end else (serial path)

    # Display Summary
    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Summary" -Level Header
    Write-Log -Message "========================================" -Level Header
    
    $totalClusters = $clustersToProcess.Count
    $clustersWithUpdates = @($results | Where-Object { $_.UpdateName -notin @("N/A", "None", "Error") } | Select-Object -ExpandProperty ClusterName -Unique).Count
    $clustersWithReadyUpdates = @($results | Where-Object { $_.UpdateState -in $script:ReadyStates } | Select-Object -ExpandProperty ClusterName -Unique).Count
    $clustersWithPrereqUpdates = @($results | Where-Object { $_.UpdateState -in $script:PrereqStates } | Select-Object -ExpandProperty ClusterName -Unique).Count
    $totalUpdates = @($results | Where-Object { $_.UpdateName -notin @("N/A", "None", "Error") }).Count

    Write-Log -Message "" -Level Info
    Write-Log -Message "Total Clusters:              $totalClusters" -Level Info
    Write-Log -Message "Clusters with Updates:       $clustersWithUpdates" -Level $(if ($clustersWithUpdates -gt 0) { "Warning" } else { "Info" })
    Write-Log -Message "Clusters with Ready Updates: $clustersWithReadyUpdates" -Level $(if ($clustersWithReadyUpdates -gt 0) { "Success" } else { "Info" })
    if ($clustersWithPrereqUpdates -gt 0) {
        Write-Log -Message "Clusters with Prerequisite:  $clustersWithPrereqUpdates (SBE update required first)" -Level Warning
    }
    Write-Log -Message "Total Updates Found:         $totalUpdates" -Level Info

    # Show SBE dependency details for HasPrerequisite/AdditionalContentRequired updates
    $prereqUpdates = @($results | Where-Object { $_.UpdateState -in @("HasPrerequisite", "AdditionalContentRequired") -and $_.SBEDependency })
    if ($prereqUpdates.Count -gt 0) {
        Write-Log -Message "" -Level Info
        Write-Log -Message "Updates Blocked by SBE Prerequisites:" -Level Warning
        foreach ($pu in $prereqUpdates) {
            Write-Log -Message "  $($pu.ClusterName) - $($pu.UpdateName): $($pu.SBEDependency)" -Level Warning
        }
    }

    # Show most common update versions
    if ($updateVersionCounts.Count -gt 0) {
        Write-Log -Message "" -Level Info
        Write-Log -Message "Ready Update Versions:" -Level Header
        $sortedVersions = $updateVersionCounts.GetEnumerator() | Sort-Object -Property Value -Descending
        foreach ($version in $sortedVersions) {
            Write-Log -Message "  $($version.Key): $($version.Value) cluster(s)" -Level Info
        }
    }

    # Display results table
    Write-Log -Message "" -Level Info
    Write-Log -Message "Detailed Results:" -Level Header
    $results | Format-Table ClusterName, UpdateName, UpdateState, Version, PackageType -AutoSize

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
                        Timestamp             = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        TotalClusters         = $totalClusters
                        ClustersWithUpdates   = $clustersWithUpdates
                        UpdateVersionSummary  = $updateVersionCounts
                        Results               = $results
                    }
                    Write-Utf8NoBomFile -Path $ExportPath -Content ($exportData | ConvertTo-Json -Depth 10)
                    Write-Log -Message "Results exported to JSON: $ExportPath" -Level Success
                }
                'JUnitXml' {
                    $junitResults = $results | ForEach-Object {
                        [PSCustomObject]@{
                            ClusterName  = $_.ClusterName
                            Status       = if ($_.UpdateState -in $script:ReadyStates) { "Ready" } elseif ($_.UpdateState -eq "Error") { "Failed" } else { "Skipped" }
                            Message      = "Update: $($_.UpdateName), State: $($_.UpdateState), Version: $($_.Version)"
                            UpdateName   = $_.UpdateName
                            CurrentState = $_.UpdateState
                        }
                    }
                    Export-ResultsToJUnitXml -Results $junitResults -OutputPath $ExportPath `
                        -TestSuiteName "AzureLocalAvailableUpdates" -OperationType "AvailableUpdates"
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
