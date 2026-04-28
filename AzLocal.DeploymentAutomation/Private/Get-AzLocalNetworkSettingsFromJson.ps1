Function Get-AzLocalNetworkSettingsFromJson {
    <#
    .SYNOPSIS

    Loads network settings from a JSON file or JSON string for non-interactive deployments.

    .DESCRIPTION

    Parses a JSON file path or inline JSON string containing network settings and validates
    the required fields. Expected JSON structure:

        {
            "subnetMask": "255.255.255.0",
            "defaultGateway": "10.0.0.1",
            "startingIPAddress": "10.0.0.10",
            "endingIPAddress": "10.0.0.50",
            "nodeIPAddresses": ["10.0.0.100", "10.0.0.101"]
        }

    #>

    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$NetworkSettingsJson,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$TypeOfDeployment,

        [Parameter(Mandatory = $false, Position = 2)]
        [int]$NodeCount = 0
    )

    # Determine effective node count for validation
    switch ($TypeOfDeployment) {
        "SingleNode" { $expectedNodes = 1 }
        default      { $expectedNodes = $NodeCount }
    }

    # Load JSON from file path or inline string
    if (Test-Path $NetworkSettingsJson -ErrorAction SilentlyContinue) {
        Write-Verbose "Loading network settings from file: $NetworkSettingsJson"
        try {
            $jsonContent = Get-Content $NetworkSettingsJson -Raw -ErrorAction Stop
            $settings = $jsonContent | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Write-AzLocalLog "Failed to read or parse network settings file '$NetworkSettingsJson'." -Level Error
            throw "Failed to parse network settings file. $($_.Exception.Message)"
        }
    } else {
        Write-Verbose "Parsing inline network settings JSON..."
        try {
            $settings = $NetworkSettingsJson | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Write-AzLocalLog "Failed to parse network settings JSON string." -Level Error
            throw "Failed to parse network settings JSON. $($_.Exception.Message)"
        }
    }

    # Validate required fields
    $requiredFields = @('subnetMask', 'defaultGateway', 'startingIPAddress', 'endingIPAddress', 'nodeIPAddresses')
    foreach ($field in $requiredFields) {
        if (-not $settings.PSObject.Properties[$field]) {
            Write-AzLocalLog "Network settings JSON is missing required field '$field'." -Level Error
            throw "Network settings JSON is missing required field '$field'."
        }
    }

    # Validate IP address formats
    try {
        [System.Net.IPAddress]::Parse($settings.subnetMask) | Out-Null
        [System.Net.IPAddress]::Parse($settings.defaultGateway) | Out-Null
        [System.Net.IPAddress]::Parse($settings.startingIPAddress) | Out-Null
        [System.Net.IPAddress]::Parse($settings.endingIPAddress) | Out-Null
    } catch {
        Write-AzLocalLog "Invalid IP address format in network settings JSON." -Level Error
        throw "Invalid IP address in network settings JSON. $($_.Exception.Message)"
    }

    # Validate node IP addresses
    $nodeIPs = @($settings.nodeIPAddresses)
    if ($nodeIPs.Count -ne $expectedNodes) {
        Write-AzLocalLog "Network settings JSON contains $($nodeIPs.Count) node IP addresses but $TypeOfDeployment deployment requires $expectedNodes." -Level Error
        throw "Expected $expectedNodes node IP addresses for $TypeOfDeployment deployment, but found $($nodeIPs.Count)."
    }
    foreach ($nodeIP in $nodeIPs) {
        try {
            [System.Net.IPAddress]::Parse($nodeIP) | Out-Null
        } catch {
            Write-AzLocalLog "Invalid node IP address '$nodeIP' in network settings JSON." -Level Error
            throw "Invalid node IP address '$nodeIP'. $($_.Exception.Message)"
        }
    }

    # For Disaggregated (SAN) deployments, also extract SAN-specific settings.
    # Expected optional sanSettings block:
    #   "sanSettings": {
    #       "infraVolLunId": "PURE1234567890ABCDEF",
    #       "infraPerfLunId": "PURE0987654321MNOPQR",
    #       "sanNetworkAdapterName": "ethernet 3",
    #       "sanNetworkVlanId": 711,
    #       "sanNetworkAddressPrefix": "10.10.30.0/24"
    #   }
    $sanSettings = $null
    if ($TypeOfDeployment -eq 'Disaggregated') {
        if (-not $settings.PSObject.Properties['sanSettings'] -or -not $settings.sanSettings) {
            throw "Disaggregated deployments require a 'sanSettings' block in the network settings JSON (infraVolLunId, infraPerfLunId, sanNetworkAdapterName, sanNetworkVlanId, sanNetworkAddressPrefix)."
        }
        $san = $settings.sanSettings
        $requiredSan = @('infraVolLunId', 'infraPerfLunId', 'sanNetworkAdapterName', 'sanNetworkVlanId', 'sanNetworkAddressPrefix')
        foreach ($f in $requiredSan) {
            if (-not $san.PSObject.Properties[$f] -or [string]::IsNullOrWhiteSpace([string]$san.$f)) {
                throw "Disaggregated network settings JSON is missing required sanSettings field '$f'."
            }
        }
        $sanVlan = 0
        if (-not [int]::TryParse([string]$san.sanNetworkVlanId, [ref]$sanVlan) -or $sanVlan -lt 0 -or $sanVlan -gt 4095) {
            throw "sanSettings.sanNetworkVlanId must be an integer 0-4095."
        }
        if ([string]$san.sanNetworkAddressPrefix -notmatch '^(\d{1,3}\.){3}\d{1,3}/\d{1,2}$') {
            throw "sanSettings.sanNetworkAddressPrefix must be valid CIDR notation (e.g. 10.10.30.0/24)."
        }
        $sanSettings = [PsCustomObject][Ordered]@{
            infraVolLunId           = $san.infraVolLunId
            infraPerfLunId          = $san.infraPerfLunId
            sanNetworkAdapterName   = $san.sanNetworkAdapterName
            sanNetworkVlanId        = $sanVlan
            sanNetworkAddressPrefix = $san.sanNetworkAddressPrefix
        }
    }

    Write-AzLocalLog "Network settings loaded from JSON successfully." -Level Success

    return [PsCustomObject][Ordered]@{
        subnetMask        = $settings.subnetMask
        defaultGateway    = $settings.defaultGateway
        startingIPAddress = $settings.startingIPAddress
        endingIPAddress   = $settings.endingIPAddress
        nodeIPAddresses   = $nodeIPs
        sanSettings       = $sanSettings
    }
}
