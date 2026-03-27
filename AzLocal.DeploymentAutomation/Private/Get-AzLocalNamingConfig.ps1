Function Get-AzLocalNamingConfig {
    <#
    .SYNOPSIS

    Loads the naming configuration from the user profile, a specified path, or the module default.

    .DESCRIPTION

    Loads naming standards and defaults from a JSON configuration file. The configuration
    defines naming patterns for all Azure Local resources using placeholders such as
    {UniqueID}, {NodeNumber}, and {TypeOfDeployment}.

    Configuration is resolved in the following priority order:
    1. Explicit path via -Path parameter (highest priority)
    2. User profile config: $env:USERPROFILE\.AzLocalDeploymentAutomation\naming-standards-config.json
    3. Auto-initialise: copies the module default to the user profile directory and uses it

    The auto-initialise step ensures that customisations survive module updates via Update-Module.

    Returns a PSCustomObject with two properties:
    - Config: The parsed configuration object
    - ResolvedPath: The full path to the configuration file that was loaded

    .PARAMETER Path
    Optional. Explicit path to a naming-standards-config.json file. When specified, this
    takes highest priority and skips user profile and module default lookups.

    #>

    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path = ""
    )

    # Priority 1: Explicit path provided via parameter
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        if (-not (Test-Path $Path)) {
            Write-AzLocalLog "Naming configuration file not found at specified path: '$Path'." -Level Error
            throw "Naming configuration file not found at '$Path'."
        }
        $configFilePath = $Path
    } else {
        # Priority 2: User profile config directory
        $userConfigPath = Join-Path $env:USERPROFILE '.AzLocalDeploymentAutomation\naming-standards-config.json'

        if (Test-Path $userConfigPath) {
            $configFilePath = $userConfigPath
        } else {
            # Priority 3: Auto-initialise user profile config from module defaults
            Write-AzLocalLog "No user configuration found. Initialising from module defaults..." -Level Warning
            $configFilePath = Initialize-AzLocalUserConfig
            Write-AzLocalLog "IMPORTANT: Please review and edit '$configFilePath' to set your environment-specific values (tenantId, domain, DNS servers, etc.) before running a deployment." -Level Warning
        }
    }

    try {
        $config = Get-Content $configFilePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        Write-AzLocalLog "Naming configuration loaded from '$configFilePath'." -Level Success
        return [PSCustomObject]@{
            Config       = $config
            ResolvedPath = $configFilePath
        }
    } catch {
        Write-AzLocalLog "Failed to parse naming configuration file." -Level Error
        throw "Failed to parse naming configuration file '$configFilePath'. $($_.Exception.Message)"
    }
}
