Function Get-AzLocalDeploymentNetworkSettings {
    <#
    .SYNOPSIS

    This function retrieves the network settings for the Azure Local deployment.

    .DESCRIPTION

    This function retrieves the network settings for the Azure Local deployment. It requires the following parameters:
    - TypeOfDeployment: The type of deployment.
    - NodeCount: The number of nodes (required for StorageSwitched).

    #>

    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,Position=0)]
        [ValidateSet("SingleNode","StorageSwitchless","StorageSwitched","RackAware")]
        [string]$TypeOfDeployment,

        [Parameter(Mandatory = $false,Position=1)]
        [int]$NodeCount = 0
    )

    # Determine the effective node count based on deployment type
    switch ($TypeOfDeployment) {
        "SingleNode"            { $effectiveNodeCount = 1 }
        "StorageSwitchless"     { $effectiveNodeCount = $NodeCount }
        "StorageSwitched"       { $effectiveNodeCount = $NodeCount }
        "RackAware"             { $effectiveNodeCount = $NodeCount }
    }

    # Prompt for Network Settings
    # ///// Network Settings Prompt, cast the input to System.Net.IPAddress to validate the IP address format
    try{
        [System.Net.IPAddress]$subnetMask = Read-Host "Please enter the subnet mask (e.g. 255.255.255.224)" -ErrorAction Stop
        [System.Net.IPAddress]$defaultGateway = Read-Host "`nPlease enter the default gateway (e.g. 10.224.x.x)" -ErrorAction Stop
        [System.Net.IPAddress]$startingIPAddress = Read-Host "`nPlease enter the Management Network starting IP address (e.g. 10.224.x.x)" -ErrorAction Stop
        [System.Net.IPAddress]$endingIPAddress = Read-Host "`nPlease enter the Management Network ending IP address (e.g. 10.224.x.x)" -ErrorAction Stop

    } catch {
        Write-AzLocalLog "Invalid IP address or Subnet Mask format." -Level Error
        throw "Invalid IP address or Subnet Mask format. $($_.Exception.Message)"
    }
    # ///// Network Settings Prompt

    # Prompt for each node IP address dynamically
    $nodeIPAddresses = @()
    for ($i = 1; $i -le $effectiveNodeCount; $i++) {
        $paddedNum = $i.ToString("D2")
        try {
            [System.Net.IPAddress]$nodeIP = Read-Host "`nPlease enter Node$paddedNum IP address (e.g. 10.224.x.x)" -ErrorAction Stop
            $nodeIPAddresses += $nodeIP.IPAddressToString
        } catch {
            Write-AzLocalLog "Invalid IP address format for Node$paddedNum." -Level Error
            throw "Invalid IP address format for Node$paddedNum. $($_.Exception.Message)"
        }
    }

    # Return the network settings as a custom object
    $networkSettings = [PsCustomObject][Ordered]@{
        subnetMask       = $subnetMask.IPAddressToString
        defaultGateway   = $defaultGateway.IPAddressToString
        startingIPAddress = $startingIPAddress.IPAddressToString
        endingIPAddress  = $endingIPAddress.IPAddressToString
        nodeIPAddresses  = $nodeIPAddresses
    }

    return $networkSettings
}
