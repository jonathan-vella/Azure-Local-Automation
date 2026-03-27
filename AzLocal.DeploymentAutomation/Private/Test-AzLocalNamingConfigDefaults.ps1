Function Test-AzLocalNamingConfigDefaults {
    ########################################
    <#
    .SYNOPSIS
        Validates that the naming configuration has been customised from shipped defaults.

    .DESCRIPTION
        Checks the naming configuration object for placeholder/example values that ship with
        the module. These defaults (contoso.com, xxxxxxxx tenant ID) will never work in a real
        deployment, so this function provides a clear early failure with actionable guidance.

        Called by public deployment functions before any ARM operations are attempted.

    .PARAMETER Config
        The naming configuration object returned by Get-AzLocalNamingConfig.

    .PARAMETER ConfigFilePath
        The file path the configuration was loaded from, for error message context.

    .NOTES
        Author:  Neil Bird, MSFT
        Version: 1.0
        Created: March 27th 2026
    #>
    ########################################

    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory = $false)]
        [string]$ConfigFilePath = ""
    )

    $configErrors = @()

    # Check environment section exists and tenantId is not placeholder
    if ($null -eq $Config.PSObject.Properties['environment'] -or $null -eq $Config.environment) {
        $configErrors += "environment section is missing from the configuration file."
    } elseif ($Config.environment.tenantId -eq 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx') {
        $configErrors += "environment.tenantId is still the placeholder value. Set it to your Entra ID tenant GUID. Find it with: (Get-AzContext).Tenant.Id"
    }

    # Check defaults section exists and domainFqdn is not example value
    if ($null -eq $Config.PSObject.Properties['defaults'] -or $null -eq $Config.defaults) {
        $configErrors += "defaults section is missing from the configuration file."
    } elseif ($Config.defaults.domainFqdn -eq 'contoso.com') {
        $configErrors += "defaults.domainFqdn is still the example value 'contoso.com'. Set it to your Active Directory domain FQDN."
    }

    # Check namingStandards section exists and adouPath is not example value
    if ($null -eq $Config.PSObject.Properties['namingStandards'] -or $null -eq $Config.namingStandards) {
        $configErrors += "namingStandards section is missing from the configuration file."
    } elseif ($Config.namingStandards.adouPath -match 'DC=contoso,DC=com') {
        $configErrors += "namingStandards.adouPath still references 'DC=contoso,DC=com'. Update the OU path to match your Active Directory structure."
    }

    if ($configErrors.Count -gt 0) {
        Write-AzLocalLog "Naming configuration file has not been customised for your environment." -Level Error
        if (-not [string]::IsNullOrWhiteSpace($ConfigFilePath)) {
            Write-AzLocalLog "Config file: $ConfigFilePath" -Level Error
        }
        foreach ($err in $configErrors) {
            Write-AzLocalLog "  - $err" -Level Error
        }
        Write-AzLocalLog "Edit the configuration file and update the values above before running a deployment." -Level Error
        $pathHint = if (-not [string]::IsNullOrWhiteSpace($ConfigFilePath)) { " at '$ConfigFilePath'" } else { "" }
        throw "Naming configuration${pathHint} contains default/placeholder values that must be updated before deployment. See errors above."
    }
}
