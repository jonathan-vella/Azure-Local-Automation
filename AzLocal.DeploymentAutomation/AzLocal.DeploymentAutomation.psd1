@{

    # Script module file associated with this manifest.
    RootModule = 'AzLocal.DeploymentAutomation.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # ID used to uniquely identify this module
    GUID = 'a3e4b8c1-6f2d-4e5a-9b1c-7d8e3f0a2b4c'

    # Author of this module
    Author = 'Neil Bird, MSFT'

    # Company or vendor of this module
    CompanyName = 'Microsoft'

    # Copyright statement for this module
    Copyright = '(c) Neil Bird. Published using MIT License, See LICENSE file for details.'

    # Description of the functionality provided by this module
    Description = 'AzLocal.DeploymentAutomation module for deploying Azure Local using ARM templates and parameter files using PowerShell. Supports SingleNode, StorageSwitched (2-16 nodes with storage network switch), StorageSwitchless (2-4 nodes), RackAware (2, 4, 6, 8 nodes), and Disaggregated/SAN (1-64 nodes, SAN-backed storage with infraVolLunId/infraPerfLunId) deployments. Resource naming standards are configurable via .config/naming-standards-config.json.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{ ModuleName = 'Az.Accounts'; ModuleVersion = '2.0.0' },
        @{ ModuleName = 'Az.Resources'; ModuleVersion = '6.0.0' }
        # Az.KeyVault (v4.0.0+) is optional — only required when using -CredentialKeyVaultName.
        # The module checks for Az.KeyVault at runtime and provides a clear error if it is needed but not installed.
    )
    
    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess.
    # .ps1 files listed here are dot-sourced into the root module's session state, so they share
    # $script: scope with the root module. Only files explicitly listed here are loaded — any
    # unauthorised .ps1 file placed in these directories will be ignored.
    NestedModules = @(
        # Private (internal) functions
        'Private\Format-Json.ps1'
        'Private\Get-AzLocalDeploymentNetworkSettings.ps1'
        'Private\Get-AzLocalNamingConfig.ps1'
        'Private\Get-AzLocalNetworkSettingsFromJson.ps1'
        'Private\Initialize-AzLocalUserConfig.ps1'
        'Private\Get-AzLocalParameterFilePath.ps1'
        'Private\Get-AzLocalParameterFileSettings.ps1'
        'Private\Get-AzLocalValidationTroubleshootingHints.ps1'
        'Private\Get-ValidUniqueID.ps1'
        'Private\Import-AzLocalDeploymentCsv.ps1'
        'Private\Initialize-AzLocalLogFile.ps1'
        'Private\New-AzLocalDeploymentParameterFile.ps1'
        'Private\New-AzLocalDeploymentReport.ps1'
        'Private\New-AzLocalJUnitXml.ps1'
        'Private\Resolve-AzLocalResourceName.ps1'
        'Private\Test-AzLocalAzurePrerequisites.ps1'
        'Private\Test-AzLocalClusterPreFlight.ps1'
        'Private\Test-AzLocalNamingConfigDefaults.ps1'
        'Private\Test-AzLocalResourceNames.ps1'
        'Private\Write-AzLocalLog.ps1'

        # Public (exported) functions
        'Public\Get-AzLocalDeploymentStatus.ps1'
        'Public\Start-AzLocalCsvDeployment.ps1'
        'Public\Start-AzLocalTemplateDeployment.ps1'
        'Public\Watch-AzLocalDeployment.ps1'
    )

    # Functions to export from this module
    FunctionsToExport = @(
        'Start-AzLocalTemplateDeployment',
        'Watch-AzLocalDeployment',
        'Start-AzLocalCsvDeployment',
        'Get-AzLocalDeploymentStatus'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule
    PrivateData = @{
        PSData = @{
            # Tags applied to this module for discoverability
            Tags = @('Azure', 'AzureLocal', 'AzureStackHCI', 'Deployment', 'ARM', 'Template')

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/NeilBird/Azure-Local/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.DeploymentAutomation/README.md'

            # Release notes for this version
            ReleaseNotes = @'
## v1.0.0 - April 2026

### New deployment topology: Disaggregated (SAN storage)
Adds first-class support for SAN-backed Azure Local clusters of up to **64 nodes**, modeled on the official quickstart [microsoft.azurestackhci/create-cluster-san](https://github.com/Azure/azure-quickstart-templates/tree/master/quickstarts/microsoft.azurestackhci/create-cluster-san). Disaggregated clusters use external SAN LUNs (e.g. Pure Storage, NetApp, Dell PowerStore) instead of Storage Spaces Direct, and require additional infrastructure + performance LUN identifiers and a dedicated SAN cluster network.

- Added new TypeOfDeployment value: `Disaggregated` (1-64 nodes, SAN storage)
- Added new ARM template: `templates/azure-local-deployment-template-san.json` (uses `Microsoft.AzureStackHCI` API `2026-04-01-preview`, sets `storage.storageType = SAN`, `storage.san.{infraVolLunId,infraPerfLunId}`, replaces `hostNetwork.storageNetworks` with `hostNetwork.sanNetworks` object)
- Added new parameter-file template: `template-parameter-files/disaggregated-parameters-file.json`
- Added new parameters to `Start-AzLocalTemplateDeployment`: `-InfraVolLunId`, `-InfraPerfLunId`, `-SanNetworkAdapterName`, `-SanNetworkVlanId` (0-4095), `-SanNetworkAddressPrefix` (CIDR), `-SanBandwidthPercentageSmb` (1-97, default 50), `-SanJumboPacket` (1514|9014, default 9014)
- `configurationMode` is forced to `InfraOnly` for Disaggregated (the only value supported by the SAN deploymentSettings schema)
- Raised `-NodeCount` ValidateRange to (1, 64) - existing topology checks (SingleNode<=1, StorageSwitched 2-16, StorageSwitchless 2-4, RackAware 2/4/6/8) still apply
- `Start-AzLocalCsvDeployment` now accepts and forwards five new optional CSV columns: `InfraVolLunId`, `InfraPerfLunId`, `SanNetworkAdapterName`, `SanNetworkVlanId`, `SanNetworkAddressPrefix` (required only when TypeOfDeployment = Disaggregated)
- `Get-AzLocalNetworkSettingsFromJson` accepts a new optional `sanSettings` block (infraVolLunId, infraPerfLunId, sanNetworkAdapterName, sanNetworkVlanId, sanNetworkAddressPrefix) for non-interactive Disaggregated deployments
- `Get-AzLocalDeploymentNetworkSettings` prompts interactively for the SAN-specific values when TypeOfDeployment = Disaggregated
- `Import-AzLocalDeploymentCsv` validates the SAN columns (presence, VLAN range 0-4095, CIDR format) when a row is Disaggregated; non-Disaggregated rows can leave those columns blank
- Updated example `automation-pipelines/cluster-deployments.csv` with a Store005 Disaggregated 8-node row
- Per-phase parameter-file regeneration now skips the storageNetworkList override when running against the SAN template (the SAN template has no storageNetworkList; it uses sanNetworkList instead)
- Pre-flight, naming resolution, and KeyVault credential paths are unchanged - Disaggregated reuses all existing helpers

### Backwards-compatibility notes
- Existing parameter files, ARM template, and all four prior deployment topologies are unchanged
- `clusterPattern` and `localAvailabilityZones` parameters are emitted only for non-Disaggregated deployments (the SAN template does not declare them)
- The default `-NodeCount` ValidateRange has changed from (2, 16) to (1, 64). Calls passing NodeCount=1 explicitly are now accepted at the parameter-validation layer (still rejected for SingleNode by the topology check, which is unchanged)

## v0.9.81 - April 2026
- Fixed bug in Start-AzLocalTemplateDeployment where $_ was shadowed by a nested catch block, causing ARM deployment error details to be silently lost
- Fixed credential SecureString disposal gap: moved try/finally to wrap all post-credential code so credentials are always disposed even if pre-deployment checks throw
- Fixed Invoke-RestMethod -UseBasicParsing invalid parameter in Get-AzLocalValidationTroubleshootingHints (PS 5.1 does not support this parameter on Invoke-RestMethod) - online TSG search was silently broken
- Fixed [regex]::Unescape() in Format-Json corrupting legitimate escape sequences (UNC paths, literal backslashes) in JSON output
- Added NodeCount validation for StorageSwitchless in Get-AzLocalParameterFilePath and New-AzLocalDeploymentParameterFile - now throws a clear error instead of silently producing an invalid path
- Added NodeCount > 0 validation for multi-node deployment types in Get-AzLocalDeploymentNetworkSettings
- Added consecutive failure counter (limit 10) to Watch-AzLocalDeployment polling loop with error message logging - prevents unbounded silent retry on persistent failures
- Fixed IDisposable resource leak in New-AzLocalJUnitXml: XmlWriter and StringWriter now wrapped in try/finally
- Replaced non-ASCII emoji characters in New-AzLocalDeploymentReport with ASCII-compatible text markers to comply with encoding convention
- Fixed version mismatch between .NOTES and HTML footer in New-AzLocalDeploymentReport

## v0.9.8 - March 2026
- Added -NamingConfigPath parameter to Start-AzLocalTemplateDeployment, Start-AzLocalCsvDeployment, and Get-AzLocalDeploymentStatus for explicit config file specification
- New user profile config workflow: on first use, the module copies .config/naming-standards-config.json to $env:USERPROFILE\.AzLocalDeploymentAutomation\ so customisations survive Update-Module
- Config resolution priority: (1) explicit -NamingConfigPath, (2) user profile directory, (3) auto-initialise from module defaults
- New config validation: deployment functions now detect unmodified placeholder values (contoso.com, xxxxxxxx tenant ID, DC=contoso,DC=com) and block with actionable error messages
- New internal functions: Initialize-AzLocalUserConfig (profile config setup), Test-AzLocalNamingConfigDefaults (placeholder detection)
- Updated Get-AzLocalNamingConfig with -Path parameter and user profile fallback logic
- All CI/CD pipeline examples (GitHub Actions + Azure DevOps) now include naming_config_path/namingConfigPath parameter and pass -NamingConfigPath to all function calls
- Updated README and automation-pipelines README with new config workflow, parameter tables, and CI/CD guidance

## v0.9.7 - March 2026
- Changed Watch-AzLocalDeployment -TimeoutMinutes default from 180 to 0 (no timeout) so the watcher runs until the deployment reaches a terminal state, accommodating long-running deploy phases

## Earlier versions (v0.9.6 and below)
For full release history of v0.9.6 (RDMA / inbox driver / RP registration troubleshooting hints), v0.9.5 (GitHub Actions injection fix, Get-AzLocalValidationTroubleshootingHints + -SkipOnlineTSGSearch), v0.9.4 (Write-AzLocalLog + rich exceptions), v0.9.3 (TypeOfDeployment rename: MultiNode->StorageSwitched, Switchless->StorageSwitchless), v0.9.2 (Test-AzLocalAzurePrerequisites: RP + RBAC checks), and v0.9.1 (per-node-count switchless templates, -NodeCount parameter), see the GitHub repository: https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.DeploymentAutomation/README.md
- Updated Pester tests for new switchless file names and node-count selection (402 tests)

## v0.9.0 - February 2026
- Added CI/CD automation pipeline support for CSV-driven multi-cluster deployments
- New exported function: Start-AzLocalCsvDeployment — reads deployment CSV and submits ARM Validate/Deploy for eligible clusters
- New exported function: Get-AzLocalDeploymentStatus — monitors deployment progress across all clusters defined in CSV
- New internal functions: Import-AzLocalDeploymentCsv, Test-AzLocalClusterPreFlight, New-AzLocalJUnitXml
- Pre-flight checks: resource naming validation, resource group existence, Arc node registration, existing deployment detection
- JUnit XML output for CI/CD test result visibility (GitHub Actions dorny/test-reporter, Azure DevOps PublishTestResults)
- Example GitHub Actions workflows: validate-deployments.yml, deploy-clusters.yml, deployment-monitor.yml
- Example Azure DevOps pipelines: validate-deployments.yml, deploy-clusters.yml, deployment-monitor.yml
- Example cluster-deployments.csv with SingleNode, StorageSwitched, StorageSwitchless, and RackAware deployment types
- Authentication: OIDC (recommended), Managed Identity, Service Principal + Secret (legacy)
- automation-pipelines/README.md with full setup guide

For full release history for versions prior to v0.9.0, see:
https://github.com/NeilBird/Azure-Local/blob/main/AzLocal.DeploymentAutomation/README.md
'@
        }
    }
}
