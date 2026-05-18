function Get-AzureLocalClusterUpdateReadiness {
    <#
    .SYNOPSIS
        Assesses update readiness across Azure Local clusters and reports available updates.

    .DESCRIPTION
        This function queries Azure Local clusters and reports their update readiness state,
        available updates, and provides summary statistics to help plan update deployments.
        
        Output includes:
        - Which clusters are in "Ready" state for updates
        - Which updates are available for each cluster
        - Summary totals showing the most common applicable update version
        
        Results are displayed on screen and optionally exported to CSV, JSON, or JUnit XML.

    .PARAMETER ClusterNames
        An array of Azure Local cluster names to assess.

    .PARAMETER ClusterResourceIds
        An array of full Azure Resource IDs for the clusters to assess.

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
        - .csv  = Standard CSV format
        - .json = JSON format with summary statistics
        - .xml  = JUnit XML format for CI/CD pipeline integration (Azure DevOps, GitHub Actions, Jenkins, etc.)

    .PARAMETER ExportFormat
        Export format: Auto (default - detect from extension), Csv, Json, or JUnitXml.

    .EXAMPLE
        # Assess all clusters with a specific UpdateRing tag value
        Get-AzureLocalClusterUpdateReadiness -ScopeByUpdateRingTag -UpdateRingValue "Wave1"

    .EXAMPLE
        # Assess specific clusters and export to CSV
        Get-AzureLocalClusterUpdateReadiness -ClusterNames @("Cluster01", "Cluster02") -ExportPath "C:\Reports\readiness.csv"

    .EXAMPLE
        # Export to JUnit XML for CI/CD pipelines
        Get-AzureLocalClusterUpdateReadiness -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -ExportPath "C:\Reports\readiness.xml"

    .EXAMPLE
        # Assess clusters by Resource ID
        Get-AzureLocalClusterUpdateReadiness -ClusterResourceIds @("/subscriptions/xxx/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01")

    .NOTES
        Author: Neil Bird, Microsoft.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    [OutputType([PSCustomObject[]])]
    param(
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

        [Parameter(Mandatory = $false)]
        [string]$ExportPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Auto', 'Csv', 'Json', 'JUnitXml')]
        [string]$ExportFormat = 'Auto',

        [Parameter(Mandatory = $false)]
        [switch]$PassThru,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 32)]
        [int]$ThrottleLimit = 1
    )

    # Pre-flight: Validate export path is writable before expensive operations
    Write-Log -Message "" -Level Info

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
        # Ensure resource-graph extension is installed (for pipeline/automation scenarios)
        if (-not (Install-AzGraphExtension)) {
            Write-Error "Failed to install Azure CLI 'resource-graph' extension. Please install manually: az extension add --name resource-graph"
            return
        }
        
        Write-Log -Message "Querying Azure Resource Graph for clusters with tag 'UpdateRing' = '$UpdateRingValue'..." -Level Info
        
        # Build Azure Resource Graph query - use single line to avoid escaping issues with az CLI
        $ringFilter = ConvertTo-AzLocalUpdateRingKqlFilter -UpdateRingValue $UpdateRingValue
        $argQuery = "resources | where type =~ 'microsoft.azurestackhci/clusters' $ringFilter | project id, name, resourceGroup, subscriptionId, tags"
        
        try {
            $argParams = @{ Query = $argQuery }
            if ($SubscriptionId) { $argParams['SubscriptionId'] = $SubscriptionId }
            $clusterRows = Invoke-AzResourceGraphQuery @argParams

            if (-not $clusterRows -or $clusterRows.Count -eq 0) {
                Write-Log -Message "No clusters found with tag 'UpdateRing' = '$UpdateRingValue'" -Level Warning
                return
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
    Write-Log -Message "Assessing $($clustersToProcess.Count) cluster(s)..." -Level Info
    Write-Log -Message "" -Level Info

    # Collect results
    # Use Generic.List to avoid the O(n^2) cost of += array growth at fleet scale.
    $results = [System.Collections.Generic.List[object]]::new()
    $updateVersionCounts = @{}

    # Per-cluster readiness scriptblock. Runs inline (ThrottleLimit=1) or
    # inside Start-Job (ThrottleLimit>1). Emits one PSCustomObject per input
    # cluster augmented with internal __DisplayTag / __CountedRecommendedUpdate
    # fields that the parent uses to render coloured console output and tally
    # the shared $updateVersionCounts hashtable deterministically.
    #
    # Note: This scriptblock runs both inline (ThrottleLimit=1, in the parent
    # module's session state) and inside Start-Job (ThrottleLimit>1, in a fresh
    # child runspace). In the child runspace, module-private helpers filtered
    # out by Export-ModuleMember (Invoke-AzRestJson, Get-LatestUpdateByYYMM,
    # ConvertTo-AzLocalAdditionalProperties, Get-HealthCheckFailureSummary,
    # Get-TagValue) are NOT visible at script command-resolution scope after
    # Import-Module. We therefore resolve the module reference, then rebind
    # each private helper into the local function scope using its bound
    # scriptblock - calls to those helpers below then execute against the
    # module's own session state and resolve all transitive private references.
    $readinessJob = {
        param(
            [object[]]$Shard,
            [string]$ApiVer,
            [string[]]$ReadyStatesArg,
            [string[]]$PrereqStatesArg,
            [string]$UpdateWindowTagNameArg,
            [string]$UpdateExclusionsTagNameArg,
            [string]$ModulePath
        )
        $mod = Get-Module -Name AzLocal.UpdateManagement | Select-Object -First 1
        if (-not $mod) {
            $mod = Import-Module $ModulePath -Force -PassThru -ErrorAction Stop
        }
        foreach ($_helperName in @(
                'Invoke-AzRestJson',
                'ConvertTo-AzLocalAdditionalProperties',
                'Get-LatestUpdateByYYMM',
                'Get-HealthCheckFailureSummary',
                'Get-TagValue'
            )) {
            $_cmd = & $mod { param($n) Get-Command -Name $n -ErrorAction SilentlyContinue } $_helperName
            if ($_cmd -and $_cmd.ScriptBlock) {
                Set-Item -Path "function:script:$_helperName" -Value $_cmd.ScriptBlock
            }
        }
        $shardRows = foreach ($cluster in $Shard) {
            $clusterName = $cluster.Name
            try {
                if ($cluster.ResourceId) {
                    $uri = "https://management.azure.com$($cluster.ResourceId)?api-version=$ApiVer"
                    $clusterInfo = (Invoke-AzRestJson -Uri $uri).Data
                }
                else {
                    $clusterInfo = Get-AzureLocalClusterInfo -ClusterName $clusterName `
                        -ResourceGroupName $cluster.ResourceGroup `
                        -SubscriptionId $cluster.SubscriptionId `
                        -ApiVersion $ApiVer
                }

                if (-not $clusterInfo) {
                    [PSCustomObject]@{
                        ClusterName                  = $clusterName
                        ClusterResourceId            = $cluster.ResourceId
                        ResourceGroup                = $cluster.ResourceGroup
                        SubscriptionId               = $cluster.SubscriptionId
                        ClusterState                 = 'Not Found'
                        UpdateState                  = 'N/A'
                        HealthState                  = 'N/A'
                        CurrentVersion               = ''
                        CurrentSbeVersion            = ''
                        ReadyForUpdate               = $false
                        AvailableUpdates             = ''
                        ReadyUpdates                 = ''
                        HasPrerequisiteUpdates       = ''
                        SBEDependency                = ''
                        RecommendedUpdate            = ''
                        HealthCheckFailures          = ''
                        BlockingReasons              = ''
                        UpdateWindow                 = ''
                        UpdateExclusions             = ''
                        __DisplayTag                 = 'NotFound'
                        __CountedRecommendedUpdate   = $null
                    }
                    continue
                }

                $rgName = ($clusterInfo.id -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1
                $subId = ($clusterInfo.id -split '/subscriptions/')[1] -split '/' | Select-Object -First 1

                $updateSummary = Get-AzureLocalUpdateSummary -ClusterResourceId $clusterInfo.id -ApiVersion $ApiVer
                $updateState = if ($updateSummary) { $updateSummary.properties.state } else { 'Unknown' }

                $availableUpdates = @(Get-AzureLocalAvailableUpdates -ClusterResourceId $clusterInfo.id -ApiVersion $ApiVer -Raw)
                $readyUpdates = @($availableUpdates | Where-Object { $_.properties.state -in $ReadyStatesArg })
                $prereqUpdates = @($availableUpdates | Where-Object { $_.properties.state -in $PrereqStatesArg })

                $availableUpdateNames = ($availableUpdates | ForEach-Object { $_.name }) -join '; '
                $readyUpdateNames = ($readyUpdates | ForEach-Object { $_.name }) -join '; '
                $prereqUpdateNames = ($prereqUpdates | ForEach-Object { $_.name }) -join '; '

                $sbeDependencyInfo = ''
                foreach ($pu in $prereqUpdates) {
                    $puProps = $pu.properties
                    if ($puProps.packageType -eq 'SBE' -and $puProps.additionalProperties) {
                        $addProps = ConvertTo-AzLocalAdditionalProperties -InputObject $puProps.additionalProperties
                        if ($addProps) {
                            $sbeParts = @()
                            if ($addProps.SBEPublisher) { $sbeParts += "Publisher: $($addProps.SBEPublisher)" }
                            if ($addProps.SBEFamily) { $sbeParts += "Family: $($addProps.SBEFamily)" }
                            if ($sbeParts.Count -gt 0) { $sbeDependencyInfo = "$($pu.name): $($sbeParts -join '; ')" }
                        }
                    }
                }

                $recommendedUpdate = ''
                $counted = $null
                $isUpToDateState = $updateState -in @('UpToDate', 'AppliedSuccessfully')
                # If every entry in /updates is in a terminal 'Installed' state, treat the
                # cluster as effectively up-to-date even when updateSummary.state is stale
                # (seen in the wild: ARM reports 'UpdateAvailable' for hours after the last
                # update completes until the cluster heartbeat refreshes).
                $allInstalled = ($availableUpdates.Count -gt 0) -and `
                    -not ($availableUpdates | Where-Object { $_.properties.state -ne 'Installed' })
                if ($readyUpdates.Count -gt 0) {
                    $latestReady = Get-LatestUpdateByYYMM -Updates $readyUpdates
                    $recommendedUpdate = $latestReady.name
                    # Only ready updates contribute to the parent-side tally.
                    $counted = $recommendedUpdate
                }
                elseif (-not $isUpToDateState -and -not $allInstalled -and $availableUpdates.Count -gt 0) {
                    # Fallback: pick the newest non-Installed entry (HasPrerequisite,
                    # AdditionalContentRequired, Downloading, NotReady, etc.). Already-
                    # installed entries must never be surfaced as the "next" update.
                    $nonInstalled = @($availableUpdates | Where-Object { $_.properties.state -ne 'Installed' })
                    if ($nonInstalled.Count -gt 0) {
                        $latestAvailable = Get-LatestUpdateByYYMM -Updates $nonInstalled
                        $recommendedUpdate = $latestAvailable.name
                    }
                }

                $isReady = ($updateState -in (@('UpdateAvailable') + $ReadyStatesArg)) -and ($readyUpdates.Count -gt 0)

                $healthState = if ($updateSummary -and $updateSummary.properties.healthState) { $updateSummary.properties.healthState } else { 'Unknown' }
                $healthCheckFailures = ''
                if ($updateSummary -and $healthState -notin @('Success', 'Unknown')) {
                    $healthCheckFailures = Get-HealthCheckFailureSummary -UpdateSummary $updateSummary
                }

                # Apply readiness gates: even when ARM reports the cluster as having a
                # Ready update, downgrade ReadyForUpdate to $false if (a) the cluster is
                # not currently reachable from ARM (anything other than ConnectedRecently
                # - e.g. NotConnectedRecently, Disconnected) or (b) any [Critical]
                # severity health check is failing. Record the trigger(s) in
                # BlockingReasons so the readiness CSV explains the downgrade.
                $blockingReasons = @()
                if ($healthCheckFailures -and ($healthCheckFailures -match '\[Critical\]')) {
                    $blockingReasons += 'CriticalHealthCheck'
                }
                $clusterStatus = if ($clusterInfo.properties.PSObject.Properties['status']) { [string]$clusterInfo.properties.status } else { '' }
                if ($clusterStatus -and $clusterStatus -ne 'ConnectedRecently') {
                    $blockingReasons += $clusterStatus
                }
                if ($isReady -and $blockingReasons.Count -gt 0) {
                    $isReady = $false
                    # Drop the recommendedUpdate tally so blocked clusters do not skew
                    # the "most common applicable update" summary.
                    $counted = $null
                }

                # Installed solution/SBE versions are already present in $updateSummary;
                # surface them on the readiness row so operators can triage without a
                # separate Get-AzureLocalUpdateSummary call.
                # Solution version lives at properties.currentVersion (ARM maintains
                # this as the latest-installed Solution). SBE version is inside
                # properties.packageVersions[] where packageType == 'SBE'; pick the
                # newest by lastUpdated (fallback: highest parseable [version]).
                $currentVersion = ''
                $currentSbeVersion = ''
                if ($updateSummary -and $updateSummary.properties) {
                    if ($updateSummary.properties.PSObject.Properties['currentVersion']) {
                        $currentVersion = [string]$updateSummary.properties.currentVersion
                    }
                    if ($updateSummary.properties.PSObject.Properties['packageVersions'] -and $updateSummary.properties.packageVersions) {
                        $sbePkgs = @($updateSummary.properties.packageVersions | Where-Object { $_.packageType -eq 'SBE' -and $_.version })
                        if ($sbePkgs.Count -gt 0) {
                            $latestSbe = $sbePkgs |
                                Sort-Object -Property @{
                                    Expression = {
                                        if ($_.PSObject.Properties['lastUpdated'] -and $_.lastUpdated) {
                                            try { [datetime]$_.lastUpdated } catch { [datetime]::MinValue }
                                        } else { [datetime]::MinValue }
                                    }
                                }, @{
                                    Expression = {
                                        try { [version]($_.version -replace '[^0-9.]', '') } catch { [version]'0.0.0.0' }
                                    }
                                } -Descending |
                                Select-Object -First 1
                            if ($latestSbe -and $latestSbe.version) {
                                $currentSbeVersion = [string]$latestSbe.version
                            }
                        }
                    }
                }

                # Choose a display tag; actual Write-Host runs in the parent.
                $tag =
                    if ($blockingReasons.Count -gt 0) { "Blocked:$($blockingReasons -join ',')" }
                    elseif ($isReady) { "Ready:$recommendedUpdate" }
                    elseif ($allInstalled) { 'UpToDate' }
                    elseif ($prereqUpdates.Count -gt 0 -and $readyUpdates.Count -eq 0) { 'HasPrerequisite' }
                    elseif ($updateState -eq 'UpdateInProgress') { 'UpdateInProgress' }
                    elseif ($readyUpdates.Count -eq 0 -and $availableUpdates.Count -gt 0) { 'Downloading' }
                    elseif ($healthState -in @('Failure', 'Warning')) { "HealthIssue:$updateState`:$healthState" }
                    else { "State:$updateState" }

                $uw = if ($clusterInfo.tags) { Get-TagValue -Tags $clusterInfo.tags -Name $UpdateWindowTagNameArg } else { $null }
                $ue = if ($clusterInfo.tags) { Get-TagValue -Tags $clusterInfo.tags -Name $UpdateExclusionsTagNameArg } else { $null }

                [PSCustomObject]@{
                    ClusterName                  = $clusterName
                    ClusterResourceId            = $clusterInfo.id
                    ResourceGroup                = $rgName
                    SubscriptionId               = $subId
                    ClusterState                 = $clusterInfo.properties.status
                    UpdateState                  = $updateState
                    HealthState                  = $healthState
                    CurrentVersion               = $currentVersion
                    CurrentSbeVersion            = $currentSbeVersion
                    ReadyForUpdate               = $isReady
                    AvailableUpdates             = $availableUpdateNames
                    ReadyUpdates                 = $readyUpdateNames
                    HasPrerequisiteUpdates       = $prereqUpdateNames
                    SBEDependency                = $sbeDependencyInfo
                    RecommendedUpdate            = $recommendedUpdate
                    HealthCheckFailures          = $healthCheckFailures
                    BlockingReasons              = ($blockingReasons -join '; ')
                    UpdateWindow                 = if ($uw) { $uw } else { '' }
                    UpdateExclusions             = if ($ue) { $ue } else { '' }
                    __DisplayTag                 = $tag
                    __CountedRecommendedUpdate   = $counted
                }
            }
            catch {
                [PSCustomObject]@{
                    ClusterName                  = $clusterName
                    ClusterResourceId            = $cluster.ResourceId
                    ResourceGroup                = $cluster.ResourceGroup
                    SubscriptionId               = $cluster.SubscriptionId
                    ClusterState                 = 'Error'
                    UpdateState                  = 'Error'
                    HealthState                  = 'Error'
                    CurrentVersion               = ''
                    CurrentSbeVersion            = ''
                    ReadyForUpdate               = $false
                    AvailableUpdates             = ''
                    ReadyUpdates                 = ''
                    HasPrerequisiteUpdates       = ''
                    SBEDependency                = ''
                    RecommendedUpdate            = ''
                    HealthCheckFailures          = $_.Exception.Message
                    BlockingReasons              = ''
                    UpdateWindow                 = ''
                    UpdateExclusions             = ''
                    __DisplayTag                 = "Error:$($_.Exception.Message)"
                    __CountedRecommendedUpdate   = $null
                }
            }
        }
        return , @($shardRows)
    }

    # Normalise input cluster entries to PSCustomObjects so Start-Job
    # serialisation preserves the property shape used by the scriptblock.
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
        -ScriptBlock $readinessJob `
        -ThrottleLimit $ThrottleLimit `
        -ArgumentList @($ApiVersion, $script:ReadyStates, $script:PrereqStates, $script:UpdateWindowTagName, $script:UpdateExclusionsTagName) `
        -ActivityName 'Readiness'

    # Merge shard outputs into a ResourceId-keyed hash for input-ordered replay.
    $rowsByName = @{}
    foreach ($jr in $jobResults) {
        if ($jr.Failed) {
            foreach ($item in @($jr.Items)) {
                $rowsByName[$item.Name] = [PSCustomObject]@{
                    ClusterName                  = $item.Name
                    ClusterResourceId            = $item.ResourceId
                    ResourceGroup                = $item.ResourceGroup
                    SubscriptionId               = $item.SubscriptionId
                    ClusterState                 = 'Error'
                    UpdateState                  = 'Error'
                    HealthState                  = 'Error'
                    CurrentVersion               = ''
                    CurrentSbeVersion            = ''
                    ReadyForUpdate               = $false
                    AvailableUpdates             = ''
                    ReadyUpdates                 = ''
                    HasPrerequisiteUpdates       = ''
                    SBEDependency                = ''
                    RecommendedUpdate            = ''
                    HealthCheckFailures          = "Batch job failed: $($jr.Error)"
                    BlockingReasons              = ''
                    UpdateWindow                 = ''
                    UpdateExclusions             = ''
                    __DisplayTag                 = "Error:Batch job failed: $($jr.Error)"
                    __CountedRecommendedUpdate   = $null
                }
            }
            continue
        }
        foreach ($row in @($jr.Output)) {
            if (-not $row -or -not $row.ClusterName) { continue }
            $rowsByName[$row.ClusterName] = $row
        }
    }

    foreach ($cluster in $clustersToProcess) {
        $row = $rowsByName[$cluster.Name]
        if (-not $row) { continue }

        Write-Host "  Checking: $($cluster.Name)..." -ForegroundColor Gray -NoNewline
        $tag = if ($row.PSObject.Properties['__DisplayTag']) { $row.__DisplayTag } else { '' }
        switch -Regex ($tag) {
            '^NotFound$'           { Write-Host ' Not Found' -ForegroundColor Red }
            '^Ready:(.*)'          { Write-Host " Ready ($($matches[1]))" -ForegroundColor Green }
            '^Blocked:(.*)'        { Write-Host " Blocked ($($matches[1]))" -ForegroundColor Red }
            '^HasPrerequisite$'    { Write-Host ' Has Prerequisite (SBE update required)' -ForegroundColor Yellow }
            '^UpdateInProgress$'   { Write-Host ' Update In Progress' -ForegroundColor Yellow }
            '^Downloading$'        { Write-Host ' Updates Downloading' -ForegroundColor Yellow }
            '^HealthIssue:([^:]*):(.*)' {
                $c = if ($matches[2] -eq 'Failure') { 'Red' } else { 'Yellow' }
                Write-Host " $($matches[1]) ($($matches[2]))" -ForegroundColor $c
            }
            '^State:(.*)'          { Write-Host " $($matches[1])" -ForegroundColor Gray }
            '^Error:(.*)'          { Write-Host " Error: $($matches[1])" -ForegroundColor Red }
            default                { Write-Host " $($row.UpdateState)" -ForegroundColor Gray }
        }

        # Tally only rows that the scriptblock marked as ready (mirrors
        # the original in-loop $updateVersionCounts mutation semantics).
        $counted = if ($row.PSObject.Properties['__CountedRecommendedUpdate']) { $row.__CountedRecommendedUpdate } else { $null }
        if ($counted) {
            if ($updateVersionCounts.ContainsKey($counted)) {
                $updateVersionCounts[$counted]++
            }
            else {
                $updateVersionCounts[$counted] = 1
            }
        }

        $results.Add(($row | Select-Object -Property * -ExcludeProperty __DisplayTag, __CountedRecommendedUpdate)) | Out-Null
    }

    # Display Summary
    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Summary" -Level Header
    Write-Log -Message "========================================" -Level Header
    
    $totalClusters = $results.Count
    $readyClusters = @($results | Where-Object { $_.ReadyForUpdate -eq $true }).Count
    $notReadyClusters = $totalClusters - $readyClusters
    $inProgressClusters = @($results | Where-Object { $_.UpdateState -eq "UpdateInProgress" }).Count
    $prereqClusters = @($results | Where-Object { $_.HasPrerequisiteUpdates -ne "" }).Count
    $blockedClusters = @($results | Where-Object { $_.PSObject.Properties['BlockingReasons'] -and $_.BlockingReasons -ne "" }).Count

    Write-Log -Message "" -Level Info
    Write-Log -Message "Total Clusters Assessed:    $totalClusters" -Level Info
    Write-Log -Message "Ready for Update:           $readyClusters" -Level Success
    Write-Log -Message "Not Ready / Other State:    $notReadyClusters" -Level $(if ($notReadyClusters -gt 0) { "Warning" } else { "Info" })
    Write-Log -Message "Update In Progress:         $inProgressClusters" -Level $(if ($inProgressClusters -gt 0) { "Warning" } else { "Info" })
    if ($blockedClusters -gt 0) {
        Write-Log -Message "Blocked by Readiness Gate:  $blockedClusters (see BlockingReasons column)" -Level Error
    }
    if ($prereqClusters -gt 0) {
        Write-Log -Message "Blocked by SBE Prereq:     $prereqClusters" -Level Warning
    }
    
    # Show SBE dependency details for clusters with HasPrerequisite updates
    $clustersWithSBEDeps = @($results | Where-Object { $_.SBEDependency -ne "" })
    if ($clustersWithSBEDeps.Count -gt 0) {
        Write-Log -Message "" -Level Info
        Write-Log -Message "Clusters Blocked by SBE Prerequisites:" -Level Warning
        Write-Log -Message "  These clusters have updates that require a Solution Builder Extension (SBE) update from the hardware vendor before they can proceed." -Level Warning
        foreach ($dep in $clustersWithSBEDeps) {
            Write-Log -Message "  $($dep.ClusterName): $($dep.SBEDependency)" -Level Warning
        }
    }

    # Show health state breakdown
    $healthFailures = @($results | Where-Object { $_.HealthState -eq "Failure" }).Count
    $healthWarnings = @($results | Where-Object { $_.HealthState -eq "Warning" }).Count
    if ($healthFailures -gt 0 -or $healthWarnings -gt 0) {
        Write-Log -Message "" -Level Info
        Write-Log -Message "Health Check Issues:" -Level Header
        if ($healthFailures -gt 0) {
            Write-Log -Message "  Critical Failures:        $healthFailures" -Level Error
        }
        if ($healthWarnings -gt 0) {
            Write-Log -Message "  Warnings:                 $healthWarnings" -Level Warning
        }
    }

    # Show most common update versions
    if ($updateVersionCounts.Count -gt 0) {
        Write-Log -Message "" -Level Info
        Write-Log -Message "Available Update Versions (clusters ready to install):" -Level Header
        $sortedVersions = $updateVersionCounts.GetEnumerator() | Sort-Object -Property Value -Descending
        foreach ($version in $sortedVersions) {
            if ($readyClusters -gt 0) {
                $percentage = [math]::Round(($version.Value / $readyClusters) * 100, 1)
                Write-Log -Message "  $($version.Key): $($version.Value) cluster(s) ($percentage%)" -Level Info
            }
            else {
                Write-Log -Message "  $($version.Key): $($version.Value) cluster(s)" -Level Info
            }
        }
        
        $mostCommonVersion = ($sortedVersions | Select-Object -First 1).Key
        Write-Log -Message "" -Level Info
        Write-Log -Message "Most Common Applicable Update: $mostCommonVersion" -Level Success
    }

    # Display results table
    Write-Log -Message "" -Level Info
    Write-Log -Message "Detailed Results:" -Level Header
    $results | Format-Table ClusterName, ResourceGroup, CurrentVersion, UpdateState, HealthState, ReadyForUpdate, RecommendedUpdate -AutoSize | Out-Host
    
    # Show clusters with health check failures
    $clustersWithHealthIssues = @($results | Where-Object { $_.HealthCheckFailures -ne "" })
    if ($clustersWithHealthIssues.Count -gt 0) {
        Write-Log -Message "" -Level Info
        Write-Log -Message "Clusters with Health Check Issues:" -Level Warning
        foreach ($cluster in $clustersWithHealthIssues) {
            $issueLevel = if ($cluster.HealthState -eq "Failure") { "Error" } else { "Warning" }
            Write-Log -Message "  $($cluster.ClusterName): $($cluster.HealthCheckFailures)" -Level $issueLevel
        }
    }

    # Export if path specified
    if ($ExportPath) {
        try {
            $ExportPath = Resolve-SafeOutputPath -Path $ExportPath
            $exportDir = Split-Path -Path $ExportPath -Parent
            if ($exportDir -and -not (Test-Path $exportDir)) {
                New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
            }
            
            $format = Get-ExportFormat -Path $ExportPath -ExportFormat $ExportFormat
            
            # Transform results for JUnit-compatible format
            $junitResults = $results | ForEach-Object {
                $statusVal = if ($_.ReadyForUpdate -eq $true) {
                    'Ready'
                } elseif ($_.PSObject.Properties['BlockingReasons'] -and $_.BlockingReasons -ne '') {
                    'Blocked'
                } elseif ($_.HealthState -eq 'Failure') {
                    'Failed'
                } else {
                    'Skipped'
                }
                [PSCustomObject]@{
                    ClusterName  = $_.ClusterName
                    Status       = $statusVal
                    Message      = "CurrentVersion: $($_.CurrentVersion), CurrentSbeVersion: $($_.CurrentSbeVersion), UpdateState: $($_.UpdateState), HealthState: $($_.HealthState), RecommendedUpdate: $($_.RecommendedUpdate), BlockingReasons: $($_.BlockingReasons)"
                    UpdateName   = $_.RecommendedUpdate
                    CurrentState = $_.UpdateState
                }
            }
            
            switch ($format) {
                'Csv' {
                    $results | ConvertTo-SafeCsvCollection | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
                    Write-Log -Message "Results exported to CSV: $ExportPath" -Level Success
                }
                'Json' {
                    $exportData = @{
                        Timestamp       = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        TotalClusters   = $totalClusters
                        ClustersReady   = $readyClusters
                        ClustersNotReady = $notReadyClusters
                        Results         = $results
                    }
                    Write-Utf8NoBomFile -Path $ExportPath -Content ($exportData | ConvertTo-Json -Depth 10)
                    Write-Log -Message "Results exported to JSON: $ExportPath" -Level Success
                }
                'JUnitXml' {
                    Export-ResultsToJUnitXml -Results $junitResults -OutputPath $ExportPath `
                        -TestSuiteName "AzureLocalClusterReadiness" -OperationType "ReadinessCheck"
                    Write-Log -Message "Results exported to JUnit XML (CI/CD compatible): $ExportPath" -Level Success
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
