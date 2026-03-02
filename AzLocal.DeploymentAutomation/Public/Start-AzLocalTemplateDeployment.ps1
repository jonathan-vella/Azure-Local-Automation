Function Start-AzLocalTemplateDeployment {
    <#
    .SYNOPSIS

    This script is used to deploy Azure Local using an ARM template deployment

    .DESCRIPTION

    This script is used to deploy Azure Local using an ARM template deployment. It requires the following parameters:
    - SubscriptionId: The ID of the Azure subscription to use for the deployment.
    - TenantId: The ID of the Azure tenant to use for the deployment.
    - TypeOfDeployment: The type of deployment to perform (e.g., SingleNode, MultiNode, Switchless, RackAware).
    - DeploymentMode: Validate (validate only), Deploy (deploy only), or ValidateAndDeploy (validate first, then deploy on success).
    - NodeCount: The number of nodes for MultiNode (2-16), Switchless (2-4), or RackAware (2, 4, 6, 8) deployments.

    Credentials can be supplied in three ways (highest to lowest priority):
    1. Azure Key Vault: -CredentialKeyVaultName (with optional -LocalAdminSecretName / -LCMAdminSecretName)
    2. PSCredential objects: -LocalAdminCredential and -LCMAdminCredential
    3. Interactive prompts: Read-Host -AsSecureString (default when no credential parameters are supplied)

    For fully non-interactive (CI/CD) deployments, also supply -UniqueID and -NetworkSettingsJson.
    Supports -WhatIf and -Confirm for safe dry-run and confirmation before ARM submission.

    Azure Local cluster deployments require two sequential ARM deployments: first with deploymentMode
    set to 'Validate', then once validation succeeds, a second deployment with deploymentMode set to
    'Deploy'. The 'ValidateAndDeploy' option automates this two-phase process.
    Reference: https://learn.microsoft.com/en-us/azure/azure-local/deploy/deployment-azure-resource-manager-template

    Resource naming standards are loaded from .config/naming-standards-config.json.

    #>

    [OutputType('Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroupDeployment')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialKeyVaultName',
        Justification = 'This is the name of the Key Vault resource, not a credential value.')]
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true,Position=0)]
        [guid]$SubscriptionId,

        [Parameter(Mandatory = $true,Position=1)]
        [ValidateSet("SingleNode","Switchless","MultiNode","RackAware")]
        [string]$TypeOfDeployment,
        
        [Parameter(Mandatory = $true,Position=2)]
        [guid]$TenantId,

        [Parameter(Mandatory = $true,Position=3)]
        [ValidateSet("Validate","Deploy","ValidateAndDeploy")]
        [string]$DeploymentMode,

        [Parameter(Mandatory = $false,Position=4)]
        [ValidateRange(2, 16)]
        [int]$NodeCount = 0,

        [Parameter(Mandatory = $false,Position=5)]
        [string]$Location = "",

        [Parameter(Mandatory = $false,Position=6)]
        [string[]]$DnsServers = @(),

        [Parameter(Mandatory = $false,Position=7)]
        [string[]]$ComputeManagementAdapters = @(),

        [Parameter(Mandatory = $false,Position=8)]
        [string[]]$StorageAdapters = @(),

        [Parameter(Mandatory = $false)]
        [string]$LogFilePath = "",

        # --- Credential parameters (optional - falls back to interactive Read-Host prompts) ---

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$LocalAdminCredential,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$LCMAdminCredential,

        # --- Azure Key Vault credential retrieval (optional - overrides interactive prompts) ---

        [Parameter(Mandatory = $false)]
        [string]$CredentialKeyVaultName = "",

        [Parameter(Mandatory = $false)]
        [string]$LocalAdminSecretName = "",

        [Parameter(Mandatory = $false)]
        [string]$LCMAdminSecretName = "",

        # --- Non-interactive parameters (optional - bypass Read-Host prompts) ---

        [Parameter(Mandatory = $false)]
        [ValidatePattern('^[a-zA-Z0-9]{2,8}$')]
        [string]$UniqueID = "",

        [Parameter(Mandatory = $false)]
        [string]$NetworkSettingsJson = ""

    )

    # Reset module-scoped log path (prevents bleed-over from previous function calls)
    $script:AzLocalLogFilePath = $null

    # Initialise log file if specified
    if (-not [string]::IsNullOrWhiteSpace($LogFilePath)) {
        Initialize-AzLocalLogFile -LogFilePath $LogFilePath
    }

    Write-AzLocalLog "Starting Azure Local Template Deployment" -Level Success
    Write-AzLocalLog "/////////////////////////////////////////" -Level Success -NoTimestamp
    Write-AzLocalLog "Subscription ID: $SubscriptionId" -Level Info
    Write-AzLocalLog "Tenant ID: $TenantId" -Level Info
    Write-AzLocalLog "Type of Deployment: $TypeOfDeployment" -Level Info
    Write-Verbose "DeploymentMode: $DeploymentMode | NodeCount: $NodeCount | Location: $Location"

    # Validate NodeCount for each deployment type
    if ($TypeOfDeployment -eq "SingleNode" -and $NodeCount -gt 1) {
        Write-AzLocalLog "SingleNode deployment does not support -NodeCount greater than 1. SingleNode is always a single node." -Level Error
        throw "SingleNode deployment does not support -NodeCount greater than 1. Use -NodeCount 1 or omit it for SingleNode deployments."
    }
    if ($TypeOfDeployment -eq "MultiNode" -and $NodeCount -lt 2) {
        Write-AzLocalLog "MultiNode deployment requires the -NodeCount parameter (minimum 2)." -Level Error
        throw "MultiNode deployment requires -NodeCount >= 2."
    }
    if ($TypeOfDeployment -eq "Switchless" -and ($NodeCount -lt 2 -or $NodeCount -gt 4)) {
        Write-AzLocalLog "Switchless deployment requires the -NodeCount parameter (2 to 4 nodes)." -Level Error
        throw "Switchless deployment requires -NodeCount between 2 and 4."
    }
    if ($TypeOfDeployment -eq "RackAware" -and ($NodeCount -notin @(2, 4, 6, 8))) {
        Write-AzLocalLog "RackAware deployment requires the -NodeCount parameter with an even number of nodes (2, 4, 6, or 8)." -Level Error
        throw "RackAware deployment requires -NodeCount of 2, 4, 6, or 8."
    }

    # Load naming configuration from .config/naming-standards-config.json
    Write-Verbose "Loading naming configuration..."
    $NamingConfig = Get-AzLocalNamingConfig

    # Get Unique ID - use parameter if provided, otherwise prompt interactively
    if (-not [string]::IsNullOrWhiteSpace($UniqueID)) {
        Write-AzLocalLog "Unique ID '$UniqueID' provided via parameter." -Level Success
    } else {
        $UniqueID = Get-ValidUniqueID
    }

    Write-AzLocalLog "Unique ID: $UniqueID" -Level Success

    # Get Deployment Network Settings - use JSON file/string if provided, otherwise prompt interactively
    if (-not [string]::IsNullOrWhiteSpace($NetworkSettingsJson)) {
        Write-Verbose "Loading network settings from provided JSON..."
        $NetworkSettings = Get-AzLocalNetworkSettingsFromJson -NetworkSettingsJson $NetworkSettingsJson -TypeOfDeployment $TypeOfDeployment -NodeCount $NodeCount
    } else {
        Write-Verbose "Collecting network settings interactively for $TypeOfDeployment deployment..."
        $NetworkSettings = Get-AzLocalDeploymentNetworkSettings -TypeOfDeployment $TypeOfDeployment -NodeCount $NodeCount
    }

    # Call function to Get Parameter File Path
    $ParameterFilePath = Get-AzLocalParameterFilePath -TypeOfDeployment $TypeOfDeployment

    # Call function to Get Parameter File Settings
    Write-Verbose "Loading parameter file settings from $ParameterFilePath..."
    [PsCustomObject]$ParameterFileSettings = Get-AzLocalParameterFileSettings -ParameterFilePath $ParameterFilePath

    $TemplateFilePath = Join-Path $script:ModuleRoot "templates\azure-local-deployment-template.json"
    if(-Not (Test-Path $TemplateFilePath)) {
        Write-AzLocalLog "Template file not found at '$TemplateFilePath'." -Level Error
        throw "Template file not found at '$TemplateFilePath'."
    }
    Write-Verbose "Template file found: $TemplateFilePath"

    # Define the network settings, from the returned object
    $SubnetMask = $NetworkSettings.subnetMask
    $DefaultGateway = $NetworkSettings.defaultGateway
    $startingIPAddress = $NetworkSettings.startingIPAddress
    $endingIPAddress = $NetworkSettings.endingIPAddress
    $nodeIPAddresses = $NetworkSettings.nodeIPAddresses

    # Resolve resource names from naming configuration using UniqueID
    $ClusterWitnessStorageAccountName = Resolve-AzLocalResourceName -Pattern $NamingConfig.namingStandards.clusterWitnessStorageAccountName -UniqueID $UniqueID
    $ClusterName = Resolve-AzLocalResourceName -Pattern $NamingConfig.namingStandards.clusterName -UniqueID $UniqueID
    $ResourceGroupName = Resolve-AzLocalResourceName -Pattern $NamingConfig.namingStandards.resourceGroupName -UniqueID $UniqueID
    # Location: use parameter override if provided, otherwise fall back to config default
    if ([string]::IsNullOrWhiteSpace($Location)) {
        $Location = $NamingConfig.defaults.location
    }
    $DomainFqdn = $NamingConfig.defaults.domainFqdn
    $NamingPrefix = $NamingConfig.defaults.namingPrefix
    # DnsServers: use parameter override if provided, otherwise fall back to config default
    if ($DnsServers.Count -eq 0) {
        $DnsServers = @($NamingConfig.defaults.dnsServers)
    }
    # ComputeManagementAdapters: use parameter override if provided, otherwise fall back to config default
    if ($ComputeManagementAdapters.Count -eq 0) {
        $ComputeManagementAdapters = @($NamingConfig.defaults.computeManagementAdapters)
    }
    # StorageAdapters: use parameter override if provided, otherwise fall back to config default
    if ($StorageAdapters.Count -eq 0) {
        $StorageAdapters = @($NamingConfig.defaults.storageAdapters)
    }
    $AzureStackLCMAdminUsername = $NamingConfig.defaults.azureStackLCMAdminUsername
    $KeyVaultName = Resolve-AzLocalResourceName -Pattern $NamingConfig.namingStandards.keyVaultName -UniqueID $UniqueID
    $CustomLocation = Resolve-AzLocalResourceName -Pattern $NamingConfig.namingStandards.customLocation -UniqueID $UniqueID
    $ResourceBridgeName = Resolve-AzLocalResourceName -Pattern $NamingConfig.namingStandards.resourceBridgeName -UniqueID $UniqueID

    # Storage Account for diagnostics
    $StorageAccountName = Resolve-AzLocalResourceName -Pattern $NamingConfig.namingStandards.diagnosticStorageAccountName -UniqueID $UniqueID
    $StorageAccountType = $NamingConfig.defaults.storageAccountType

    # Validate all resolved resource names against Azure naming rules (early fail-fast)
    Write-Verbose "Validating resolved resource names against Azure naming constraints..."
    $deploymentName = Resolve-AzLocalResourceName -Pattern $NamingConfig.namingStandards.deploymentName -UniqueID $UniqueID -TypeOfDeployment $TypeOfDeployment
    $namesToValidate = @{
        'ClusterName'                      = $ClusterName
        'ResourceGroupName'                = $ResourceGroupName
        'KeyVaultName'                     = $KeyVaultName
        'CustomLocation'                   = $CustomLocation
        'ResourceBridgeName'               = $ResourceBridgeName
        'DiagnosticStorageAccountName'     = $StorageAccountName
        'ClusterWitnessStorageAccountName' = $ClusterWitnessStorageAccountName
        'DeploymentName'                   = $deploymentName
    }
    Test-AzLocalResourceNames -Names $namesToValidate

    # Resolve credentials: Key Vault > PSCredential parameter > Interactive prompt
    # Priority: CredentialKeyVaultName (highest) > LocalAdminCredential/LCMAdminCredential > Read-Host (lowest)

    if (-not [string]::IsNullOrWhiteSpace($CredentialKeyVaultName)) {
        # --- Retrieve credentials from Azure Key Vault ---
        # Verify Az.KeyVault module is available before attempting retrieval
        if (-not (Get-Module -ListAvailable -Name 'Az.KeyVault')) {
            Write-AzLocalLog "Az.KeyVault module is not installed. Install it with: Install-Module Az.KeyVault" -Level Error
            throw "Az.KeyVault module is required for Key Vault credential retrieval. Install with: Install-Module Az.KeyVault -Scope CurrentUser"
        }
        Write-AzLocalLog "Retrieving credentials from Key Vault '$CredentialKeyVaultName'..." -Level Info
        Write-Verbose "Key Vault credential retrieval mode enabled."

        # Local Admin password from Key Vault
        $kvLocalSecretName = if (-not [string]::IsNullOrWhiteSpace($LocalAdminSecretName)) { $LocalAdminSecretName } else { "LocalAdminCredential" }
        try {
            $kvLocalSecret = Get-AzKeyVaultSecret -VaultName $CredentialKeyVaultName -Name $kvLocalSecretName -ErrorAction Stop
            $localAdminPassword = $kvLocalSecret.SecretValue
            Write-AzLocalLog "Local admin password retrieved from Key Vault secret '$kvLocalSecretName'." -Level Success
        } catch {
            Write-AzLocalLog "Failed to retrieve local admin secret '$kvLocalSecretName' from Key Vault '$CredentialKeyVaultName'." -Level Error
            throw "Failed to retrieve Key Vault secret '$kvLocalSecretName'. $($_.Exception.Message)"
        }

        # LCM Admin password from Key Vault
        $kvLCMSecretName = if (-not [string]::IsNullOrWhiteSpace($LCMAdminSecretName)) { $LCMAdminSecretName } else { "AzureStackLCMUserCredential" }
        try {
            $kvLCMSecret = Get-AzKeyVaultSecret -VaultName $CredentialKeyVaultName -Name $kvLCMSecretName -ErrorAction Stop
            $AzureStackLCMAdminPassword = $kvLCMSecret.SecretValue
            Write-AzLocalLog "LCM admin password retrieved from Key Vault secret '$kvLCMSecretName'." -Level Success
        } catch {
            Write-AzLocalLog "Failed to retrieve LCM admin secret '$kvLCMSecretName' from Key Vault '$CredentialKeyVaultName'." -Level Error
            throw "Failed to retrieve Key Vault secret '$kvLCMSecretName'. $($_.Exception.Message)"
        }

    } elseif ($LocalAdminCredential -and $LCMAdminCredential) {
        # --- Use PSCredential parameters ---
        Write-Verbose "Using credentials supplied via -LocalAdminCredential and -LCMAdminCredential parameters."
        $localAdminPassword = $LocalAdminCredential.Password
        $AzureStackLCMAdminPassword = $LCMAdminCredential.Password
        Write-AzLocalLog "Credentials provided via PSCredential parameters." -Level Success

    } else {
        # --- Interactive prompt fallback ---
        Write-Verbose "No credential parameters or Key Vault specified. Prompting interactively..."
        $localAdminPassword = Read-Host "`nPlease enter the Nodes Local Admin Password" -AsSecureString -ErrorAction Stop
        if(-not($localAdminPassword)) {
            Write-AzLocalLog "Null local admin password. This is a mandatory requirement." -Level Error
            throw "Local admin password is required."
        }
        Write-Verbose "Local admin password captured."

        $AzureStackLCMAdminPassword = Read-Host "`nPlease enter the LCM domain user account admin Password" -AsSecureString -ErrorAction Stop
        if(-not($AzureStackLCMAdminPassword)) {
            Write-AzLocalLog "Null LCM domain user account password. This is a mandatory requirement." -Level Error
            throw "LCM domain user account password is required."
        }
        Write-Verbose "LCM admin password captured."
    }

    if($TypeOfDeployment -eq "SingleNode") {
        $effectiveNodeCount = 1
        $storageConnectivitySwitchless = $true
        $witnessType = "No Witness"

    } elseif ($TypeOfDeployment -eq "Switchless") {
        $effectiveNodeCount = $NodeCount
        $storageConnectivitySwitchless = $true
        $witnessType = "Cloud"

    } elseif ($TypeOfDeployment -eq "MultiNode") {
        $effectiveNodeCount = $NodeCount
        $storageConnectivitySwitchless = $false
        $witnessType = "Cloud"

    } elseif ($TypeOfDeployment -eq "RackAware") {
        $effectiveNodeCount = $NodeCount
        $storageConnectivitySwitchless = $false
        $witnessType = "Cloud"
    }

    # Build RackAware local availability zones (auto-split evenly across 2 zones)
    $clusterPattern = "Standard"
    $localAvailabilityZones = @()
    if ($TypeOfDeployment -eq "RackAware") {
        $clusterPattern = "RackAware"
        # Zone assignment will be populated after node names are built below
    }

    # Build node names and Arc resource IDs dynamically using naming config
    $nodeNames = @()
    $arcNodeResourceIds = @()
    for ($i = 1; $i -le $effectiveNodeCount; $i++) {
        $nodeName = Resolve-AzLocalResourceName -Pattern $NamingConfig.namingStandards.nodeNamePattern -UniqueID $UniqueID -NodeNumber $i
        $nodeNames += $nodeName
        $arcNodeResourceIds += "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.HybridCompute/machines/$nodeName"
    }

    # Validate node names against Azure naming rules (NetBIOS: 1-15 chars, alphanumeric only)
    $nodeNamesToValidate = @{}
    for ($i = 0; $i -lt $nodeNames.Count; $i++) {
        $nodeNamesToValidate["NodeName$($i + 1)"] = $nodeNames[$i]
    }
    Test-AzLocalResourceNames -Names $nodeNamesToValidate

    # Populate RackAware local availability zones after node names are built
    if ($TypeOfDeployment -eq "RackAware") {
        $halfCount = $effectiveNodeCount / 2
        $zoneANodes = $nodeNames[0..($halfCount - 1)]
        $zoneBNodes = $nodeNames[$halfCount..($effectiveNodeCount - 1)]
        $localAvailabilityZones = @(
            [PSCustomObject][Ordered]@{
                "localAvailabilityZoneName" = "ZoneA"
                "nodes" = @($zoneANodes)
            },
            [PSCustomObject][Ordered]@{
                "localAvailabilityZoneName" = "ZoneB"
                "nodes" = @($zoneBNodes)
            }
        )
        Write-AzLocalLog "RackAware: ZoneA nodes: $($zoneANodes -join ', ')" -Level Success
        Write-AzLocalLog "RackAware: ZoneB nodes: $($zoneBNodes -join ', ')" -Level Success
    }

    # Dynamic OU path for the AD Objects of the cluster using the Unique ID
    $adouPath = Resolve-AzLocalResourceName -Pattern $NamingConfig.namingStandards.adouPath -UniqueID $UniqueID

    # Get the HCI Resource Provider Object ID
    $hciResourceProviderObjectID = (Get-AzADServicePrincipal -DisplayName "Microsoft.AzureStackHCI Resource Provider").Id
    if(-not($hciResourceProviderObjectID)) {
        Write-AzLocalLog "Unable to find the HCI Resource Provider Object ID." -Level Error
        throw "HCI Resource Provider 'Microsoft.AzureStackHCI Resource Provider' not found. Ensure it is registered in the tenant."
    }
    Write-AzLocalLog "HCI Resource Provider Object ID: $hciResourceProviderObjectID" -Level Success

    if($TypeOfDeployment -eq "SingleNode") {
        $physicalNodeSettings = [PSCustomObject][Ordered]@{"value" = @([PSCustomObject][Ordered]@{
            "name" = $nodeNames[0]
            "ipv4Address" = $nodeIPAddresses[0]
            })
        }
    } else {
        # MultiNode, Switchless, and RackAware: build physical node settings dynamically
        $nodeSettingsArray = @()
        for ($i = 0; $i -lt $effectiveNodeCount; $i++) {
            $nodeSettingsArray += [PSCustomObject][Ordered]@{
                "name" = $nodeNames[$i]
                "ipv4Address" = $nodeIPAddresses[$i]
            }
        }
        $physicalNodeSettings = [PSCustomObject][Ordered]@{"value" = $nodeSettingsArray}
    }

    # Determine the deployment phases based on DeploymentMode
    if ($DeploymentMode -eq "ValidateAndDeploy") {
        $deploymentPhases = @("Validate", "Deploy")
    } else {
        $deploymentPhases = @($DeploymentMode)
    }

    # Define the parameters that need to be modified for the ARM template deployment
    # This variable is a PSCustomObject, that contains the parameters (stored as [PSCustomObject] with value property)
    # The parameters are defined in the template parameter files, and are passed to the Resource Group deployment
    [PSCustomObject]$Parameters = [Ordered]@{
        "location" = [PSCustomObject][Ordered]@{"value" = $Location}
        "clusterName" = [PSCustomObject][Ordered]@{"value" = $ClusterName}
        "tenantId" = [PSCustomObject][Ordered]@{"value" = $TenantId}
        "arcNodeResourceIds" = [PSCustomObject][Ordered]@{"value" = $arcNodeResourceIds}
        "keyVaultName" = [PSCustomObject][Ordered]@{"value" = $KeyVaultName}
        "azureStackLCMAdminUsername" = [PSCustomObject][Ordered]@{"value" = $AzureStackLCMAdminUsername}
        "customLocation" = [PSCustomObject][Ordered]@{"value" = $CustomLocation}
        "resourceBridgeName" = [PSCustomObject][Ordered]@{"value" = $ResourceBridgeName}
        "diagnosticStorageAccountName" = [PSCustomObject][Ordered]@{"value" = $StorageAccountName}
        "witnessType" = [PSCustomObject][Ordered]@{"value" = $witnessType}
        "clusterWitnessStorageAccountName" = [PSCustomObject][Ordered]@{"value" = $ClusterWitnessStorageAccountName}
        "storageAccountType" = [PSCustomObject][Ordered]@{"value" = $StorageAccountType}
        "subnetMask" = [PSCustomObject][Ordered]@{"value" = $SubnetMask}
        "defaultGateway" = [PSCustomObject][Ordered]@{"value" = $DefaultGateway}
        "startingIPAddress" = [PSCustomObject][Ordered]@{"value" = $startingIPAddress}
        "endingIPAddress" = [PSCustomObject][Ordered]@{"value" = $endingIPAddress}
        "domainFqdn" = [PSCustomObject][Ordered]@{"value" = $DomainFqdn}
        "namingPrefix" = [PSCustomObject][Ordered]@{"value" = $NamingPrefix}
        "adouPath" = [PSCustomObject][Ordered]@{"value" = $adouPath}
        "dnsServers" = [PSCustomObject][Ordered]@{"value" = $DnsServers}
        "storageConnectivitySwitchless" = [PSCustomObject][Ordered]@{"value" = $storageConnectivitySwitchless}
        "clusterPattern" = [PSCustomObject][Ordered]@{"value" = $clusterPattern}
        "localAvailabilityZones" = [PSCustomObject][Ordered]@{"value" = $localAvailabilityZones}
        "physicalNodesSettings" = $physicalNodeSettings
        "hciResourceProviderObjectID" = [PSCustomObject][Ordered]@{"value" = $hciResourceProviderObjectID}
        "deploymentMode" = [PSCustomObject][Ordered]@{"value" = $deploymentPhases[0]}
    }

    # Create the deployment
    # ($deploymentName was resolved and validated earlier alongside other resource names)
    
    # Verify the resource group and Arc nodes exist before starting deployment
    $ResourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if(-not($ResourceGroup)) {
        Write-AzLocalLog "Resource group '$ResourceGroupName' not found in Subscription: $SubscriptionID." -Level Error
        Write-AzLocalLog "Unable to proceed - Arc Node(s) cannot exist in Azure if the resource group does not exist." -Level Error
        throw "Resource group '$ResourceGroupName' not found."

    } else {

        # Resource group exists, check if the Arc Nodes exist in the resource group
        Write-AzLocalLog "Found target resource group '$ResourceGroupName' for deployment." -Level Success
        ForEach($arcNodeResourceId in $arcNodeResourceIds) {
            Write-AzLocalLog "Checking Arc Node is registered in resource group: '$ResourceGroupName'" -Level Warning
            Write-Verbose "Arc Node Resource ID: '$arcNodeResourceId'"
            $ClusterNodeCheck = $null
            $ClusterNodeCheck = Get-AzResource -ResourceId $arcNodeResourceId -ErrorAction SilentlyContinue
            if($ClusterNodeCheck) {
                Write-AzLocalLog "Arc Node exists in target resource group: '$ResourceGroupName'" -Level Success
            } else {
                Write-AzLocalLog "Arc node not found in target resource group: '$ResourceGroupName'" -Level Error
                Write-AzLocalLog "Missing Resource ID: $arcNodeResourceId" -Level Error
                throw "Arc node '$arcNodeResourceId' not found in resource group '$ResourceGroupName'."
            }
        }
    }

    try{
        # Execute each deployment phase (Validate, then optionally Deploy)
        foreach ($phase in $deploymentPhases) {

            Write-AzLocalLog "========================================================" -Level Info -NoTimestamp
            Write-AzLocalLog "  Deployment Phase: $phase" -Level Info -NoTimestamp
            Write-AzLocalLog "========================================================" -Level Info -NoTimestamp

            # ShouldProcess gate - respects -WhatIf and -Confirm
            if (-not $PSCmdlet.ShouldProcess("Resource Group '$ResourceGroupName'", "$phase deployment '$deploymentName'")) {
                Write-AzLocalLog "Deployment phase '$phase' skipped by user." -Level Warning
                continue
            }

            # Update the deploymentMode in the parameter file for this phase
            $Parameters.deploymentMode = [PSCustomObject][Ordered]@{"value" = $phase}

            # Re-generate the deployment parameter file with the updated deploymentMode
            # Reload the base parameter file settings to avoid stale state
            Write-Verbose "Reloading parameter file settings for '$phase' phase..."
            [PsCustomObject]$PhaseParameterFileSettings = Get-AzLocalParameterFileSettings -ParameterFilePath $ParameterFilePath

            # Re-apply adapter overrides to the fresh parameter file settings
            foreach ($intent in $PhaseParameterFileSettings.parameters.intentList.value) {
                if ($intent.name -eq "Compute_Management") { $intent.adapter = $ComputeManagementAdapters }
                if ($intent.name -eq "Storage") { $intent.adapter = $StorageAdapters }
            }
            for ($si = 0; $si -lt $PhaseParameterFileSettings.parameters.storageNetworkList.value.Count; $si++) {
                if ($si -lt $StorageAdapters.Count) {
                    $PhaseParameterFileSettings.parameters.storageNetworkList.value[$si].networkAdapterName = $StorageAdapters[$si]
                }
            }

            $DeploymentParameterFile = New-AzLocalDeploymentParameterFile -Parameters $Parameters -UniqueID $UniqueID -TypeOfDeployment $TypeOfDeployment -ParameterFileSettings $PhaseParameterFileSettings
            if(-Not (Test-Path $DeploymentParameterFile)) {
                throw "Deployment parameter file was not created for '$phase' phase."
            }

            # Start the deployment for this phase
            Write-AzLocalLog "Starting '$phase' deployment '$deploymentName' in resource group: '$ResourceGroupName'" -Level Success
            $ClusterDeployment = New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFilePath -TemplateParameterFile $DeploymentParameterFile -AzureStackLCMAdminPassword $AzureStackLCMAdminPassword -localAdminPassword $localAdminPassword -Verbose -ErrorVariable ClusterDeploymentError -ErrorAction Stop

            if ($ClusterDeployment.ProvisioningState -eq "Succeeded") {
                Write-AzLocalLog "'$phase' phase succeeded!" -Level Success
            } else {
                Write-AzLocalLog "'$phase' phase failed! ProvisioningState: $($ClusterDeployment.ProvisioningState)" -Level Error
                Write-AzLocalLog "Error details: $ClusterDeploymentError" -Level Error
                return $ClusterDeployment
            }

            # If this was the Validate phase and there is a Deploy phase next, inform the user
            if ($phase -eq "Validate" -and $deploymentPhases.Count -gt 1) {
                Write-AzLocalLog "Validation succeeded. Proceeding to Deploy phase..." -Level Success
                Write-Verbose "Reference: https://learn.microsoft.com/en-us/azure/azure-local/deploy/deployment-azure-resource-manager-template"
            }
        }
    } catch {
        Write-AzLocalLog "Error during '$($deploymentPhases[-1])' deployment: $($_.Exception.Message)" -Level Error
        throw
    } finally {
        # Clear sensitive credential variables from memory
        $localAdminPassword = $null
        $AzureStackLCMAdminPassword = $null
        $kvLocalSecret = $null
        $kvLCMSecret = $null
    }
    
    Write-AzLocalLog "All deployment phases completed successfully!" -Level Success
    
    # Return the deployment object for further processing
    return $ClusterDeployment
}
