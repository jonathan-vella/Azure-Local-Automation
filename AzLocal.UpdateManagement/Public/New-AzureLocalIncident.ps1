function New-AzureLocalIncident {
    <#
    .SYNOPSIS
        Opens or de-duplicates ServiceNow incidents from a JUnit results file.

    .DESCRIPTION
        Consumes the JUnit XML produced by Get-AzureLocalUpdateRuns /
        Invoke-AzureLocalFleetOperation, applies the configured trigger
        matrix (Get-AzureLocalItsmConfig), and for each cluster row that
        matches a 'raiseTicket: true' trigger:

          1. Computes a deterministic SHA256 dedupe key.
          2. Queries ServiceNow for an existing incident with the same key
             in states (New, In Progress, On Hold). Skips re-creation if
             found (returns Action='DedupedToExisting' with the sys_id),
             unless -ForceCreate is supplied.
          3. Otherwise creates a new incident with category / severity /
             custom fields populated from the trigger matrix and run
             metadata. Returns Action='Created' with the new sys_id.

        In -DryRun mode the function still parses, evaluates triggers, and
        builds the payloads, but performs zero HTTP writes. Useful for
        first-time matrix validation.

        Phase 2 (Sync-AzureLocalIncident) handles close-out on subsequent
        successful runs. Phase 3 mirrors to Teams / Slack.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$InputArtifactPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [pscustomobject]$Config,

        [Parameter(Mandatory = $false)]
        [hashtable]$RunMetadata,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [switch]$ForceCreate,

        [Parameter(Mandatory = $false)]
        [string]$ExportPath
    )

    if (-not (Test-Path -Path $InputArtifactPath -PathType Leaf)) {
        throw "New-AzureLocalIncident: input artefact not found at '$InputArtifactPath'."
    }

    if (-not $RunMetadata) { $RunMetadata = @{} }

    # 1. Parse JUnit -> per-cluster rows ------------------------------------
    [xml]$xml = Get-Content -Path $InputArtifactPath -Raw
    $rows = @()
    foreach ($tc in $xml.SelectNodes('//testcase')) {
        $status = 'Unknown'
        $message = $null
        if ($tc.failure) { $status = 'Failed'; $message = [string]$tc.failure.'#text' }
        elseif ($tc.error)   { $status = 'Error';  $message = [string]$tc.error.'#text' }
        elseif ($tc.skipped) { $status = 'Skipped' }
        else { $status = 'Success' }

        # Module's JUnit writer (Export-ResultsToJUnitXml) emits properties on each testcase
        $props = @{}
        if ($tc.properties -and $tc.properties.property) {
            foreach ($p in $tc.properties.property) {
                $props[[string]$p.name] = [string]$p.value
            }
        }
        if ($props.ContainsKey('Status') -and -not [string]::IsNullOrWhiteSpace($props['Status'])) {
            $status = $props['Status']
        }

        $rows += [pscustomobject]@{
            ClassName         = [string]$tc.classname
            Name              = [string]$tc.name
            Status            = $status
            Message           = $message
            ClusterName       = if ($props.ContainsKey('ClusterName')) { $props['ClusterName'] } else { [string]$tc.name }
            ClusterResourceId = if ($props.ContainsKey('ClusterResourceId')) { $props['ClusterResourceId'] } else { '' }
            UpdateName        = if ($props.ContainsKey('UpdateName')) { $props['UpdateName'] } else { '' }
            Properties        = $props
        }
    }

    # 2. Resolve ServiceNow secrets / token (skipped in DryRun) -------------
    $instanceUrl = $null
    $accessToken = $null
    if (-not $DryRun) {
        $sn = $Config.Secrets['servicenow']
        $kv = [string]$Config.Secrets['keyvaultName']
        if (-not $sn) { throw "New-AzureLocalIncident: config missing 'secrets.servicenow'." }

        $instanceUrl  = Resolve-AzLocalItsmSecret -Reference ([string]$sn['instanceUrl'])  -DefaultKeyVault $kv -AllowLiteral
        $clientId     = Resolve-AzLocalItsmSecret -Reference ([string]$sn['clientId'])     -DefaultKeyVault $kv
        $clientSecret = Resolve-AzLocalItsmSecret -Reference ([string]$sn['clientSecret']) -DefaultKeyVault $kv

        $tok = Invoke-AzLocalServiceNowAdapter -Action GetToken `
            -InstanceUrl $instanceUrl -ClientId $clientId -ClientSecret $clientSecret
        $accessToken = $tok.AccessToken
    }

    # 3. Evaluate triggers + create / dedupe per row ------------------------
    $results = New-Object System.Collections.ArrayList
    $defaults = $Config.Defaults
    $titleTemplate = if ($defaults -and $defaults['templates'] -and $defaults['templates']['titleTemplate']) {
        [string]$defaults['templates']['titleTemplate']
    } else {
        '[Azure Local] {{cluster.name}} - {{trigger.category}} ({{run.updateName}})'
    }
    $bodyTemplatePath = if ($defaults -and $defaults['templates'] -and $defaults['templates']['bodyTemplatePath']) {
        Resolve-AzLocalItsmTemplatePath -RawPath ([string]$defaults['templates']['bodyTemplatePath']) -ConfigSourcePath $Config.SourcePath
    } else { $null }

    foreach ($row in $rows) {
        $decision = Get-AzLocalItsmTriggerDecision -Status $row.Status -Triggers $Config.Triggers -Defaults $defaults

        if (-not $decision.ShouldTicket) {
            [void]$results.Add([pscustomobject]@{
                ClusterName       = $row.ClusterName
                ClusterResourceId = $row.ClusterResourceId
                UpdateName        = $row.UpdateName
                Status            = $row.Status
                Action            = 'Skipped'
                Severity          = $null
                TicketId          = $null
                TicketSysId       = $null
                TicketUrl         = $null
                DedupeKey         = $null
                Reason            = $decision.Reason
            })
            continue
        }

        $dedupeInputsValid = -not ([string]::IsNullOrWhiteSpace($row.ClusterResourceId) -or [string]::IsNullOrWhiteSpace($row.UpdateName))
        if (-not $dedupeInputsValid) {
            [void]$results.Add([pscustomobject]@{
                ClusterName       = $row.ClusterName
                ClusterResourceId = $row.ClusterResourceId
                UpdateName        = $row.UpdateName
                Status            = $row.Status
                Action            = 'Skipped'
                Severity          = $null
                TicketId          = $null
                TicketSysId       = $null
                TicketUrl         = $null
                DedupeKey         = $null
                Reason            = "Row missing ClusterResourceId or UpdateName; cannot compute dedupe key. Ensure your JUnit emitter writes both properties on each testcase."
            })
            continue
        }

        $dedupeKey = Get-AzLocalItsmDedupeKey `
            -ClusterResourceId $row.ClusterResourceId `
            -UpdateName        $row.UpdateName `
            -TriggerCategory   $decision.Category

        $context = @{
            cluster = @{
                name        = $row.ClusterName
                resourceId  = $row.ClusterResourceId
            }
            trigger = @{
                category = $decision.Category
                severity = $decision.Severity
                status   = $row.Status
            }
            run = @{
                updateName = $row.UpdateName
                id         = if ($RunMetadata['RunId']) { $RunMetadata['RunId'] } else { '' }
                url        = if ($RunMetadata['RunUrl']) { $RunMetadata['RunUrl'] } else { '' }
                platform   = if ($RunMetadata['Platform']) { $RunMetadata['Platform'] } else { '' }
            }
            message = $row.Message
        }

        $title = Format-AzLocalIncidentBody -Template $titleTemplate -Context $context -NoHtmlEscape
        $body  = if ($bodyTemplatePath) {
            Format-AzLocalIncidentBody -TemplatePath $bodyTemplatePath -Context $context
        } else {
            "Status: {0}`nCluster: {1}`nUpdate: {2}`nRun: {3}`n`n{4}" -f $row.Status, $row.ClusterName, $row.UpdateName, $context.run.url, $row.Message
        }

        $action = 'Created'
        $sysId = $null; $ticketNumber = $null; $ticketUrl = $null
        $existing = $null

        if (-not $DryRun -and -not $ForceCreate) {
            try {
                $existing = Invoke-AzLocalServiceNowAdapter -Action FindByDedupe `
                    -InstanceUrl $instanceUrl -AccessToken $accessToken -DedupeKey $dedupeKey
            }
            catch {
                Write-Warning "New-AzureLocalIncident: FindByDedupe failed for $($row.ClusterName) / ${dedupeKey}: $($_.Exception.Message)"
            }
        }

        if ($existing) {
            $action       = 'DedupedToExisting'
            $sysId        = [string]$existing.sys_id
            $ticketNumber = [string]$existing.number
            $ticketUrl    = "$instanceUrl/nav_to.do?uri=incident.do?sys_id=$sysId"
        }
        elseif ($DryRun) {
            $action = 'DryRun'
        }
        else {
            $impact, $urgency = Get-AzLocalItsmPriorityFromSeverity -Severity $decision.Severity
            $fields = @{
                short_description              = $title
                description                    = $body
                impact                         = $impact
                urgency                        = $urgency
                category                       = $decision.Category
                u_azlocal_dedupe_key           = $dedupeKey
                u_azlocal_cluster_resource_id  = $row.ClusterResourceId
                u_azlocal_update_name          = $row.UpdateName
                u_azlocal_run_id               = [string]$context.run.id
                u_azlocal_source               = 'AzLocal.UpdateManagement'
            }
            if ($defaults['assignmentGroup']) { $fields['assignment_group'] = [string]$defaults['assignmentGroup'] }
            if ($defaults['callerId'])        { $fields['caller_id']        = [string]$defaults['callerId'] }
            if ($defaults['cmdbCi'])          { $fields['cmdb_ci']          = [string]$defaults['cmdbCi'] }

            if ($PSCmdlet.ShouldProcess($row.ClusterName, "Create ServiceNow incident for trigger '$($row.Status)'")) {
                try {
                    $created = Invoke-AzLocalServiceNowAdapter -Action CreateIncident `
                        -InstanceUrl $instanceUrl -AccessToken $accessToken -IncidentFields $fields
                    $sysId        = [string]$created.sys_id
                    $ticketNumber = [string]$created.number
                    $ticketUrl    = "$instanceUrl/nav_to.do?uri=incident.do?sys_id=$sysId"
                }
                catch {
                    $action = 'CreateFailed'
                    Write-Warning "New-AzureLocalIncident: CreateIncident failed for $($row.ClusterName): $($_.Exception.Message)"
                }
            }
            else {
                $action = 'WhatIf'
            }
        }

        [void]$results.Add([pscustomobject]@{
            ClusterName       = $row.ClusterName
            ClusterResourceId = $row.ClusterResourceId
            UpdateName        = $row.UpdateName
            Status            = $row.Status
            Action            = $action
            Severity          = $decision.Severity
            TicketId          = $ticketNumber
            TicketSysId       = $sysId
            TicketUrl         = $ticketUrl
            DedupeKey         = $dedupeKey
            Reason            = $decision.Reason
        })
    }

    if ($ExportPath) {
        try {
            $exportDir = Split-Path -Path $ExportPath -Parent
            if ($exportDir -and -not (Test-Path -Path $exportDir)) {
                New-Item -Path $exportDir -ItemType Directory -Force | Out-Null
            }
            $results | ConvertTo-SafeCsvCollection | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8 -Force
        }
        catch {
            Write-Warning "New-AzureLocalIncident: failed to export results to '$ExportPath': $($_.Exception.Message)"
        }
    }

    return $results
}

function Resolve-AzLocalItsmTemplatePath {
    <#
    .SYNOPSIS
        Resolves a template path from the ITSM config (relative paths
        are resolved against the config file's directory).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][string]$RawPath,
        [Parameter(Mandatory = $true)][string]$ConfigSourcePath
    )
    if ([IO.Path]::IsPathRooted($RawPath)) { return $RawPath }
    $configDir = Split-Path -Path $ConfigSourcePath -Parent
    return (Join-Path $configDir $RawPath)
}

function Get-AzLocalItsmPriorityFromSeverity {
    <#
    .SYNOPSIS
        Maps a 1..5 severity to ServiceNow (impact, urgency) per the design.
    #>
    [CmdletBinding()]
    [OutputType([int[]])]
    param(
        [Parameter(Mandatory = $true)][ValidateRange(1,5)][int]$Severity
    )
    switch ($Severity) {
        1 { return @(1,1) }
        2 { return @(2,2) }
        3 { return @(3,3) }
        4 { return @(4,4) }
        5 { return @(4,4) }
    }
}
