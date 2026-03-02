@{

    # Script module file associated with this manifest.
    RootModule = 'AzLocal.DeploymentAutomation.psm1'

    # Version number of this module.
    ModuleVersion = '0.9.2'

    # ID used to uniquely identify this module
    GUID = 'a3e4b8c1-6f2d-4e5a-9b1c-7d8e3f0a2b4c'

    # Author of this module
    Author = 'Neil Bird, MSFT'

    # Company or vendor of this module
    CompanyName = 'Microsoft'

    # Copyright statement for this module
    Copyright = '(c) Neil Bird. All rights reserved. See LICENSE for details.'

    # Description of the functionality provided by this module
    Description = 'AzLocal.DeploymentAutomation module for deploying Azure Local using ARM templates and parameter files using PowerShell. Supports SingleNode, MultiNode switched (2-16 nodes), Switchless (2-4 nodes), and RackAware (2, 4, 6, 8 nodes) deployments. Resource naming standards are configurable via .config/naming-standards-config.json.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{ ModuleName = 'Az.Accounts'; ModuleVersion = '2.0.0' },
        @{ ModuleName = 'Az.Resources'; ModuleVersion = '6.0.0' },
        @{ ModuleName = 'Az.KeyVault'; ModuleVersion = '4.0.0' }
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
            ProjectUri = 'https://github.com/NeilBird/Azure-Local'

            # Release notes for this version
            ReleaseNotes = @'
## v0.9.2 - March 2026
- Added Azure prerequisite checks: automatic resource provider registration and RBAC role assignment validation
- New internal function: Test-AzLocalAzurePrerequisites — checks 12 required resource providers (auto-registers missing ones) and 6 required RBAC roles (advisory)
- Integrated prerequisite checks into both Start-AzLocalTemplateDeployment (standalone) and Test-AzLocalClusterPreFlight (CSV batch) paths
- RBAC checks are advisory (warnings) — missing roles are reported but do not block deployment
- Resource provider registration failures are hard failures — deployment cannot proceed without required providers
- Reference: https://learn.microsoft.com/azure/azure-local/deploy/deployment-arc-register-server-permissions
- Updated Pester tests with prerequisite check coverage

## v0.9.1 - March 2026
- Split switchless template into per-node-count files: switchless-2node, switchless-3node, switchless-4node (dual-link mesh: 2×(N-1) storage networks)
- Added -NodeCount parameter to Get-AzLocalParameterFilePath and New-AzLocalDeploymentParameterFile for switchless file selection
- Added environment section to .config/naming-standards-config.json for tenantId and hciResourceProviderObjectID
- HCI Resource Provider lookup now falls back to config value when Get-AzADServicePrincipal is unavailable
- Replaced real Azure GUIDs in example-single-node-parameters-file.json with placeholder values
- Fixed switchless networkingType from switchedMultiServerDeployment to switchlessMultiServerDeployment
- Fixed <caculated> typo to <calculated> in switchless template customLocation field
- Updated README with environment configuration steps, deployment type storage network details, and per-node-count file structure
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
- Example cluster-deployments.csv with SingleNode, MultiNode, Switchless, and RackAware deployment types
- Authentication: OIDC (recommended), Managed Identity, Service Principal + Secret (legacy)
- automation-pipelines/README.md with full setup guide

## v0.8.0 - February 2026
- Added Set-StrictMode -Version Latest at module scope for stricter runtime error detection
- Added [OutputType()] declarations to all functions for improved IntelliSense and documentation
- Replaced string concatenation with Join-Path for all path construction (cross-platform safe)
- Added Az.KeyVault module availability check before Key Vault credential retrieval
- Added finally block to clear credential variables from memory after deployment execution
- Removed no-op regex replacements and dead commented-out code
- Replaced Remove-Variable anti-pattern with null assignment
- Normalised return keyword casing throughout module

## v0.7.0 - February 2026
- Added PSCredential parameter support (-LocalAdminCredential, -LCMAdminCredential) for non-interactive credential supply
- Added Azure Key Vault credential retrieval (-CredentialKeyVaultName, -LocalAdminSecretName, -LCMAdminSecretName)
- Credential resolution follows three-tier priority: Key Vault > PSCredential > interactive Read-Host
- Added -UniqueID parameter with ValidatePattern for non-interactive unique identifier supply
- Added -NetworkSettingsJson parameter and Get-AzLocalNetworkSettingsFromJson internal function for JSON-based network configuration
- Added SupportsShouldProcess with ConfirmImpact = High: -WhatIf and -Confirm supported on deployment phases
- Full CI/CD automation support: all interactive prompts can now be bypassed via parameters
- Updated Pester test suite with 39 new tests covering credential, network JSON, UniqueID, and ShouldProcess features (259 total)

## v0.6.0 - February 2026
- Added Write-AzLocalLog internal helper for standardised console and log file output
- Added -LogFilePath parameter to Start-AzLocalTemplateDeployment and Watch-AzLocalDeployment
- All console output now uses timestamped, colour-coded messages with severity levels (Info, Warning, Error, Success, Debug, Verbose)
- Replaced all Return "Error" patterns with throw for proper PowerShell error handling
- Added try/catch with error context to Get-AzLocalParameterFileSettings
- Added Write-Verbose instrumentation throughout for diagnostic visibility (-Verbose support)
- Updated README with Watch-AzLocalDeployment documentation, usage examples, and parameter reference
- Updated Pester tests for new error handling patterns, Write-AzLocalLog, and LogFilePath parameter

## v0.5.0 - February 2026
- Added Watch-AzLocalDeployment function for monitoring long-running ARM deployments
- Polls deployment status at configurable intervals with status change history
- Supports -TimeoutMinutes and -PassThru parameters
- Exported as a public function alongside Start-AzLocalTemplateDeployment

## v0.4.0 - February 2026
- Added RackAware deployment type with auto-zone assignment (2, 4, 6, or 8 nodes, evenly split across ZoneA and ZoneB)
- Updated ARM template API version from 2024-09-01-preview to 2025-02-01-preview
- Added Azure Government Cloud support (KeyVaultDNS, AzureServiceEndpoint)
- Added clusterPattern and localAvailabilityZones ARM template parameters
- Fixed AzureStackLCMAdminPasssword typo across all files (now AzureStackLCMAdminPassword)
- Added allowSharedKeyAccess: false to StorageAccountConfigurations for security hardening
- Changed Key Vault enableSoftDelete from true to false (matching upstream)
- Added rack-aware-parameters-file.json template parameter file
- Updated Pester test suite for RackAware coverage

## v0.3.0 - February 2026
- Added ValidateAndDeploy deployment mode for automated two-phase deployments
- Added optional -Location parameter to override config default
- Added optional -DnsServers parameter to override config default
- Added optional -ComputeManagementAdapters parameter to override config default
- Added optional -StorageAdapters parameter to override config default
- DNS servers, adapter names now managed via .config/naming-standards-config.json defaults

## v0.2.0 - February 2026
- Added MultiNode switched deployment support
- Refactored StoreNumber to UniqueID for broader applicability
- Added .config/naming-standards-config.json for configurable resource naming standards
- Node names now use {UniqueID}NODE{NodeNumber} pattern with dynamic node numbering
- Added Get-AzLocalNamingConfig and Resolve-AzLocalResourceName helper functions
- Created module manifest (.psd1) exporting Start-AzLocalTemplateDeployment
- Added multi-node-switched-parameters-file.json template
- Added Pester test suite (Tests/ folder) with HTML report generation

## v0.1.1 - May 2025
- Initial release with SingleNode, TwoNode, and Switchless support
- TwoNode was later consolidated into MultiNode (2-16 nodes) in v0.8.0
'@
        }
    }
}
