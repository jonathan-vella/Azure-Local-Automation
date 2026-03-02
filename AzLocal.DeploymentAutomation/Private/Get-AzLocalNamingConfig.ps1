Function Get-AzLocalNamingConfig {
    <#
    .SYNOPSIS

    Loads the naming configuration from the .config/naming-standards-config.json file.

    .DESCRIPTION

    This function loads the naming standards and defaults from the JSON configuration file
    located in the .config folder. The configuration file defines naming patterns for all
    Azure Local resources using placeholders such as {UniqueID}, {NodeNumber}, and {TypeOfDeployment}.

    #>

    [OutputType([PSCustomObject])]
    param()

    $configFilePath = Join-Path $script:ModuleRoot ".config\naming-standards-config.json"

    if(-not(Test-Path $configFilePath)) {
        Write-AzLocalLog "Naming configuration file not found at '$configFilePath'." -Level Error
        Write-AzLocalLog "Please ensure the .config/naming-standards-config.json file exists." -Level Error
        throw "Naming configuration file not found at '$configFilePath'."
    }

    try {
        $config = Get-Content $configFilePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        Write-AzLocalLog "Naming configuration loaded from '$configFilePath'." -Level Success
        return $config
    } catch {
        Write-AzLocalLog "Failed to parse naming configuration file." -Level Error
        throw "Failed to parse naming configuration file '$configFilePath'. $($_.Exception.Message)"
    }
}
