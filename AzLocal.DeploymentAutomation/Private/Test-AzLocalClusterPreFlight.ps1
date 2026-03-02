Function Test-AzLocalClusterPreFlight {
    <#
    .SYNOPSIS

    Runs pre-flight checks for a single cluster deployment.

    .DESCRIPTION

    Validates that a cluster is ready for deployment by checking:
    1. Resource names pass Azure naming validation (Test-AzLocalResourceNames)
    2. Resource group exists in the target subscription
    3. All expected Arc node resources (Microsoft.HybridCompute/machines) are registered
    4. No ARM deployment is currently in-progress for this cluster
    5. The cluster resource does not already exist (already deployed)

    Returns a result object with Status (Passed/Failed/Skipped) and diagnostic Messages.

    .PARAMETER ClusterRow
    A PSCustomObject from the CSV representing one cluster deployment.

    .PARAMETER NamingConfig
    The naming configuration object from Get-AzLocalNamingConfig.

    .PARAMETER DeploymentMode
    The deployment mode (Validate or Deploy) to check for in-progress deployments.

    #>

    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [PSCustomObject]$ClusterRow,

        [Parameter(Mandatory = $true, Position = 1)]
        [PSCustomObject]$NamingConfig,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateSet("Validate", "Deploy")]
        [string]$DeploymentMode
    )

    $uniqueID = $ClusterRow.UniqueID
    $messages = @()
    $status = 'Passed'
    $startTime = Get-Date

    Write-AzLocalLog "Pre-flight check: $uniqueID" -Level Info

    # Resolve resource names
    $resourceGroupName = Resolve-AzLocalResourceName -Pattern $NamingConfig.namingStandards.resourceGroupName -UniqueID $uniqueID
    $clusterName = Resolve-AzLocalResourceName -Pattern $NamingConfig.namingStandards.clusterName -UniqueID $uniqueID
    $deploymentName = Resolve-AzLocalResourceName -Pattern $NamingConfig.namingStandards.deploymentName -UniqueID $uniqueID -TypeOfDeployment $ClusterRow.TypeOfDeployment
    $keyVaultName = Resolve-AzLocalResourceName -Pattern $NamingConfig.namingStandards.keyVaultName -UniqueID $uniqueID
    $customLocation = Resolve-AzLocalResourceName -Pattern $NamingConfig.namingStandards.customLocation -UniqueID $uniqueID
    $resourceBridgeName = Resolve-AzLocalResourceName -Pattern $NamingConfig.namingStandards.resourceBridgeName -UniqueID $uniqueID
    $diagnosticStorageAccountName = Resolve-AzLocalResourceName -Pattern $NamingConfig.namingStandards.diagnosticStorageAccountName -UniqueID $uniqueID
    $clusterWitnessStorageAccountName = Resolve-AzLocalResourceName -Pattern $NamingConfig.namingStandards.clusterWitnessStorageAccountName -UniqueID $uniqueID

    # Determine effective node count
    $nodeCount = [int]$ClusterRow.NodeCount
    if ($ClusterRow.TypeOfDeployment -eq 'SingleNode') { $effectiveNodeCount = 1 } else { $effectiveNodeCount = $nodeCount }

    # Build node names
    $nodeNames = @()
    for ($i = 1; $i -le $effectiveNodeCount; $i++) {
        $nodeNames += Resolve-AzLocalResourceName -Pattern $NamingConfig.namingStandards.nodeNamePattern -UniqueID $uniqueID -NodeNumber $i
    }

    # 1. Validate resource names
    try {
        $namesToValidate = @{
            'ClusterName'                      = $clusterName
            'ResourceGroupName'                = $resourceGroupName
            'KeyVaultName'                     = $keyVaultName
            'CustomLocation'                   = $customLocation
            'ResourceBridgeName'               = $resourceBridgeName
            'DiagnosticStorageAccountName'     = $diagnosticStorageAccountName
            'ClusterWitnessStorageAccountName' = $clusterWitnessStorageAccountName
            'DeploymentName'                   = $deploymentName
        }
        # Add node names
        for ($i = 0; $i -lt $nodeNames.Count; $i++) {
            $namesToValidate["NodeName$($i + 1)"] = $nodeNames[$i]
        }
        Test-AzLocalResourceNames -Names $namesToValidate
        $messages += "Resource name validation: PASSED"
    } catch {
        $status = 'Failed'
        $messages += "Resource name validation: FAILED - $($_.Exception.Message)"
        # Return early - no point checking Azure if names are invalid
        $duration = ((Get-Date) - $startTime).TotalSeconds
        return [PSCustomObject]@{
            UniqueID          = $uniqueID
            ClusterName       = $clusterName
            ResourceGroupName = $resourceGroupName
            DeploymentName    = $deploymentName
            Status            = $status
            Messages          = $messages
            Duration          = [math]::Round($duration, 2)
        }
    }

    # 2. Check resource group exists
    $rg = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
    if (-not $rg) {
        $status = 'Failed'
        $messages += "Resource group '$resourceGroupName': NOT FOUND"
        $duration = ((Get-Date) - $startTime).TotalSeconds
        return [PSCustomObject]@{
            UniqueID          = $uniqueID
            ClusterName       = $clusterName
            ResourceGroupName = $resourceGroupName
            DeploymentName    = $deploymentName
            Status            = $status
            Messages          = $messages
            Duration          = [math]::Round($duration, 2)
        }
    }
    $messages += "Resource group '$resourceGroupName': EXISTS"

    # 3. Check all Arc nodes are registered
    $allNodesPresent = $true
    foreach ($nodeName in $nodeNames) {
        $arcResourceId = "/subscriptions/$($ClusterRow.SubscriptionId)/resourceGroups/$resourceGroupName/providers/Microsoft.HybridCompute/machines/$nodeName"
        $arcNode = Get-AzResource -ResourceId $arcResourceId -ErrorAction SilentlyContinue
        if ($arcNode) {
            $messages += "Arc node '$nodeName': REGISTERED"
        } else {
            $allNodesPresent = $false
            $messages += "Arc node '$nodeName': NOT FOUND"
        }
    }
    if (-not $allNodesPresent) {
        $status = 'Failed'
        $messages += "Pre-flight FAILED: Not all Arc nodes are registered."
        $duration = ((Get-Date) - $startTime).TotalSeconds
        return [PSCustomObject]@{
            UniqueID          = $uniqueID
            ClusterName       = $clusterName
            ResourceGroupName = $resourceGroupName
            DeploymentName    = $deploymentName
            Status            = $status
            Messages          = $messages
            Duration          = [math]::Round($duration, 2)
        }
    }

    # 4. Check for existing cluster resource (already deployed)
    $clusterResourceId = "/subscriptions/$($ClusterRow.SubscriptionId)/resourceGroups/$resourceGroupName/providers/Microsoft.AzureStackHCI/clusters/$clusterName"
    $existingCluster = Get-AzResource -ResourceId $clusterResourceId -ErrorAction SilentlyContinue
    if ($existingCluster) {
        $status = 'Skipped'
        $messages += "Cluster '$clusterName' already exists in resource group. Skipping."
        $duration = ((Get-Date) - $startTime).TotalSeconds
        return [PSCustomObject]@{
            UniqueID          = $uniqueID
            ClusterName       = $clusterName
            ResourceGroupName = $resourceGroupName
            DeploymentName    = $deploymentName
            Status            = $status
            Messages          = $messages
            Duration          = [math]::Round($duration, 2)
        }
    }
    $messages += "Cluster '$clusterName': Not yet deployed (eligible)"

    # 5. Check for in-progress deployment
    $existingDeployment = Get-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name $deploymentName -ErrorAction SilentlyContinue
    if ($existingDeployment) {
        $provState = $existingDeployment.ProvisioningState
        if ($provState -eq 'Running' -or $provState -eq 'Accepted') {
            $status = 'Skipped'
            $messages += "Deployment '$deploymentName' is already in-progress (State: $provState). Skipping."
        } elseif ($provState -eq 'Succeeded' -and $DeploymentMode -eq 'Validate') {
            $status = 'Skipped'
            $messages += "Validation deployment '$deploymentName' already succeeded. Skipping."
        } elseif ($provState -eq 'Failed') {
            $messages += "Previous deployment '$deploymentName' failed (can be retried)."
        } else {
            $messages += "Existing deployment '$deploymentName' state: $provState"
        }
    } else {
        $messages += "No existing deployment '$deploymentName' found (new deployment)."
    }

    $duration = ((Get-Date) - $startTime).TotalSeconds
    return [PSCustomObject]@{
        UniqueID          = $uniqueID
        ClusterName       = $clusterName
        ResourceGroupName = $resourceGroupName
        DeploymentName    = $deploymentName
        Status            = $status
        Messages          = $messages
        Duration          = [math]::Round($duration, 2)
    }
}
