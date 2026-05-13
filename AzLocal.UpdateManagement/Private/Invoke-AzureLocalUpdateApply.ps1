function Invoke-AzureLocalUpdateApply {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClusterResourceId,

        [Parameter(Mandatory = $true)]
        [string]$UpdateName,

        [Parameter(Mandatory = $false)]
        [string]$ApiVersion = $script:DefaultApiVersion
    )

    # Ensure Azure CLI is available
    Test-AzCliAvailable | Out-Null

    $uri = "https://management.azure.com$ClusterResourceId/updates/$UpdateName/apply?api-version=$ApiVersion"
    
    Write-Verbose "Applying update via POST to: $uri"
    
    # The apply endpoint is a POST with empty body
    $result = az rest --method POST --uri $uri --only-show-errors 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        return $true
    }
    elseif ($result -match "202" -or $result -match "Accepted") {
        # 202 Accepted is a valid response for long-running operations
        return $true
    }
    
    Write-Verbose "Apply result: $result"
    return $false
}
