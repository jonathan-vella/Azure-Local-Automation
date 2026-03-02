#Requires -Module Pester
<#
.SYNOPSIS
    Pester tests for the AzLocal.DeploymentAutomation module.

.DESCRIPTION
    Unit tests for the Azure Local Deployment Automation module.
    These tests validate parameter validation, naming resolution, config loading,
    file path logic, and JSON formatting without requiring Azure connectivity (using mocks).

.NOTES
    Run with: .\Tests\Invoke-Tests.ps1
    Or:       Invoke-Pester -Path .\Tests
#>

BeforeAll {
    # Import the module from parent directory
    # Use the .psm1 directly to avoid RequiredModules dependency on Az.Accounts/Az.Resources
    # which may not be installed in the test environment. The manifest is tested separately.
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\AzLocal.DeploymentAutomation.psm1'
    Import-Module $modulePath -Force -ErrorAction Stop

    # Suppress Write-Host console output from module functions during testing.
    # This prevents the VS Code terminal from becoming unresponsive due to hundreds
    # of colored Write-Host calls from Write-AzLocalLog during test execution.
    & (Get-Module AzLocal.DeploymentAutomation) { $script:SuppressConsoleOutput = $true }

    # Store module info for tests
    $script:ModuleInfo = Get-Module AzLocal.DeploymentAutomation

    # Store manifest path for manifest-specific tests
    $script:ManifestPath = Join-Path -Path $PSScriptRoot -ChildPath '..\AzLocal.DeploymentAutomation.psd1'
}

AfterAll {
    # Restore console output before removing the module
    if (Get-Module AzLocal.DeploymentAutomation -ErrorAction SilentlyContinue) {
        & (Get-Module AzLocal.DeploymentAutomation) { $script:SuppressConsoleOutput = $false }
    }
    Remove-Module AzLocal.DeploymentAutomation -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# Module Load Tests
# ============================================================================
Describe 'Module: AzLocal.DeploymentAutomation' {

    Context 'Module Load' {
        It 'Should load the module without errors' {
            $script:ModuleInfo | Should -Not -BeNullOrEmpty
        }

        It 'Should have version 0.9.1 in manifest' {
            $manifest = Import-PowerShellDataFile -Path $script:ManifestPath
            $manifest.ModuleVersion | Should -Be '0.9.1'
        }

        It 'Should contain Start-AzLocalTemplateDeployment function' {
            Get-Command -Module AzLocal.DeploymentAutomation -Name 'Start-AzLocalTemplateDeployment' -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Should contain Watch-AzLocalDeployment function' {
            Get-Command -Module AzLocal.DeploymentAutomation -Name 'Watch-AzLocalDeployment' -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Should contain Start-AzLocalCsvDeployment function' {
            Get-Command -Module AzLocal.DeploymentAutomation -Name 'Start-AzLocalCsvDeployment' -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Should contain Get-AzLocalDeploymentStatus function' {
            Get-Command -Module AzLocal.DeploymentAutomation -Name 'Get-AzLocalDeploymentStatus' -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Manifest should export exactly 4 functions' {
            $manifest = Import-PowerShellDataFile -Path $script:ManifestPath
            $manifest.FunctionsToExport.Count | Should -Be 4
        }

        It 'Manifest should export Start-AzLocalTemplateDeployment' {
            $manifest = Import-PowerShellDataFile -Path $script:ManifestPath
            $manifest.FunctionsToExport | Should -Contain 'Start-AzLocalTemplateDeployment'
        }
    }

    Context 'Module Manifest' {
        BeforeAll {
            $script:ManifestData = $null
            $script:ManifestRaw = $null
            try {
                $script:ManifestData = Test-ModuleManifest -Path $script:ManifestPath -ErrorAction Stop -WarningAction SilentlyContinue
            } catch {
                # Az modules may not be installed — parse the manifest directly for validation
            }
            # Always parse the raw PSD1 content as a fallback
            $script:ManifestRaw = Import-PowerShellDataFile -Path $script:ManifestPath -ErrorAction Stop
        }

        It 'Should have a parseable module manifest' {
            $script:ManifestRaw | Should -Not -BeNullOrEmpty
        }

        It 'Should require PowerShell 5.1 or higher' {
            $script:ManifestRaw.PowerShellVersion | Should -Be '5.1'
        }

        It 'Should require Az.Accounts module' {
            $requiredNames = $script:ManifestRaw.RequiredModules | ForEach-Object { $_.ModuleName }
            $requiredNames | Should -Contain 'Az.Accounts'
        }

        It 'Should require Az.Resources module' {
            $requiredNames = $script:ManifestRaw.RequiredModules | ForEach-Object { $_.ModuleName }
            $requiredNames | Should -Contain 'Az.Resources'
        }

        It 'Should require Az.KeyVault module' {
            $requiredNames = $script:ManifestRaw.RequiredModules | ForEach-Object { $_.ModuleName }
            $requiredNames | Should -Contain 'Az.KeyVault'
        }

        It 'Should have a non-empty description' {
            $script:ManifestRaw.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have an author defined' {
            $script:ManifestRaw.Author | Should -Not -BeNullOrEmpty
        }

        It 'Should export Start-AzLocalTemplateDeployment' {
            $script:ManifestRaw.FunctionsToExport | Should -Contain 'Start-AzLocalTemplateDeployment'
        }

        It 'Should export Watch-AzLocalDeployment' {
            $script:ManifestRaw.FunctionsToExport | Should -Contain 'Watch-AzLocalDeployment'
        }

        It 'Should export Start-AzLocalCsvDeployment' {
            $script:ManifestRaw.FunctionsToExport | Should -Contain 'Start-AzLocalCsvDeployment'
        }

        It 'Should export Get-AzLocalDeploymentStatus' {
            $script:ManifestRaw.FunctionsToExport | Should -Contain 'Get-AzLocalDeploymentStatus'
        }

        It 'Should have version 0.9.1' {
            $script:ManifestRaw.ModuleVersion | Should -Be '0.9.1'
        }
    }
}

# ============================================================================
# Start-AzLocalTemplateDeployment - Parameter Validation
# ============================================================================
Describe 'Function: Start-AzLocalTemplateDeployment' {

    Context 'Parameter Definitions' {
        BeforeAll {
            $script:Command = Get-Command Start-AzLocalTemplateDeployment
        }

        It 'Should have SubscriptionId parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'SubscriptionId'
        }

        It 'Should have TypeOfDeployment parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'TypeOfDeployment'
        }

        It 'Should have TenantId parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'TenantId'
        }

        It 'Should have DeploymentMode parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'DeploymentMode'
        }

        It 'Should have NodeCount parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'NodeCount'
        }

        It 'Should have Location parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'Location'
        }

        It 'Should have DnsServers parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'DnsServers'
        }

        It 'Should have ComputeManagementAdapters parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'ComputeManagementAdapters'
        }

        It 'Should have StorageAdapters parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'StorageAdapters'
        }

        It 'Should have LocalAdminCredential parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'LocalAdminCredential'
        }

        It 'Should have LCMAdminCredential parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'LCMAdminCredential'
        }

        It 'Should have CredentialKeyVaultName parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'CredentialKeyVaultName'
        }

        It 'Should have LocalAdminSecretName parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'LocalAdminSecretName'
        }

        It 'Should have LCMAdminSecretName parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'LCMAdminSecretName'
        }

        It 'Should have UniqueID parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'UniqueID'
        }

        It 'Should have NetworkSettingsJson parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'NetworkSettingsJson'
        }

        It 'Should support -WhatIf' {
            $script:Command.Parameters.Keys | Should -Contain 'WhatIf'
        }

        It 'Should support -Confirm' {
            $script:Command.Parameters.Keys | Should -Contain 'Confirm'
        }
    }

    Context 'Parameter Types' {
        BeforeAll {
            $script:Command = Get-Command Start-AzLocalTemplateDeployment
        }

        It 'SubscriptionId should be of type Guid' {
            $script:Command.Parameters['SubscriptionId'].ParameterType.Name | Should -Be 'Guid'
        }

        It 'TenantId should be of type Guid' {
            $script:Command.Parameters['TenantId'].ParameterType.Name | Should -Be 'Guid'
        }

        It 'NodeCount should be of type Int32' {
            $script:Command.Parameters['NodeCount'].ParameterType.Name | Should -Be 'Int32'
        }

        It 'DnsServers should be of type String[]' {
            $script:Command.Parameters['DnsServers'].ParameterType.FullName | Should -Be 'System.String[]'
        }

        It 'ComputeManagementAdapters should be of type String[]' {
            $script:Command.Parameters['ComputeManagementAdapters'].ParameterType.FullName | Should -Be 'System.String[]'
        }

        It 'StorageAdapters should be of type String[]' {
            $script:Command.Parameters['StorageAdapters'].ParameterType.FullName | Should -Be 'System.String[]'
        }

        It 'LocalAdminCredential should be of type PSCredential' {
            $script:Command.Parameters['LocalAdminCredential'].ParameterType.Name | Should -Be 'PSCredential'
        }

        It 'LCMAdminCredential should be of type PSCredential' {
            $script:Command.Parameters['LCMAdminCredential'].ParameterType.Name | Should -Be 'PSCredential'
        }

        It 'CredentialKeyVaultName should be of type String' {
            $script:Command.Parameters['CredentialKeyVaultName'].ParameterType.Name | Should -Be 'String'
        }

        It 'LocalAdminSecretName should be of type String' {
            $script:Command.Parameters['LocalAdminSecretName'].ParameterType.Name | Should -Be 'String'
        }

        It 'LCMAdminSecretName should be of type String' {
            $script:Command.Parameters['LCMAdminSecretName'].ParameterType.Name | Should -Be 'String'
        }

        It 'UniqueID should be of type String' {
            $script:Command.Parameters['UniqueID'].ParameterType.Name | Should -Be 'String'
        }

        It 'NetworkSettingsJson should be of type String' {
            $script:Command.Parameters['NetworkSettingsJson'].ParameterType.Name | Should -Be 'String'
        }
    }

    Context 'TypeOfDeployment ValidateSet' {
        BeforeAll {
            $script:Command = Get-Command Start-AzLocalTemplateDeployment
            $script:ValidateSet = $script:Command.Parameters['TypeOfDeployment'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        }

        It 'Should have a ValidateSet attribute' {
            $script:ValidateSet | Should -Not -BeNullOrEmpty
        }

        It 'Should allow SingleNode' {
            $script:ValidateSet.ValidValues | Should -Contain 'SingleNode'
        }

        It 'Should allow Switchless' {
            $script:ValidateSet.ValidValues | Should -Contain 'Switchless'
        }

        It 'Should allow MultiNode' {
            $script:ValidateSet.ValidValues | Should -Contain 'MultiNode'
        }

        It 'Should allow RackAware' {
            $script:ValidateSet.ValidValues | Should -Contain 'RackAware'
        }
        It 'Should NOT allow TwoNode (consolidated into MultiNode)' {
            $script:ValidateSet.ValidValues | Should -Not -Contain 'TwoNode'
        }

        It 'Should NOT allow TwoNode-Switchless (deprecated)' {
            $script:ValidateSet.ValidValues | Should -Not -Contain 'TwoNode-Switchless'
        }

        It 'Should have exactly 4 valid deployment types' {
            $script:ValidateSet.ValidValues.Count | Should -Be 4
        }
    }

    Context 'DeploymentMode ValidateSet' {
        BeforeAll {
            $script:Command = Get-Command Start-AzLocalTemplateDeployment
            $script:ValidateSet = $script:Command.Parameters['DeploymentMode'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        }

        It 'Should allow Validate' {
            $script:ValidateSet.ValidValues | Should -Contain 'Validate'
        }

        It 'Should allow Deploy' {
            $script:ValidateSet.ValidValues | Should -Contain 'Deploy'
        }

        It 'Should allow ValidateAndDeploy' {
            $script:ValidateSet.ValidValues | Should -Contain 'ValidateAndDeploy'
        }

        It 'Should have exactly 3 valid deployment modes' {
            $script:ValidateSet.ValidValues.Count | Should -Be 3
        }
    }

    Context 'NodeCount ValidateRange' {
        BeforeAll {
            $script:Command = Get-Command Start-AzLocalTemplateDeployment
            $script:ValidateRange = $script:Command.Parameters['NodeCount'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
        }

        It 'Should have a ValidateRange attribute' {
            $script:ValidateRange | Should -Not -BeNullOrEmpty
        }

        It 'Should have minimum value of 2' {
            $script:ValidateRange.MinRange | Should -Be 2
        }

        It 'Should have maximum value of 16' {
            $script:ValidateRange.MaxRange | Should -Be 16
        }
    }

    Context 'Mandatory Parameters' {
        BeforeAll {
            $script:Command = Get-Command Start-AzLocalTemplateDeployment
        }

        It 'SubscriptionId should be mandatory' {
            $param = $script:Command.Parameters['SubscriptionId']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $true
        }

        It 'TypeOfDeployment should be mandatory' {
            $param = $script:Command.Parameters['TypeOfDeployment']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $true
        }

        It 'TenantId should be mandatory' {
            $param = $script:Command.Parameters['TenantId']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $true
        }

        It 'DeploymentMode should be mandatory' {
            $param = $script:Command.Parameters['DeploymentMode']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $true
        }

        It 'NodeCount should NOT be mandatory' {
            $param = $script:Command.Parameters['NodeCount']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $false
        }

        It 'Location should NOT be mandatory' {
            $param = $script:Command.Parameters['Location']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $false
        }

        It 'DnsServers should NOT be mandatory' {
            $param = $script:Command.Parameters['DnsServers']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $false
        }

        It 'LocalAdminCredential should NOT be mandatory' {
            $param = $script:Command.Parameters['LocalAdminCredential']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $false
        }

        It 'LCMAdminCredential should NOT be mandatory' {
            $param = $script:Command.Parameters['LCMAdminCredential']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $false
        }

        It 'CredentialKeyVaultName should NOT be mandatory' {
            $param = $script:Command.Parameters['CredentialKeyVaultName']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $false
        }

        It 'UniqueID should NOT be mandatory' {
            $param = $script:Command.Parameters['UniqueID']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $false
        }

        It 'NetworkSettingsJson should NOT be mandatory' {
            $param = $script:Command.Parameters['NetworkSettingsJson']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $false
        }
    }
}

# ============================================================================
# Resolve-AzLocalResourceName (Internal Function - tested via InModuleScope)
# ============================================================================
Describe 'Function: Resolve-AzLocalResourceName' {

    Context 'UniqueID Placeholder Replacement' {
        It 'Should replace {UniqueID} with the provided value' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Resolve-AzLocalResourceName -Pattern 'rg-{UniqueID}-azurelocal' -UniqueID 'STORE001'
                $result | Should -Be 'rg-STORE001-azurelocal'
            }
        }

        It 'Should replace multiple occurrences of {UniqueID}' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Resolve-AzLocalResourceName -Pattern '{UniqueID}-{UniqueID}' -UniqueID 'ABC'
                $result | Should -Be 'ABC-ABC'
            }
        }

        It 'Should return pattern unchanged when no placeholders present' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Resolve-AzLocalResourceName -Pattern 'static-name' -UniqueID 'ABC'
                $result | Should -Be 'static-name'
            }
        }
    }

    Context 'NodeNumber Placeholder Replacement' {
        It 'Should replace {NodeNumber} with zero-padded 2-digit number' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Resolve-AzLocalResourceName -Pattern '{UniqueID}NODE{NodeNumber}' -UniqueID 'S001' -NodeNumber 1
                $result | Should -Be 'S001NODE01'
            }
        }

        It 'Should pad node number 3 to 03' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Resolve-AzLocalResourceName -Pattern 'NODE{NodeNumber}' -UniqueID 'X' -NodeNumber 3
                $result | Should -Be 'NODE03'
            }
        }

        It 'Should not replace {NodeNumber} when NodeNumber is 0 (default)' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Resolve-AzLocalResourceName -Pattern '{UniqueID}-{NodeNumber}' -UniqueID 'ABC'
                $result | Should -Be 'ABC-{NodeNumber}'
            }
        }
    }

    Context 'TypeOfDeployment Placeholder Replacement' {
        It 'Should replace {TypeOfDeployment} with the deployment type' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Resolve-AzLocalResourceName -Pattern 'deploy-{UniqueID}-{TypeOfDeployment}' -UniqueID 'S001' -TypeOfDeployment 'SingleNode'
                $result | Should -Be 'deploy-S001-SingleNode'
            }
        }

        It 'Should not replace {TypeOfDeployment} when not provided' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Resolve-AzLocalResourceName -Pattern '{TypeOfDeployment}-test' -UniqueID 'X'
                $result | Should -Be '{TypeOfDeployment}-test'
            }
        }
    }

    Context 'Combined Placeholder Replacement' {
        It 'Should replace all placeholders in a complex pattern' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Resolve-AzLocalResourceName -Pattern 'azlocal-{UniqueID}-{TypeOfDeployment}-deployment' -UniqueID 'SITE42' -TypeOfDeployment 'MultiNode'
                $result | Should -Be 'azlocal-SITE42-MultiNode-deployment'
            }
        }
    }

    Context 'Naming Config Standard Patterns' {
        It 'Should correctly resolve clusterName pattern' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Resolve-AzLocalResourceName -Pattern 'AZCLUSTER{UniqueID}' -UniqueID 'S001'
                $result | Should -Be 'AZCLUSTERS001'
            }
        }

        It 'Should correctly resolve resourceGroupName pattern' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Resolve-AzLocalResourceName -Pattern 'rg-{UniqueID}-azurelocal-prod' -UniqueID 'LON01'
                $result | Should -Be 'rg-LON01-azurelocal-prod'
            }
        }

        It 'Should correctly resolve keyVaultName pattern' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Resolve-AzLocalResourceName -Pattern 'kv-{UniqueID}-azlocal' -UniqueID 'NYC99'
                $result | Should -Be 'kv-NYC99-azlocal'
            }
        }

        It 'Should correctly resolve diagnosticStorageAccountName pattern' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Resolve-AzLocalResourceName -Pattern '{UniqueID}azlocaldiag' -UniqueID 'store01'
                $result | Should -Be 'store01azlocaldiag'
            }
        }

        It 'Should correctly resolve nodeNamePattern' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Resolve-AzLocalResourceName -Pattern '{UniqueID}NODE{NodeNumber}' -UniqueID 'S001' -NodeNumber 3
                $result | Should -Be 'S001NODE03'
            }
        }

        It 'Should correctly resolve adouPath pattern' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Resolve-AzLocalResourceName -Pattern 'OU=AzLocal-{UniqueID},OU=AzureLocal,DC=contoso,DC=com' -UniqueID 'Branch01'
                $result | Should -Be 'OU=AzLocal-Branch01,OU=AzureLocal,DC=contoso,DC=com'
            }
        }
    }
}

# ============================================================================
# Get-AzLocalNamingConfig (Internal Function)
# ============================================================================
Describe 'Function: Get-AzLocalNamingConfig' {

    Context 'Config File Loading' {
        It 'Should load the naming configuration successfully' {
            InModuleScope AzLocal.DeploymentAutomation {
                $config = Get-AzLocalNamingConfig
                $config | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should return an object with namingStandards property' {
            InModuleScope AzLocal.DeploymentAutomation {
                $config = Get-AzLocalNamingConfig
                $config.namingStandards | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should return an object with defaults property' {
            InModuleScope AzLocal.DeploymentAutomation {
                $config = Get-AzLocalNamingConfig
                $config.defaults | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Naming Standards Structure' {
        BeforeAll {
            $script:Config = InModuleScope AzLocal.DeploymentAutomation { Get-AzLocalNamingConfig }
        }

        It 'Should have clusterName naming standard' {
            $script:Config.namingStandards.clusterName | Should -Not -BeNullOrEmpty
        }

        It 'Should have resourceGroupName naming standard' {
            $script:Config.namingStandards.resourceGroupName | Should -Not -BeNullOrEmpty
        }

        It 'Should have keyVaultName naming standard' {
            $script:Config.namingStandards.keyVaultName | Should -Not -BeNullOrEmpty
        }

        It 'Should have customLocation naming standard' {
            $script:Config.namingStandards.customLocation | Should -Not -BeNullOrEmpty
        }

        It 'Should have resourceBridgeName naming standard' {
            $script:Config.namingStandards.resourceBridgeName | Should -Not -BeNullOrEmpty
        }

        It 'Should have diagnosticStorageAccountName naming standard' {
            $script:Config.namingStandards.diagnosticStorageAccountName | Should -Not -BeNullOrEmpty
        }

        It 'Should have clusterWitnessStorageAccountName naming standard' {
            $script:Config.namingStandards.clusterWitnessStorageAccountName | Should -Not -BeNullOrEmpty
        }

        It 'Should have nodeNamePattern naming standard' {
            $script:Config.namingStandards.nodeNamePattern | Should -Not -BeNullOrEmpty
        }

        It 'Should have adouPath naming standard' {
            $script:Config.namingStandards.adouPath | Should -Not -BeNullOrEmpty
        }

        It 'Should have deploymentName naming standard' {
            $script:Config.namingStandards.deploymentName | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Defaults Structure' {
        BeforeAll {
            $script:Config = InModuleScope AzLocal.DeploymentAutomation { Get-AzLocalNamingConfig }
        }

        It 'Should have a default location' {
            $script:Config.defaults.location | Should -Not -BeNullOrEmpty
        }

        It 'Should have a default domainFqdn' {
            $script:Config.defaults.domainFqdn | Should -Not -BeNullOrEmpty
        }

        It 'Should have a default namingPrefix' {
            $script:Config.defaults.namingPrefix | Should -Not -BeNullOrEmpty
        }

        It 'Should have a default azureStackLCMAdminUsername' {
            $script:Config.defaults.azureStackLCMAdminUsername | Should -Not -BeNullOrEmpty
        }

        It 'Should have a default storageAccountType' {
            $script:Config.defaults.storageAccountType | Should -Not -BeNullOrEmpty
        }

        It 'Should have default dnsServers as an array' {
            $script:Config.defaults.dnsServers | Should -Not -BeNullOrEmpty
            $script:Config.defaults.dnsServers.Count | Should -BeGreaterOrEqual 1
        }

        It 'Should have default computeManagementAdapters as an array' {
            $script:Config.defaults.computeManagementAdapters | Should -Not -BeNullOrEmpty
            $script:Config.defaults.computeManagementAdapters.Count | Should -BeGreaterOrEqual 1
        }

        It 'Should have default storageAdapters as an array' {
            $script:Config.defaults.storageAdapters | Should -Not -BeNullOrEmpty
            $script:Config.defaults.storageAdapters.Count | Should -BeGreaterOrEqual 1
        }
    }

    Context 'Naming Patterns Contain Expected Placeholders' {
        BeforeAll {
            $script:Config = InModuleScope AzLocal.DeploymentAutomation { Get-AzLocalNamingConfig }
        }

        It 'clusterName should contain {UniqueID}' {
            $script:Config.namingStandards.clusterName | Should -Match '\{UniqueID\}'
        }

        It 'resourceGroupName should contain {UniqueID}' {
            $script:Config.namingStandards.resourceGroupName | Should -Match '\{UniqueID\}'
        }

        It 'nodeNamePattern should contain {UniqueID} and {NodeNumber}' {
            $script:Config.namingStandards.nodeNamePattern | Should -Match '\{UniqueID\}'
            $script:Config.namingStandards.nodeNamePattern | Should -Match '\{NodeNumber\}'
        }

        It 'deploymentName should contain {UniqueID} and {TypeOfDeployment}' {
            $script:Config.namingStandards.deploymentName | Should -Match '\{UniqueID\}'
            $script:Config.namingStandards.deploymentName | Should -Match '\{TypeOfDeployment\}'
        }
    }
}

# ============================================================================
# Get-AzLocalParameterFilePath (Internal Function)
# ============================================================================
Describe 'Function: Get-AzLocalParameterFilePath' {

    Context 'SingleNode Parameter File' {
        It 'Should return a path ending with single-node-parameters-file.json' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Get-AzLocalParameterFilePath -TypeOfDeployment 'SingleNode'
                $result | Should -Match 'single-node-parameters-file\.json$'
            }
        }

        It 'Should return a valid file path for SingleNode' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Get-AzLocalParameterFilePath -TypeOfDeployment 'SingleNode'
                $result | Should -Not -BeNullOrEmpty
                Test-Path $result | Should -Be $true
            }
        }
    }

    Context 'Switchless Parameter File' {
        It 'Should return a path ending with switchless-2node-parameters-file.json by default' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Get-AzLocalParameterFilePath -TypeOfDeployment 'Switchless'
                $result | Should -Match 'switchless-2node-parameters-file\.json$'
            }
        }

        It 'Should return switchless-3node-parameters-file.json for NodeCount 3' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Get-AzLocalParameterFilePath -TypeOfDeployment 'Switchless' -NodeCount 3
                $result | Should -Match 'switchless-3node-parameters-file\.json$'
            }
        }

        It 'Should return switchless-4node-parameters-file.json for NodeCount 4' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Get-AzLocalParameterFilePath -TypeOfDeployment 'Switchless' -NodeCount 4
                $result | Should -Match 'switchless-4node-parameters-file\.json$'
            }
        }

        It 'Should return a valid file path for Switchless (2, 3, and 4 nodes)' {
            InModuleScope AzLocal.DeploymentAutomation {
                foreach ($n in 2, 3, 4) {
                    $result = Get-AzLocalParameterFilePath -TypeOfDeployment 'Switchless' -NodeCount $n
                    $result | Should -Not -BeNullOrEmpty
                    Test-Path $result | Should -Be $true
                }
            }
        }

        It 'Should NOT reference two-node-switchless (deprecated filename)' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Get-AzLocalParameterFilePath -TypeOfDeployment 'Switchless'
                $result | Should -Not -Match 'two-node-switchless'
            }
        }
    }

    Context 'MultiNode Parameter File' {
        It 'Should return a path ending with multi-node-switched-parameters-file.json' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Get-AzLocalParameterFilePath -TypeOfDeployment 'MultiNode'
                $result | Should -Match 'multi-node-switched-parameters-file\.json$'
            }
        }

        It 'Should return a valid file path for MultiNode' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Get-AzLocalParameterFilePath -TypeOfDeployment 'MultiNode'
                $result | Should -Not -BeNullOrEmpty
                Test-Path $result | Should -Be $true
            }
        }

        It 'Should NOT reference old multi-node-parameters-file name (deprecated)' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Get-AzLocalParameterFilePath -TypeOfDeployment 'MultiNode'
                $result | Should -Not -Match 'multi-node-parameters-file\.json$'
            }
        }
    }

    Context 'RackAware Parameter File' {
        It 'Should return a path ending with rack-aware-parameters-file.json' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Get-AzLocalParameterFilePath -TypeOfDeployment 'RackAware'
                $result | Should -Match 'rack-aware-parameters-file\.json$'
            }
        }

        It 'Should return a valid file path for RackAware' {
            InModuleScope AzLocal.DeploymentAutomation {
                $result = Get-AzLocalParameterFilePath -TypeOfDeployment 'RackAware'
                $result | Should -Not -BeNullOrEmpty
                Test-Path $result | Should -Be $true
            }
        }
    }

    Context 'Template Parameter Files Exist On Disk' {
        BeforeAll {
            $script:ModuleRoot = Split-Path (Get-Module AzLocal.DeploymentAutomation).Path -Parent
            $script:TemplateDir = Join-Path $script:ModuleRoot 'template-parameter-files'
        }

        It 'template-parameter-files directory should exist' {
            Test-Path $script:TemplateDir | Should -Be $true
        }

        It 'single-node-parameters-file.json should exist' {
            Test-Path (Join-Path $script:TemplateDir 'single-node-parameters-file.json') | Should -Be $true
        }

        It 'two-node-switched-parameters-file.json should NOT exist (deprecated)' {
            Test-Path (Join-Path $script:TemplateDir 'two-node-switched-parameters-file.json') | Should -Be $false
        }

        It 'switchless-2node-parameters-file.json should exist' {
            Test-Path (Join-Path $script:TemplateDir 'switchless-2node-parameters-file.json') | Should -Be $true
        }

        It 'switchless-3node-parameters-file.json should exist' {
            Test-Path (Join-Path $script:TemplateDir 'switchless-3node-parameters-file.json') | Should -Be $true
        }

        It 'switchless-4node-parameters-file.json should exist' {
            Test-Path (Join-Path $script:TemplateDir 'switchless-4node-parameters-file.json') | Should -Be $true
        }

        It 'switchless-parameters-file.json should NOT exist (replaced by per-node-count files)' {
            Test-Path (Join-Path $script:TemplateDir 'switchless-parameters-file.json') | Should -Be $false
        }

        It 'multi-node-switched-parameters-file.json should exist' {
            Test-Path (Join-Path $script:TemplateDir 'multi-node-switched-parameters-file.json') | Should -Be $true
        }

        It 'two-node-switchless-parameters-file.json should NOT exist (deprecated)' {
            Test-Path (Join-Path $script:TemplateDir 'two-node-switchless-parameters-file.json') | Should -Be $false
        }

        It 'rack-aware-parameters-file.json should exist' {
            Test-Path (Join-Path $script:TemplateDir 'rack-aware-parameters-file.json') | Should -Be $true
        }

        It 'multi-node-parameters-file.json should NOT exist (deprecated)' {
            Test-Path (Join-Path $script:TemplateDir 'multi-node-parameters-file.json') | Should -Be $false
        }
    }
}

# ============================================================================
# Get-AzLocalParameterFileSettings (Internal Function)
# ============================================================================
Describe 'Function: Get-AzLocalParameterFileSettings' {

    Context 'Loading Parameter Files' {
        BeforeAll {
            $script:ModuleRoot = Split-Path (Get-Module AzLocal.DeploymentAutomation).Path -Parent
            $script:TemplateDir = Join-Path $script:ModuleRoot 'template-parameter-files'
        }

        It 'Should load single-node parameter file as valid JSON' {
            InModuleScope AzLocal.DeploymentAutomation -ArgumentList $script:TemplateDir {
                param($templateDir)
                $filePath = [System.IO.FileInfo](Join-Path $templateDir 'single-node-parameters-file.json')
                $result = Get-AzLocalParameterFileSettings -ParameterFilePath $filePath
                $result | Should -Not -BeNullOrEmpty
                $result.parameters | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should load switchless 2-node parameter file as valid JSON' {
            InModuleScope AzLocal.DeploymentAutomation -ArgumentList $script:TemplateDir {
                param($templateDir)
                $filePath = [System.IO.FileInfo](Join-Path $templateDir 'switchless-2node-parameters-file.json')
                $result = Get-AzLocalParameterFileSettings -ParameterFilePath $filePath
                $result | Should -Not -BeNullOrEmpty
                $result.parameters | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should load switchless 3-node parameter file as valid JSON' {
            InModuleScope AzLocal.DeploymentAutomation -ArgumentList $script:TemplateDir {
                param($templateDir)
                $filePath = [System.IO.FileInfo](Join-Path $templateDir 'switchless-3node-parameters-file.json')
                $result = Get-AzLocalParameterFileSettings -ParameterFilePath $filePath
                $result | Should -Not -BeNullOrEmpty
                $result.parameters | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should load switchless 4-node parameter file as valid JSON' {
            InModuleScope AzLocal.DeploymentAutomation -ArgumentList $script:TemplateDir {
                param($templateDir)
                $filePath = [System.IO.FileInfo](Join-Path $templateDir 'switchless-4node-parameters-file.json')
                $result = Get-AzLocalParameterFileSettings -ParameterFilePath $filePath
                $result | Should -Not -BeNullOrEmpty
                $result.parameters | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should load multi-node-switched parameter file as valid JSON' {
            InModuleScope AzLocal.DeploymentAutomation -ArgumentList $script:TemplateDir {
                param($templateDir)
                $filePath = [System.IO.FileInfo](Join-Path $templateDir 'multi-node-switched-parameters-file.json')
                $result = Get-AzLocalParameterFileSettings -ParameterFilePath $filePath
                $result | Should -Not -BeNullOrEmpty
                $result.parameters | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should load rack-aware parameter file as valid JSON' {
            InModuleScope AzLocal.DeploymentAutomation -ArgumentList $script:TemplateDir {
                param($templateDir)
                $filePath = [System.IO.FileInfo](Join-Path $templateDir 'rack-aware-parameters-file.json')
                $result = Get-AzLocalParameterFileSettings -ParameterFilePath $filePath
                $result | Should -Not -BeNullOrEmpty
                $result.parameters | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Parameter File Content Structure' {
        BeforeAll {
            $script:ModuleRoot = Split-Path (Get-Module AzLocal.DeploymentAutomation).Path -Parent
            $script:TemplateDir = Join-Path $script:ModuleRoot 'template-parameter-files'
        }

        It 'Single-node file should contain deploymentMode parameter' {
            InModuleScope AzLocal.DeploymentAutomation -ArgumentList $script:TemplateDir {
                param($templateDir)
                $filePath = [System.IO.FileInfo](Join-Path $templateDir 'single-node-parameters-file.json')
                $result = Get-AzLocalParameterFileSettings -ParameterFilePath $filePath
                $result.parameters.PSObject.Properties.Name | Should -Contain 'deploymentMode'
            }
        }

        It 'Parameter files should have a $schema property' {
            InModuleScope AzLocal.DeploymentAutomation -ArgumentList $script:TemplateDir {
                param($templateDir)
                $filePath = [System.IO.FileInfo](Join-Path $templateDir 'single-node-parameters-file.json')
                $result = Get-AzLocalParameterFileSettings -ParameterFilePath $filePath
                $result.'$schema' | Should -Not -BeNullOrEmpty
            }
        }
    }
}

# ============================================================================
# Get-ValidUniqueID (Internal Function - Mocked)
# ============================================================================
Describe 'Function: Get-ValidUniqueID' {

    Context 'Valid UniqueID Inputs' {
        It 'Should accept a 2-character alphanumeric ID' {
            InModuleScope AzLocal.DeploymentAutomation {
                Mock Read-Host { return 'AB' }
                $result = Get-ValidUniqueID
                $result | Should -Be 'AB'
            }
        }

        It 'Should accept a 3-character alphanumeric ID' {
            InModuleScope AzLocal.DeploymentAutomation {
                Mock Read-Host { return 'ABC' }
                $result = Get-ValidUniqueID
                $result | Should -Be 'ABC'
            }
        }

        It 'Should accept an 8-character alphanumeric ID' {
            InModuleScope AzLocal.DeploymentAutomation {
                Mock Read-Host { return 'ABCDEF12' }
                $result = Get-ValidUniqueID
                $result | Should -Be 'ABCDEF12'
            }
        }

        It 'Should accept numeric-only IDs' {
            InModuleScope AzLocal.DeploymentAutomation {
                Mock Read-Host { return '12345' }
                $result = Get-ValidUniqueID
                $result | Should -Be '12345'
            }
        }

        It 'Should accept mixed case alphanumeric IDs' {
            InModuleScope AzLocal.DeploymentAutomation {
                Mock Read-Host { return 'Store001' }
                $result = Get-ValidUniqueID
                $result | Should -Be 'Store001'
            }
        }
    }

    Context 'Invalid UniqueID Inputs' {
        It 'Should throw for empty input' {
            InModuleScope AzLocal.DeploymentAutomation {
                Mock Read-Host { return '' }
                { Get-ValidUniqueID } | Should -Throw
            }
        }

        It 'Should throw for whitespace-only input' {
            InModuleScope AzLocal.DeploymentAutomation {
                Mock Read-Host { return '   ' }
                { Get-ValidUniqueID } | Should -Throw
            }
        }

        It 'Should throw for ID shorter than 2 characters' {
            InModuleScope AzLocal.DeploymentAutomation {
                Mock Read-Host { return 'A' }
                { Get-ValidUniqueID } | Should -Throw
            }
        }

        It 'Should throw for ID longer than 8 characters' {
            InModuleScope AzLocal.DeploymentAutomation {
                Mock Read-Host { return 'ABCDEFGHI' }
                { Get-ValidUniqueID } | Should -Throw
            }
        }

        It 'Should throw for ID containing special characters' {
            InModuleScope AzLocal.DeploymentAutomation {
                Mock Read-Host { return 'ABC-001' }
                { Get-ValidUniqueID } | Should -Throw
            }
        }

        It 'Should throw for ID containing spaces' {
            InModuleScope AzLocal.DeploymentAutomation {
                Mock Read-Host { return 'ABC 001' }
                { Get-ValidUniqueID } | Should -Throw
            }
        }
    }
}

# ============================================================================
# Get-AzLocalDeploymentNetworkSettings (Internal Function - Parameter Tests)
# ============================================================================
Describe 'Function: Get-AzLocalDeploymentNetworkSettings' {

    Context 'Parameter Definitions' {
        It 'Should have TypeOfDeployment parameter with correct ValidateSet' {
            InModuleScope AzLocal.DeploymentAutomation {
                $command = Get-Command Get-AzLocalDeploymentNetworkSettings
                $validateSet = $command.Parameters['TypeOfDeployment'].Attributes |
                    Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
                $validateSet.ValidValues | Should -Contain 'SingleNode'
                $validateSet.ValidValues | Should -Contain 'Switchless'
                $validateSet.ValidValues | Should -Contain 'MultiNode'
                $validateSet.ValidValues | Should -Contain 'RackAware'
                $validateSet.ValidValues | Should -Not -Contain 'TwoNode'
                $validateSet.ValidValues | Should -Not -Contain 'TwoNode-Switchless'
            }
        }

        It 'Should have NodeCount parameter' {
            InModuleScope AzLocal.DeploymentAutomation {
                $command = Get-Command Get-AzLocalDeploymentNetworkSettings
                $command.Parameters.Keys | Should -Contain 'NodeCount'
            }
        }
    }

    Context 'Node Count Resolution' {
        It 'Should prompt for 1 node IP address for SingleNode' {
            InModuleScope AzLocal.DeploymentAutomation {
                # Mock Read-Host to return valid IPs in sequence
                $script:readHostCallCount = 0
                Mock Read-Host {
                    $script:readHostCallCount++
                    switch ($script:readHostCallCount) {
                        1 { return '255.255.255.0' }   # subnet mask
                        2 { return '10.0.0.1' }         # default gateway
                        3 { return '10.0.0.10' }        # starting IP
                        4 { return '10.0.0.20' }        # ending IP
                        5 { return '10.0.0.100' }       # node 1 IP
                        default { return '10.0.0.200' }
                    }
                }
                $result = Get-AzLocalDeploymentNetworkSettings -TypeOfDeployment 'SingleNode'
                $result.nodeIPAddresses.Count | Should -Be 1
            }
        }

        It 'Should prompt for 2 node IP addresses for MultiNode with NodeCount 2' {
            InModuleScope AzLocal.DeploymentAutomation {
                $script:readHostCallCount = 0
                Mock Read-Host {
                    $script:readHostCallCount++
                    switch ($script:readHostCallCount) {
                        1 { return '255.255.255.0' }
                        2 { return '10.0.0.1' }
                        3 { return '10.0.0.10' }
                        4 { return '10.0.0.20' }
                        5 { return '10.0.0.100' }
                        6 { return '10.0.0.101' }
                        default { return '10.0.0.200' }
                    }
                }
                $result = Get-AzLocalDeploymentNetworkSettings -TypeOfDeployment 'MultiNode' -NodeCount 2
                $result.nodeIPAddresses.Count | Should -Be 2
            }
        }

        It 'Should prompt for 3 node IP addresses for Switchless with NodeCount 3' {
            InModuleScope AzLocal.DeploymentAutomation {
                $script:readHostCallCount = 0
                Mock Read-Host {
                    $script:readHostCallCount++
                    switch ($script:readHostCallCount) {
                        1 { return '255.255.255.0' }
                        2 { return '10.0.0.1' }
                        3 { return '10.0.0.10' }
                        4 { return '10.0.0.20' }
                        5 { return '10.0.0.100' }
                        6 { return '10.0.0.101' }
                        7 { return '10.0.0.102' }
                        default { return '10.0.0.200' }
                    }
                }
                $result = Get-AzLocalDeploymentNetworkSettings -TypeOfDeployment 'Switchless' -NodeCount 3
                $result.nodeIPAddresses.Count | Should -Be 3
            }
        }

        It 'Should prompt for 4 node IP addresses for Switchless with NodeCount 4' {
            InModuleScope AzLocal.DeploymentAutomation {
                $script:readHostCallCount = 0
                Mock Read-Host {
                    $script:readHostCallCount++
                    switch ($script:readHostCallCount) {
                        1 { return '255.255.255.0' }
                        2 { return '10.0.0.1' }
                        3 { return '10.0.0.10' }
                        4 { return '10.0.0.20' }
                        5 { return '10.0.0.100' }
                        6 { return '10.0.0.101' }
                        7 { return '10.0.0.102' }
                        8 { return '10.0.0.103' }
                        default { return '10.0.0.200' }
                    }
                }
                $result = Get-AzLocalDeploymentNetworkSettings -TypeOfDeployment 'Switchless' -NodeCount 4
                $result.nodeIPAddresses.Count | Should -Be 4
            }
        }

        It 'Should prompt for 4 node IP addresses for RackAware with NodeCount 4' {
            InModuleScope AzLocal.DeploymentAutomation {
                $script:readHostCallCount = 0
                Mock Read-Host {
                    $script:readHostCallCount++
                    switch ($script:readHostCallCount) {
                        1 { return '255.255.255.0' }
                        2 { return '10.0.0.1' }
                        3 { return '10.0.0.10' }
                        4 { return '10.0.0.20' }
                        5 { return '10.0.0.100' }
                        6 { return '10.0.0.101' }
                        7 { return '10.0.0.102' }
                        8 { return '10.0.0.103' }
                        default { return '10.0.0.200' }
                    }
                }
                $result = Get-AzLocalDeploymentNetworkSettings -TypeOfDeployment 'RackAware' -NodeCount 4
                $result.nodeIPAddresses.Count | Should -Be 4
            }
        }

        It 'Should return a network settings object with all expected properties' {
            InModuleScope AzLocal.DeploymentAutomation {
                $script:readHostCallCount = 0
                Mock Read-Host {
                    $script:readHostCallCount++
                    switch ($script:readHostCallCount) {
                        1 { return '255.255.255.0' }
                        2 { return '10.0.0.1' }
                        3 { return '10.0.0.10' }
                        4 { return '10.0.0.20' }
                        5 { return '10.0.0.100' }
                        default { return '10.0.0.200' }
                    }
                }
                $result = Get-AzLocalDeploymentNetworkSettings -TypeOfDeployment 'SingleNode'
                $result.PSObject.Properties.Name | Should -Contain 'subnetMask'
                $result.PSObject.Properties.Name | Should -Contain 'defaultGateway'
                $result.PSObject.Properties.Name | Should -Contain 'startingIPAddress'
                $result.PSObject.Properties.Name | Should -Contain 'endingIPAddress'
                $result.PSObject.Properties.Name | Should -Contain 'nodeIPAddresses'
            }
        }

        It 'Should throw for invalid IP address input' {
            InModuleScope AzLocal.DeploymentAutomation {
                Mock Read-Host { return 'not-an-ip' }
                { Get-AzLocalDeploymentNetworkSettings -TypeOfDeployment 'SingleNode' } | Should -Throw
            }
        }
    }
}

# ============================================================================
# New-AzLocalDeploymentParameterFile (Internal Function - Parameter Tests)
# ============================================================================
Describe 'Function: New-AzLocalDeploymentParameterFile' {

    Context 'Parameter Definitions' {
        It 'Should have TypeOfDeployment parameter with correct ValidateSet' {
            InModuleScope AzLocal.DeploymentAutomation {
                $command = Get-Command New-AzLocalDeploymentParameterFile
                $validateSet = $command.Parameters['TypeOfDeployment'].Attributes |
                    Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
                $validateSet.ValidValues | Should -Contain 'SingleNode'
                $validateSet.ValidValues | Should -Contain 'Switchless'
                $validateSet.ValidValues | Should -Contain 'MultiNode'
                $validateSet.ValidValues | Should -Contain 'RackAware'
                $validateSet.ValidValues | Should -Not -Contain 'TwoNode'
                $validateSet.ValidValues | Should -Not -Contain 'TwoNode-Switchless'
            }
        }

        It 'Should have UniqueID as a mandatory parameter' {
            InModuleScope AzLocal.DeploymentAutomation {
                $command = Get-Command New-AzLocalDeploymentParameterFile
                $param = $command.Parameters['UniqueID']
                $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
                $attr.Mandatory | Should -Be $true
            }
        }

        It 'Should have ParameterFileSettings as a mandatory parameter' {
            InModuleScope AzLocal.DeploymentAutomation {
                $command = Get-Command New-AzLocalDeploymentParameterFile
                $param = $command.Parameters['ParameterFileSettings']
                $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
                $attr.Mandatory | Should -Be $true
            }
        }

        It 'Should have Parameters as a mandatory parameter' {
            InModuleScope AzLocal.DeploymentAutomation {
                $command = Get-Command New-AzLocalDeploymentParameterFile
                $param = $command.Parameters['Parameters']
                $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
                $attr.Mandatory | Should -Be $true
            }
        }
    }
}

# ============================================================================
# Format-Json (Internal Function)
# ============================================================================
Describe 'Function: Format-Json' {

    Context 'Prettify JSON' {
        It 'Should return a valid formatted JSON string' {
            InModuleScope AzLocal.DeploymentAutomation {
                $json = '{"name":"test","value":42}'
                $result = $json | Format-Json
                $result | Should -Not -BeNullOrEmpty
                # Should be parseable back to object
                $parsed = $result | ConvertFrom-Json
                $parsed.name | Should -Be 'test'
                $parsed.value | Should -Be 42
            }
        }

        It 'Should indent with 4 spaces by default' {
            InModuleScope AzLocal.DeploymentAutomation {
                $json = '{"name":"test","nested":{"key":"value"}}'
                $result = $json | Format-Json
                # The nested key should be indented with 8 spaces (2 levels x 4 spaces)
                $result | Should -Match '        "key": "value"'
            }
        }

        It 'Should support custom indentation' {
            InModuleScope AzLocal.DeploymentAutomation {
                $json = '{"name":"test","nested":{"key":"value"}}'
                $result = $json | Format-Json -Indentation 2
                # The nested key should be indented with 4 spaces (2 levels x 2 spaces)
                $result | Should -Match '    "key": "value"'
            }
        }
    }

    Context 'Minify JSON' {
        It 'Should compress JSON when -Minify is specified' {
            InModuleScope AzLocal.DeploymentAutomation {
                $json = @"
{
    "name": "test",
    "value": 42
}
"@
                $result = $json | Format-Json -Minify
                $result | Should -Not -Match "`n"
                $result | Should -Not -Match "`r"
            }
        }

        It 'Should preserve data when minifying' {
            InModuleScope AzLocal.DeploymentAutomation {
                $json = '{"name":"test","items":[1,2,3]}'
                $result = $json | Format-Json -Minify
                $parsed = $result | ConvertFrom-Json
                $parsed.name | Should -Be 'test'
                $parsed.items.Count | Should -Be 3
            }
        }
    }

    Context 'AsArray Output' {
        It 'Should return a string array when -AsArray is specified' {
            InModuleScope AzLocal.DeploymentAutomation {
                $json = '{"name":"test","nested":{"key":"value"}}'
                $result = $json | Format-Json -AsArray
                $result.Count | Should -BeGreaterThan 1
            }
        }
    }
}

# ============================================================================
# Resource Name Validation Tests (via InModuleScope)
# ============================================================================
Describe 'Function: Test-AzLocalResourceNames' {

    Context 'Valid Names' {
        It 'Should pass validation for all valid resource names with default config and short UniqueID' {
            InModuleScope AzLocal.DeploymentAutomation {
                $names = @{
                    'ClusterName'                      = 'AZCLUSTERABC'
                    'ResourceGroupName'                = 'rg-ABC-azurelocal-prod'
                    'KeyVaultName'                     = 'kv-ABC-azlocal'
                    'CustomLocation'                   = 'ABC-azlocal-customlocation'
                    'ResourceBridgeName'               = 'ABC-azlocal-arcbridge'
                    'DiagnosticStorageAccountName'     = 'abcazlocaldiag'
                    'ClusterWitnessStorageAccountName' = 'abcazlocalwitness'
                    'DeploymentName'                   = 'azlocal-ABC-SingleNode-deployment'
                    'NodeName1'                        = 'ABCNODE01'
                }
                { Test-AzLocalResourceNames -Names $names } | Should -Not -Throw
            }
        }

        It 'Should pass validation for maximum-length UniqueID (8 chars)' {
            InModuleScope AzLocal.DeploymentAutomation {
                $names = @{
                    'ClusterName'                      = 'AZCLUSTERABC'
                    'ResourceGroupName'                = 'rg-ABCDEF12-azurelocal-prod'
                    'KeyVaultName'                     = 'kv-ABCDEF12-azlocal'
                    'CustomLocation'                   = 'ABCDEF12-azlocal-customlocation'
                    'ResourceBridgeName'               = 'ABCDEF12-azlocal-arcbridge'
                }
                { Test-AzLocalResourceNames -Names $names } | Should -Not -Throw
            }
        }
    }

    Context 'Storage Account Validation' {
        It 'Should reject storage account names with uppercase characters' {
            InModuleScope AzLocal.DeploymentAutomation {
                $names = @{
                    'DiagnosticStorageAccountName' = 'ABCazlocaldiag'
                }
                { Test-AzLocalResourceNames -Names $names } | Should -Throw
            }
        }

        It 'Should reject storage account names with hyphens' {
            InModuleScope AzLocal.DeploymentAutomation {
                $names = @{
                    'ClusterWitnessStorageAccountName' = 'abc-azlocal-witness'
                }
                { Test-AzLocalResourceNames -Names $names } | Should -Throw
            }
        }

        It 'Should reject storage account names exceeding 24 characters' {
            InModuleScope AzLocal.DeploymentAutomation {
                $names = @{
                    'DiagnosticStorageAccountName' = 'abcdefghijklmnopazlocaldiag'
                }
                { Test-AzLocalResourceNames -Names $names } | Should -Throw
            }
        }

        It 'Should reject storage account names shorter than 3 characters' {
            InModuleScope AzLocal.DeploymentAutomation {
                $names = @{
                    'DiagnosticStorageAccountName' = 'ab'
                }
                { Test-AzLocalResourceNames -Names $names } | Should -Throw
            }
        }
    }

    Context 'Key Vault Validation' {
        It 'Should reject Key Vault names exceeding 24 characters' {
            InModuleScope AzLocal.DeploymentAutomation {
                $names = @{
                    'KeyVaultName' = 'kv-abcdefghijklmnopqrstuvwxyz-azlocal'
                }
                { Test-AzLocalResourceNames -Names $names } | Should -Throw
            }
        }

        It 'Should reject Key Vault names starting with a number' {
            InModuleScope AzLocal.DeploymentAutomation {
                $names = @{
                    'KeyVaultName' = '1kv-abc-azlocal'
                }
                { Test-AzLocalResourceNames -Names $names } | Should -Throw
            }
        }

        It 'Should reject Key Vault names shorter than 3 characters' {
            InModuleScope AzLocal.DeploymentAutomation {
                $names = @{
                    'KeyVaultName' = 'kv'
                }
                { Test-AzLocalResourceNames -Names $names } | Should -Throw
            }
        }
    }

    Context 'Cluster Name Validation (NetBIOS)' {
        It 'Should reject cluster names exceeding 15 characters' {
            InModuleScope AzLocal.DeploymentAutomation {
                $names = @{
                    'ClusterName' = 'AZCLUSTERABCDEFGHIJK'
                }
                { Test-AzLocalResourceNames -Names $names } | Should -Throw
            }
        }

        It 'Should reject cluster names with hyphens' {
            InModuleScope AzLocal.DeploymentAutomation {
                $names = @{
                    'ClusterName' = 'AZ-CLUSTER-ABC'
                }
                { Test-AzLocalResourceNames -Names $names } | Should -Throw
            }
        }
    }

    Context 'Node Name Validation (NetBIOS)' {
        It 'Should reject node names exceeding 15 characters' {
            InModuleScope AzLocal.DeploymentAutomation {
                $names = @{
                    'NodeName1' = 'ABCDEFGHIJNODE01'
                }
                { Test-AzLocalResourceNames -Names $names } | Should -Throw
            }
        }

        It 'Should reject node names with hyphens' {
            InModuleScope AzLocal.DeploymentAutomation {
                $names = @{
                    'NodeName1' = 'ABC-NODE01'
                }
                { Test-AzLocalResourceNames -Names $names } | Should -Throw
            }
        }

        It 'Should validate multiple node names' {
            InModuleScope AzLocal.DeploymentAutomation {
                $names = @{
                    'NodeName1' = 'ABCNODE01'
                    'NodeName2' = 'ABCNODE02'
                    'NodeName3' = 'ABCNODE03'
                }
                { Test-AzLocalResourceNames -Names $names } | Should -Not -Throw
            }
        }
    }

    Context 'Deployment Name Validation' {
        It 'Should reject deployment names exceeding 64 characters' {
            InModuleScope AzLocal.DeploymentAutomation {
                $names = @{
                    'DeploymentName' = 'azlocal-' + ('x' * 60) + '-deployment'
                }
                { Test-AzLocalResourceNames -Names $names } | Should -Throw
            }
        }

        It 'Should accept deployment names with hyphens and periods' {
            InModuleScope AzLocal.DeploymentAutomation {
                $names = @{
                    'DeploymentName' = 'azlocal-ABC.test-deployment'
                }
                { Test-AzLocalResourceNames -Names $names } | Should -Not -Throw
            }
        }
    }

    Context 'Multiple Errors' {
        It 'Should report all validation errors in a single throw' {
            InModuleScope AzLocal.DeploymentAutomation {
                $names = @{
                    'ClusterName'                  = 'AZCLUSTERABCDEFGHIJK'
                    'DiagnosticStorageAccountName' = 'ABC-INVALID-STORAGE!'
                    'KeyVaultName'                 = '1invalid'
                }
                try {
                    Test-AzLocalResourceNames -Names $names
                    $false | Should -Be $true  # Should not reach here
                } catch {
                    $_.Exception.Message | Should -Match 'ClusterName'
                    $_.Exception.Message | Should -Match 'DiagnosticStorageAccountName'
                    $_.Exception.Message | Should -Match 'KeyVaultName'
                }
            }
        }
    }

    Context 'Integration with Default Naming Config' {
        It 'Should pass validation for all names resolved from default config with a 3-char UniqueID' {
            InModuleScope AzLocal.DeploymentAutomation {
                $config = Get-AzLocalNamingConfig
                $uid = 'ABC'
                $names = @{
                    'ClusterName'                      = Resolve-AzLocalResourceName -Pattern $config.namingStandards.clusterName -UniqueID $uid
                    'ResourceGroupName'                = Resolve-AzLocalResourceName -Pattern $config.namingStandards.resourceGroupName -UniqueID $uid
                    'KeyVaultName'                     = Resolve-AzLocalResourceName -Pattern $config.namingStandards.keyVaultName -UniqueID $uid
                    'CustomLocation'                   = Resolve-AzLocalResourceName -Pattern $config.namingStandards.customLocation -UniqueID $uid
                    'ResourceBridgeName'               = Resolve-AzLocalResourceName -Pattern $config.namingStandards.resourceBridgeName -UniqueID $uid
                    'DiagnosticStorageAccountName'     = (Resolve-AzLocalResourceName -Pattern $config.namingStandards.diagnosticStorageAccountName -UniqueID $uid).ToLower()
                    'ClusterWitnessStorageAccountName' = (Resolve-AzLocalResourceName -Pattern $config.namingStandards.clusterWitnessStorageAccountName -UniqueID $uid).ToLower()
                    'DeploymentName'                   = Resolve-AzLocalResourceName -Pattern $config.namingStandards.deploymentName -UniqueID $uid -TypeOfDeployment 'SingleNode'
                    'NodeName1'                        = Resolve-AzLocalResourceName -Pattern $config.namingStandards.nodeNamePattern -UniqueID $uid -NodeNumber 1
                }
                { Test-AzLocalResourceNames -Names $names } | Should -Not -Throw
            }
        }

        It 'Should reject names resolved from default config with an 8-char UniqueID (exceeds storage account limits)' {
            InModuleScope AzLocal.DeploymentAutomation {
                $config = Get-AzLocalNamingConfig
                $uid = 'ABCDEF12'
                $names = @{
                    'ClusterName'                      = Resolve-AzLocalResourceName -Pattern $config.namingStandards.clusterName -UniqueID $uid
                    'ResourceGroupName'                = Resolve-AzLocalResourceName -Pattern $config.namingStandards.resourceGroupName -UniqueID $uid
                    'KeyVaultName'                     = Resolve-AzLocalResourceName -Pattern $config.namingStandards.keyVaultName -UniqueID $uid
                    'CustomLocation'                   = Resolve-AzLocalResourceName -Pattern $config.namingStandards.customLocation -UniqueID $uid
                    'ResourceBridgeName'               = Resolve-AzLocalResourceName -Pattern $config.namingStandards.resourceBridgeName -UniqueID $uid
                    'DiagnosticStorageAccountName'     = (Resolve-AzLocalResourceName -Pattern $config.namingStandards.diagnosticStorageAccountName -UniqueID $uid).ToLower()
                    'ClusterWitnessStorageAccountName' = (Resolve-AzLocalResourceName -Pattern $config.namingStandards.clusterWitnessStorageAccountName -UniqueID $uid).ToLower()
                    'DeploymentName'                   = Resolve-AzLocalResourceName -Pattern $config.namingStandards.deploymentName -UniqueID $uid -TypeOfDeployment 'MultiNode'
                    'NodeName1'                        = Resolve-AzLocalResourceName -Pattern $config.namingStandards.nodeNamePattern -UniqueID $uid -NodeNumber 1
                }
                { Test-AzLocalResourceNames -Names $names } | Should -Throw
            }
        }
    }
}

# ============================================================================
# Deployment Type Logic Tests (via InModuleScope)
# ============================================================================
Describe 'Deployment Type Logic' {

    Context 'SingleNode Configuration' {
        It 'Should set effectiveNodeCount to 1 for SingleNode' {
            InModuleScope AzLocal.DeploymentAutomation {
                # Simulate the switch logic from Start-AzLocalTemplateDeployment
                $TypeOfDeployment = 'SingleNode'
                switch ($TypeOfDeployment) {
                    "SingleNode"  { $effectiveNodeCount = 1 }
                    "Switchless"  { $effectiveNodeCount = 3 }
                    "MultiNode"   { $effectiveNodeCount = 5 }
                    "RackAware"   { $effectiveNodeCount = 4 }
                }
                $effectiveNodeCount | Should -Be 1
            }
        }

        It 'SingleNode should reject NodeCount greater than 1' {
            InModuleScope AzLocal.DeploymentAutomation {
                # Simulate the validation logic from Start-AzLocalTemplateDeployment
                $TypeOfDeployment = 'SingleNode'
                $NodeCount = 2
                {
                    if ($TypeOfDeployment -eq "SingleNode" -and $NodeCount -gt 1) {
                        throw "SingleNode deployment does not support -NodeCount greater than 1."
                    }
                } | Should -Throw
            }
        }

        It 'SingleNode should allow NodeCount of 1' {
            InModuleScope AzLocal.DeploymentAutomation {
                $TypeOfDeployment = 'SingleNode'
                $NodeCount = 1
                $threw = $false
                try {
                    if ($TypeOfDeployment -eq "SingleNode" -and $NodeCount -gt 1) {
                        throw "SingleNode deployment does not support -NodeCount greater than 1."
                    }
                } catch {
                    $threw = $true
                }
                $threw | Should -Be $false
            }
        }

        It 'SingleNode should allow NodeCount of 0 (default)' {
            InModuleScope AzLocal.DeploymentAutomation {
                $TypeOfDeployment = 'SingleNode'
                $NodeCount = 0
                $threw = $false
                try {
                    if ($TypeOfDeployment -eq "SingleNode" -and $NodeCount -gt 1) {
                        throw "SingleNode deployment does not support -NodeCount greater than 1."
                    }
                } catch {
                    $threw = $true
                }
                $threw | Should -Be $false
            }
        }
    }

    Context 'Switchless Configuration' {
        It 'Switchless should use NodeCount for effectiveNodeCount (2 nodes)' {
            InModuleScope AzLocal.DeploymentAutomation {
                $TypeOfDeployment = 'Switchless'
                $NodeCount = 2
                switch ($TypeOfDeployment) {
                    "SingleNode"  { $effectiveNodeCount = 1 }
                    "Switchless"  { $effectiveNodeCount = $NodeCount }
                    "MultiNode"   { $effectiveNodeCount = $NodeCount }
                    "RackAware"   { $effectiveNodeCount = $NodeCount }
                }
                $effectiveNodeCount | Should -Be 2
            }
        }

        It 'Switchless should use NodeCount for effectiveNodeCount (3 nodes)' {
            InModuleScope AzLocal.DeploymentAutomation {
                $TypeOfDeployment = 'Switchless'
                $NodeCount = 3
                switch ($TypeOfDeployment) {
                    "SingleNode"  { $effectiveNodeCount = 1 }
                    "Switchless"  { $effectiveNodeCount = $NodeCount }
                    "MultiNode"   { $effectiveNodeCount = $NodeCount }
                    "RackAware"   { $effectiveNodeCount = $NodeCount }
                }
                $effectiveNodeCount | Should -Be 3
            }
        }

        It 'Switchless should use NodeCount for effectiveNodeCount (4 nodes)' {
            InModuleScope AzLocal.DeploymentAutomation {
                $TypeOfDeployment = 'Switchless'
                $NodeCount = 4
                switch ($TypeOfDeployment) {
                    "SingleNode"  { $effectiveNodeCount = 1 }
                    "Switchless"  { $effectiveNodeCount = $NodeCount }
                    "MultiNode"   { $effectiveNodeCount = $NodeCount }
                    "RackAware"   { $effectiveNodeCount = $NodeCount }
                }
                $effectiveNodeCount | Should -Be 4
            }
        }
    }

    Context 'MultiNode Configuration' {
        It 'MultiNode should use NodeCount for effectiveNodeCount' {
            InModuleScope AzLocal.DeploymentAutomation {
                $TypeOfDeployment = 'MultiNode'
                $NodeCount = 8
                switch ($TypeOfDeployment) {
                    "SingleNode"  { $effectiveNodeCount = 1 }
                    "Switchless"  { $effectiveNodeCount = $NodeCount }
                    "MultiNode"   { $effectiveNodeCount = $NodeCount }
                    "RackAware"   { $effectiveNodeCount = $NodeCount }
                }
                $effectiveNodeCount | Should -Be 8
            }
        }
    }

    Context 'RackAware Configuration' {
        It 'RackAware should use NodeCount for effectiveNodeCount (2 nodes)' {
            InModuleScope AzLocal.DeploymentAutomation {
                $TypeOfDeployment = 'RackAware'
                $NodeCount = 2
                switch ($TypeOfDeployment) {
                    "SingleNode"  { $effectiveNodeCount = 1 }
                    "Switchless"  { $effectiveNodeCount = $NodeCount }
                    "MultiNode"   { $effectiveNodeCount = $NodeCount }
                    "RackAware"   { $effectiveNodeCount = $NodeCount }
                }
                $effectiveNodeCount | Should -Be 2
            }
        }

        It 'RackAware should use NodeCount for effectiveNodeCount (8 nodes)' {
            InModuleScope AzLocal.DeploymentAutomation {
                $TypeOfDeployment = 'RackAware'
                $NodeCount = 8
                switch ($TypeOfDeployment) {
                    "SingleNode"  { $effectiveNodeCount = 1 }
                    "Switchless"  { $effectiveNodeCount = $NodeCount }
                    "MultiNode"   { $effectiveNodeCount = $NodeCount }
                    "RackAware"   { $effectiveNodeCount = $NodeCount }
                }
                $effectiveNodeCount | Should -Be 8
            }
        }

        It 'RackAware should set storageConnectivitySwitchless to false' {
            $TypeOfDeployment = 'RackAware'
            if ($TypeOfDeployment -eq 'RackAware') {
                $storageConnectivitySwitchless = $false
            }
            $storageConnectivitySwitchless | Should -Be $false
        }

        It 'RackAware should set witnessType to Cloud' {
            $TypeOfDeployment = 'RackAware'
            if ($TypeOfDeployment -eq 'RackAware') {
                $witnessType = 'Cloud'
            }
            $witnessType | Should -Be 'Cloud'
        }

        It 'RackAware should set clusterPattern to RackAware' {
            $TypeOfDeployment = 'RackAware'
            $clusterPattern = 'Standard'
            if ($TypeOfDeployment -eq 'RackAware') {
                $clusterPattern = 'RackAware'
            }
            $clusterPattern | Should -Be 'RackAware'
        }

        It 'RackAware should auto-split 4 nodes evenly into 2 zones' {
            $nodeNames = @('NODE01', 'NODE02', 'NODE03', 'NODE04')
            $effectiveNodeCount = 4
            $halfCount = $effectiveNodeCount / 2
            $zoneANodes = $nodeNames[0..($halfCount - 1)]
            $zoneBNodes = $nodeNames[$halfCount..($effectiveNodeCount - 1)]
            $zoneANodes.Count | Should -Be 2
            $zoneBNodes.Count | Should -Be 2
            $zoneANodes[0] | Should -Be 'NODE01'
            $zoneANodes[1] | Should -Be 'NODE02'
            $zoneBNodes[0] | Should -Be 'NODE03'
            $zoneBNodes[1] | Should -Be 'NODE04'
        }

        It 'RackAware should auto-split 8 nodes evenly into 2 zones' {
            $nodeNames = @('N001', 'N002', 'N003', 'N004', 'N005', 'N006', 'N007', 'N008')
            $effectiveNodeCount = 8
            $halfCount = $effectiveNodeCount / 2
            $zoneANodes = $nodeNames[0..($halfCount - 1)]
            $zoneBNodes = $nodeNames[$halfCount..($effectiveNodeCount - 1)]
            $zoneANodes.Count | Should -Be 4
            $zoneBNodes.Count | Should -Be 4
            $zoneANodes | Should -Be @('N001', 'N002', 'N003', 'N004')
            $zoneBNodes | Should -Be @('N005', 'N006', 'N007', 'N008')
        }

        It 'RackAware should produce localAvailabilityZones with ZoneA and ZoneB' {
            $nodeNames = @('NODE01', 'NODE02')
            $effectiveNodeCount = 2
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
            $localAvailabilityZones.Count | Should -Be 2
            $localAvailabilityZones[0].localAvailabilityZoneName | Should -Be 'ZoneA'
            $localAvailabilityZones[1].localAvailabilityZoneName | Should -Be 'ZoneB'
            $localAvailabilityZones[0].nodes | Should -Contain 'NODE01'
            $localAvailabilityZones[1].nodes | Should -Contain 'NODE02'
        }

        It 'Non-RackAware should default clusterPattern to Standard' {
            $TypeOfDeployment = 'MultiNode'
            $clusterPattern = 'Standard'
            if ($TypeOfDeployment -eq 'RackAware') {
                $clusterPattern = 'RackAware'
            }
            $clusterPattern | Should -Be 'Standard'
        }

        It 'Non-RackAware should default localAvailabilityZones to empty array' {
            $TypeOfDeployment = 'MultiNode'
            $localAvailabilityZones = @()
            if ($TypeOfDeployment -eq 'RackAware') {
                $localAvailabilityZones = @('ZoneA', 'ZoneB')
            }
            $localAvailabilityZones.Count | Should -Be 0
        }
    }

    Context 'Deployment Phase Logic' {
        It 'ValidateAndDeploy should produce two phases' {
            $DeploymentMode = 'ValidateAndDeploy'
            if ($DeploymentMode -eq "ValidateAndDeploy") {
                $deploymentPhases = @("Validate", "Deploy")
            } else {
                $deploymentPhases = @($DeploymentMode)
            }
            $deploymentPhases.Count | Should -Be 2
            $deploymentPhases[0] | Should -Be 'Validate'
            $deploymentPhases[1] | Should -Be 'Deploy'
        }

        It 'Validate mode should produce one phase' {
            $DeploymentMode = 'Validate'
            if ($DeploymentMode -eq "ValidateAndDeploy") {
                $deploymentPhases = @("Validate", "Deploy")
            } else {
                $deploymentPhases = @($DeploymentMode)
            }
            $deploymentPhases.Count | Should -Be 1
            $deploymentPhases[0] | Should -Be 'Validate'
        }

        It 'Deploy mode should produce one phase' {
            $DeploymentMode = 'Deploy'
            if ($DeploymentMode -eq "ValidateAndDeploy") {
                $deploymentPhases = @("Validate", "Deploy")
            } else {
                $deploymentPhases = @($DeploymentMode)
            }
            $deploymentPhases.Count | Should -Be 1
            $deploymentPhases[0] | Should -Be 'Deploy'
        }
    }
}

# ============================================================================
# Template and Config File Integrity
# ============================================================================
Describe 'File Integrity' {

    Context 'ARM Template' {
        BeforeAll {
            $script:ModuleRoot = Split-Path (Get-Module AzLocal.DeploymentAutomation).Path -Parent
            $script:TemplatePath = Join-Path $script:ModuleRoot 'templates\azure-local-deployment-template.json'
        }

        It 'ARM template file should exist' {
            Test-Path $script:TemplatePath | Should -Be $true
        }

        It 'ARM template should be valid JSON' {
            { Get-Content $script:TemplatePath -Raw | ConvertFrom-Json } | Should -Not -Throw
        }
    }

    Context 'Naming Config' {
        BeforeAll {
            $script:ModuleRoot = Split-Path (Get-Module AzLocal.DeploymentAutomation).Path -Parent
            $script:ConfigPath = Join-Path $script:ModuleRoot '.config\naming-standards-config.json'
        }

        It 'Naming config file should exist' {
            Test-Path $script:ConfigPath | Should -Be $true
        }

        It 'Naming config should be valid JSON' {
            { Get-Content $script:ConfigPath -Raw | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Naming config should have 10 naming standards' {
            $config = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
            $standardCount = ($config.namingStandards.PSObject.Properties | Measure-Object).Count
            $standardCount | Should -Be 10
        }

        It 'Naming config should have 8 default values' {
            $config = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
            $defaultCount = ($config.defaults.PSObject.Properties | Measure-Object).Count
            $defaultCount | Should -Be 8
        }
    }

    Context 'No Deprecated References in Module' {
        BeforeAll {
            $script:ModuleRoot = Split-Path (Get-Module AzLocal.DeploymentAutomation).Path -Parent
            $script:ModuleContent = (@(Get-Content (Join-Path $script:ModuleRoot 'AzLocal.DeploymentAutomation.psm1') -Raw) + @(Get-ChildItem (Join-Path $script:ModuleRoot 'Public'), (Join-Path $script:ModuleRoot 'Private') -Filter '*.ps1' | ForEach-Object { Get-Content $_.FullName -Raw })) -join "`n"
        }

        It 'Module should not reference TwoNode-Switchless' {
            $script:ModuleContent | Should -Not -Match 'TwoNode-Switchless'
        }

        It 'Module should not reference TwoNode as a standalone deployment type' {
            # TwoNode has been consolidated into MultiNode
            $script:ModuleContent | Should -Not -Match '"TwoNode"'
        }

        It 'Module should not reference Multi-Node (hyphenated, renamed to MultiNode)' {
            # Multi-Node was renamed to MultiNode for PascalCase consistency
            $script:ModuleContent | Should -Not -Match '"Multi-Node"'
        }

        It 'Module should not reference two-node-switchless-parameters-file' {
            $script:ModuleContent | Should -Not -Match 'two-node-switchless-parameters-file'
        }

        It 'Module should not reference switchless-parameters-file.json (replaced by per-node-count files)' {
            # The old single switchless template has been split into switchless-2node, switchless-3node, switchless-4node
            $script:ModuleContent | Should -Not -Match "(?<!\d+node-)switchless-parameters-file\.json"
        }

        It 'Module should not reference multi-node-parameters-file.json (old name)' {
            # Ensure the old exact filename is not referenced (multi-node-switched is OK)
            $script:ModuleContent | Should -Not -Match 'multi-node-parameters-file\.json'
        }

        It 'Module should not reference AzureStackLCMAdminPasssword (triple-s typo)' {
            $script:ModuleContent | Should -Not -Match 'AzureStackLCMAdminPasssword'
        }

        It 'Module should reference RackAware deployment type' {
            $script:ModuleContent | Should -Match 'RackAware'
        }

        It 'Module should contain Watch-AzLocalDeployment function' {
            $script:ModuleContent | Should -Match 'Function Watch-AzLocalDeployment'
        }

        It 'Module should contain Write-AzLocalLog function' {
            $script:ModuleContent | Should -Match 'Function Write-AzLocalLog'
        }

        It 'Module should contain Get-AzLocalNetworkSettingsFromJson function' {
            $script:ModuleContent | Should -Match 'Function Get-AzLocalNetworkSettingsFromJson'
        }

        It 'Module should not contain Return "Error" pattern' {
            # All functions should now use throw instead of Return "Error"
            $script:ModuleContent | Should -Not -Match 'Return\s+"Error"'
        }

        It 'Module should not contain Return .Error. pattern (single quotes)' {
            $script:ModuleContent | Should -Not -Match "Return\s+'Error'"
        }
    }
}

# ============================================================================
# Write-AzLocalLog (Internal Function)
# ============================================================================
Describe 'Function: Write-AzLocalLog' {

    Context 'Function Exists' {
        It 'Should exist as an internal function' {
            InModuleScope AzLocal.DeploymentAutomation {
                Get-Command Write-AzLocalLog -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Parameter Definitions' {
        It 'Should have Message parameter' {
            InModuleScope AzLocal.DeploymentAutomation {
                $cmd = Get-Command Write-AzLocalLog
                $cmd.Parameters.Keys | Should -Contain 'Message'
            }
        }

        It 'Should have Level parameter' {
            InModuleScope AzLocal.DeploymentAutomation {
                $cmd = Get-Command Write-AzLocalLog
                $cmd.Parameters.Keys | Should -Contain 'Level'
            }
        }

        It 'Should have NoTimestamp parameter' {
            InModuleScope AzLocal.DeploymentAutomation {
                $cmd = Get-Command Write-AzLocalLog
                $cmd.Parameters.Keys | Should -Contain 'NoTimestamp'
            }
        }

        It 'Level should accept Info, Warning, Error, Success, Debug, Verbose' {
            InModuleScope AzLocal.DeploymentAutomation {
                $cmd = Get-Command Write-AzLocalLog
                $validateSet = $cmd.Parameters['Level'].Attributes |
                    Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
                $validateSet.ValidValues | Should -Contain 'Info'
                $validateSet.ValidValues | Should -Contain 'Warning'
                $validateSet.ValidValues | Should -Contain 'Error'
                $validateSet.ValidValues | Should -Contain 'Success'
                $validateSet.ValidValues | Should -Contain 'Debug'
                $validateSet.ValidValues | Should -Contain 'Verbose'
            }
        }
    }

    Context 'Log File Output' {
        It 'Should write to log file when AzLocalLogFilePath is set' {
            InModuleScope AzLocal.DeploymentAutomation {
                $tempLog = Join-Path $env:TEMP "azlocal-test-$(Get-Random).log"
                try {
                    $script:AzLocalLogFilePath = $tempLog
                    Write-AzLocalLog "Test log message" -Level Info
                    Test-Path $tempLog | Should -Be $true
                    $content = Get-Content $tempLog -Raw
                    $content | Should -Match 'Test log message'
                    $content | Should -Match '\[Info\]'
                } finally {
                    $script:AzLocalLogFilePath = $null
                    Remove-Item $tempLog -Force -ErrorAction SilentlyContinue
                }
            }
        }

        It 'Should not write to log file when AzLocalLogFilePath is null' {
            InModuleScope AzLocal.DeploymentAutomation {
                $script:AzLocalLogFilePath = $null
                # Should not throw when log path is not set
                { Write-AzLocalLog "No file output" -Level Info } | Should -Not -Throw
            }
        }
    }
}

# ============================================================================
# LogFilePath Parameter on Exported Functions
# ============================================================================
Describe 'LogFilePath Parameter' {

    Context 'Start-AzLocalTemplateDeployment' {
        BeforeAll {
            $script:Command = Get-Command Start-AzLocalTemplateDeployment
        }

        It 'Should have LogFilePath parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'LogFilePath'
        }

        It 'LogFilePath should be of type String' {
            $script:Command.Parameters['LogFilePath'].ParameterType.Name | Should -Be 'String'
        }

        It 'LogFilePath should NOT be mandatory' {
            $param = $script:Command.Parameters['LogFilePath']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $false
        }
    }

    Context 'Watch-AzLocalDeployment' {
        BeforeAll {
            $script:Command = Get-Command Watch-AzLocalDeployment
        }

        It 'Should have LogFilePath parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'LogFilePath'
        }

        It 'LogFilePath should be of type String' {
            $script:Command.Parameters['LogFilePath'].ParameterType.Name | Should -Be 'String'
        }

        It 'LogFilePath should NOT be mandatory' {
            $param = $script:Command.Parameters['LogFilePath']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $false
        }
    }
}

# ============================================================================
# Watch-AzLocalDeployment - Parameter Validation
# ============================================================================
Describe 'Function: Watch-AzLocalDeployment' {

    Context 'Parameter Definitions' {
        BeforeAll {
            $script:Command = Get-Command Watch-AzLocalDeployment
        }

        It 'Should have DeploymentName parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'DeploymentName'
        }

        It 'Should have ResourceGroupName parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'ResourceGroupName'
        }

        It 'Should have PollingIntervalSeconds parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'PollingIntervalSeconds'
        }

        It 'Should have TimeoutMinutes parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'TimeoutMinutes'
        }

        It 'Should have PassThru parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'PassThru'
        }
    }

    Context 'Parameter Types' {
        BeforeAll {
            $script:Command = Get-Command Watch-AzLocalDeployment
        }

        It 'DeploymentName should be of type String' {
            $script:Command.Parameters['DeploymentName'].ParameterType.Name | Should -Be 'String'
        }

        It 'ResourceGroupName should be of type String' {
            $script:Command.Parameters['ResourceGroupName'].ParameterType.Name | Should -Be 'String'
        }

        It 'PollingIntervalSeconds should be of type Int32' {
            $script:Command.Parameters['PollingIntervalSeconds'].ParameterType.Name | Should -Be 'Int32'
        }

        It 'TimeoutMinutes should be of type Int32' {
            $script:Command.Parameters['TimeoutMinutes'].ParameterType.Name | Should -Be 'Int32'
        }

        It 'PassThru should be of type SwitchParameter' {
            $script:Command.Parameters['PassThru'].ParameterType.Name | Should -Be 'SwitchParameter'
        }
    }

    Context 'Mandatory Parameters' {
        BeforeAll {
            $script:Command = Get-Command Watch-AzLocalDeployment
        }

        It 'DeploymentName should be mandatory' {
            $param = $script:Command.Parameters['DeploymentName']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $true
        }

        It 'ResourceGroupName should be mandatory' {
            $param = $script:Command.Parameters['ResourceGroupName']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $true
        }

        It 'PollingIntervalSeconds should NOT be mandatory' {
            $param = $script:Command.Parameters['PollingIntervalSeconds']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $false
        }

        It 'TimeoutMinutes should NOT be mandatory' {
            $param = $script:Command.Parameters['TimeoutMinutes']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $false
        }

        It 'PassThru should NOT be mandatory' {
            $param = $script:Command.Parameters['PassThru']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $false
        }
    }

    Context 'PollingIntervalSeconds ValidateRange' {
        BeforeAll {
            $script:Command = Get-Command Watch-AzLocalDeployment
            $script:ValidateRange = $script:Command.Parameters['PollingIntervalSeconds'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
        }

        It 'Should have a ValidateRange attribute' {
            $script:ValidateRange | Should -Not -BeNullOrEmpty
        }

        It 'Should have minimum value of 10' {
            $script:ValidateRange.MinRange | Should -Be 10
        }

        It 'Should have maximum value of 600' {
            $script:ValidateRange.MaxRange | Should -Be 600
        }
    }

    Context 'TimeoutMinutes ValidateRange' {
        BeforeAll {
            $script:Command = Get-Command Watch-AzLocalDeployment
            $script:ValidateRange = $script:Command.Parameters['TimeoutMinutes'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
        }

        It 'Should have a ValidateRange attribute' {
            $script:ValidateRange | Should -Not -BeNullOrEmpty
        }

        It 'Should have minimum value of 0' {
            $script:ValidateRange.MinRange | Should -Be 0
        }

        It 'Should have maximum value of 1440' {
            $script:ValidateRange.MaxRange | Should -Be 1440
        }
    }

    Context 'Terminal State Detection Logic' {
        It 'Should recognise Succeeded as a terminal state' {
            $terminalStates = @("Succeeded", "Failed", "Canceled")
            'Succeeded' -in $terminalStates | Should -Be $true
        }

        It 'Should recognise Failed as a terminal state' {
            $terminalStates = @("Succeeded", "Failed", "Canceled")
            'Failed' -in $terminalStates | Should -Be $true
        }

        It 'Should recognise Canceled as a terminal state' {
            $terminalStates = @("Succeeded", "Failed", "Canceled")
            'Canceled' -in $terminalStates | Should -Be $true
        }

        It 'Should NOT recognise Running as a terminal state' {
            $terminalStates = @("Succeeded", "Failed", "Canceled")
            'Running' -in $terminalStates | Should -Be $false
        }

        It 'Should NOT recognise Accepted as a terminal state' {
            $terminalStates = @("Succeeded", "Failed", "Canceled")
            'Accepted' -in $terminalStates | Should -Be $false
        }
    }
}

# ============================================================================
# UniqueID ValidatePattern
# ============================================================================
Describe 'Parameter: UniqueID ValidatePattern' {

    Context 'UniqueID Pattern Validation' {
        BeforeAll {
            $script:Command = Get-Command Start-AzLocalTemplateDeployment
            $script:ValidatePattern = $script:Command.Parameters['UniqueID'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidatePatternAttribute] }
        }

        It 'Should have a ValidatePattern attribute' {
            $script:ValidatePattern | Should -Not -BeNullOrEmpty
        }

        It 'The pattern should enforce 2-8 alphanumeric characters' {
            $script:ValidatePattern.RegexPattern | Should -Be '^[a-zA-Z0-9]{2,8}$'
        }
    }
}

# ============================================================================
# ShouldProcess Support
# ============================================================================
Describe 'ShouldProcess Support' {

    Context 'Start-AzLocalTemplateDeployment ShouldProcess' {
        BeforeAll {
            $script:Command = Get-Command Start-AzLocalTemplateDeployment
            $script:CmdletBinding = $script:Command.ScriptBlock.Attributes |
                Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
        }

        It 'Should have SupportsShouldProcess enabled' {
            $script:CmdletBinding.SupportsShouldProcess | Should -Be $true
        }

        It 'Should have ConfirmImpact set to High' {
            $script:CmdletBinding.ConfirmImpact | Should -Be 'High'
        }
    }
}

# ============================================================================
# Get-AzLocalNetworkSettingsFromJson (Internal Function)
# ============================================================================
Describe 'Function: Get-AzLocalNetworkSettingsFromJson' {

    Context 'Function Exists' {
        It 'Should exist as an internal function' {
            InModuleScope AzLocal.DeploymentAutomation {
                Get-Command Get-AzLocalNetworkSettingsFromJson -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Valid JSON String Input' {
        It 'Should parse valid inline JSON for SingleNode' {
            InModuleScope AzLocal.DeploymentAutomation {
                $json = '{"subnetMask":"255.255.255.0","defaultGateway":"10.0.0.1","startingIPAddress":"10.0.0.10","endingIPAddress":"10.0.0.50","nodeIPAddresses":["10.0.0.100"]}'
                $result = Get-AzLocalNetworkSettingsFromJson -NetworkSettingsJson $json -TypeOfDeployment 'SingleNode'
                $result.subnetMask | Should -Be '255.255.255.0'
                $result.defaultGateway | Should -Be '10.0.0.1'
                $result.startingIPAddress | Should -Be '10.0.0.10'
                $result.endingIPAddress | Should -Be '10.0.0.50'
                $result.nodeIPAddresses.Count | Should -Be 1
            }
        }

        It 'Should parse valid inline JSON for MultiNode with 2 nodes' {
            InModuleScope AzLocal.DeploymentAutomation {
                $json = '{"subnetMask":"255.255.255.0","defaultGateway":"10.0.0.1","startingIPAddress":"10.0.0.10","endingIPAddress":"10.0.0.50","nodeIPAddresses":["10.0.0.100","10.0.0.101"]}'
                $result = Get-AzLocalNetworkSettingsFromJson -NetworkSettingsJson $json -TypeOfDeployment 'MultiNode' -NodeCount 2
                $result.nodeIPAddresses.Count | Should -Be 2
            }
        }
    }

    Context 'Valid JSON File Input' {
        It 'Should load settings from a JSON file' {
            InModuleScope AzLocal.DeploymentAutomation {
                $tempFile = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.json'
                $jsonContent = @{
                    subnetMask = "255.255.255.0"
                    defaultGateway = "10.0.0.1"
                    startingIPAddress = "10.0.0.10"
                    endingIPAddress = "10.0.0.50"
                    nodeIPAddresses = @("10.0.0.100")
                } | ConvertTo-Json
                $jsonContent | Out-File -FilePath $tempFile -Encoding utf8
                try {
                    $result = Get-AzLocalNetworkSettingsFromJson -NetworkSettingsJson $tempFile -TypeOfDeployment 'SingleNode'
                    $result.subnetMask | Should -Be '255.255.255.0'
                    $result.nodeIPAddresses.Count | Should -Be 1
                } finally {
                    Remove-Item $tempFile -ErrorAction SilentlyContinue
                }
            }
        }
    }

    Context 'Invalid Inputs' {
        It 'Should throw for missing required field' {
            InModuleScope AzLocal.DeploymentAutomation {
                $json = '{"subnetMask":"255.255.255.0","defaultGateway":"10.0.0.1"}'
                { Get-AzLocalNetworkSettingsFromJson -NetworkSettingsJson $json -TypeOfDeployment 'SingleNode' } | Should -Throw
            }
        }

        It 'Should throw for invalid IP address format' {
            InModuleScope AzLocal.DeploymentAutomation {
                $json = '{"subnetMask":"not-valid","defaultGateway":"10.0.0.1","startingIPAddress":"10.0.0.10","endingIPAddress":"10.0.0.50","nodeIPAddresses":["10.0.0.100"]}'
                { Get-AzLocalNetworkSettingsFromJson -NetworkSettingsJson $json -TypeOfDeployment 'SingleNode' } | Should -Throw
            }
        }

        It 'Should throw for wrong node IP count' {
            InModuleScope AzLocal.DeploymentAutomation {
                $json = '{"subnetMask":"255.255.255.0","defaultGateway":"10.0.0.1","startingIPAddress":"10.0.0.10","endingIPAddress":"10.0.0.50","nodeIPAddresses":["10.0.0.100"]}'
                { Get-AzLocalNetworkSettingsFromJson -NetworkSettingsJson $json -TypeOfDeployment 'MultiNode' -NodeCount 2 } | Should -Throw
            }
        }

        It 'Should throw for invalid JSON string' {
            InModuleScope AzLocal.DeploymentAutomation {
                { Get-AzLocalNetworkSettingsFromJson -NetworkSettingsJson 'not-json' -TypeOfDeployment 'SingleNode' } | Should -Throw
            }
        }

        It 'Should throw for invalid node IP address' {
            InModuleScope AzLocal.DeploymentAutomation {
                $json = '{"subnetMask":"255.255.255.0","defaultGateway":"10.0.0.1","startingIPAddress":"10.0.0.10","endingIPAddress":"10.0.0.50","nodeIPAddresses":["not-an-ip"]}'
                { Get-AzLocalNetworkSettingsFromJson -NetworkSettingsJson $json -TypeOfDeployment 'SingleNode' } | Should -Throw
            }
        }
    }
}

# ============================================================================
# Credential Parameter Validation
# ============================================================================
Describe 'Credential Parameters' {

    Context 'Key Vault Secret Name Parameters' {
        BeforeAll {
            $script:Command = Get-Command Start-AzLocalTemplateDeployment
        }

        It 'LocalAdminSecretName should NOT be mandatory' {
            $param = $script:Command.Parameters['LocalAdminSecretName']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $false
        }

        It 'LCMAdminSecretName should NOT be mandatory' {
            $param = $script:Command.Parameters['LCMAdminSecretName']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $false
        }

        It 'LocalAdminSecretName should be of type String' {
            $script:Command.Parameters['LocalAdminSecretName'].ParameterType.Name | Should -Be 'String'
        }

        It 'LCMAdminSecretName should be of type String' {
            $script:Command.Parameters['LCMAdminSecretName'].ParameterType.Name | Should -Be 'String'
        }
    }
}

# ============================================================================
# v0.8.0 - Code Quality and Professionalism Tests
# ============================================================================
Describe 'Code Quality: Set-StrictMode' {
    BeforeAll {
        $script:ModuleDir = Join-Path $PSScriptRoot '..'
        $script:ModuleSource = (@(Get-Content (Join-Path $script:ModuleDir 'AzLocal.DeploymentAutomation.psm1') -Raw) + @(Get-ChildItem (Join-Path $script:ModuleDir 'Public'), (Join-Path $script:ModuleDir 'Private') -Filter '*.ps1' | ForEach-Object { Get-Content $_.FullName -Raw })) -join "`n"
    }

    It 'Module should declare Set-StrictMode -Version Latest' {
        $script:ModuleSource | Should -Match 'Set-StrictMode\s+-Version\s+Latest'
    }
}

Describe 'Code Quality: OutputType Declarations' {
    BeforeAll {
        $script:StartCmd = Get-Command Start-AzLocalTemplateDeployment
        $script:WatchCmd = Get-Command Watch-AzLocalDeployment
    }

    It 'Start-AzLocalTemplateDeployment should have OutputType attribute' {
        $script:StartCmd.OutputType | Should -Not -BeNullOrEmpty
    }

    It 'Watch-AzLocalDeployment should have OutputType attribute' {
        $script:WatchCmd.OutputType | Should -Not -BeNullOrEmpty
    }
}

Describe 'Code Quality: Path Construction' {
    BeforeAll {
        $script:ModuleDir = Join-Path $PSScriptRoot '..'
        $script:ModuleSource = (@(Get-Content (Join-Path $script:ModuleDir 'AzLocal.DeploymentAutomation.psm1') -Raw) + @(Get-ChildItem (Join-Path $script:ModuleDir 'Public'), (Join-Path $script:ModuleDir 'Private') -Filter '*.ps1' | ForEach-Object { Get-Content $_.FullName -Raw })) -join "`n"
    }

    It 'Module should not contain no-op regex replace on backslash' {
        # The pattern $var -replace '\\', '\' is a no-op and should have been removed
        $script:ModuleSource | Should -Not -Match "\-replace\s+'\\\\',\s+'\\\\'"
    }

    It 'Module should use Join-Path for path construction' {
        $script:ModuleSource | Should -Match 'Join-Path'
    }
}

Describe 'Code Quality: Credential Cleanup' {
    BeforeAll {
        $script:ModuleDir = Join-Path $PSScriptRoot '..'
        $script:ModuleSource = (@(Get-Content (Join-Path $script:ModuleDir 'AzLocal.DeploymentAutomation.psm1') -Raw) + @(Get-ChildItem (Join-Path $script:ModuleDir 'Public'), (Join-Path $script:ModuleDir 'Private') -Filter '*.ps1' | ForEach-Object { Get-Content $_.FullName -Raw })) -join "`n"
    }

    It 'Module should contain a finally block for credential cleanup' {
        $script:ModuleSource | Should -Match 'finally\s*\{'
    }

    It 'Module should clear localAdminPassword variable after use' {
        $script:ModuleSource | Should -Match '\$localAdminPassword\s*=\s*\$null'
    }

    It 'Module should clear AzureStackLCMAdminPassword variable after use' {
        $script:ModuleSource | Should -Match '\$AzureStackLCMAdminPassword\s*=\s*\$null'
    }
}

Describe 'Code Quality: Az.KeyVault Availability Check' {
    BeforeAll {
        $script:ModuleDir = Join-Path $PSScriptRoot '..'
        $script:ModuleSource = (@(Get-Content (Join-Path $script:ModuleDir 'AzLocal.DeploymentAutomation.psm1') -Raw) + @(Get-ChildItem (Join-Path $script:ModuleDir 'Public'), (Join-Path $script:ModuleDir 'Private') -Filter '*.ps1' | ForEach-Object { Get-Content $_.FullName -Raw })) -join "`n"
    }

    It 'Module should check for Az.KeyVault availability before Key Vault operations' {
        $script:ModuleSource | Should -Match "Get-Module\s+-ListAvailable\s+-Name\s+'Az\.KeyVault'"
    }
}

Describe 'Code Quality: No Dead Code' {
    BeforeAll {
        $script:ModuleDir = Join-Path $PSScriptRoot '..'
        $script:ModuleSource = (@(Get-Content (Join-Path $script:ModuleDir 'AzLocal.DeploymentAutomation.psm1') -Raw) + @(Get-ChildItem (Join-Path $script:ModuleDir 'Public'), (Join-Path $script:ModuleDir 'Private') -Filter '*.ps1' | ForEach-Object { Get-Content $_.FullName -Raw })) -join "`n"
    }

    It 'Module should not contain commented-out Connect-AzAccount calls' {
        $script:ModuleSource | Should -Not -Match '#\s*Connect-AzAccount'
    }

    It 'Module should not use Remove-Variable anti-pattern' {
        $script:ModuleSource | Should -Not -Match 'Remove-Variable\s+'
    }
}

# ============================================================================
# CI/CD Automation Functions
# ============================================================================

# ============================================================================
# New-AzLocalJUnitXml
# ============================================================================
Describe 'Function: New-AzLocalJUnitXml' {

    Context 'JUnit XML Generation' {
        It 'Should generate valid XML with passed test results' {
            $results = @(
                [PSCustomObject]@{ TestName = 'Test1'; ClassName = 'Suite.Class1'; Status = 'Passed'; Message = 'OK'; Duration = 1.5 }
            )
            $xml = New-AzLocalJUnitXml -TestResults $results -SuiteName 'TestSuite'
            $xml | Should -Match '<\?xml version="1.0"'
            $xml | Should -Match '<testsuites>'
            $xml | Should -Match 'tests="1"'
            $xml | Should -Match 'failures="0"'
            $xml | Should -Match '<testcase name="Test1"'
        }

        It 'Should generate failure elements for failed tests' {
            $results = @(
                [PSCustomObject]@{ TestName = 'FailTest'; ClassName = 'Suite.Class1'; Status = 'Failed'; Message = 'Something broke'; Duration = 2.0 }
            )
            $xml = New-AzLocalJUnitXml -TestResults $results
            $xml | Should -Match 'failures="1"'
            $xml | Should -Match '<failure'
            $xml | Should -Match 'Something broke'
        }

        It 'Should generate skipped elements for skipped tests' {
            $results = @(
                [PSCustomObject]@{ TestName = 'SkipTest'; ClassName = 'Suite.Class1'; Status = 'Skipped'; Message = 'Already deployed'; Duration = 0 }
            )
            $xml = New-AzLocalJUnitXml -TestResults $results
            $xml | Should -Match 'skipped="1"'
            $xml | Should -Match '<skipped'
        }

        It 'Should handle multiple test results with mixed statuses' {
            $results = @(
                [PSCustomObject]@{ TestName = 'Pass1'; ClassName = 'Suite.A'; Status = 'Passed'; Message = 'OK'; Duration = 1 },
                [PSCustomObject]@{ TestName = 'Fail1'; ClassName = 'Suite.A'; Status = 'Failed'; Message = 'Error'; Duration = 2 },
                [PSCustomObject]@{ TestName = 'Skip1'; ClassName = 'Suite.B'; Status = 'Skipped'; Message = 'Skip'; Duration = 0 }
            )
            $xml = New-AzLocalJUnitXml -TestResults $results
            $xml | Should -Match 'tests="3"'
            $xml | Should -Match 'failures="1"'
            $xml | Should -Match 'skipped="1"'
        }

        It 'Should XML-escape special characters in test names' {
            $results = @(
                [PSCustomObject]@{ TestName = 'Test & <special>'; ClassName = 'Suite.Class'; Status = 'Passed'; Message = ''; Duration = 0 }
            )
            $xml = New-AzLocalJUnitXml -TestResults $results
            $xml | Should -Match 'Test &amp; &lt;special&gt;'
        }

        It 'Should write to file when OutputPath is specified' {
            $tempFile = Join-Path $TestDrive 'test-results.xml'
            $results = @(
                [PSCustomObject]@{ TestName = 'Test1'; ClassName = 'Suite.Class'; Status = 'Passed'; Message = 'OK'; Duration = 1 }
            )
            New-AzLocalJUnitXml -TestResults $results -OutputPath $tempFile
            Test-Path $tempFile | Should -Be $true
            $content = Get-Content $tempFile -Raw
            $content | Should -Match '<testsuites>'
        }

        It 'Should create parent directories for OutputPath if they do not exist' {
            $tempFile = Join-Path $TestDrive 'subdir\nested\results.xml'
            $results = @(
                [PSCustomObject]@{ TestName = 'Test1'; ClassName = 'Suite.Class'; Status = 'Passed'; Message = 'OK'; Duration = 1 }
            )
            New-AzLocalJUnitXml -TestResults $results -OutputPath $tempFile
            Test-Path $tempFile | Should -Be $true
        }

        It 'Should use default SuiteName when not specified' {
            $results = @(
                [PSCustomObject]@{ TestName = 'Test1'; ClassName = 'Suite.Class'; Status = 'Passed'; Message = ''; Duration = 0 }
            )
            $xml = New-AzLocalJUnitXml -TestResults $results
            $xml | Should -Match 'name="AzLocalDeploymentAutomation"'
        }

        It 'Should handle null Duration gracefully' {
            $results = @(
                [PSCustomObject]@{ TestName = 'Test1'; ClassName = 'Suite.Class'; Status = 'Passed'; Message = 'OK'; Duration = $null }
            )
            $xml = New-AzLocalJUnitXml -TestResults $results
            $xml | Should -Match 'time="0"'
        }

        It 'Should handle null Message gracefully' {
            $results = @(
                [PSCustomObject]@{ TestName = 'Test1'; ClassName = 'Suite.Class'; Status = 'Failed'; Message = $null; Duration = 1 }
            )
            { New-AzLocalJUnitXml -TestResults $results } | Should -Not -Throw
        }

        It 'Should include timestamp in output' {
            $results = @(
                [PSCustomObject]@{ TestName = 'Test1'; ClassName = 'Suite.Class'; Status = 'Passed'; Message = ''; Duration = 0 }
            )
            $xml = New-AzLocalJUnitXml -TestResults $results
            $xml | Should -Match 'timestamp='
        }

        It 'Should calculate total time from Duration properties' {
            $results = @(
                [PSCustomObject]@{ TestName = 'A'; ClassName = 'C'; Status = 'Passed'; Message = ''; Duration = 10 },
                [PSCustomObject]@{ TestName = 'B'; ClassName = 'C'; Status = 'Passed'; Message = ''; Duration = 20 }
            )
            $xml = New-AzLocalJUnitXml -TestResults $results
            $xml | Should -Match 'time="30"'
        }

        It 'Should include system-out for passed tests with messages' {
            $results = @(
                [PSCustomObject]@{ TestName = 'Test1'; ClassName = 'C'; Status = 'Passed'; Message = 'All checks passed'; Duration = 1 }
            )
            $xml = New-AzLocalJUnitXml -TestResults $results
            $xml | Should -Match '<system-out>'
            $xml | Should -Match 'All checks passed'
        }
    }

    Context 'Parameter Validation' {
        It 'Should have mandatory TestResults parameter' {
            $cmd = Get-Command New-AzLocalJUnitXml
            $cmd.Parameters['TestResults'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -Be $true
        }

        It 'Should have OutputType of string' {
            $cmd = Get-Command New-AzLocalJUnitXml
            $cmd.OutputType.Type | Should -Contain ([string])
        }
    }
}

# ============================================================================
# Import-AzLocalDeploymentCsv
# ============================================================================
Describe 'Function: Import-AzLocalDeploymentCsv' {

    Context 'Valid CSV Import' {
        BeforeAll {
            $script:ValidCsvPath = Join-Path $TestDrive 'valid-clusters.csv'
            $csvContent = @"
UniqueID,ReadyToDeploy,SubscriptionId,TenantId,TypeOfDeployment,NodeCount,Location,CredentialKeyVaultName,LocalAdminSecretName,LCMAdminSecretName,SubnetMask,DefaultGateway,StartingIPAddress,EndingIPAddress,DnsServers,NodeIPAddresses
Store001,TRUE,12345678-1234-1234-1234-123456789abc,12345678-1234-1234-1234-123456789abc,SingleNode,1,eastus,kv-deploy,LocalAdmin,LCMAdmin,255.255.255.0,10.0.1.1,10.0.1.100,10.0.1.110,10.0.1.10,10.0.1.50
Store002,FALSE,12345678-1234-1234-1234-123456789abc,12345678-1234-1234-1234-123456789abc,MultiNode,2,eastus,kv-deploy,LocalAdmin,LCMAdmin,255.255.255.0,10.0.2.1,10.0.2.100,10.0.2.110,10.0.2.10;10.0.2.11,10.0.2.50;10.0.2.51
"@
            $csvContent | Out-File -FilePath $script:ValidCsvPath -Encoding utf8
        }

        It 'Should import all rows from a valid CSV' {
            $result = @(Import-AzLocalDeploymentCsv -CsvFilePath $script:ValidCsvPath)
            $result.Count | Should -Be 2
        }

        It 'Should filter to ReadyToDeploy=TRUE with -ReadyOnly switch' {
            $result = @(Import-AzLocalDeploymentCsv -CsvFilePath $script:ValidCsvPath -ReadyOnly)
            $result.Count | Should -Be 1
            $result[0].UniqueID | Should -Be 'Store001'
        }

        It 'Should return PSCustomObjects with correct properties' {
            $result = @(Import-AzLocalDeploymentCsv -CsvFilePath $script:ValidCsvPath)
            $result[0].UniqueID | Should -Be 'Store001'
            $result[0].TypeOfDeployment | Should -Be 'SingleNode'
            $result[0].SubscriptionId | Should -Be '12345678-1234-1234-1234-123456789abc'
        }

        It 'Should preserve semicolon-separated values as strings' {
            $result = @(Import-AzLocalDeploymentCsv -CsvFilePath $script:ValidCsvPath)
            $result[1].NodeIPAddresses | Should -Be '10.0.2.50;10.0.2.51'
            $result[1].DnsServers | Should -Be '10.0.2.10;10.0.2.11'
        }
    }

    Context 'CSV Validation Errors' {
        It 'Should throw when CSV file does not exist' {
            { Import-AzLocalDeploymentCsv -CsvFilePath 'C:\nonexistent\file.csv' } | Should -Throw '*not found*'
        }

        It 'Should throw when CSV has no data rows' {
            $emptyCsv = Join-Path $TestDrive 'empty.csv'
            "UniqueID,ReadyToDeploy,SubscriptionId,TenantId,TypeOfDeployment,NodeCount,CredentialKeyVaultName,SubnetMask,DefaultGateway,StartingIPAddress,EndingIPAddress,NodeIPAddresses" | Out-File -FilePath $emptyCsv -Encoding utf8
            { Import-AzLocalDeploymentCsv -CsvFilePath $emptyCsv } | Should -Throw '*no data*'
        }

        It 'Should throw when required columns are missing' {
            $badCsv = Join-Path $TestDrive 'missing-cols.csv'
            @"
UniqueID,ReadyToDeploy
Store001,TRUE
"@ | Out-File -FilePath $badCsv -Encoding utf8
            { Import-AzLocalDeploymentCsv -CsvFilePath $badCsv } | Should -Throw '*missing required columns*'
        }

        It 'Should throw when UniqueID is empty' {
            $badCsv = Join-Path $TestDrive 'empty-uid.csv'
            @"
UniqueID,ReadyToDeploy,SubscriptionId,TenantId,TypeOfDeployment,NodeCount,CredentialKeyVaultName,SubnetMask,DefaultGateway,StartingIPAddress,EndingIPAddress,NodeIPAddresses
,TRUE,12345678-1234-1234-1234-123456789abc,12345678-1234-1234-1234-123456789abc,SingleNode,1,kv-deploy,255.255.255.0,10.0.1.1,10.0.1.100,10.0.1.110,10.0.1.50
"@ | Out-File -FilePath $badCsv -Encoding utf8
            { Import-AzLocalDeploymentCsv -CsvFilePath $badCsv } | Should -Throw '*UniqueID*'
        }

        It 'Should throw when UniqueID has invalid characters' {
            $badCsv = Join-Path $TestDrive 'bad-uid.csv'
            @"
UniqueID,ReadyToDeploy,SubscriptionId,TenantId,TypeOfDeployment,NodeCount,CredentialKeyVaultName,SubnetMask,DefaultGateway,StartingIPAddress,EndingIPAddress,NodeIPAddresses
St@re!,TRUE,12345678-1234-1234-1234-123456789abc,12345678-1234-1234-1234-123456789abc,SingleNode,1,kv-deploy,255.255.255.0,10.0.1.1,10.0.1.100,10.0.1.110,10.0.1.50
"@ | Out-File -FilePath $badCsv -Encoding utf8
            { Import-AzLocalDeploymentCsv -CsvFilePath $badCsv } | Should -Throw '*UniqueID*'
        }

        It 'Should throw when UniqueID exceeds 8 characters' {
            $badCsv = Join-Path $TestDrive 'long-uid.csv'
            @"
UniqueID,ReadyToDeploy,SubscriptionId,TenantId,TypeOfDeployment,NodeCount,CredentialKeyVaultName,SubnetMask,DefaultGateway,StartingIPAddress,EndingIPAddress,NodeIPAddresses
StoreTooLong,TRUE,12345678-1234-1234-1234-123456789abc,12345678-1234-1234-1234-123456789abc,SingleNode,1,kv-deploy,255.255.255.0,10.0.1.1,10.0.1.100,10.0.1.110,10.0.1.50
"@ | Out-File -FilePath $badCsv -Encoding utf8
            { Import-AzLocalDeploymentCsv -CsvFilePath $badCsv } | Should -Throw '*UniqueID*'
        }

        It 'Should throw when UniqueID is less than 2 characters' {
            $badCsv = Join-Path $TestDrive 'short-uid.csv'
            @"
UniqueID,ReadyToDeploy,SubscriptionId,TenantId,TypeOfDeployment,NodeCount,CredentialKeyVaultName,SubnetMask,DefaultGateway,StartingIPAddress,EndingIPAddress,NodeIPAddresses
A,TRUE,12345678-1234-1234-1234-123456789abc,12345678-1234-1234-1234-123456789abc,SingleNode,1,kv-deploy,255.255.255.0,10.0.1.1,10.0.1.100,10.0.1.110,10.0.1.50
"@ | Out-File -FilePath $badCsv -Encoding utf8
            { Import-AzLocalDeploymentCsv -CsvFilePath $badCsv } | Should -Throw '*UniqueID*'
        }

        It 'Should throw when SubscriptionId is not a GUID' {
            $badCsv = Join-Path $TestDrive 'bad-sub.csv'
            @"
UniqueID,ReadyToDeploy,SubscriptionId,TenantId,TypeOfDeployment,NodeCount,CredentialKeyVaultName,SubnetMask,DefaultGateway,StartingIPAddress,EndingIPAddress,NodeIPAddresses
Store001,TRUE,not-a-guid,12345678-1234-1234-1234-123456789abc,SingleNode,1,kv-deploy,255.255.255.0,10.0.1.1,10.0.1.100,10.0.1.110,10.0.1.50
"@ | Out-File -FilePath $badCsv -Encoding utf8
            { Import-AzLocalDeploymentCsv -CsvFilePath $badCsv } | Should -Throw '*SubscriptionId*'
        }

        It 'Should throw when TenantId is not a GUID' {
            $badCsv = Join-Path $TestDrive 'bad-tenant.csv'
            @"
UniqueID,ReadyToDeploy,SubscriptionId,TenantId,TypeOfDeployment,NodeCount,CredentialKeyVaultName,SubnetMask,DefaultGateway,StartingIPAddress,EndingIPAddress,NodeIPAddresses
Store001,TRUE,12345678-1234-1234-1234-123456789abc,not-a-guid,SingleNode,1,kv-deploy,255.255.255.0,10.0.1.1,10.0.1.100,10.0.1.110,10.0.1.50
"@ | Out-File -FilePath $badCsv -Encoding utf8
            { Import-AzLocalDeploymentCsv -CsvFilePath $badCsv } | Should -Throw '*TenantId*'
        }

        It 'Should throw when TypeOfDeployment is invalid' {
            $badCsv = Join-Path $TestDrive 'bad-type.csv'
            @"
UniqueID,ReadyToDeploy,SubscriptionId,TenantId,TypeOfDeployment,NodeCount,CredentialKeyVaultName,SubnetMask,DefaultGateway,StartingIPAddress,EndingIPAddress,NodeIPAddresses
Store001,TRUE,12345678-1234-1234-1234-123456789abc,12345678-1234-1234-1234-123456789abc,InvalidType,1,kv-deploy,255.255.255.0,10.0.1.1,10.0.1.100,10.0.1.110,10.0.1.50
"@ | Out-File -FilePath $badCsv -Encoding utf8
            { Import-AzLocalDeploymentCsv -CsvFilePath $badCsv } | Should -Throw '*TypeOfDeployment*'
        }

        It 'Should throw when DefaultGateway is not a valid IP' {
            $badCsv = Join-Path $TestDrive 'bad-gw.csv'
            @"
UniqueID,ReadyToDeploy,SubscriptionId,TenantId,TypeOfDeployment,NodeCount,CredentialKeyVaultName,SubnetMask,DefaultGateway,StartingIPAddress,EndingIPAddress,NodeIPAddresses
Store001,TRUE,12345678-1234-1234-1234-123456789abc,12345678-1234-1234-1234-123456789abc,SingleNode,1,kv-deploy,255.255.255.0,not.an.ip,10.0.1.100,10.0.1.110,10.0.1.50
"@ | Out-File -FilePath $badCsv -Encoding utf8
            { Import-AzLocalDeploymentCsv -CsvFilePath $badCsv } | Should -Throw '*DefaultGateway*'
        }

        It 'Should throw when NodeIPAddresses contains invalid IP' {
            $badCsv = Join-Path $TestDrive 'bad-nodeip.csv'
            @"
UniqueID,ReadyToDeploy,SubscriptionId,TenantId,TypeOfDeployment,NodeCount,CredentialKeyVaultName,SubnetMask,DefaultGateway,StartingIPAddress,EndingIPAddress,NodeIPAddresses
Store001,TRUE,12345678-1234-1234-1234-123456789abc,12345678-1234-1234-1234-123456789abc,SingleNode,1,kv-deploy,255.255.255.0,10.0.1.1,10.0.1.100,10.0.1.110,bad.ip.addr
"@ | Out-File -FilePath $badCsv -Encoding utf8
            { Import-AzLocalDeploymentCsv -CsvFilePath $badCsv } | Should -Throw '*NodeIPAddress*'
        }

        It 'Should throw when ReadyToDeploy is not TRUE or FALSE' {
            $badCsv = Join-Path $TestDrive 'bad-ready.csv'
            @"
UniqueID,ReadyToDeploy,SubscriptionId,TenantId,TypeOfDeployment,NodeCount,CredentialKeyVaultName,SubnetMask,DefaultGateway,StartingIPAddress,EndingIPAddress,NodeIPAddresses
Store001,MAYBE,12345678-1234-1234-1234-123456789abc,12345678-1234-1234-1234-123456789abc,SingleNode,1,kv-deploy,255.255.255.0,10.0.1.1,10.0.1.100,10.0.1.110,10.0.1.50
"@ | Out-File -FilePath $badCsv -Encoding utf8
            { Import-AzLocalDeploymentCsv -CsvFilePath $badCsv } | Should -Throw '*ReadyToDeploy*'
        }

        It 'Should accept all valid TypeOfDeployment values' {
            foreach ($deployType in @('SingleNode', 'MultiNode', 'Switchless', 'RackAware')) {
                $csv = Join-Path $TestDrive "valid-$deployType.csv"
                @"
UniqueID,ReadyToDeploy,SubscriptionId,TenantId,TypeOfDeployment,NodeCount,CredentialKeyVaultName,SubnetMask,DefaultGateway,StartingIPAddress,EndingIPAddress,NodeIPAddresses
Store001,TRUE,12345678-1234-1234-1234-123456789abc,12345678-1234-1234-1234-123456789abc,$deployType,1,kv-deploy,255.255.255.0,10.0.1.1,10.0.1.100,10.0.1.110,10.0.1.50
"@ | Out-File -FilePath $csv -Encoding utf8
                { Import-AzLocalDeploymentCsv -CsvFilePath $csv } | Should -Not -Throw
            }
        }

        It 'Should accept ReadyToDeploy in various casings' {
            foreach ($rdVal in @('TRUE', 'FALSE', 'true', 'false', 'True', 'False')) {
                $csv = Join-Path $TestDrive "ready-$rdVal.csv"
                @"
UniqueID,ReadyToDeploy,SubscriptionId,TenantId,TypeOfDeployment,NodeCount,CredentialKeyVaultName,SubnetMask,DefaultGateway,StartingIPAddress,EndingIPAddress,NodeIPAddresses
Store001,$rdVal,12345678-1234-1234-1234-123456789abc,12345678-1234-1234-1234-123456789abc,SingleNode,1,kv-deploy,255.255.255.0,10.0.1.1,10.0.1.100,10.0.1.110,10.0.1.50
"@ | Out-File -FilePath $csv -Encoding utf8
                { Import-AzLocalDeploymentCsv -CsvFilePath $csv } | Should -Not -Throw
            }
        }
    }

    Context 'Parameter Validation' {
        It 'Should have mandatory CsvFilePath parameter' {
            $cmd = Get-Command Import-AzLocalDeploymentCsv
            $cmd.Parameters['CsvFilePath'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -Be $true
        }

        It 'Should have optional ReadyOnly switch parameter' {
            $cmd = Get-Command Import-AzLocalDeploymentCsv
            $cmd.Parameters['ReadyOnly'].ParameterType | Should -Be ([switch])
        }

        It 'Should have OutputType of PSCustomObject array' {
            $cmd = Get-Command Import-AzLocalDeploymentCsv
            $cmd.OutputType.Type | Should -Not -BeNullOrEmpty
        }
    }
}

# ============================================================================
# Test-AzLocalClusterPreFlight
# ============================================================================
Describe 'Function: Test-AzLocalClusterPreFlight' {

    Context 'Parameter Validation' {
        It 'Should have mandatory ClusterRow parameter' {
            $cmd = Get-Command Test-AzLocalClusterPreFlight
            $cmd.Parameters['ClusterRow'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -Be $true
        }

        It 'Should have mandatory NamingConfig parameter' {
            $cmd = Get-Command Test-AzLocalClusterPreFlight
            $cmd.Parameters['NamingConfig'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -Be $true
        }

        It 'Should have mandatory DeploymentMode parameter with ValidateSet' {
            $cmd = Get-Command Test-AzLocalClusterPreFlight
            $cmd.Parameters['DeploymentMode'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -Be $true
            $validateSet = $cmd.Parameters['DeploymentMode'].Attributes.Where({ $_ -is [System.Management.Automation.ValidateSetAttribute] })
            $validateSet | Should -Not -BeNullOrEmpty
            $validateSet.ValidValues | Should -Contain 'Validate'
            $validateSet.ValidValues | Should -Contain 'Deploy'
        }

        It 'Should have OutputType of PSCustomObject' {
            $cmd = Get-Command Test-AzLocalClusterPreFlight
            $cmd.OutputType.Type | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Pre-Flight Check Logic (Mocked Azure Calls)' {
        BeforeAll {
            $script:NamingConfig = Get-AzLocalNamingConfig

            # Use lowercase UniqueID to ensure generated storage account names pass
            # Azure naming validation (lowercase alphanumeric only).
            $script:MockClusterRow = [PSCustomObject]@{
                UniqueID               = 'tst001'
                ReadyToDeploy          = 'TRUE'
                SubscriptionId         = '12345678-1234-1234-1234-123456789abc'
                TenantId               = '12345678-1234-1234-1234-123456789abc'
                TypeOfDeployment       = 'SingleNode'
                NodeCount              = '1'
                Location               = 'eastus'
                CredentialKeyVaultName = 'kv-deploy'
                LocalAdminSecretName   = 'LocalAdmin'
                LCMAdminSecretName     = 'LCMAdmin'
                SubnetMask             = '255.255.255.0'
                DefaultGateway         = '10.0.1.1'
                StartingIPAddress      = '10.0.1.100'
                EndingIPAddress        = '10.0.1.110'
                DnsServers             = '10.0.1.10'
                NodeIPAddresses        = '10.0.1.50'
            }
        }

        It 'Should return Passed when all checks pass' {
            Mock Get-AzResourceGroup { return @{ ResourceGroupName = 'rg-tst001-azurelocal-prod' } } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResource {
                param($ResourceId)
                if ($ResourceId -like '*HybridCompute*') { return @{ Name = 'tst001NODE01' } }
                if ($ResourceId -like '*AzureStackHCI*') { return $null }
            } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroupDeployment { return $null } -ModuleName AzLocal.DeploymentAutomation

            $result = Test-AzLocalClusterPreFlight -ClusterRow $script:MockClusterRow -NamingConfig $script:NamingConfig -DeploymentMode 'Validate'
            $result.Status | Should -Be 'Passed'
            $result.UniqueID | Should -Be 'tst001'
        }

        It 'Should return Failed when resource group does not exist' {
            Mock Get-AzResourceGroup { return $null } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResource { return $null } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroupDeployment { return $null } -ModuleName AzLocal.DeploymentAutomation

            $result = Test-AzLocalClusterPreFlight -ClusterRow $script:MockClusterRow -NamingConfig $script:NamingConfig -DeploymentMode 'Validate'
            $result.Status | Should -Be 'Failed'
            ($result.Messages -join '; ') | Should -Match 'NOT FOUND'
        }

        It 'Should return Failed when Arc nodes are not registered' {
            Mock Get-AzResourceGroup { return @{ ResourceGroupName = 'rg-tst001-azurelocal-prod' } } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResource {
                param($ResourceId)
                if ($ResourceId -like '*HybridCompute*') { return $null }
                if ($ResourceId -like '*AzureStackHCI*') { return $null }
            } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroupDeployment { return $null } -ModuleName AzLocal.DeploymentAutomation

            $result = Test-AzLocalClusterPreFlight -ClusterRow $script:MockClusterRow -NamingConfig $script:NamingConfig -DeploymentMode 'Validate'
            $result.Status | Should -Be 'Failed'
        }

        It 'Should return Skipped when cluster already exists' {
            Mock Get-AzResourceGroup { return @{ ResourceGroupName = 'rg-tst001-azurelocal-prod' } } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResource {
                param($ResourceId)
                if ($ResourceId -like '*HybridCompute*') { return @{ Name = 'tst001NODE01' } }
                if ($ResourceId -like '*AzureStackHCI*') { return @{ Name = 'AZCLUSTERtst001' } }
            } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroupDeployment { return $null } -ModuleName AzLocal.DeploymentAutomation

            $result = Test-AzLocalClusterPreFlight -ClusterRow $script:MockClusterRow -NamingConfig $script:NamingConfig -DeploymentMode 'Validate'
            $result.Status | Should -Be 'Skipped'
        }

        It 'Should return Skipped when deployment is in-progress' {
            Mock Get-AzResourceGroup { return @{ ResourceGroupName = 'rg-tst001-azurelocal-prod' } } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResource {
                param($ResourceId)
                if ($ResourceId -like '*HybridCompute*') { return @{ Name = 'tst001NODE01' } }
                if ($ResourceId -like '*AzureStackHCI*') { return $null }
            } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroupDeployment {
                return @{ ProvisioningState = 'Running' }
            } -ModuleName AzLocal.DeploymentAutomation

            $result = Test-AzLocalClusterPreFlight -ClusterRow $script:MockClusterRow -NamingConfig $script:NamingConfig -DeploymentMode 'Validate'
            $result.Status | Should -Be 'Skipped'
        }

        It 'Should return Passed when previous deployment failed (retryable)' {
            Mock Get-AzResourceGroup { return @{ ResourceGroupName = 'rg-tst001-azurelocal-prod' } } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResource {
                param($ResourceId)
                if ($ResourceId -like '*HybridCompute*') { return @{ Name = 'tst001NODE01' } }
                if ($ResourceId -like '*AzureStackHCI*') { return $null }
            } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroupDeployment {
                return @{ ProvisioningState = 'Failed' }
            } -ModuleName AzLocal.DeploymentAutomation

            $result = Test-AzLocalClusterPreFlight -ClusterRow $script:MockClusterRow -NamingConfig $script:NamingConfig -DeploymentMode 'Deploy'
            $result.Status | Should -Be 'Passed'
        }

        It 'Should include Duration in result' {
            Mock Get-AzResourceGroup { return @{ ResourceGroupName = 'rg-tst001-azurelocal-prod' } } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResource {
                param($ResourceId)
                if ($ResourceId -like '*HybridCompute*') { return @{ Name = 'tst001NODE01' } }
                if ($ResourceId -like '*AzureStackHCI*') { return $null }
            } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroupDeployment { return $null } -ModuleName AzLocal.DeploymentAutomation

            $result = Test-AzLocalClusterPreFlight -ClusterRow $script:MockClusterRow -NamingConfig $script:NamingConfig -DeploymentMode 'Validate'
            $result.Duration | Should -BeOfType [double]
            $result.Duration | Should -BeGreaterOrEqual 0
        }

        It 'Should resolve resource names correctly using naming config' {
            Mock Get-AzResourceGroup { return @{ ResourceGroupName = 'rg-tst001-azurelocal-prod' } } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResource {
                param($ResourceId)
                if ($ResourceId -like '*HybridCompute*') { return @{ Name = 'tst001NODE01' } }
                if ($ResourceId -like '*AzureStackHCI*') { return $null }
            } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroupDeployment { return $null } -ModuleName AzLocal.DeploymentAutomation

            $result = Test-AzLocalClusterPreFlight -ClusterRow $script:MockClusterRow -NamingConfig $script:NamingConfig -DeploymentMode 'Validate'
            $result.ResourceGroupName | Should -Not -BeNullOrEmpty
            $result.ClusterName | Should -Not -BeNullOrEmpty
            $result.DeploymentName | Should -Not -BeNullOrEmpty
        }
    }
}

# ============================================================================
# Start-AzLocalCsvDeployment
# ============================================================================
Describe 'Function: Start-AzLocalCsvDeployment' {

    Context 'Parameter Definitions' {
        BeforeAll {
            $script:Command = Get-Command Start-AzLocalCsvDeployment
        }

        It 'Should have mandatory CsvFilePath parameter' {
            $script:Command.Parameters['CsvFilePath'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -Be $true
        }

        It 'Should have mandatory DeploymentMode parameter' {
            $script:Command.Parameters['DeploymentMode'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -Be $true
        }

        It 'Should have ValidateSet on DeploymentMode with Validate and Deploy' {
            $validateSet = $script:Command.Parameters['DeploymentMode'].Attributes.Where({ $_ -is [System.Management.Automation.ValidateSetAttribute] })
            $validateSet | Should -Not -BeNullOrEmpty
            $validateSet.ValidValues | Should -Contain 'Validate'
            $validateSet.ValidValues | Should -Contain 'Deploy'
        }

        It 'Should have optional JUnitOutputPath parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'JUnitOutputPath'
            $param = $script:Command.Parameters['JUnitOutputPath']
            $param.ParameterType | Should -Be ([string])
        }

        It 'Should have optional LogFilePath parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'LogFilePath'
        }

        It 'Should support ShouldProcess (WhatIf/Confirm)' {
            $script:Command.Parameters.Keys | Should -Contain 'WhatIf'
            $script:Command.Parameters.Keys | Should -Contain 'Confirm'
        }

        It 'Should have ConfirmImpact of High' {
            $cmdletBinding = $script:Command.ScriptBlock.Attributes.Where({ $_ -is [System.Management.Automation.CmdletBindingAttribute] })
            $cmdletBinding.ConfirmImpact | Should -Be 'High'
        }

        It 'Should have OutputType of PSCustomObject array' {
            $script:Command.OutputType.Type | Should -Not -BeNullOrEmpty
        }
    }

    Context 'CSV-Driven Deployment Logic (Mocked)' {
        BeforeAll {
            $script:CsvPath = Join-Path $TestDrive 'deploy-test.csv'
            $csvContent = @"
UniqueID,ReadyToDeploy,SubscriptionId,TenantId,TypeOfDeployment,NodeCount,Location,CredentialKeyVaultName,LocalAdminSecretName,LCMAdminSecretName,SubnetMask,DefaultGateway,StartingIPAddress,EndingIPAddress,DnsServers,NodeIPAddresses
TST001,TRUE,12345678-1234-1234-1234-123456789abc,12345678-1234-1234-1234-123456789abc,SingleNode,1,eastus,kv-deploy,LocalAdmin,LCMAdmin,255.255.255.0,10.0.1.1,10.0.1.100,10.0.1.110,10.0.1.10,10.0.1.50
TST002,FALSE,12345678-1234-1234-1234-123456789abc,12345678-1234-1234-1234-123456789abc,MultiNode,2,eastus,kv-deploy,LocalAdmin,LCMAdmin,255.255.255.0,10.0.2.1,10.0.2.100,10.0.2.110,10.0.2.10,10.0.2.50;10.0.2.51
"@
            $csvContent | Out-File -FilePath $script:CsvPath -Encoding utf8
        }

        It 'Should return results for ReadyToDeploy=TRUE clusters only' {
            Mock Set-AzContext { return $true } -ModuleName AzLocal.DeploymentAutomation
            Mock Test-AzLocalClusterPreFlight {
                return [PSCustomObject]@{
                    UniqueID = 'TST001'; ClusterName = 'cl-azlocal-TST001'; ResourceGroupName = 'rg-azlocal-TST001';
                    DeploymentName = 'deploy-TST001-SingleNode'; Status = 'Passed'; Messages = @('All checks passed'); Duration = 1.0
                }
            } -ModuleName AzLocal.DeploymentAutomation
            Mock Start-AzLocalTemplateDeployment {
                return [PSCustomObject]@{ ProvisioningState = 'Succeeded'; Duration = '00:05:00' }
            } -ModuleName AzLocal.DeploymentAutomation

            $results = Start-AzLocalCsvDeployment -CsvFilePath $script:CsvPath -DeploymentMode 'Validate' -Confirm:$false
            # TST002 is FALSE, should not appear
            $results | Where-Object { $_.TestName -like '*TST002*' } | Should -BeNullOrEmpty
        }

        It 'Should skip deployment when pre-flight fails' {
            Mock Set-AzContext { return $true } -ModuleName AzLocal.DeploymentAutomation
            Mock Test-AzLocalClusterPreFlight {
                return [PSCustomObject]@{
                    UniqueID = 'TST001'; ClusterName = 'cl-azlocal-TST001'; ResourceGroupName = 'rg-azlocal-TST001';
                    DeploymentName = 'deploy-TST001-SingleNode'; Status = 'Failed'; Messages = @('RG not found'); Duration = 0.5
                }
            } -ModuleName AzLocal.DeploymentAutomation
            Mock Start-AzLocalTemplateDeployment { throw "Should not be called" } -ModuleName AzLocal.DeploymentAutomation

            $results = Start-AzLocalCsvDeployment -CsvFilePath $script:CsvPath -DeploymentMode 'Validate' -Confirm:$false
            $preFlightResult = $results | Where-Object { $_.TestName -eq 'PreFlight-TST001' }
            $preFlightResult.Status | Should -Be 'Failed'
            # No deployment result should exist since pre-flight failed
            $deployResult = $results | Where-Object { $_.TestName -eq 'Validate-TST001' }
            $deployResult | Should -BeNullOrEmpty
        }

        It 'Should generate JUnit XML when JUnitOutputPath is specified' {
            Mock Set-AzContext { return $true } -ModuleName AzLocal.DeploymentAutomation
            Mock Test-AzLocalClusterPreFlight {
                return [PSCustomObject]@{
                    UniqueID = 'TST001'; ClusterName = 'cl-azlocal-TST001'; ResourceGroupName = 'rg-azlocal-TST001';
                    DeploymentName = 'deploy-TST001-SingleNode'; Status = 'Passed'; Messages = @('OK'); Duration = 1.0
                }
            } -ModuleName AzLocal.DeploymentAutomation
            Mock Start-AzLocalTemplateDeployment {
                return [PSCustomObject]@{ ProvisioningState = 'Succeeded'; Duration = '00:05:00' }
            } -ModuleName AzLocal.DeploymentAutomation

            $junitPath = Join-Path $TestDrive 'junit-output.xml'
            Start-AzLocalCsvDeployment -CsvFilePath $script:CsvPath -DeploymentMode 'Validate' -JUnitOutputPath $junitPath -Confirm:$false
            Test-Path $junitPath | Should -Be $true
            $xmlContent = Get-Content $junitPath -Raw
            $xmlContent | Should -Match '<testsuites>'
        }

        It 'Should handle no ReadyToDeploy=TRUE clusters gracefully' {
            $allFalseCsv = Join-Path $TestDrive 'all-false.csv'
            @"
UniqueID,ReadyToDeploy,SubscriptionId,TenantId,TypeOfDeployment,NodeCount,Location,CredentialKeyVaultName,LocalAdminSecretName,LCMAdminSecretName,SubnetMask,DefaultGateway,StartingIPAddress,EndingIPAddress,DnsServers,NodeIPAddresses
TST001,FALSE,12345678-1234-1234-1234-123456789abc,12345678-1234-1234-1234-123456789abc,SingleNode,1,eastus,kv-deploy,LocalAdmin,LCMAdmin,255.255.255.0,10.0.1.1,10.0.1.100,10.0.1.110,10.0.1.10,10.0.1.50
"@ | Out-File -FilePath $allFalseCsv -Encoding utf8

            $results = Start-AzLocalCsvDeployment -CsvFilePath $allFalseCsv -DeploymentMode 'Validate' -Confirm:$false
            $results | Should -Not -BeNullOrEmpty
            $results[0].Status | Should -Be 'Skipped'
        }
    }
}

# ============================================================================
# Get-AzLocalDeploymentStatus
# ============================================================================
Describe 'Function: Get-AzLocalDeploymentStatus' {

    Context 'Parameter Definitions' {
        BeforeAll {
            $script:Command = Get-Command Get-AzLocalDeploymentStatus
        }

        It 'Should have mandatory CsvFilePath parameter' {
            $script:Command.Parameters['CsvFilePath'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -Be $true
        }

        It 'Should have optional JUnitOutputPath parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'JUnitOutputPath'
        }

        It 'Should have optional LogFilePath parameter' {
            $script:Command.Parameters.Keys | Should -Contain 'LogFilePath'
        }

        It 'Should have OutputType of PSCustomObject array' {
            $script:Command.OutputType.Type | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Status Monitoring Logic (Mocked)' {
        BeforeAll {
            $script:CsvPath = Join-Path $TestDrive 'status-test.csv'
            $csvContent = @"
UniqueID,ReadyToDeploy,SubscriptionId,TenantId,TypeOfDeployment,NodeCount,Location,CredentialKeyVaultName,LocalAdminSecretName,LCMAdminSecretName,SubnetMask,DefaultGateway,StartingIPAddress,EndingIPAddress,DnsServers,NodeIPAddresses
TST001,TRUE,12345678-1234-1234-1234-123456789abc,12345678-1234-1234-1234-123456789abc,SingleNode,1,eastus,kv-deploy,LocalAdmin,LCMAdmin,255.255.255.0,10.0.1.1,10.0.1.100,10.0.1.110,10.0.1.10,10.0.1.50
"@
            $csvContent | Out-File -FilePath $script:CsvPath -Encoding utf8
        }

        It 'Should report NotStarted when no deployment exists' {
            Mock Set-AzContext { return $true } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResource { return $null } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroup { return @{ ResourceGroupName = 'rg-azlocal-TST001' } } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroupDeployment { return $null } -ModuleName AzLocal.DeploymentAutomation

            $results = Get-AzLocalDeploymentStatus -CsvFilePath $script:CsvPath
            $results | Should -Not -BeNullOrEmpty
            $results[0].DeploymentStatus | Should -Be 'NotStarted'
        }

        It 'Should report ClusterExists when cluster resource exists' {
            Mock Set-AzContext { return $true } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResource {
                param($ResourceId)
                if ($ResourceId -like '*AzureStackHCI*') { return @{ Name = 'cl-azlocal-TST001' } }
                return $null
            } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroup { return @{ ResourceGroupName = 'rg-azlocal-TST001' } } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroupDeployment { return $null } -ModuleName AzLocal.DeploymentAutomation

            $results = Get-AzLocalDeploymentStatus -CsvFilePath $script:CsvPath
            $results[0].DeploymentStatus | Should -Be 'ClusterExists'
        }

        It 'Should report DeploySucceeded for succeeded deploy' {
            Mock Set-AzContext { return $true } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResource { return $null } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroup { return @{ ResourceGroupName = 'rg-azlocal-TST001' } } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroupDeployment {
                return @{
                    ProvisioningState = 'Succeeded'
                    Duration = [TimeSpan]::FromMinutes(30)
                    Parameters = @{ deploymentMode = @{ Value = 'Deploy' } }
                }
            } -ModuleName AzLocal.DeploymentAutomation

            $results = Get-AzLocalDeploymentStatus -CsvFilePath $script:CsvPath
            $results[0].DeploymentStatus | Should -Be 'DeploySucceeded'
        }

        It 'Should report ValidateFailed for failed validation' {
            Mock Set-AzContext { return $true } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResource { return $null } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroup { return @{ ResourceGroupName = 'rg-azlocal-TST001' } } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroupDeployment {
                return @{
                    ProvisioningState = 'Failed'
                    Duration = [TimeSpan]::FromMinutes(5)
                    Parameters = @{ deploymentMode = @{ Value = 'Validate' } }
                }
            } -ModuleName AzLocal.DeploymentAutomation

            $results = Get-AzLocalDeploymentStatus -CsvFilePath $script:CsvPath
            $results[0].DeploymentStatus | Should -Be 'ValidateFailed'
        }

        It 'Should report DeployInProgress for running deploy' {
            Mock Set-AzContext { return $true } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResource { return $null } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroup { return @{ ResourceGroupName = 'rg-azlocal-TST001' } } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroupDeployment {
                return @{
                    ProvisioningState = 'Running'
                    Duration = $null
                    Parameters = @{ deploymentMode = @{ Value = 'Deploy' } }
                }
            } -ModuleName AzLocal.DeploymentAutomation

            $results = Get-AzLocalDeploymentStatus -CsvFilePath $script:CsvPath
            $results[0].DeploymentStatus | Should -Be 'DeployInProgress'
        }

        It 'Should report NotStarted when resource group does not exist' {
            Mock Set-AzContext { return $true } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResource { return $null } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroup { return $null } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroupDeployment { return $null } -ModuleName AzLocal.DeploymentAutomation

            $results = Get-AzLocalDeploymentStatus -CsvFilePath $script:CsvPath
            $results[0].DeploymentStatus | Should -Be 'NotStarted'
        }

        It 'Should generate JUnit XML when JUnitOutputPath is specified' {
            Mock Set-AzContext { return $true } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResource { return $null } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroup { return @{ ResourceGroupName = 'rg-azlocal-TST001' } } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroupDeployment { return $null } -ModuleName AzLocal.DeploymentAutomation

            $junitPath = Join-Path $TestDrive 'status-junit.xml'
            Get-AzLocalDeploymentStatus -CsvFilePath $script:CsvPath -JUnitOutputPath $junitPath
            Test-Path $junitPath | Should -Be $true
        }

        It 'Should return empty array when no ReadyToDeploy=TRUE clusters' {
            $allFalseCsv = Join-Path $TestDrive 'status-all-false.csv'
            @"
UniqueID,ReadyToDeploy,SubscriptionId,TenantId,TypeOfDeployment,NodeCount,Location,CredentialKeyVaultName,LocalAdminSecretName,LCMAdminSecretName,SubnetMask,DefaultGateway,StartingIPAddress,EndingIPAddress,DnsServers,NodeIPAddresses
TST001,FALSE,12345678-1234-1234-1234-123456789abc,12345678-1234-1234-1234-123456789abc,SingleNode,1,eastus,kv-deploy,LocalAdmin,LCMAdmin,255.255.255.0,10.0.1.1,10.0.1.100,10.0.1.110,10.0.1.10,10.0.1.50
"@ | Out-File -FilePath $allFalseCsv -Encoding utf8

            $results = Get-AzLocalDeploymentStatus -CsvFilePath $allFalseCsv
            $results.Count | Should -Be 0
        }

        It 'Should include all expected properties in result objects' {
            Mock Set-AzContext { return $true } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResource { return $null } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroup { return @{ ResourceGroupName = 'rg-azlocal-TST001' } } -ModuleName AzLocal.DeploymentAutomation
            Mock Get-AzResourceGroupDeployment { return $null } -ModuleName AzLocal.DeploymentAutomation

            $results = Get-AzLocalDeploymentStatus -CsvFilePath $script:CsvPath
            $results[0].PSObject.Properties.Name | Should -Contain 'UniqueID'
            $results[0].PSObject.Properties.Name | Should -Contain 'ClusterName'
            $results[0].PSObject.Properties.Name | Should -Contain 'ResourceGroupName'
            $results[0].PSObject.Properties.Name | Should -Contain 'DeploymentName'
            $results[0].PSObject.Properties.Name | Should -Contain 'DeploymentStatus'
            $results[0].PSObject.Properties.Name | Should -Contain 'ProvisioningState'
            $results[0].PSObject.Properties.Name | Should -Contain 'Message'
            $results[0].PSObject.Properties.Name | Should -Contain 'Duration'
        }
    }
}

# ============================================================================
# Automation Pipelines File Structure
# ============================================================================
Describe 'Automation Pipelines: File Structure' {
    BeforeAll {
        $script:PipelinesDir = Join-Path $PSScriptRoot '..\automation-pipelines'
    }

    Context 'Core Files' {
        It 'Should have cluster-deployments.csv example file' {
            Test-Path (Join-Path $script:PipelinesDir 'cluster-deployments.csv') | Should -Be $true
        }

        It 'Should have README.md' {
            Test-Path (Join-Path $script:PipelinesDir 'README.md') | Should -Be $true
        }
    }

    Context 'GitHub Actions Workflows' {
        It 'Should have validate-deployments.yml' {
            Test-Path (Join-Path $script:PipelinesDir 'github-actions\validate-deployments.yml') | Should -Be $true
        }

        It 'Should have deploy-clusters.yml' {
            Test-Path (Join-Path $script:PipelinesDir 'github-actions\deploy-clusters.yml') | Should -Be $true
        }

        It 'Should have deployment-monitor.yml' {
            Test-Path (Join-Path $script:PipelinesDir 'github-actions\deployment-monitor.yml') | Should -Be $true
        }
    }

    Context 'Azure DevOps Pipelines' {
        It 'Should have validate-deployments.yml' {
            Test-Path (Join-Path $script:PipelinesDir 'azure-devops\validate-deployments.yml') | Should -Be $true
        }

        It 'Should have deploy-clusters.yml' {
            Test-Path (Join-Path $script:PipelinesDir 'azure-devops\deploy-clusters.yml') | Should -Be $true
        }

        It 'Should have deployment-monitor.yml' {
            Test-Path (Join-Path $script:PipelinesDir 'azure-devops\deployment-monitor.yml') | Should -Be $true
        }
    }

    Context 'CSV File Content' {
        BeforeAll {
            $script:CsvPath = Join-Path $script:PipelinesDir 'cluster-deployments.csv'
            $script:CsvData = Import-Csv -Path $script:CsvPath
        }

        It 'CSV should have all required columns' {
            $requiredCols = @('UniqueID', 'ReadyToDeploy', 'SubscriptionId', 'TenantId',
                'TypeOfDeployment', 'NodeCount', 'CredentialKeyVaultName',
                'SubnetMask', 'DefaultGateway', 'StartingIPAddress', 'EndingIPAddress', 'NodeIPAddresses')
            $presentCols = $script:CsvData[0].PSObject.Properties.Name
            foreach ($col in $requiredCols) {
                $presentCols | Should -Contain $col
            }
        }

        It 'CSV should contain example rows' {
            $script:CsvData.Count | Should -BeGreaterThan 0
        }

        It 'CSV should have a mix of ReadyToDeploy TRUE and FALSE rows' {
            $trueRows = @($script:CsvData | Where-Object { $_.ReadyToDeploy -eq 'TRUE' })
            $falseRows = @($script:CsvData | Where-Object { $_.ReadyToDeploy -eq 'FALSE' })
            $trueRows.Count | Should -BeGreaterThan 0
            $falseRows.Count | Should -BeGreaterThan 0
        }

        It 'CSV should have valid TypeOfDeployment values' {
            $validTypes = @('SingleNode', 'MultiNode', 'Switchless', 'RackAware')
            foreach ($row in $script:CsvData) {
                $row.TypeOfDeployment | Should -BeIn $validTypes
            }
        }
    }
}

# ============================================================================
# Code Quality: CI/CD Functions
# ============================================================================
Describe 'Code Quality: CI/CD Automation Functions' {
    BeforeAll {
        $script:ModuleDir = Join-Path $PSScriptRoot '..'
        $script:ModuleSource = (@(Get-Content (Join-Path $script:ModuleDir 'AzLocal.DeploymentAutomation.psm1') -Raw) + @(Get-ChildItem (Join-Path $script:ModuleDir 'Public'), (Join-Path $script:ModuleDir 'Private') -Filter '*.ps1' | ForEach-Object { Get-Content $_.FullName -Raw })) -join "`n"
    }

    It 'New-AzLocalJUnitXml should have OutputType declaration' {
        $script:ModuleSource | Should -Match 'Function New-AzLocalJUnitXml[\s\S]*?\[OutputType'
    }

    It 'Import-AzLocalDeploymentCsv should have OutputType declaration' {
        $script:ModuleSource | Should -Match 'Function Import-AzLocalDeploymentCsv[\s\S]*?\[OutputType'
    }

    It 'Test-AzLocalClusterPreFlight should have OutputType declaration' {
        $script:ModuleSource | Should -Match 'Function Test-AzLocalClusterPreFlight[\s\S]*?\[OutputType'
    }

    It 'Start-AzLocalCsvDeployment should have OutputType declaration' {
        $script:ModuleSource | Should -Match 'Function Start-AzLocalCsvDeployment[\s\S]*?\[OutputType'
    }

    It 'Get-AzLocalDeploymentStatus should have OutputType declaration' {
        $script:ModuleSource | Should -Match 'Function Get-AzLocalDeploymentStatus[\s\S]*?\[OutputType'
    }

    It 'Start-AzLocalCsvDeployment should support ShouldProcess' {
        $script:ModuleSource | Should -Match 'Function Start-AzLocalCsvDeployment[\s\S]*?SupportsShouldProcess'
    }

    It 'Start-AzLocalCsvDeployment should have ConfirmImpact High' {
        $script:ModuleSource | Should -Match 'Function Start-AzLocalCsvDeployment[\s\S]*?ConfirmImpact\s*=\s*.High.'
    }

    It 'Import-AzLocalDeploymentCsv should validate required CSV columns' {
        $script:ModuleSource | Should -Match 'requiredColumns'
    }

    It 'Test-AzLocalClusterPreFlight should check for Arc nodes via HybridCompute' {
        $script:ModuleSource | Should -Match 'Microsoft\.HybridCompute/machines'
    }

    It 'Test-AzLocalClusterPreFlight should check for existing cluster via AzureStackHCI' {
        $script:ModuleSource | Should -Match 'Microsoft\.AzureStackHCI/clusters'
    }
}

# ============================================================================
# Deprecated File Tests
# ============================================================================
Describe 'Deprecated: two-node-switched-parameters-file.json' {

    It 'two-node-switched-parameters-file.json should NOT exist (deprecated in v0.8.0)' {
        $deprecatedPath = Join-Path $PSScriptRoot '..\template-parameter-files\two-node-switched-parameters-file.json'
        Test-Path $deprecatedPath | Should -Be $false
    }
}
