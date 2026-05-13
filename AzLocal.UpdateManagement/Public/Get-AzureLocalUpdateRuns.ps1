function Get-AzureLocalUpdateRuns {
    <#
    .SYNOPSIS
        Gets update run history and status for one or more Azure Local clusters.
    .DESCRIPTION
        Retrieves update run information for Azure Local (Azure Stack HCI) clusters.
        Update runs contain the history and status of update operations including
        start time, end time, progress, and any errors that occurred.
        
        Supports multiple input methods:
        - Single cluster by name (original behavior)
        - Multiple clusters by name or resource ID
        - All clusters matching an UpdateRing tag value
        
        Returns clean, human-readable objects with key information extracted from the API response.
    .PARAMETER ClusterName
        The name of a single Azure Local cluster (original behavior).
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
        The resource group containing the cluster. If not specified, searches all resource groups.
    .PARAMETER SubscriptionId
        The Azure subscription ID. If not specified, uses the current subscription context.
    .PARAMETER UpdateName
        Optional. The specific update name to get runs for. If not specified, returns runs for all updates.
    .PARAMETER Latest
        Optional. Return only the most recent update run per cluster.
    .PARAMETER Raw
        Optional. Return the raw API response objects instead of formatted output.
    .PARAMETER ApiVersion
        The Azure REST API version to use. Default is the module's default API version.
    .PARAMETER ExportPath
        Path to export the results. Supports .csv, .json, and .xml (JUnit format) extensions.
    .OUTPUTS
        PSCustomObject[] - Array of update run objects with the following properties:
        - ClusterName: The cluster name (in multi-cluster mode)
        - UpdateName: The update package name (e.g., "Solution12.2601.1002.38")
        - RunId: The unique GUID for this update run
        - State: Current state (InProgress, Succeeded, Failed, etc.)
        - StartTime: When the update run started
        - Duration: How long the update has been running or took to complete
        - Progress: Step completion progress (e.g., "3/5 steps")
        - CurrentStep: The currently executing or failed step name
        - Location: Azure region
    .EXAMPLE
        # Single cluster (original behavior)
        Get-AzureLocalUpdateRuns -ClusterName "MyCluster" -ResourceGroupName "MyRG"
    .EXAMPLE
        # Multiple clusters by tag
        Get-AzureLocalUpdateRuns -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -Latest
    .EXAMPLE
        # Export to CSV
        Get-AzureLocalUpdateRuns -ScopeByUpdateRingTag -UpdateRingValue "Production" -Latest -ExportPath "C:\Reports\runs.csv"
    .EXAMPLE
        Get-AzureLocalUpdateRuns -ClusterName "MyCluster" -Raw
        Gets raw API response for programmatic processing.
    #>
    [CmdletBinding(DefaultParameterSetName = 'SingleCluster')]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'SingleCluster')]
        [string]$ClusterName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string[]]$ClusterNames,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceId')]
        [string[]]$ClusterResourceIds,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [switch]$ScopeByUpdateRingTag,

        [ValidatePattern('^[A-Za-z0-9_-]{1,64}$')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [string]$UpdateRingValue,

        [Parameter(Mandatory = $false, ParameterSetName = 'SingleCluster')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [string]$UpdateName,

        [Parameter(Mandatory = $false)]
        [switch]$Latest,

        [Parameter(Mandatory = $false)]
        [switch]$Raw,

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

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByResourceId')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByTag')]
        [ValidateRange(1, 32)]
        [int]$ThrottleLimit = 1,

        # v0.7.1: when omitted (default), Get-AzureLocalUpdateRuns will auto-reset
        # the UpdateSideloaded tag (True->False) and clear UpdateVersionInProgress
        # for any cluster whose latest update run is Succeeded AND whose
        # UpdateVersionInProgress tag matches the run's update name. Pass this
        # switch on read-only audit pipelines that must not mutate cluster tags.
        [Parameter(Mandatory = $false)]
        [switch]$SkipSideloadedReset
    )

    # Pre-flight: Validate export path is writable before expensive operations
    if ($ExportPath) {
        try { Test-ExportPathWritable -Path $ExportPath | Out-Null }
        catch { Write-Warning $_.Exception.Message; return }
    }

    # Original single-cluster behavior
    if ($PSCmdlet.ParameterSetName -eq 'SingleCluster') {
        Test-AzCliAvailable | Out-Null
        Write-Log -Message "" -Level Info
        Write-Log -Message "========================================" -Level Header
        Write-Log -Message "Azure Local Cluster Update Runs" -Level Header
        Write-Log -Message "========================================" -Level Header
        Write-Log -Message "Cluster: $ClusterName" -Level Info

        if (-not $SubscriptionId) {
            $SubscriptionId = (az account show --query id -o tsv)
            Write-Log -Message "Using current subscription: $SubscriptionId" -Level Info
        }

        Write-Log -Message "Looking up cluster resource..." -Level Info
        $clusterInfo = Get-AzureLocalClusterInfo -ClusterName $ClusterName `
            -ResourceGroupName $ResourceGroupName `
            -SubscriptionId $SubscriptionId `
            -ApiVersion $ApiVersion

        if (-not $clusterInfo) {
            Write-Log -Message "Cluster '$ClusterName' not found." -Level Error
            return $null
        }
        Write-Log -Message "Found cluster: $($clusterInfo.id)" -Level Success

        Write-Log -Message "Querying update runs..." -Level Info
        $allRuns = Get-AzLocalClusterUpdateRuns -resourceId $clusterInfo.id -updateNameFilter $UpdateName -apiVer $ApiVersion
        Write-Log -Message "Found $($allRuns.Count) update run(s)" -Level $(if ($allRuns.Count -gt 0) { "Success" } else { "Warning" })

        if ($Raw) {
            if ($Latest) {
                return $allRuns | Sort-Object { $_.properties.timeStarted } -Descending | Select-Object -First 1
            }
            return $allRuns
        }

        # Format runs
        $formattedRuns = [System.Collections.Generic.List[object]]::new()
        foreach ($run in $allRuns) {
            $formattedRuns.Add((Format-AzLocalUpdateRun -run $run -clusterName $ClusterName -clusterResourceId $clusterInfo.id)) | Out-Null
        }

        $formattedRuns = @($formattedRuns | Sort-Object StartTime -Descending)

        if ($Latest) {
            $formattedRuns = @($formattedRuns | Select-Object -First 1)
        }

        if ($formattedRuns.Count -gt 0) {
            Write-Log -Message "" -Level Info
            Write-Log -Message "Update Runs for Cluster: $ClusterName" -Level Header
            Write-Log -Message ("=" * 60) -Level Header
            $formattedRuns | Format-Table -AutoSize | Out-String | Write-Host

            # If the latest run failed due to health check, show blocking health failures
            $latestRun = $formattedRuns | Select-Object -First 1
            if ($latestRun.State -eq "Failed" -and $latestRun.CurrentStep -match "health check") {
                Write-Log -Message "The latest update run was blocked by health check failures." -Level Warning
                Write-Log -Message "Querying current health check status..." -Level Info
                $healthResults = Test-AzureLocalClusterHealth -ClusterResourceIds @($clusterInfo.id) -BlockingOnly
                if ($healthResults -and $healthResults[0].CriticalCount -gt 0) {
                    Write-Log -Message "" -Level Info
                    Write-Log -Message "The following critical health issues must be resolved before this update can proceed:" -Level Error
                    foreach ($failure in $healthResults[0].Failures) {
                        $nodeInfo = if ($failure.TargetResourceName) { " (Node: $($failure.TargetResourceName))" } else { "" }
                        Write-Log -Message "  [Critical] $($failure.CheckName)$nodeInfo`: $($failure.Description)" -Level Error
                        if ($failure.Remediation) {
                            Write-Log -Message "    Remediation: $($failure.Remediation)" -Level Warning
                        }
                    }
                }
            }
        }
        else {
            Write-Log -Message "" -Level Info
            Write-Log -Message "No update runs found for cluster '$ClusterName'" -Level Warning
        }

        # Display latest run details
        if ($formattedRuns.Count -gt 0) {
            Write-Log -Message "" -Level Info
            Write-Log -Message "Latest Update Run:" -Level Header
            Write-Host ""
            $formattedRuns | Select-Object -First 1 | Format-List | Out-String -Stream | ForEach-Object {
                if ($_ -ne "") { Write-Host "`t$_" }
            }
            Write-Host ""
        }

        # v0.7.1: Sideloaded auto-reset (default ON; -SkipSideloadedReset to disable).
        if (-not $SkipSideloadedReset -and $formattedRuns.Count -gt 0) {
            try {
                [void](Invoke-AzLocalSideloadedAutoReset -FormattedRuns $formattedRuns -ApiVersion $ApiVersion)
            }
            catch {
                Write-Log -Message "Sideloaded auto-reset failed: $($_.Exception.Message)" -Level Warning
            }
        }

        if ($PassThru) {
            return $formattedRuns
        }
        return
    }

    # Multi-cluster mode
    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Azure Local Update Runs (Fleet)" -Level Header
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
        
        $argQuery = "resources | where type =~ 'microsoft.azurestackhci/clusters' | where tags['UpdateRing'] =~ '$($UpdateRingValue -replace "'", "''")' | project id, name, resourceGroup, subscriptionId, tags"
        
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
    Write-Log -Message "Querying update runs for $($clustersToProcess.Count) cluster(s)..." -Level Info

    # Collect results
    $allFormattedRuns = [System.Collections.Generic.List[object]]::new()
    $stateCounts = @{}

    # Per-cluster update-runs scriptblock. Runs inline (ThrottleLimit=1)
    # or inside Start-Job (ThrottleLimit>1). Emits a structured shape the
    # parent replays deterministically: Rows (formatted run rows already
    # flattened) plus LatestState for tally + coloured display. Format-
    # AzLocalUpdateRun and Get-AzLocalClusterUpdateRuns are module-private
    # (filtered out by Export-ModuleMember), so when this scriptblock runs
    # inside a Start-Job runspace they are NOT visible at script scope after
    # Import-Module. We therefore re-import the module with -PassThru and
    # invoke the private helpers via the module's own session state using
    # & $module { ... }, which is the supported pattern for reaching
    # non-exported helpers from a child runspace. The inline (ThrottleLimit=1)
    # path runs in the parent runspace where the module's script scope is
    # already active, so the same scriptblock works there too because
    # Get-Module returns the already-loaded module.
    $runsJob = {
        param(
            [object[]]$Shard,
            [string]$ApiVer,
            [string]$UpdateNameFilter,
            [bool]$LatestOnly,
            [string]$ModulePath
        )
        # Always resolve a module reference (PassThru import in child runspace,
        # already-loaded module in the inline parent runspace). $mod is then
        # used to bridge into the module's session state for private helpers.
        $mod = Get-Module -Name AzLocal.UpdateManagement | Select-Object -First 1
        if (-not $mod) {
            $mod = Import-Module $ModulePath -Force -PassThru -ErrorAction Stop
        }
        $out = foreach ($cluster in $Shard) {
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
                        ClusterName  = $clusterName
                        DisplayTag   = 'NotFound'
                        LatestState  = $null
                        RunCount     = 0
                        Rows         = @([PSCustomObject]@{
                                ClusterName       = $clusterName
                                ClusterResourceId = $null
                                UpdateName        = 'N/A'
                                RunId             = ''
                                State             = 'Cluster Not Found'
                                StartTime         = ''
                                EndTime           = ''
                                Duration          = ''
                                Progress          = ''
                                CurrentStep       = ''
                                CurrentStepDetail = ''
                                Location          = ''
                            })
                    }
                    continue
                }

                $runs = @(& $mod {
                        param($rid, $filter, $ver)
                        Get-AzLocalClusterUpdateRuns -resourceId $rid -updateNameFilter $filter -apiVer $ver
                    } $resourceId $UpdateNameFilter $ApiVer)

                if ($runs.Count -gt 0) {
                    $latestRun = $runs | Sort-Object { $_.properties.timeStarted } -Descending | Select-Object -First 1
                    $latestState = $latestRun.properties.state
                    $runsToFormat = if ($LatestOnly) { @($latestRun) } else { $runs }

                    $rows = foreach ($run in $runsToFormat) {
                        $formatted = & $mod {
                            param($r, $cn, $crid)
                            Format-AzLocalUpdateRun -run $r -clusterName $cn -clusterResourceId $crid
                        } $run $clusterName $resourceId
                        [PSCustomObject]@{
                            ClusterName       = $clusterName
                            ClusterResourceId = $resourceId
                            UpdateName        = $formatted.UpdateName
                            RunId             = $formatted.RunId
                            State             = $formatted.State
                            StartTime         = $formatted.StartTime
                            EndTime           = $formatted.EndTime
                            Duration          = $formatted.Duration
                            Progress          = $formatted.Progress
                            CurrentStep       = $formatted.CurrentStep
                            CurrentStepDetail = $formatted.CurrentStepDetail
                            Location          = $formatted.Location
                        }
                    }

                    [PSCustomObject]@{
                        ClusterName = $clusterName
                        DisplayTag  = 'Runs'
                        LatestState = $latestState
                        RunCount    = $runs.Count
                        Rows        = @($rows)
                    }
                }
                else {
                    [PSCustomObject]@{
                        ClusterName = $clusterName
                        DisplayTag  = 'NoRuns'
                        LatestState = $null
                        RunCount    = 0
                        Rows        = @([PSCustomObject]@{
                                ClusterName       = $clusterName
                                ClusterResourceId = $resourceId
                                UpdateName        = 'None'
                                RunId             = ''
                                State             = 'No Runs'
                                StartTime         = ''
                                EndTime           = ''
                                Duration          = ''
                                Progress          = ''
                                CurrentStep       = ''
                                CurrentStepDetail = ''
                                Location          = ''
                            })
                    }
                }
            }
            catch {
                $msg = $_.Exception.Message
                [PSCustomObject]@{
                    ClusterName = $clusterName
                    DisplayTag  = "Error:$msg"
                    LatestState = $null
                    RunCount    = 0
                    Rows        = @([PSCustomObject]@{
                            ClusterName       = $clusterName
                            ClusterResourceId = $resourceId
                            UpdateName        = 'Error'
                            RunId             = ''
                            State             = 'Error'
                            StartTime         = ''
                            EndTime           = ''
                            Duration          = ''
                            Progress          = ''
                            CurrentStep       = $msg
                            CurrentStepDetail = $msg
                            Location          = ''
                        })
                }
            }
        }
        return , @($out)
    }

    $shardInputs = @($clustersToProcess | ForEach-Object {
            [PSCustomObject]@{
                ResourceId     = $_.ResourceId
                Name           = $_.Name
                ResourceGroup  = $_.ResourceGroup
                SubscriptionId = $_.SubscriptionId
            }
        })

    $latestOnly = [bool]$Latest
    $jobResults = Invoke-FleetJobsInParallel `
        -InputItems $shardInputs `
        -ScriptBlock $runsJob `
        -ThrottleLimit $ThrottleLimit `
        -ArgumentList @($ApiVersion, [string]$UpdateName, $latestOnly) `
        -ActivityName 'UpdateRuns'

    # Merge shard outputs into a hash keyed by ClusterName for ordered replay.
    $perCluster = @{}
    foreach ($jr in $jobResults) {
        if ($jr.Failed) {
            foreach ($item in @($jr.Items)) {
                $perCluster[$item.Name] = [PSCustomObject]@{
                    ClusterName = $item.Name
                    DisplayTag  = "Error:Batch job failed: $($jr.Error)"
                    LatestState = $null
                    RunCount    = 0
                    Rows        = @([PSCustomObject]@{
                            ClusterName       = $item.Name
                            ClusterResourceId = $item.ResourceId
                            UpdateName        = 'Error'
                            RunId             = ''
                            State             = 'Error'
                            StartTime         = ''
                            EndTime           = ''
                            Duration          = ''
                            Progress          = ''
                            CurrentStep       = "Batch job failed: $($jr.Error)"
                            CurrentStepDetail = "Batch job failed: $($jr.Error)"
                            Location          = ''
                        })
                }
            }
            continue
        }
        foreach ($entry in @($jr.Output)) {
            if (-not $entry -or -not $entry.ClusterName) { continue }
            $perCluster[$entry.ClusterName] = $entry
        }
    }

    foreach ($cluster in $clustersToProcess) {
        $entry = $perCluster[$cluster.Name]
        if (-not $entry) { continue }

        Write-Host "  Checking: $($cluster.Name)..." -ForegroundColor Gray -NoNewline
        switch -Regex ($entry.DisplayTag) {
            '^NotFound$' { Write-Host ' Not Found' -ForegroundColor Red }
            '^NoRuns$'   { Write-Host ' No runs' -ForegroundColor Gray }
            '^Error:(.*)' { Write-Host " Error: $($matches[1])" -ForegroundColor Red }
            '^Runs$' {
                $stateColor = switch ($entry.LatestState) {
                    'Succeeded'  { 'Green' }
                    'InProgress' { 'Yellow' }
                    'Failed'     { 'Red' }
                    default      { 'Gray' }
                }
                Write-Host " $($entry.RunCount) run(s), latest: $($entry.LatestState)" -ForegroundColor $stateColor

                if ($entry.LatestState) {
                    if ($stateCounts.ContainsKey($entry.LatestState)) {
                        $stateCounts[$entry.LatestState]++
                    }
                    else {
                        $stateCounts[$entry.LatestState] = 1
                    }
                }
            }
            default { Write-Host '' -ForegroundColor Gray }
        }

        foreach ($row in @($entry.Rows)) {
            $allFormattedRuns.Add($row) | Out-Null
        }
    }

    # Display Summary
    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Summary" -Level Header
    Write-Log -Message "========================================" -Level Header
    
    $totalClusters = $clustersToProcess.Count
    Write-Log -Message "" -Level Info
    Write-Log -Message "Total Clusters: $totalClusters" -Level Info
    
    if ($stateCounts.Count -gt 0) {
        Write-Log -Message "Latest Run States:" -Level Header
        foreach ($state in $stateCounts.Keys | Sort-Object) {
            $level = switch ($state) {
                "Succeeded" { "Success" }
                "Failed" { "Error" }
                "InProgress" { "Warning" }
                default { "Info" }
            }
            Write-Log -Message "  $state`: $($stateCounts[$state])" -Level $level
        }
    }

    # Display results table
    Write-Log -Message "" -Level Info
    Write-Log -Message "Update Runs:" -Level Header
    $allFormattedRuns | Format-Table ClusterName, UpdateName, State, StartTime, EndTime, Duration, Progress -AutoSize | Out-Host

    # Check for health-check-blocked failures and show diagnostics
    $healthBlockedRuns = @($allFormattedRuns | Where-Object { $_.State -eq "Failed" -and $_.CurrentStep -match "health check" })
    if ($healthBlockedRuns.Count -gt 0) {
        $affectedClusters = @($healthBlockedRuns | Select-Object -ExpandProperty ClusterName -Unique)
        Write-Log -Message "" -Level Info
        Write-Log -Message "Detected $($healthBlockedRuns.Count) update run(s) blocked by health check failures." -Level Warning
        Write-Log -Message "Querying current health check status for affected cluster(s)..." -Level Info
        
        foreach ($affectedCluster in $affectedClusters) {
            # Find the resource ID for this cluster from the clusters we already processed
            $clusterEntry = $clustersToProcess | Where-Object { $_.Name -eq $affectedCluster }
            $rid = $clusterEntry.ResourceId
            if (-not $rid) { continue }
            
            $healthResults = Test-AzureLocalClusterHealth -ClusterResourceIds @($rid) -BlockingOnly
            if ($healthResults -and $healthResults[0].CriticalCount -gt 0) {
                Write-Log -Message "" -Level Info
                Write-Log -Message "Critical health issues blocking updates on '$affectedCluster':" -Level Error
                foreach ($failure in $healthResults[0].Failures) {
                    $nodeInfo = if ($failure.TargetResourceName) { " (Node: $($failure.TargetResourceName))" } else { "" }
                    Write-Log -Message "  [Critical] $($failure.CheckName)$nodeInfo`: $($failure.Description)" -Level Error
                    if ($failure.Remediation) {
                        Write-Log -Message "    Remediation: $($failure.Remediation)" -Level Warning
                    }
                }
            }
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
            
            switch ($format) {
                'Csv' {
                    $allFormattedRuns | ConvertTo-SafeCsvCollection | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
                    Write-Log -Message "Results exported to CSV: $ExportPath" -Level Success
                }
                'Json' {
                    $exportData = @{
                        Timestamp     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        TotalClusters = $totalClusters
                        StateSummary  = $stateCounts
                        Results       = $allFormattedRuns
                    }
                    Write-Utf8NoBomFile -Path $ExportPath -Content ($exportData | ConvertTo-Json -Depth 10)
                    Write-Log -Message "Results exported to JSON: $ExportPath" -Level Success
                }
                'JUnitXml' {
                    $junitResults = $allFormattedRuns | ForEach-Object {
                        [PSCustomObject]@{
                            ClusterName  = $_.ClusterName
                            Status       = if ($_.State -eq "Succeeded") { "Passed" } elseif ($_.State -in @("Failed", "Error")) { "Failed" } else { "Skipped" }
                            Message      = "Update: $($_.UpdateName), State: $($_.State), Duration: $($_.Duration), Progress: $($_.Progress)"
                            UpdateName   = $_.UpdateName
                            CurrentState = $_.State
                            StartTime    = $_.StartTime
                            EndTime      = $_.EndTime
                            Duration     = $_.Duration
                            Progress     = $_.Progress
                        }
                    }
                    Export-ResultsToJUnitXml -Results $junitResults -OutputPath $ExportPath `
                        -TestSuiteName "AzureLocalUpdateRuns" -OperationType "UpdateRuns"
                    Write-Log -Message "Results exported to JUnit XML: $ExportPath" -Level Success
                }
            }
        }
        catch {
            Write-Log -Message "Failed to export results: $($_.Exception.Message)" -Level Error
        }
    }

    Write-Log -Message "" -Level Info

    # Display latest run details per cluster
    if ($allFormattedRuns.Count -gt 0) {
        $latestPerCluster = $allFormattedRuns | Group-Object ClusterName | ForEach-Object {
            $_.Group | Sort-Object StartTime -Descending | Select-Object -First 1
        }
        Write-Log -Message "Latest Update Run per Cluster:" -Level Header
        Write-Host ""
        $latestPerCluster | Format-List | Out-String -Stream | ForEach-Object {
            if ($_ -ne "") { Write-Host "`t$_" }
        }
        Write-Host ""
    }

    # v0.7.1: Sideloaded auto-reset (default ON; -SkipSideloadedReset to disable).
    if (-not $SkipSideloadedReset -and $allFormattedRuns.Count -gt 0) {
        try {
            [void](Invoke-AzLocalSideloadedAutoReset -FormattedRuns $allFormattedRuns -ApiVersion $ApiVersion)
        }
        catch {
            Write-Log -Message "Sideloaded auto-reset failed: $($_.Exception.Message)" -Level Warning
        }
    }

    if ($PassThru) {
        return $allFormattedRuns
    }
}
