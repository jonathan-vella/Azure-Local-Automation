function Set-AzLocalClusterTagsMerge {
    <#
    .SYNOPSIS
        Merges a set of tag key/value pairs into an Azure Local cluster's tags via ARM PATCH.
    .DESCRIPTION
        Private helper that performs an additive ARM tag merge on a single cluster
        resource. Existing tags are preserved; supplied keys are added or overwritten.
        A supplied value of $null removes that tag key from the cluster.

        Used by:
        - Start-AzureLocalClusterUpdate to write UpdateVersionInProgress at update start.
        - Reset-AzureLocalSideloadedTag (and the auto-reset path in Get-AzureLocalUpdateRuns)
          to flip UpdateSideloaded=False and clear UpdateVersionInProgress on matched success.

        Failures are surfaced as terminating errors so callers can wrap in try/catch and
        decide whether to treat the failure as fatal (reset) or warn-and-continue (start).
    .PARAMETER ClusterResourceId
        The full ARM resource ID of the microsoft.azurestackhci/clusters resource.
    .PARAMETER Tags
        Hashtable of tag keys to set. Use $null as a value to remove a tag key.
    .PARAMETER ApiVersion
        The ARM api-version to use for the PATCH. Defaults to a stable cluster api-version.
    .OUTPUTS
        [bool] - $true on success. Throws on failure.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ClusterResourceId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable]$Tags,

        [Parameter(Mandatory = $false)]
        [string]$ApiVersion = $script:DefaultApiVersion
    )

    if ($Tags.Count -eq 0) {
        Write-Verbose "Set-AzLocalClusterTagsMerge: no tags supplied; nothing to do."
        return $true
    }

    # Fetch current cluster to preserve existing tags
    $getUri = "https://management.azure.com$ClusterResourceId`?api-version=$ApiVersion"
    $clusterJson = az rest --method GET --uri $getUri --only-show-errors 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Set-AzLocalClusterTagsMerge: failed to fetch cluster '$ClusterResourceId': $clusterJson"
    }

    $cluster = $clusterJson | ConvertFrom-Json
    $newTags = [ordered]@{}
    $existingTags = [ordered]@{}
    if ($cluster.tags) {
        foreach ($prop in $cluster.tags.PSObject.Properties) {
            if ($prop.MemberType -eq 'NoteProperty') {
                $newTags[$prop.Name] = $prop.Value
                $existingTags[$prop.Name] = $prop.Value
            }
        }
    }

    # Apply the merge: set non-null values, remove null values
    $changed = $false
    foreach ($key in $Tags.Keys) {
        $val = $Tags[$key]
        if ($null -eq $val) {
            if ($newTags.Contains($key)) {
                $newTags.Remove($key)
                $changed = $true
            }
        }
        else {
            $existingValue = if ($existingTags.Contains($key)) { [string]$existingTags[$key] } else { $null }
            if ($null -eq $existingValue -or $existingValue -cne [string]$val) {
                $newTags[$key] = $val
                $changed = $true
            }
        }
    }

    # Idempotency: if the merge produces no actual change, skip the PATCH entirely.
    # Avoids redundant ARM writes when running auto-reset paths against already-clean
    # clusters (common at fleet scale and across overlapping pipeline runs).
    if (-not $changed) {
        Write-Verbose "Set-AzLocalClusterTagsMerge: no tag changes for '$ClusterResourceId'; skipping PATCH."
        return $true
    }

    $describe = ($Tags.Keys | ForEach-Object { "$_=$($Tags[$_])" }) -join ', '
    if (-not $PSCmdlet.ShouldProcess($ClusterResourceId, "Merge tags ($describe)")) {
        return $true
    }

    $patchBodyObj = [PSCustomObject]@{ tags = [PSCustomObject]$newTags }
    $patchBody = $patchBodyObj | ConvertTo-Json -Compress -Depth 10

    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        Write-Utf8NoBomFile -Path $tempFile -Content $patchBody
        $patchResult = az rest --method PATCH --uri $getUri --body "@$tempFile" --headers "Content-Type=application/json" --only-show-errors 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Set-AzLocalClusterTagsMerge: PATCH failed for '$ClusterResourceId': $patchResult"
        }
    }
    finally {
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue -WhatIf:$false }
    }

    return $true
}
