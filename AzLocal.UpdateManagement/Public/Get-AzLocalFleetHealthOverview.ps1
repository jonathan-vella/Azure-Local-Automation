function Get-AzLocalFleetHealthOverview {
    <#
    .SYNOPSIS
        Returns one row per Azure Local cluster summarising health state,
        update state, current version, SBE version, Azure connectivity, and
        the age (in days) of the last 24-hour health-check run, so an
        operator can see the whole fleet's readiness at a glance.

    .DESCRIPTION
        Returns an ARG-first fleet health summary, one row per cluster:
        joins the `microsoft.azurestackhci/clusters` resource (for cluster
        identity, tags, node count, Azure connectivity) with its
        `updateSummaries/default` child (for healthState, update state,
        currentVersion, healthCheckDate, packageVersions[]). Solution
        Builder Extension (SBE) version is rolled up from packageVersions
        by `mv-expand` + `maxif(packageType =~ 'SBE')` so callers get one
        SbeVersion column per cluster regardless of how many package rows
        the cluster reports.

        Where the existing `Get-AzureLocalFleetHealthFailures` cmdlet
        focuses on individual failing checks, this cmdlet answers
        "how is the fleet doing overall?" - one row per cluster, sorted
        with the staleest health-check result first (HealthResultsAgeDays
        desc) so out-of-date check runs surface immediately.

        The query runs through the module's `Invoke-AzResourceGraphQuery`
        helper, which transparently pages for fleets larger than 1000
        clusters.

    .PARAMETER SubscriptionId
        Optional. Limit the query to a specific Azure subscription ID.
        Omit to query every subscription the caller can read.

    .PARAMETER UpdateRingTag
        Optional UpdateRing tag filter. Accepts the same syntax as the
        rest of the module: a single ring (e.g. 'Wave1'),
        semicolon-delimited list (e.g. 'Wave1;Wave2'), or the literal
        '***' wildcard. ValidatePattern rejects '*', '**', '****' so a
        single-character typo cannot accidentally widen the scope.

    .PARAMETER ExportPath
        Optional. Path to export the result. Format is auto-detected from
        the file extension (.csv or .json).

    .PARAMETER PassThru
        Return objects to the pipeline even when -ExportPath is specified.

    .OUTPUTS
        PSCustomObject[] with the columns (in this order):
          ClusterName, ClusterPortalUrl, HealthStatus, UpdateStatus,
          CurrentVersion, SbeVersion, AzureConnection, LastChecked,
          HealthResultsAgeDays, ResourceGroup, NodeCount, SubscriptionId.

        HealthStatus values: Healthy, Critical, Warning, In progress,
        Health check failed, Unknown.

    .EXAMPLE
        Get-AzLocalFleetHealthOverview

    .EXAMPLE
        Get-AzLocalFleetHealthOverview -UpdateRingTag Wave1 -ExportPath .\fleet-overview.csv

    .NOTES
        Author:  Neil Bird, Microsoft.
        Added:   v0.7.70
        Module:  AzLocal.UpdateManagement
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [ValidatePattern('^(\*\*\*|[A-Za-z0-9_-]{1,64}(;[A-Za-z0-9_-]{1,64})*)$')]
        [string]$UpdateRingTag,

        [Parameter(Mandatory = $false)]
        [string]$ExportPath,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    if ($ExportPath) {
        try { Test-ExportPathWritable -Path $ExportPath | Out-Null }
        catch { throw "ExportPath is not writable: $($_.Exception.Message)" }
    }

    # Optional UpdateRing tag filter (KQL fragment) injected into the
    # cluster-side branch of the join so the filter is evaluated server-
    # side rather than client-side.
    $ringFilter = ''
    if ($UpdateRingTag) {
        $ringFilter = ConvertTo-AzLocalUpdateRingKqlFilter -UpdateRingValue $UpdateRingTag -TagAccessor "tostring(tags['UpdateRing'])"
    }

    # KQL: join clusters with their updateSummaries/default child, roll
    # up SBE from packageVersions[], compute HealthResultsAgeDays. Both
    # sides of the join lower-case the resource id so the ARM mixed-case
    # vs the extensibilityresources path (also mixed-case but built from
    # split segments) match deterministically.
    $kql = @"
resources
| where type =~ 'microsoft.azurestackhci/clusters'
$ringFilter
| extend ClusterResourceIdLower = tolower(tostring(id))
| extend NodeCount       = iif(isnull(properties.reportedProperties.nodes), 0, toint(array_length(properties.reportedProperties.nodes)))
| extend AzureConnection = tostring(properties.connectivityStatus)
| project ClusterName=name, ClusterResourceId=tostring(id), ClusterResourceIdLower, ResourceGroup=tostring(resourceGroup), SubscriptionId=tostring(subscriptionId), NodeCount, AzureConnection
| join kind=leftouter (
    extensibilityresources
    | where type =~ 'microsoft.azurestackhci/clusters/updatesummaries'
    | extend segs = split(id, '/')
    | extend ClusterResourceIdLower = tolower(strcat('/subscriptions/', segs[2], '/resourceGroups/', segs[4], '/providers/Microsoft.AzureStackHCI/clusters/', segs[8]))
    | extend HealthState_    = tostring(properties.healthState)
    | extend UpdateState_    = tostring(properties.state)
    | extend CurrentVersion_ = tostring(properties.currentVersion)
    | extend LastChecked_    = todatetime(properties.healthCheckDate)
    | mv-expand pkg = properties.packageVersions
    | summarize
        HealthState    = any(HealthState_),
        UpdateState    = any(UpdateState_),
        CurrentVersion = any(CurrentVersion_),
        LastChecked    = max(LastChecked_),
        SbeVersion     = maxif(tostring(pkg.version), tostring(pkg.packageType) =~ 'SBE')
        by ClusterResourceIdLower
    | project ClusterResourceIdLower, HealthState, UpdateState, CurrentVersion, LastChecked, SbeVersion
) on ClusterResourceIdLower
| extend HealthResultsAgeDays = iif(isnull(LastChecked), -1, datetime_diff('day', now(), LastChecked))
| extend ClusterPortalUrl     = strcat('https://portal.azure.com/#@/resource', ClusterResourceId)
| project
    ClusterName,
    ClusterPortalUrl,
    HealthStatus    = iif(isempty(HealthState),     'Unknown',   HealthState),
    UpdateStatus    = iif(isempty(UpdateState),     'Unknown',   UpdateState),
    CurrentVersion  = iif(isempty(CurrentVersion),  '(unknown)', CurrentVersion),
    SbeVersion      = iif(isempty(SbeVersion),      '(none)',    SbeVersion),
    AzureConnection = iif(isempty(AzureConnection), 'Unknown',   AzureConnection),
    LastChecked,
    HealthResultsAgeDays,
    ResourceGroup,
    NodeCount,
    SubscriptionId
| order by HealthResultsAgeDays desc, ClusterName asc
"@

    Write-Log -Message "Querying Azure Resource Graph for fleet health overview$(if($UpdateRingTag){", UpdateRingTag=$UpdateRingTag"})..." -Level Info

    try {
        $output = if ($SubscriptionId) {
            Invoke-AzResourceGraphQuery -Query $kql -SubscriptionId $SubscriptionId
        } else {
            Invoke-AzResourceGraphQuery -Query $kql
        }
    }
    catch {
        Write-Log -Message "Resource Graph query failed: $($_.Exception.Message)" -Level Error
        throw
    }

    if (-not $output) { $output = @() }
    $output = @($output)
    Write-Log -Message "Fleet Health Overview: $($output.Count) cluster row(s)." -Level Info

    # Export if requested.
    if ($ExportPath) {
        try {
            $ExportPath = Resolve-SafeOutputPath -Path $ExportPath
            $exportDir  = Split-Path -Path $ExportPath -Parent
            if ($exportDir -and -not (Test-Path -Path $exportDir)) {
                $null = New-Item -ItemType Directory -Path $exportDir -Force
            }
            $ext = [System.IO.Path]::GetExtension($ExportPath).ToLower()
            switch ($ext) {
                '.json' {
                    Write-Utf8NoBomFile -Path $ExportPath -Content ($output | ConvertTo-Json -Depth 6)
                    Write-Log -Message "Fleet health overview exported to JSON: $ExportPath" -Level Success
                }
                default {
                    $output | ConvertTo-SafeCsvCollection | Export-Csv -Path $ExportPath -NoTypeInformation -Force
                    Write-Log -Message "Fleet health overview exported to CSV: $ExportPath" -Level Success
                }
            }
        }
        catch {
            Write-Log -Message "Failed to export fleet health overview: $($_.Exception.Message)" -Level Error
        }
    }

    if (-not $ExportPath -or $PassThru) {
        return , $output
    }
}
