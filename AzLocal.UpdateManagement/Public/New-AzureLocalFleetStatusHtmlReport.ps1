function New-AzureLocalFleetStatusHtmlReport {
    <#
    .SYNOPSIS
        Generates a self-contained HTML report of fleet update status.
    
    .DESCRIPTION
        Collects update status data from Azure Local clusters and generates a standalone
        HTML report suitable for email, SharePoint, or offline viewing. The report includes
        executive summary cards, a progress bar, cluster status table with color-coded badges,
        and optional sections for health check failures and update run history.
        
        Data is collected using the module's existing functions:
        - Get-AzureLocalClusterInventory (cluster list and UpdateRing tags)
        - Get-AzureLocalClusterUpdateReadiness (health state, readiness)
        - Get-AzureLocalUpdateSummary (current update versions)
        - Get-AzureLocalAvailableUpdates (pending updates)
        - Get-AzureLocalUpdateRuns (recent update history, optional)
        - Test-AzureLocalClusterHealth (detailed health checks, optional)
    
    .PARAMETER ClusterResourceIds
        An array of full Azure Resource IDs for the clusters to include in the report.
    
    .PARAMETER ClusterNames
        An array of Azure Local cluster names to include in the report.
    
    .PARAMETER ScopeByUpdateRingTag
        Find clusters by their 'UpdateRing' tag value via Azure Resource Graph.
    
    .PARAMETER UpdateRingValue
        The value of the 'UpdateRing' tag to match when using -ScopeByUpdateRingTag.
    
    .PARAMETER ResourceGroupName
        Resource group containing the clusters (only used with -ClusterNames).
    
    .PARAMETER SubscriptionId
        Azure subscription ID (defaults to current subscription).
    
    .PARAMETER AllClusters
        Discovers all Azure Local clusters via Azure Resource Graph and includes them
        in the report. By default, no cap is applied - every discovered cluster is included.
        Use -MaxClusters to limit the number of clusters returned (e.g. for targeted runs
        or to avoid large fan-out). Uses the current Azure CLI subscription context.

    .PARAMETER MaxClusters
        Optional cap on clusters included when -AllClusters is used. Default 0 (no cap).
        Set to a positive integer (1-100000) to limit the fleet slice. Has no effect for
        other parameter sets.
    
    .PARAMETER OutputPath
        File path for the HTML report output. Required.
    
    .PARAMETER IncludeUpdateRuns
        Include recent update run history section in the report.
    
    .PARAMETER IncludeHealthDetails
        Include detailed health check failure section in the report.
    
    .PARAMETER Title
        Custom report title. Auto-generated if not specified:
        single cluster = '<ClusterName> - Update Status Report',
        multiple clusters = 'Azure Local Fleet Update Status Report'.
    
    .PARAMETER PassThru
        Returns the HTML content as a string in addition to writing the file.
    
    .OUTPUTS
        System.String - HTML content (only when -PassThru is specified).
    
    .EXAMPLE
        New-AzureLocalFleetStatusHtmlReport -AllClusters -OutputPath "C:\Reports\fleet-all.html"
        Generates an HTML report for all clusters (up to 100) across the subscription.
    
    .EXAMPLE
        New-AzureLocalFleetStatusHtmlReport -ScopeByUpdateRingTag -UpdateRingValue "Wave1" -OutputPath "C:\Reports\wave1-status.html"
        Generates an HTML report for all Wave1 clusters.
    
    .EXAMPLE
        New-AzureLocalFleetStatusHtmlReport -ClusterNames @("Cluster01","Cluster02") -OutputPath "C:\Reports\fleet.html" -IncludeHealthDetails -IncludeUpdateRuns
        Generates a full report with health details and update run history.
    
    .EXAMPLE
        $html = New-AzureLocalFleetStatusHtmlReport -ScopeByUpdateRingTag -UpdateRingValue "Production" -OutputPath "C:\Reports\prod.html" -PassThru
        Generates the report and also captures the HTML string for further use (e.g., email body).
    #>
    [CmdletBinding(DefaultParameterSetName = 'All', SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceId')]
        [string[]]$ClusterResourceIds,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string[]]$ClusterNames,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [switch]$ScopeByUpdateRingTag,

        [ValidatePattern('^[A-Za-z0-9_-]{1,64}$')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTag')]
        [string]$UpdateRingValue,

        [Parameter(Mandatory = $false, ParameterSetName = 'All')]
        [switch]$AllClusters,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByName')]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true)]
        [ValidateScript({
            $parent = Split-Path $_ -Parent
            if ($parent -and -not (Test-Path $parent)) {
                # Check if the drive at least exists
                $drive = Split-Path $_ -Qualifier -ErrorAction SilentlyContinue
                if ($drive -and -not (Test-Path $drive)) {
                    throw "Drive '$drive' does not exist. Check the output path."
                }
            }
            if ($_ -notmatch '\.html?$') {
                throw "OutputPath must end with .html extension."
            }
            $true
        })]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeUpdateRuns,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeHealthDetails,

        [Parameter(Mandatory = $false)]
        [string]$Title = "",

        [Parameter(Mandatory = $false)]
        [PSCustomObject]$StatusData,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 8)]
        [int]$ThrottleLimit = 4,

        # Optional cap on clusters returned by -AllClusters discovery. Default 0 (no cap).
        [Parameter(Mandatory = $false, ParameterSetName = 'All')]
        [ValidateRange(0, 100000)]
        [int]$MaxClusters = 0,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    Write-Log -Message "" -Level Info
    Write-Log -Message "========================================" -Level Header
    Write-Log -Message "Fleet Status HTML Report Generation" -Level Header
    Write-Log -Message "========================================" -Level Header

    # Load System.Web for HtmlEncode (XSS protection)
    Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue

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

    # If pre-collected StatusData is provided, skip all API calls and go straight to rendering
    if ($StatusData) {
        Write-Log -Message "Using pre-collected StatusData ($($StatusData.TotalClusters) clusters, collected $($StatusData.Timestamp))" -Level Info
        $readiness = @($StatusData.Readiness)
        $clusterDetails = @($StatusData.ClusterDetails)
        $latestRuns = @($StatusData.LatestRuns)
        $healthResults = @($StatusData.HealthResults)
        [array]$updateRuns = @()
        if ($IncludeUpdateRuns) { [array]$updateRuns = @($latestRuns) }
    }
    else {
        # Collect data via Get-AzureLocalFleetStatusData (single-pass, parallel-capable)
        $collectParams = @{ ThrottleLimit = $ThrottleLimit }
        if ($IncludeUpdateRuns) { $collectParams['IncludeUpdateRuns'] = $true }
        if ($IncludeHealthDetails) { $collectParams['IncludeHealthDetails'] = $true }

        switch ($PSCmdlet.ParameterSetName) {
            'ByTag'        { $collectParams['ScopeByUpdateRingTag'] = $true; $collectParams['UpdateRingValue'] = $UpdateRingValue }
            'ByResourceId' { $collectParams['ClusterResourceIds'] = $ClusterResourceIds }
            'ByName'       {
                $collectParams['ClusterNames'] = $ClusterNames
                if ($ResourceGroupName) { $collectParams['ResourceGroupName'] = $ResourceGroupName }
                if ($SubscriptionId) { $collectParams['SubscriptionId'] = $SubscriptionId }
            }
            'All'          { $collectParams['AllClusters'] = $true; $collectParams['MaxClusters'] = $MaxClusters }
        }

        $StatusData = Get-AzureLocalFleetStatusData @collectParams
        if (-not $StatusData) {
            Write-Log -Message "No data collected. Cannot generate report." -Level Warning
            return
        }

        $readiness = @($StatusData.Readiness)
        $clusterDetails = @($StatusData.ClusterDetails)
        $latestRuns = @($StatusData.LatestRuns)
        $healthResults = @($StatusData.HealthResults)
        [array]$updateRuns = @()
        if ($IncludeUpdateRuns) { [array]$updateRuns = @($latestRuns) }
    }

    if ($readiness.Count -eq 0) {
        Write-Log -Message "No clusters found. Cannot generate report." -Level Warning
        return
    }

    # Auto-generate title if not explicitly provided
    if ([string]::IsNullOrWhiteSpace($Title)) {
        if ($readiness.Count -eq 1) {
            $Title = "$($readiness[0].ClusterName) - Update Status Report"
        }
        else {
            $Title = "Azure Local Fleet Update Status Report"
        }
    }

    #--- Calculate summary statistics ---
    $totalClusters = $readiness.Count
    $upToDate   = @($readiness | Where-Object { $_.UpdateState -in @("UpToDate", "AppliedSuccessfully") }).Count
    $inProgress = @($readiness | Where-Object { $_.UpdateState -eq "UpdateInProgress" }).Count
    $updateAvailable = @($readiness | Where-Object { $_.ReadyForUpdate -eq $true }).Count
    $healthFailures  = @($readiness | Where-Object { $_.HealthState -eq "Failure" }).Count
    $otherCount = [math]::Max(0, $totalClusters - $upToDate - $inProgress - $updateAvailable - $healthFailures)

    $pctUpToDate   = if ($totalClusters -gt 0) { [math]::Round(($upToDate / $totalClusters) * 100, 1) } else { 0 }
    $pctInProgress = if ($totalClusters -gt 0) { [math]::Round(($inProgress / $totalClusters) * 100, 1) } else { 0 }
    $pctAvailable  = if ($totalClusters -gt 0) { [math]::Round(($updateAvailable / $totalClusters) * 100, 1) } else { 0 }
    $pctFailures   = if ($totalClusters -gt 0) { [math]::Round(($healthFailures / $totalClusters) * 100, 1) } else { 0 }
    $pctOther      = if ($totalClusters -gt 0) { [math]::Round(($otherCount / $totalClusters) * 100, 1) } else { 0 }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $scopeDescription = if ($StatusData.Scope) { $StatusData.Scope } else {
        switch ($PSCmdlet.ParameterSetName) {
            'ByTag'        { "UpdateRing = $UpdateRingValue" }
            'ByResourceId' { "$($ClusterResourceIds.Count) cluster(s) by Resource ID" }
            'ByName'       { "$($ClusterNames.Count) cluster(s) by name" }
            'All'          { "All clusters ($totalClusters)" }
        }
    }

    #--- Build cluster identity section HTML (used at top or bottom depending on count) ---
    $clusterIdentityHtml = [System.Text.StringBuilder]::new()
    $identitySectionTitle = if ($clusterDetails.Count -le 10) { "Cluster Information" } else { "Appendix: Cluster Information" }
    [void]$clusterIdentityHtml.Append(@"

    <div class="section">
        <h2>$([System.Web.HttpUtility]::HtmlEncode($identitySectionTitle))</h2>
        <table>
            <thead>
                <tr>
                    <th>Cluster Name</th>
                    <th>Current Version</th>
                    <th>Current SBE Version</th>
                    <th>Node Count</th>
                    <th>Resource Group</th>
                    <th>Resource ID</th>
                </tr>
            </thead>
            <tbody>
"@)
    foreach ($detail in $clusterDetails) {
        $encDetailName    = [System.Web.HttpUtility]::HtmlEncode($detail.ClusterName)
        $encDetailVersion = [System.Web.HttpUtility]::HtmlEncode($detail.CurrentVersion)
        $sbeValue         = if ($detail.PSObject.Properties['CurrentSbeVersion'] -and $detail.CurrentSbeVersion) { $detail.CurrentSbeVersion } else { 'N/A' }
        $encDetailSbe     = [System.Web.HttpUtility]::HtmlEncode($sbeValue)
        $encDetailNodes   = [System.Web.HttpUtility]::HtmlEncode($detail.NodeCount)
        $encDetailRG      = [System.Web.HttpUtility]::HtmlEncode($detail.ResourceGroup)
        $encDetailRID     = [System.Web.HttpUtility]::HtmlEncode($detail.ResourceId)
        $detailPortalUrl  = if ($detail.ResourceId) { [System.Web.HttpUtility]::HtmlEncode("https://portal.azure.com/#@/resource$($detail.ResourceId)") } else { "" }

        $detailNameCell = if ($detailPortalUrl) {
            "<a href=`"$detailPortalUrl`" class=`"portal-link`" target=`"_blank`" title=`"Open in Azure Portal`"><strong>$encDetailName</strong></a>"
        } else { "<strong>$encDetailName</strong>" }

        [void]$clusterIdentityHtml.Append(@"

                <tr>
                    <td>$detailNameCell</td>
                    <td>$encDetailVersion</td>
                    <td>$encDetailSbe</td>
                    <td>$encDetailNodes</td>
                    <td>$encDetailRG</td>
                    <td class="resource-id-cell">$encDetailRID</td>
                </tr>
"@)
    }
    [void]$clusterIdentityHtml.Append(@"

            </tbody>
        </table>
    </div>
"@)
    $clusterIdentitySection = $clusterIdentityHtml.ToString()

    #--- Build HTML ---
    Write-Log -Message "Generating HTML report..." -Level Info

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append(@"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$([System.Web.HttpUtility]::HtmlEncode($Title))</title>
    <style>
        :root {
            --success-color: #28a745;
            --failure-color: #dc3545;
            --warning-color: #ffc107;
            --info-color: #17a2b8;
            --pending-color: #6c757d;
            --bg-color: #f8f9fa;
            --card-bg: #ffffff;
            --text-color: #212529;
            --border-color: #dee2e6;
        }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: var(--bg-color);
            color: var(--text-color);
            line-height: 1.6;
            padding: 20px;
        }
        .container { max-width: 1400px; margin: 0 auto; }
        header {
            background: linear-gradient(135deg, #552F99, #B596F5);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            position: relative;
        }
        header h1 { font-size: 2em; margin-bottom: 10px; }
        header p { opacity: 0.9; }
        header .logo {
            position: absolute;
            top: 20px;
            right: 30px;
            width: 64px;
            height: 64px;
            opacity: 0.9;
        }
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }
        .summary-card {
            background: var(--card-bg);
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            border-left: 4px solid var(--border-color);
        }
        .summary-card.total      { border-left-color: #9266E6; }
        .summary-card.uptodate   { border-left-color: var(--success-color); }
        .summary-card.inprogress { border-left-color: var(--warning-color); }
        .summary-card.available  { border-left-color: var(--info-color); }
        .summary-card.failures   { border-left-color: var(--failure-color); }
        .summary-card .number {
            font-size: 2.5em; font-weight: bold; display: block;
        }
        .summary-card.total .number      { color: #9266E6; }
        .summary-card.uptodate .number   { color: var(--success-color); }
        .summary-card.inprogress .number { color: var(--warning-color); }
        .summary-card.available .number  { color: var(--info-color); }
        .summary-card.failures .number   { color: var(--failure-color); }
        .summary-card .label {
            text-transform: uppercase; font-size: 0.85em;
            color: #6c757d; letter-spacing: 1px;
        }
        .progress-bar-container {
            background: var(--card-bg);
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .progress-bar-container h3 { margin-bottom: 10px; }
        .progress {
            height: 30px; background: #e9ecef;
            border-radius: 15px; overflow: hidden; display: flex;
        }
        .progress-uptodate   { background: var(--success-color); }
        .progress-inprogress { background: var(--warning-color); }
        .progress-available  { background: var(--info-color); }
        .progress-failures   { background: var(--failure-color); }
        .progress-other      { background: var(--pending-color); }
        .section {
            background: var(--card-bg);
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            overflow-x: auto;
            margin-bottom: 20px;
        }
        .section h2 {
            background: #f1f3f5;
            padding: 15px 20px;
            border-bottom: 1px solid var(--border-color);
        }
        table {
            width: 100%; border-collapse: collapse;
            min-width: 800px;
        }
        th {
            background: #f8f9fa; padding: 12px 16px;
            text-align: left; font-weight: 600;
            border-bottom: 2px solid var(--border-color);
            white-space: nowrap;
        }
        td {
            padding: 12px 16px;
            border-bottom: 1px solid #f1f3f5;
        }
        tr:hover td { background: #f8f9fa; }
        .status-badge {
            display: inline-block; padding: 4px 12px;
            border-radius: 12px; font-size: 0.85em;
            font-weight: 600; white-space: nowrap;
        }
        .status-uptodate      { background: #d4edda; color: #155724; }
        .status-inprogress    { background: #fff3cd; color: #856404; }
        .status-available     { background: #d1ecf1; color: #0c5460; }
        .status-failure       { background: #f8d7da; color: #721c24; }
        .status-unknown       { background: #e2e3e5; color: #383d41; }
        .severity-critical    { background: #f8d7da; color: #721c24; font-weight: 600; }
        .severity-warning     { background: #fff3cd; color: #856404; }
        .severity-info        { background: #d1ecf1; color: #0c5460; }
        .message-cell {
            max-width: 500px;
            white-space: normal;
            word-wrap: break-word;
            font-size: 0.9em;
        }
        .resource-id-cell {
            font-family: 'Consolas', 'Courier New', monospace;
            font-size: 0.85em;
            white-space: nowrap;
            user-select: all;
        }
        a.portal-link {
            color: #0078d4;
            text-decoration: none;
            border-bottom: 1px dashed #0078d4;
        }
        a.portal-link:hover {
            color: #005a9e;
            border-bottom-color: #005a9e;
        }
        details {
            margin-bottom: 8px;
        }
        details summary {
            cursor: pointer;
            padding: 10px 16px;
            border-bottom: 1px solid #f1f3f5;
            font-weight: 600;
            list-style: none;
        }
        details summary::-webkit-details-marker { display: none; }
        details summary::before {
            content: '\25B6';
            display: inline-block;
            margin-right: 8px;
            transition: transform 0.2s;
            font-size: 0.8em;
        }
        details[open] summary::before {
            transform: rotate(90deg);
        }
        details[open] summary {
            border-bottom: 2px solid var(--border-color);
        }
        .failure-summary-counts {
            font-weight: normal;
            font-size: 0.9em;
            color: #6c757d;
            margin-left: 8px;
        }
        .failure-summary-top-issue {
            font-weight: normal;
            font-size: 0.85em;
            color: #495057;
            margin-left: 4px;
        }
        footer {
            text-align: center; padding: 20px;
            color: #6c757d; font-size: 0.9em;
        }
        .severity-filter {
            padding: 10px 20px;
            background: #f8f9fa;
            border-bottom: 1px solid var(--border-color);
            font-size: 0.9em;
        }
        .severity-filter label {
            margin-right: 16px;
            cursor: pointer;
            user-select: none;
        }
        .severity-filter input[type="checkbox"] {
            margin-right: 4px;
            cursor: pointer;
        }
        tr.sev-hidden { display: none; }
    </style>
    <script>
    function toggleSeverity(severity, checked) {
        var rows = document.querySelectorAll('tr.sev-' + severity);
        for (var i = 0; i < rows.length; i++) {
            if (checked) { rows[i].classList.remove('sev-hidden'); }
            else { rows[i].classList.add('sev-hidden'); }
        }
    }
    </script>
</head>
<body>
<div class="container">
    <header>
        <svg class="logo" viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg"><path d="M125.25 107.513c-1.13 4.978-7.317 9.827-18.488 13.625a152.571 152.571 0 0 1-85.704.121c-10.303-3.648-15.864-8.263-16.732-13.021-.15-.839 0-13.895 0-13.895l121.159-1.123s-.092 13.681-.235 14.293Z" fill="#5EA0EF"/><path d="M65.04 115.031c33.479-.336 60.525-9.991 60.409-21.564-.116-11.573-27.35-20.683-60.83-20.347-33.479.336-60.525 9.99-60.409 21.564.116 11.573 27.35 20.683 60.83 20.347Z" fill="#50E6FF"/><path d="M105.989 11H22.011A3.011 3.011 0 0 0 19 14.011v18.585a3.011 3.011 0 0 0 3.011 3.011h83.978a3.011 3.011 0 0 0 3.011-3.01V14.01a3.011 3.011 0 0 0-3.011-3.01Z" fill="#B596F5"/><path d="M100.23 15.307h-3.72c-.83 0-1.504.673-1.504 1.503v3.72c0 .83.673 1.503 1.503 1.503h3.721c.83 0 1.502-.673 1.502-1.503v-3.72c0-.83-.672-1.503-1.502-1.503Zm0 9.273h-3.72c-.83 0-1.504.673-1.504 1.503v3.72c0 .83.673 1.503 1.503 1.503h3.721c.83 0 1.502-.673 1.502-1.503v-3.72c0-.83-.672-1.503-1.502-1.503Z" fill="#F2F2F2"/><path d="M105.989 40.166H22.011A3.011 3.011 0 0 0 19 43.176v18.586a3.011 3.011 0 0 0 3.011 3.011h83.978a3.011 3.011 0 0 0 3.011-3.01V43.176a3.01 3.01 0 0 0-3.011-3.011Z" fill="#9266E6"/><path d="M100.23 44.467h-3.72c-.83 0-1.504.673-1.504 1.503v3.72c0 .83.673 1.503 1.503 1.503h3.721c.83 0 1.502-.673 1.502-1.503v-3.72c0-.83-.672-1.503-1.502-1.503Zm0 9.273h-3.72c-.83 0-1.504.673-1.504 1.503v3.72c0 .83.673 1.503 1.503 1.503h3.721c.83 0 1.502-.673 1.502-1.502v-3.72c0-.83-.672-1.504-1.502-1.504Z" fill="#F2F2F2"/><path d="M105.989 69.326H22.011A3.011 3.011 0 0 0 19 72.336v18.586a3.011 3.011 0 0 0 3.011 3.011h83.978a3.01 3.01 0 0 0 3.011-3.01V72.336a3.011 3.011 0 0 0-3.011-3.011Z" fill="#552F99"/><path d="M100.23 73.627h-3.72c-.83 0-1.504.673-1.504 1.503v3.72c0 .83.673 1.503 1.503 1.503h3.721c.83 0 1.502-.673 1.502-1.502V75.13c0-.83-.672-1.503-1.502-1.503Zm0 9.273h-3.72c-.83 0-1.504.673-1.504 1.503v3.72c0 .83.673 1.503 1.503 1.503h3.721c.83 0 1.502-.672 1.502-1.502v-3.72c0-.83-.672-1.504-1.502-1.504Z" fill="#F2F2F2"/></svg>
        <h1>$([System.Web.HttpUtility]::HtmlEncode($Title))</h1>
        <p>Generated $([System.Web.HttpUtility]::HtmlEncode($timestamp)) | Scope: $([System.Web.HttpUtility]::HtmlEncode($scopeDescription))</p>
    </header>

    <div class="summary">
        <div class="summary-card total">
            <span class="number">$([System.Web.HttpUtility]::HtmlEncode($totalClusters))</span>
            <span class="label">Total Clusters</span>
        </div>
        <div class="summary-card uptodate">
            <span class="number">$([System.Web.HttpUtility]::HtmlEncode($upToDate))</span>
            <span class="label">Up to Date</span>
        </div>
        <div class="summary-card inprogress">
            <span class="number">$([System.Web.HttpUtility]::HtmlEncode($inProgress))</span>
            <span class="label">In Progress</span>
        </div>
        <div class="summary-card available">
            <span class="number">$([System.Web.HttpUtility]::HtmlEncode($updateAvailable))</span>
            <span class="label">Ready for Update</span>
        </div>
        <div class="summary-card failures">
            <span class="number">$([System.Web.HttpUtility]::HtmlEncode($healthFailures))</span>
            <span class="label">Health Failures</span>
        </div>
    </div>

    <div class="progress-bar-container">
        <h3>Fleet Update Progress</h3>
        <div class="progress">
            <div class="progress-uptodate" style="width: $pctUpToDate%;" title="Up to Date: $upToDate ($pctUpToDate%)"></div>
            <div class="progress-inprogress" style="width: $pctInProgress%;" title="In Progress: $inProgress ($pctInProgress%)"></div>
            <div class="progress-available" style="width: $pctAvailable%;" title="Ready for Update: $updateAvailable ($pctAvailable%)"></div>
            <div class="progress-failures" style="width: $pctFailures%;" title="Health Failures: $healthFailures ($pctFailures%)"></div>
            <div class="progress-other" style="width: $pctOther%;" title="Other: $otherCount ($pctOther%)"></div>
        </div>
    </div>
"@)

    # Insert cluster identity section at top for 10 or fewer clusters
    if ($clusterDetails.Count -le 10) {
        [void]$sb.Append($clusterIdentitySection)
    }

    [void]$sb.Append(@"

    <div class="section">
        <h2>Cluster Status Details</h2>
        <table>
            <thead>
                <tr>
                    <th>Cluster Name</th>
                    <th>Resource Group</th>
                    <th>Update State</th>
                    <th>Health State</th>
                    <th>Ready</th>
                    <th>Active Update</th>
                    <th>Recommended Update</th>
                </tr>
            </thead>
            <tbody>
"@)

    # Pre-build hash indexes for O(1) lookups inside the per-cluster/per-run loops below.
    # Replaces repeated O(N) "Where-Object ClusterName -eq $x" scans that caused
    # quadratic time on large fleets (e.g. 500 clusters x 500 runs).
    $latestRunsByCluster = @{}
    foreach ($__r in $latestRuns) {
        if ($__r -and $__r.ClusterName -and -not $latestRunsByCluster.ContainsKey($__r.ClusterName)) {
            $latestRunsByCluster[$__r.ClusterName] = $__r
        }
    }
    $clusterDetailsByName = @{}
    foreach ($__d in $clusterDetails) {
        if ($__d -and $__d.ClusterName -and -not $clusterDetailsByName.ContainsKey($__d.ClusterName)) {
            $clusterDetailsByName[$__d.ClusterName] = $__d
        }
    }

    foreach ($cluster in $readiness) {
        $updateBadge = switch ($cluster.UpdateState) {
            'UpToDate'              { 'status-uptodate' }
            'AppliedSuccessfully'   { 'status-uptodate' }
            'UpdateInProgress'      { 'status-inprogress' }
            'UpdateFailed'          { 'status-failure' }
            'UpdateAvailable'       { 'status-available' }
            'Ready'                 { 'status-available' }
            default                 { 'status-unknown' }
        }
        $healthBadge = switch ($cluster.HealthState) {
            'Success' { 'status-uptodate' }
            'Failure' { 'status-failure' }
            'Warning' { 'status-inprogress' }
            default   { 'status-unknown' }
        }
        $readyText = if ($cluster.ReadyForUpdate) { "Yes" } else { "No" }
        $encReadyText = [System.Web.HttpUtility]::HtmlEncode($readyText)

        # Determine active update (in-progress or failed) from latest run data
        $activeUpdate = ""
        $activeUpdateBadge = ""
        $activeUpdateName = ""
        $recommendedDisplay = $cluster.RecommendedUpdate
        $clusterLatestRun = if ($cluster.ClusterName -and $latestRunsByCluster.ContainsKey($cluster.ClusterName)) { $latestRunsByCluster[$cluster.ClusterName] } else { $null }
        if ($clusterLatestRun -and $clusterLatestRun.State -in @("InProgress", "Failed")) {
            $activeUpdate = "$($clusterLatestRun.UpdateName) ($($clusterLatestRun.State))"
            $activeUpdateName = $clusterLatestRun.UpdateName
            $activeUpdateBadge = if ($clusterLatestRun.State -eq "InProgress") { "status-inprogress" } else { "status-failure" }
            # Show N/A for recommended when there's an active update that must be completed
            $recommendedDisplay = "N/A"
        }

        # Build portal URLs
        $clusterResourceId = if ($cluster.ClusterName -and $clusterDetailsByName.ContainsKey($cluster.ClusterName)) { $clusterDetailsByName[$cluster.ClusterName].ResourceId } else { $null }
        $clusterPortalUrl = if ($clusterResourceId) { [System.Web.HttpUtility]::HtmlEncode("https://portal.azure.com/#@/resource$clusterResourceId") } else { "" }
        $updatePortalUrl = if ($clusterResourceId -and $activeUpdateName) { [System.Web.HttpUtility]::HtmlEncode("https://portal.azure.com/#@/resource$clusterResourceId/updates") } else { "" }

        $encName    = [System.Web.HttpUtility]::HtmlEncode($cluster.ClusterName)
        $encRG      = [System.Web.HttpUtility]::HtmlEncode($cluster.ResourceGroup)
        $encUpdate  = [System.Web.HttpUtility]::HtmlEncode($cluster.UpdateState)
        $encHealth  = [System.Web.HttpUtility]::HtmlEncode($cluster.HealthState)
        $encActive  = [System.Web.HttpUtility]::HtmlEncode($activeUpdate)
        $encRecommended = [System.Web.HttpUtility]::HtmlEncode($recommendedDisplay)

        # Cluster name as portal link
        $nameCell = if ($clusterPortalUrl) {
            "<a href=`"$clusterPortalUrl`" class=`"portal-link`" target=`"_blank`" title=`"Open in Azure Portal`"><strong>$encName</strong></a>"
        } else { "<strong>$encName</strong>" }

        # Active update as portal link
        $activeCell = if ($activeUpdate -and $updatePortalUrl) {
            "<a href=`"$updatePortalUrl`" class=`"portal-link`" target=`"_blank`" title=`"View updates in Azure Portal`"><span class=`"status-badge $activeUpdateBadge`">$encActive</span></a>"
        } elseif ($activeUpdate) {
            "<span class=`"status-badge $activeUpdateBadge`">$encActive</span>"
        } else { "" }

        [void]$sb.Append(@"

                <tr>
                    <td>$nameCell</td>
                    <td>$encRG</td>
                    <td><span class="status-badge $updateBadge">$encUpdate</span></td>
                    <td><span class="status-badge $healthBadge">$encHealth</span></td>
                    <td>$encReadyText</td>
                    <td>$activeCell</td>
                    <td>$encRecommended</td>
                </tr>
"@)
    }

    [void]$sb.Append(@"

            </tbody>
        </table>
    </div>
"@)

    #--- Update Run History section (optional) ---
    if ($IncludeUpdateRuns -and $updateRuns.Count -gt 0) {
        # Only show the Attempts column if at least one update had multiple attempts,
        # so the common case (all successes on first try) stays visually clean.
        $showAttempts = @($updateRuns | Where-Object { $_.PSObject.Properties['Attempts'] -and [int]$_.Attempts -gt 1 }).Count -gt 0
        [void]$sb.Append(@"

    <div class="section">
        <h2>Recent Update Run History</h2>
        <table>
            <thead>
                <tr>
                    <th>Cluster</th>
                    <th>Update Name</th>
                    <th>State</th>
                    <th>Progress</th>
                    <th>Current Step</th>
$(if ($showAttempts) { "                    <th>Update Attempts</th>`n" })                    <th>Duration</th>
                    <th>Start Time</th>
                    <th>End Time</th>
                </tr>
            </thead>
            <tbody>
"@)
        foreach ($run in $updateRuns) {
            $runBadge = switch ($run.State) {
                'Succeeded'  { 'status-uptodate' }
                'Failed'     { 'status-failure' }
                'InProgress' { 'status-inprogress' }
                default      { 'status-unknown' }
            }
            # Build portal links for cluster and update (uses $clusterDetailsByName pre-built above)
            $runClusterRid = if ($run.ClusterName -and $clusterDetailsByName.ContainsKey($run.ClusterName)) { $clusterDetailsByName[$run.ClusterName].ResourceId } else { $null }
            $runClusterUrl = if ($runClusterRid) { [System.Web.HttpUtility]::HtmlEncode("https://portal.azure.com/#@/resource$runClusterRid") } else { "" }
            $runUpdateUrl  = if ($runClusterRid) { [System.Web.HttpUtility]::HtmlEncode("https://portal.azure.com/#@/resource$runClusterRid/updates") } else { "" }

            $encRunCluster  = [System.Web.HttpUtility]::HtmlEncode($run.ClusterName)
            $encRunUpdate   = [System.Web.HttpUtility]::HtmlEncode($run.UpdateName)
            $encRunState    = [System.Web.HttpUtility]::HtmlEncode($run.State)
            $encRunProgress = [System.Web.HttpUtility]::HtmlEncode($run.Progress)
            $encRunStep     = [System.Web.HttpUtility]::HtmlEncode($run.CurrentStepDetail)
            $encRunDuration = [System.Web.HttpUtility]::HtmlEncode($run.Duration)
            $encRunStart    = [System.Web.HttpUtility]::HtmlEncode($run.StartTime)
            $encRunEnd      = if ($run.PSObject.Properties['EndTime']) { [System.Web.HttpUtility]::HtmlEncode($run.EndTime) } else { '' }
            $runAttempts    = if ($run.PSObject.Properties['Attempts'] -and $run.Attempts) { [int]$run.Attempts } else { 1 }
            $encRunAttempts = [System.Web.HttpUtility]::HtmlEncode([string]$runAttempts)

            $runClusterCell = if ($runClusterUrl) {
                "<a href=`"$runClusterUrl`" class=`"portal-link`" target=`"_blank`"><strong>$encRunCluster</strong></a>"
            } else { "<strong>$encRunCluster</strong>" }

            $runUpdateCell = if ($runUpdateUrl) {
                "<a href=`"$runUpdateUrl`" class=`"portal-link`" target=`"_blank`" title=`"View update history in Azure Portal`">$encRunUpdate</a>"
            } else { $encRunUpdate }

            [void]$sb.Append(@"

                <tr>
                    <td>$runClusterCell</td>
                    <td>$runUpdateCell</td>
                    <td><span class="status-badge $runBadge">$encRunState</span></td>
                    <td>$encRunProgress</td>
                    <td class="message-cell" title="$encRunStep">$encRunStep</td>
$(if ($showAttempts) { "                    <td>$encRunAttempts</td>`n" })                    <td>$encRunDuration</td>
                    <td>$encRunStart</td>
                    <td>$encRunEnd</td>
                </tr>
"@)
        }

        [void]$sb.Append(@"

            </tbody>
        </table>
    </div>
"@)
    }

    #--- Health Check Failures section (optional) ---
    if ($IncludeHealthDetails -and $healthResults.Count -gt 0) {
        $allFailures = @($healthResults | ForEach-Object { $_.Failures } | Where-Object { $_ })
        if ($allFailures.Count -gt 0) {
            $uniqueFailureClusters = @($allFailures | Select-Object -ExpandProperty ClusterName -Unique)

            # Pre-group failures by ClusterName for O(1) lookups in the per-cluster loop below.
            $failuresByCluster = @{}
            foreach ($__f in $allFailures) {
                if (-not $__f -or -not $__f.ClusterName) { continue }
                if (-not $failuresByCluster.ContainsKey($__f.ClusterName)) {
                    $failuresByCluster[$__f.ClusterName] = [System.Collections.Generic.List[object]]::new()
                }
                [void]$failuresByCluster[$__f.ClusterName].Add($__f)
            }

            if ($uniqueFailureClusters.Count -le 1) {
                # Single cluster: flat table (no collapsing)
                [void]$sb.Append(@"

    <div class="section">
        <h2>Health Check Failures</h2>
        <div class="severity-filter">
            Filter by Severity:
            <label><input type="checkbox" checked onchange="toggleSeverity('critical', this.checked)"> Critical</label>
            <label><input type="checkbox" checked onchange="toggleSeverity('warning', this.checked)"> Warning</label>
            <label><input type="checkbox" onchange="toggleSeverity('informational', this.checked)"> Informational</label>
        </div>
        <table>
            <thead>
                <tr>
                    <th>Cluster</th>
                    <th>Severity</th>
                    <th>Check Name</th>
                    <th>Target</th>
                    <th>Description</th>
                    <th>Remediation</th>
                </tr>
            </thead>
            <tbody>
"@)
                foreach ($failure in $allFailures) {
                    $sevBadge = switch ($failure.Severity) {
                        'Critical'      { 'severity-critical' }
                        'Warning'       { 'severity-warning' }
                        'Informational' { 'severity-info' }
                        default         { 'status-unknown' }
                    }
                    $sevClass = "sev-$($failure.Severity.ToLower())"
                    $sevHidden = if ($failure.Severity -eq 'Informational') { ' sev-hidden' } else { '' }
                    $encCluster = [System.Web.HttpUtility]::HtmlEncode($failure.ClusterName)
                    $encSev     = [System.Web.HttpUtility]::HtmlEncode($failure.Severity)
                    $encCheck   = [System.Web.HttpUtility]::HtmlEncode($failure.CheckName)
                    $encTarget  = [System.Web.HttpUtility]::HtmlEncode($failure.TargetResourceName)
                    $encDesc    = [System.Web.HttpUtility]::HtmlEncode($failure.Description)
                    $encRemed   = [System.Web.HttpUtility]::HtmlEncode($failure.Remediation)

                    [void]$sb.Append(@"

                <tr class="$sevClass$sevHidden">
                    <td><strong>$encCluster</strong></td>
                    <td><span class="status-badge $sevBadge">$encSev</span></td>
                    <td>$encCheck</td>
                    <td>$encTarget</td>
                    <td class="message-cell" title="$encDesc">$encDesc</td>
                    <td class="message-cell" title="$encRemed">$encRemed</td>
                </tr>
"@)
                }

                [void]$sb.Append(@"

            </tbody>
        </table>
    </div>
"@)
            }
            else {
                # Multiple clusters: collapsible per-cluster groups
                [void]$sb.Append(@"

    <div class="section">
        <h2>Health Check Failures</h2>
        <div class="severity-filter">
            Filter by Severity:
            <label><input type="checkbox" checked onchange="toggleSeverity('critical', this.checked)"> Critical</label>
            <label><input type="checkbox" checked onchange="toggleSeverity('warning', this.checked)"> Warning</label>
            <label><input type="checkbox" onchange="toggleSeverity('informational', this.checked)"> Informational</label>
        </div>
"@)
                foreach ($clusterGroup in $uniqueFailureClusters) {
                    $clusterFailures = if ($failuresByCluster.ContainsKey($clusterGroup)) { @($failuresByCluster[$clusterGroup]) } else { @() }
                    $critCount = @($clusterFailures | Where-Object { $_.Severity -eq 'Critical' }).Count
                    $warnCount = @($clusterFailures | Where-Object { $_.Severity -eq 'Warning' }).Count
                    $infoCount = @($clusterFailures | Where-Object { $_.Severity -eq 'Informational' }).Count

                    # Determine worst severity badge and top issue
                    $worstBadge = if ($critCount -gt 0) { 'severity-critical' } elseif ($warnCount -gt 0) { 'severity-warning' } else { 'severity-info' }
                    $worstLabel = if ($critCount -gt 0) { 'Critical' } elseif ($warnCount -gt 0) { 'Warning' } else { 'Informational' }
                    $topIssue = ($clusterFailures | Sort-Object { switch ($_.Severity) { 'Critical' { 0 } 'Warning' { 1 } default { 2 } } } | Select-Object -First 1).CheckName

                    # Build count summary
                    $countParts = @()
                    if ($critCount -gt 0) { $countParts += "$critCount Critical" }
                    if ($warnCount -gt 0) { $countParts += "$warnCount Warning" }
                    if ($infoCount -gt 0) { $countParts += "$infoCount Informational" }
                    $countSummary = $countParts -join ', '

                    $encGroupName = [System.Web.HttpUtility]::HtmlEncode($clusterGroup)
                    $encTopIssue  = [System.Web.HttpUtility]::HtmlEncode($topIssue)

                    [void]$sb.Append(@"

        <details>
            <summary>
                <strong>$encGroupName</strong>
                <span class="status-badge $worstBadge">$([System.Web.HttpUtility]::HtmlEncode($worstLabel))</span>
                <span class="failure-summary-counts">$([System.Web.HttpUtility]::HtmlEncode($countSummary))</span>
                <span class="failure-summary-top-issue">| $encTopIssue</span>
            </summary>
            <table>
                <thead>
                    <tr>
                        <th>Severity</th>
                        <th>Check Name</th>
                        <th>Target</th>
                        <th>Description</th>
                        <th>Remediation</th>
                    </tr>
                </thead>
                <tbody>
"@)
                    foreach ($failure in $clusterFailures) {
                        $sevBadge = switch ($failure.Severity) {
                            'Critical'      { 'severity-critical' }
                            'Warning'       { 'severity-warning' }
                            'Informational' { 'severity-info' }
                            default         { 'status-unknown' }
                        }
                        $sevClass = "sev-$($failure.Severity.ToLower())"
                        $sevHidden = if ($failure.Severity -eq 'Informational') { ' sev-hidden' } else { '' }
                        $encSev    = [System.Web.HttpUtility]::HtmlEncode($failure.Severity)
                        $encCheck  = [System.Web.HttpUtility]::HtmlEncode($failure.CheckName)
                        $encTarget = [System.Web.HttpUtility]::HtmlEncode($failure.TargetResourceName)
                        $encDesc   = [System.Web.HttpUtility]::HtmlEncode($failure.Description)
                        $encRemed  = [System.Web.HttpUtility]::HtmlEncode($failure.Remediation)

                        [void]$sb.Append(@"

                    <tr class="$sevClass$sevHidden">
                        <td><span class="status-badge $sevBadge">$encSev</span></td>
                        <td>$encCheck</td>
                        <td>$encTarget</td>
                        <td class="message-cell" title="$encDesc">$encDesc</td>
                        <td class="message-cell" title="$encRemed">$encRemed</td>
                    </tr>
"@)
                    }

                    [void]$sb.Append(@"

                </tbody>
            </table>
        </details>
"@)
                }

                [void]$sb.Append(@"

    </div>
"@)
            }
        }
    }

    #--- Cluster identity appendix for large fleets (>10 clusters) ---
    if ($clusterDetails.Count -gt 10) {
        [void]$sb.Append($clusterIdentitySection)
    }

    #--- Footer ---
    $moduleVersion = (Get-Module AzLocal.UpdateManagement | Select-Object -First 1).Version
    if (-not $moduleVersion) {
        # $PSScriptRoot resolves to Public/ (not the module root) because this
        # file is loaded via NestedModules. Use Get-AzLocalModuleRootManifestPath
        # to locate the manifest at the module root.
        $manifestPath = Get-AzLocalModuleRootManifestPath -CallerScriptPath $PSCommandPath
        if ($manifestPath -and (Test-Path -LiteralPath $manifestPath) -and ($manifestPath -like '*.psd1')) {
            $manifest = Import-PowerShellDataFile -Path $manifestPath -ErrorAction SilentlyContinue
            $moduleVersion = $manifest.ModuleVersion
        }
        if (-not $moduleVersion) { $moduleVersion = "unknown" }
    }

    [void]$sb.Append(@"

    <footer>
        <p>Generated by AzLocal.UpdateManagement v$moduleVersion | $timestamp</p>
        <p>This report is provided as-is with no warranty. Not a Microsoft supported service offering.</p>
    </footer>
</div>
</body>
</html>
"@)

    $htmlContent = $sb.ToString()

    #--- Write to file ---
    if (-not $PSCmdlet.ShouldProcess($OutputPath, 'Write HTML fleet status report')) {
        return $htmlContent
    }
    $OutputPath = Resolve-SafeOutputPath -Path $OutputPath
    $outputDir = Split-Path -Path $OutputPath -Parent
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    # Write UTF-8 *without* BOM. PowerShell 5.1's Out-File -Encoding UTF8
    # emits a BOM which breaks some browsers' rendering of the first bytes
    # and confuses downstream tooling (grep/diff/CI log viewers).
    Write-Utf8NoBomFile -Path $OutputPath -Content $htmlContent

    Write-Log -Message "" -Level Info
    Write-Log -Message "HTML fleet status report written to: $OutputPath" -Level Success
    try {
        $fullPath = (Resolve-Path $OutputPath -ErrorAction Stop).Path
        $fileUri = "file:///$($fullPath -replace '\\', '/')"
        Write-Log -Message "  Open report: $fileUri" -Level Info
    }
    catch {
        Write-Log -Message "  Open report: $OutputPath" -Level Info
    }
    Write-Log -Message "  Total Clusters: $totalClusters | Up to Date: $upToDate | In Progress: $inProgress | Ready: $updateAvailable | Failures: $healthFailures" -Level Info

    if ($PassThru) {
        return $htmlContent
    }
}
