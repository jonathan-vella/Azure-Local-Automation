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

    Write-AzLocalLog "Network settings loaded from JSON successfully." -Level Success

    return [PsCustomObject][Ordered]@{
        subnetMask        = $settings.subnetMask
        defaultGateway    = $settings.defaultGateway
        startingIPAddress = $settings.startingIPAddress
        endingIPAddress   = $settings.endingIPAddress
        nodeIPAddresses   = $nodeIPs
    }
}
