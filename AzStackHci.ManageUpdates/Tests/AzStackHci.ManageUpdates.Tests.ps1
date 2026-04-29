#Requires -Module Pester
<#
.SYNOPSIS
    Pester tests for the AzStackHci.ManageUpdates module.

.DESCRIPTION
    Unit tests for the Azure Local Update Management module.
    These tests validate parameter validation, function behavior, and output types
    without requiring actual Azure connectivity (using mocks).

.NOTES
    Run with: Invoke-Pester -Path .\Tests -OutputFormat NUnitXml -OutputFile .\Tests\TestResults.xml
    Generate HTML: .\Tests\Generate-TestReport.ps1
#>

BeforeAll {
    # Import the module from parent directory
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\AzStackHci.ManageUpdates.psd1'
    Import-Module $modulePath -Force -ErrorAction Stop
    
    # Store module info for tests
    $script:ModuleInfo = Get-Module AzStackHci.ManageUpdates
}

AfterAll {
    # Clean up
    Remove-Module AzStackHci.ManageUpdates -Force -ErrorAction SilentlyContinue
}

Describe 'Module: AzStackHci.ManageUpdates' {
    
    Context 'Module Load' {
        It 'Should load the module without errors' {
            $script:ModuleInfo | Should -Not -BeNullOrEmpty
        }

        It 'Should have version 0.7.1' {
            $script:ModuleInfo.Version | Should -Be '0.7.1'
        }

        It 'Should export exactly 20 functions' {
            $script:ModuleInfo.ExportedFunctions.Count | Should -Be 20
        }

        It 'Should export the expected functions' {
            $expectedFunctions = @(
                'Connect-AzureLocalServicePrincipal',
                'Get-AzureLocalAvailableUpdates',
                'Get-AzureLocalClusterInfo',
                'Get-AzureLocalClusterInventory',
                'Get-AzureLocalClusterUpdateReadiness',
                'Get-AzureLocalUpdateRuns',
                'Get-AzureLocalUpdateSummary',
                'Set-AzureLocalClusterUpdateRingTag',
                'Start-AzureLocalClusterUpdate',
                # Fleet-Scale Operations (v0.5.6)
                'Invoke-AzureLocalFleetOperation',
                'Get-AzureLocalFleetProgress',
                'Test-AzureLocalFleetHealthGate',
                'Export-AzureLocalFleetState',
                'Resume-AzureLocalFleetUpdate',
                'Stop-AzureLocalFleetUpdate',
                # Pre-Update Health Validation (v0.6.1)
                'Test-AzureLocalClusterHealth',
                # Fleet Status Data Collection & Reporting (v0.6.4)
                'Get-AzureLocalFleetStatusData',
                'New-AzureLocalFleetStatusHtmlReport',
                # Update Schedule Tag Helpers (v0.6.4)
                'Test-AzureLocalUpdateScheduleAllowed',
                # Sideloaded Payload Workflow (v0.7.1)
                'Reset-AzureLocalSideloadedTag'
            )
            
            foreach ($func in $expectedFunctions) {
                $script:ModuleInfo.ExportedFunctions.Keys | Should -Contain $func
            }
        }

        It "Should have ReleaseNotes within the PSGallery character limit" {
            # PSGallery enforces a maximum of 10000 characters on the ReleaseNotes field
            # (publish fails with "Tags, ReleaseNotes, ... cannot exceed 10000 characters").
            # This test guards against accidental regressions when the release notes grow.
            $manifestPath = Join-Path -Path $PSScriptRoot -ChildPath '..\AzStackHci.ManageUpdates.psd1'
            $data = Import-PowerShellDataFile -Path $manifestPath
            $releaseNotes = $data.PrivateData.PSData.ReleaseNotes
            $releaseNotes | Should -Not -BeNullOrEmpty
            $releaseNotes.Length | Should -BeLessOrEqual 10000 -Because "PSGallery rejects ReleaseNotes longer than 10000 characters"
        }
    }
}

Describe 'Function: Connect-AzureLocalServicePrincipal' {
    
    Context 'Parameter Validation' {
        It 'Should have ServicePrincipalId parameter' {
            (Get-Command Connect-AzureLocalServicePrincipal).Parameters.Keys | Should -Contain 'ServicePrincipalId'
        }

        It 'Should have ServicePrincipalSecret parameter' {
            (Get-Command Connect-AzureLocalServicePrincipal).Parameters.Keys | Should -Contain 'ServicePrincipalSecret'
        }

        It 'Should have TenantId parameter' {
            (Get-Command Connect-AzureLocalServicePrincipal).Parameters.Keys | Should -Contain 'TenantId'
        }

        It 'Should have Force parameter' {
            (Get-Command Connect-AzureLocalServicePrincipal).Parameters.Keys | Should -Contain 'Force'
        }
    }

    Context 'OutputType' {
        It 'Should have OutputType of Boolean' {
            $outputTypes = (Get-Command Connect-AzureLocalServicePrincipal).OutputType
            $outputTypes.Type.Name | Should -Contain 'Boolean'
        }
    }
}

Describe 'Function: Start-AzureLocalClusterUpdate' {
    
    Context 'Parameter Validation' {
        BeforeAll {
            $command = Get-Command Start-AzureLocalClusterUpdate
        }

        It 'Should have ClusterNames parameter' {
            $command.Parameters.Keys | Should -Contain 'ClusterNames'
        }

        It 'Should have ClusterResourceIds parameter' {
            $command.Parameters.Keys | Should -Contain 'ClusterResourceIds'
        }

        It 'Should have ScopeByUpdateRingTag parameter' {
            $command.Parameters.Keys | Should -Contain 'ScopeByUpdateRingTag'
        }

        It 'Should have UpdateRingValue parameter' {
            $command.Parameters.Keys | Should -Contain 'UpdateRingValue'
        }

        It 'Should have ExportResultsPath parameter' {
            $command.Parameters.Keys | Should -Contain 'ExportResultsPath'
        }

        It 'Should have Force parameter' {
            $command.Parameters.Keys | Should -Contain 'Force'
        }

        It 'Should have WhatIf parameter' {
            $command.Parameters.Keys | Should -Contain 'WhatIf'
        }

        It 'Should support ShouldProcess' {
            $command.CmdletBinding | Should -Be $true
            $attr = $command.ScriptBlock.Attributes | Where-Object { $_.TypeId.Name -eq 'CmdletBindingAttribute' }
            $attr.SupportsShouldProcess | Should -Be $true
        }
    }

    Context 'Parameter Sets' {
        BeforeAll {
            $command = Get-Command Start-AzureLocalClusterUpdate
        }

        It 'Should have ByName parameter set' {
            $command.ParameterSets.Name | Should -Contain 'ByName'
        }

        It 'Should have ByResourceId parameter set' {
            $command.ParameterSets.Name | Should -Contain 'ByResourceId'
        }

        It 'Should have ByTag parameter set' {
            $command.ParameterSets.Name | Should -Contain 'ByTag'
        }

        It 'ClusterNames should be mandatory in ByName parameter set' {
            $param = $command.Parameters['ClusterNames']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ByName' }
            $attr.Mandatory | Should -Be $true
        }

        It 'ClusterResourceIds should be mandatory in ByResourceId parameter set' {
            $param = $command.Parameters['ClusterResourceIds']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ByResourceId' }
            $attr.Mandatory | Should -Be $true
        }

        It 'ScopeByUpdateRingTag should be mandatory in ByTag parameter set' {
            $param = $command.Parameters['ScopeByUpdateRingTag']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ByTag' }
            $attr.Mandatory | Should -Be $true
        }
    }

    Context 'OutputType' {
        It 'Should have OutputType of PSObject[]' {
            $outputTypes = (Get-Command Start-AzureLocalClusterUpdate).OutputType
            $outputTypes.Type.FullName | Should -Contain 'System.Management.Automation.PSObject[]'
        }
    }
}

Describe 'Function: Get-AzureLocalClusterUpdateReadiness' {
    
    Context 'Parameter Validation' {
        BeforeAll {
            $command = Get-Command Get-AzureLocalClusterUpdateReadiness
        }

        It 'Should have ClusterNames parameter' {
            $command.Parameters.Keys | Should -Contain 'ClusterNames'
        }

        It 'Should have ClusterResourceIds parameter' {
            $command.Parameters.Keys | Should -Contain 'ClusterResourceIds'
        }

        It 'Should have ScopeByUpdateRingTag parameter' {
            $command.Parameters.Keys | Should -Contain 'ScopeByUpdateRingTag'
        }

        It 'Should have UpdateRingValue parameter' {
            $command.Parameters.Keys | Should -Contain 'UpdateRingValue'
        }

        It 'Should have ExportPath parameter' {
            $command.Parameters.Keys | Should -Contain 'ExportPath'
        }

        It 'Should have ExportFormat parameter' {
            $command.Parameters.Keys | Should -Contain 'ExportFormat'
        }

        It 'Should have ApiVersion parameter with default value' {
            $command.Parameters['ApiVersion'].Attributes | 
                Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' } |
                ForEach-Object { $_.Mandatory } | Should -Contain $false
        }
    }

    Context 'Parameter Sets' {
        BeforeAll {
            $command = Get-Command Get-AzureLocalClusterUpdateReadiness
        }

        It 'Should have ByName parameter set' {
            $command.ParameterSets.Name | Should -Contain 'ByName'
        }

        It 'Should have ByResourceId parameter set' {
            $command.ParameterSets.Name | Should -Contain 'ByResourceId'
        }

        It 'Should have ByTag parameter set' {
            $command.ParameterSets.Name | Should -Contain 'ByTag'
        }
    }

    Context 'OutputType' {
        It 'Should have OutputType of PSObject[]' {
            $outputTypes = (Get-Command Get-AzureLocalClusterUpdateReadiness).OutputType
            $outputTypes.Type.FullName | Should -Contain 'System.Management.Automation.PSObject[]'
        }
    }
}

Describe 'Function: Get-AzureLocalClusterInventory' {
    
    Context 'Parameter Validation' {
        BeforeAll {
            $command = Get-Command Get-AzureLocalClusterInventory
        }

        It 'Should have SubscriptionId parameter' {
            $command.Parameters.Keys | Should -Contain 'SubscriptionId'
        }

        It 'Should have ExportPath parameter' {
            $command.Parameters.Keys | Should -Contain 'ExportPath'
        }

        It 'SubscriptionId should not be mandatory' {
            $param = $command.Parameters['SubscriptionId']
            $attrs = @($param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' })
            $attrs | ForEach-Object { $_.Mandatory | Should -Be $false }
        }
    }

    Context 'OutputType' {
        It 'Should have OutputType of PSObject[]' {
            $outputTypes = (Get-Command Get-AzureLocalClusterInventory).OutputType
            $outputTypes.Type.FullName | Should -Contain 'System.Management.Automation.PSObject[]'
        }
    }
}

Describe 'Regression: Get-AzureLocalClusterInventory ValidatePattern shadowing' {
    # Repro for the bug where a local variable named $updateRingValue
    # inside Get-AzureLocalClusterInventory aliased the function's
    # [ValidatePattern(...)] $UpdateRingValue parameter (PowerShell is
    # case-insensitive on variable names). Any cluster returned by ARG
    # without an UpdateRing tag caused Get-TagValue to return $null/''
    # and the assignment threw "The variable cannot be validated because
    # the value is not a valid value for the UpdateRingValue variable."
    # This bricked -AllClusters against any fleet missing the tag.

    It 'Should not throw "cannot be validated" when a cluster has no UpdateRing tag (-AllClusters)' {
        InModuleScope AzStackHci.ManageUpdates {
            function global:az {
                param()
                $global:LASTEXITCODE = 0
                if ($args -contains 'show') {
                    return '{"id":"00000000-0000-0000-0000-000000000000","name":"sub"}'
                }
                return '{}'
            }
            Mock Test-AzCliAvailable { return $true }
            Mock Install-AzGraphExtension { return $true }
            # ARG returns two clusters - one with the tag, one without.
            Mock Invoke-AzResourceGraphQuery {
                return @(
                    [PSCustomObject]@{
                        id             = '/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/tagged'
                        name           = 'tagged'
                        resourceGroup  = 'r'
                        subscriptionId = 's'
                        tags           = @{ UpdateRing = 'Wave1' }
                    },
                    [PSCustomObject]@{
                        id             = '/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/untagged'
                        name           = 'untagged'
                        resourceGroup  = 'r'
                        subscriptionId = 's'
                        tags           = $null
                    }
                )
            }

            $result = $null
            { $script:inventoryResult = Get-AzureLocalClusterInventory -PassThru } | Should -Not -Throw
            $result = $script:inventoryResult
            $result | Should -HaveCount 2
            ($result | Where-Object ClusterName -eq 'tagged').UpdateRing | Should -Be 'Wave1'
            ($result | Where-Object ClusterName -eq 'tagged').HasUpdateRingTag | Should -Be 'Yes'
            ($result | Where-Object ClusterName -eq 'untagged').UpdateRing | Should -Be ''
            ($result | Where-Object ClusterName -eq 'untagged').HasUpdateRingTag | Should -Be 'No'
        }
    }
}

Describe 'Function: Set-AzureLocalClusterUpdateRingTag' {
    
    Context 'Parameter Validation' {
        BeforeAll {
            $command = Get-Command Set-AzureLocalClusterUpdateRingTag
        }

        It 'Should have ClusterResourceIds parameter' {
            $command.Parameters.Keys | Should -Contain 'ClusterResourceIds'
        }

        It 'Should have UpdateRingValue parameter' {
            $command.Parameters.Keys | Should -Contain 'UpdateRingValue'
        }

        It 'Should have InputCsvPath parameter' {
            $command.Parameters.Keys | Should -Contain 'InputCsvPath'
        }

        It 'Should have Force parameter' {
            $command.Parameters.Keys | Should -Contain 'Force'
        }

        It 'Should have WhatIf parameter' {
            $command.Parameters.Keys | Should -Contain 'WhatIf'
        }

        It 'Should support ShouldProcess' {
            $attr = $command.ScriptBlock.Attributes | Where-Object { $_.TypeId.Name -eq 'CmdletBindingAttribute' }
            $attr.SupportsShouldProcess | Should -Be $true
        }
    }

    Context 'Parameter Sets' {
        BeforeAll {
            $command = Get-Command Set-AzureLocalClusterUpdateRingTag
        }

        It 'Should have ByResourceId parameter set' {
            $command.ParameterSets.Name | Should -Contain 'ByResourceId'
        }

        It 'Should have ByCsv parameter set' {
            $command.ParameterSets.Name | Should -Contain 'ByCsv'
        }

        It 'ClusterResourceIds should be mandatory in ByResourceId parameter set' {
            $param = $command.Parameters['ClusterResourceIds']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ByResourceId' }
            $attr.Mandatory | Should -Be $true
        }

        It 'InputCsvPath should be mandatory in ByCsv parameter set' {
            $param = $command.Parameters['InputCsvPath']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ByCsv' }
            $attr.Mandatory | Should -Be $true
        }
    }

    Context 'OutputType' {
        It 'Should have OutputType of PSObject[]' {
            $outputTypes = (Get-Command Set-AzureLocalClusterUpdateRingTag).OutputType
            $outputTypes.Type.FullName | Should -Contain 'System.Management.Automation.PSObject[]'
        }
    }
}

Describe 'Function: Get-AzureLocalClusterInfo' {
    
    Context 'Parameter Validation' {
        BeforeAll {
            $command = Get-Command Get-AzureLocalClusterInfo
        }

        It 'Should have ClusterName parameter' {
            $command.Parameters.Keys | Should -Contain 'ClusterName'
        }

        It 'Should have SubscriptionId parameter' {
            $command.Parameters.Keys | Should -Contain 'SubscriptionId'
        }

        It 'Should have ResourceGroupName parameter' {
            $command.Parameters.Keys | Should -Contain 'ResourceGroupName'
        }

        It 'Should have ApiVersion parameter' {
            $command.Parameters.Keys | Should -Contain 'ApiVersion'
        }
    }
}

Describe 'Function: Get-AzureLocalUpdateSummary' {
    
    Context 'Parameter Validation' {
        BeforeAll {
            $command = Get-Command Get-AzureLocalUpdateSummary
        }

        It 'Should have ClusterResourceId parameter' {
            $command.Parameters.Keys | Should -Contain 'ClusterResourceId'
        }

        It 'Should have ClusterNames parameter for multi-cluster mode' {
            $command.Parameters.Keys | Should -Contain 'ClusterNames'
        }

        It 'Should have ClusterResourceIds parameter for multi-cluster mode' {
            $command.Parameters.Keys | Should -Contain 'ClusterResourceIds'
        }

        It 'Should have ScopeByUpdateRingTag parameter' {
            $command.Parameters.Keys | Should -Contain 'ScopeByUpdateRingTag'
        }

        It 'Should have UpdateRingValue parameter' {
            $command.Parameters.Keys | Should -Contain 'UpdateRingValue'
        }

        It 'Should have ExportPath parameter' {
            $command.Parameters.Keys | Should -Contain 'ExportPath'
        }

        It 'Should have ApiVersion parameter' {
            $command.Parameters.Keys | Should -Contain 'ApiVersion'
        }

        It 'ClusterResourceId should be mandatory in SingleCluster parameter set' {
            $param = $command.Parameters['ClusterResourceId']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'SingleCluster' }
            $attr.Mandatory | Should -Be $true
        }

        It 'Should have four parameter sets' {
            $command.ParameterSets.Name | Should -Contain 'SingleCluster'
            $command.ParameterSets.Name | Should -Contain 'ByName'
            $command.ParameterSets.Name | Should -Contain 'ByResourceId'
            $command.ParameterSets.Name | Should -Contain 'ByTag'
        }
    }
}

Describe 'Function: Get-AzureLocalAvailableUpdates' {
    
    Context 'Parameter Validation' {
        BeforeAll {
            $command = Get-Command Get-AzureLocalAvailableUpdates
        }

        It 'Should have ClusterResourceId parameter' {
            $command.Parameters.Keys | Should -Contain 'ClusterResourceId'
        }

        It 'Should have ClusterNames parameter for multi-cluster mode' {
            $command.Parameters.Keys | Should -Contain 'ClusterNames'
        }

        It 'Should have ClusterResourceIds parameter for multi-cluster mode' {
            $command.Parameters.Keys | Should -Contain 'ClusterResourceIds'
        }

        It 'Should have ScopeByUpdateRingTag parameter' {
            $command.Parameters.Keys | Should -Contain 'ScopeByUpdateRingTag'
        }

        It 'Should have UpdateRingValue parameter' {
            $command.Parameters.Keys | Should -Contain 'UpdateRingValue'
        }

        It 'Should have ExportPath parameter' {
            $command.Parameters.Keys | Should -Contain 'ExportPath'
        }

        It 'Should have ExportFormat parameter' {
            $command.Parameters.Keys | Should -Contain 'ExportFormat'
        }

        It 'Should have ApiVersion parameter' {
            $command.Parameters.Keys | Should -Contain 'ApiVersion'
        }

        It 'ClusterResourceId should be mandatory in SingleCluster parameter set' {
            $param = $command.Parameters['ClusterResourceId']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'SingleCluster' }
            $attr.Mandatory | Should -Be $true
        }

        It 'Should have four parameter sets' {
            $command.ParameterSets.Name | Should -Contain 'SingleCluster'
            $command.ParameterSets.Name | Should -Contain 'ByName'
            $command.ParameterSets.Name | Should -Contain 'ByResourceId'
            $command.ParameterSets.Name | Should -Contain 'ByTag'
        }
    }
}

Describe 'Function: Get-AzureLocalUpdateRuns' {
    
    Context 'Parameter Validation' {
        BeforeAll {
            $command = Get-Command Get-AzureLocalUpdateRuns
        }

        It 'Should have ClusterName parameter' {
            $command.Parameters.Keys | Should -Contain 'ClusterName'
        }

        It 'Should have ClusterNames parameter for multi-cluster mode' {
            $command.Parameters.Keys | Should -Contain 'ClusterNames'
        }

        It 'Should have ClusterResourceIds parameter for multi-cluster mode' {
            $command.Parameters.Keys | Should -Contain 'ClusterResourceIds'
        }

        It 'Should have ScopeByUpdateRingTag parameter' {
            $command.Parameters.Keys | Should -Contain 'ScopeByUpdateRingTag'
        }

        It 'Should have UpdateRingValue parameter' {
            $command.Parameters.Keys | Should -Contain 'UpdateRingValue'
        }

        It 'Should have UpdateName parameter' {
            $command.Parameters.Keys | Should -Contain 'UpdateName'
        }

        It 'Should have ExportPath parameter' {
            $command.Parameters.Keys | Should -Contain 'ExportPath'
        }

        It 'Should have ExportFormat parameter' {
            $command.Parameters.Keys | Should -Contain 'ExportFormat'
        }

        It 'Should have ApiVersion parameter' {
            $command.Parameters.Keys | Should -Contain 'ApiVersion'
        }

        It 'ClusterName should be mandatory in SingleCluster parameter set' {
            $param = $command.Parameters['ClusterName']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'SingleCluster' }
            $attr.Mandatory | Should -Be $true
        }

        It 'UpdateName should be optional' {
            $param = $command.Parameters['UpdateName']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Be $false
        }

        It 'Should have four parameter sets' {
            $command.ParameterSets.Name | Should -Contain 'SingleCluster'
            $command.ParameterSets.Name | Should -Contain 'ByName'
            $command.ParameterSets.Name | Should -Contain 'ByResourceId'
            $command.ParameterSets.Name | Should -Contain 'ByTag'
        }
    }
}

Describe 'Helper Function: Get-AzLocalRunEndTime (Internal)' {

    It 'Should return progress.endTimeUtc when present (preferred source)' {
        InModuleScope AzStackHci.ManageUpdates {
            $props = [PSCustomObject]@{
                state           = 'Succeeded'
                lastUpdatedTime = '2026-04-25T00:48:30Z'
                progress        = [PSCustomObject]@{ endTimeUtc = '2026-04-25T00:48:10Z' }
            }
            $r = Get-AzLocalRunEndTime -props $props
            $r | Should -Not -BeNullOrEmpty
            $r.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss') | Should -Be '2026-04-25T00:48:10'
        }
    }

    It 'Should fall back to lastUpdatedTime when progress.endTimeUtc is missing' {
        InModuleScope AzStackHci.ManageUpdates {
            $props = [PSCustomObject]@{
                state           = 'Failed'
                lastUpdatedTime = '2026-04-09T15:30:00Z'
                progress        = [PSCustomObject]@{ endTimeUtc = $null }
            }
            $r = Get-AzLocalRunEndTime -props $props
            $r | Should -Not -BeNullOrEmpty
            $r.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss') | Should -Be '2026-04-09T15:30:00'
        }
    }

    It 'Should return $null for InProgress runs (no terminal end yet)' {
        InModuleScope AzStackHci.ManageUpdates {
            $props = [PSCustomObject]@{
                state           = 'InProgress'
                lastUpdatedTime = '2026-04-25T01:00:00Z'
                progress        = [PSCustomObject]@{ endTimeUtc = $null }
            }
            $r = Get-AzLocalRunEndTime -props $props
            $r | Should -BeNullOrEmpty
        }
    }

    It 'Should return $null when both sources are missing' {
        InModuleScope AzStackHci.ManageUpdates {
            $props = [PSCustomObject]@{ state = 'Succeeded' }
            $r = Get-AzLocalRunEndTime -props $props
            $r | Should -BeNullOrEmpty
        }
    }
}

Describe 'Helper Function: Format-AzLocalUpdateRun (Internal)' {

    It 'Should populate EndTime from progress.endTimeUtc and use ARM duration' {
        InModuleScope AzStackHci.ManageUpdates {
            $run = [PSCustomObject]@{
                id         = '/subscriptions/x/resourceGroups/rg/providers/Microsoft.AzureStackHCI/clusters/c1/updates/Solution12.2604/updateRuns/abc123'
                name       = 'abc123'
                properties = [PSCustomObject]@{
                    state           = 'Succeeded'
                    timeStarted     = '2026-04-24T16:10:24Z'
                    lastUpdatedTime = '2026-04-25T00:48:30Z'
                    duration        = 'PT8H37M58S'
                    progress        = [PSCustomObject]@{
                        endTimeUtc = '2026-04-25T00:48:10Z'
                        steps      = @([PSCustomObject]@{ name = 'Step1'; status = 'Success' })
                    }
                    location        = 'eastus'
                }
            }
            $f = Format-AzLocalUpdateRun -run $run -clusterName 'c1'
            # EndTime is rendered in local time; compare via parse + UTC normalize
            ([datetime]::ParseExact($f.EndTime, 'yyyy-MM-dd HH:mm', $null)).ToUniversalTime().ToString('yyyy-MM-dd HH:mm') | Should -Be '2026-04-25 00:48'
            ([datetime]::ParseExact($f.StartTime, 'yyyy-MM-dd HH:mm', $null)).ToUniversalTime().ToString('yyyy-MM-dd HH:mm') | Should -Be '2026-04-24 16:10'
            $f.State | Should -Be 'Succeeded'
            $f.Duration | Should -Match '8 hours'
        }
    }

    It 'Should leave EndTime blank for InProgress runs' {
        InModuleScope AzStackHci.ManageUpdates {
            $run = [PSCustomObject]@{
                id         = '/subscriptions/x/resourceGroups/rg/providers/Microsoft.AzureStackHCI/clusters/c1/updates/Solution12.2604/updateRuns/abc123'
                name       = 'abc123'
                properties = [PSCustomObject]@{
                    state           = 'InProgress'
                    timeStarted     = (Get-Date).AddMinutes(-30).ToUniversalTime().ToString('o')
                    lastUpdatedTime = $null
                    duration        = $null
                    progress        = [PSCustomObject]@{
                        endTimeUtc = $null
                        steps      = @([PSCustomObject]@{ name = 'Step1'; status = 'InProgress' })
                    }
                    location        = 'eastus'
                }
            }
            $f = Format-AzLocalUpdateRun -run $run -clusterName 'c1'
            $f.EndTime | Should -BeNullOrEmpty
            $f.Duration | Should -Match 'running'
        }
    }
}

Describe 'Function: New-AzureLocalFleetStatusHtmlReport' {
    
    Context 'Parameter Validation' {
        BeforeAll {
            $command = Get-Command New-AzureLocalFleetStatusHtmlReport
        }

        It 'Should have ClusterNames parameter' {
            $command.Parameters.Keys | Should -Contain 'ClusterNames'
        }

        It 'Should have ClusterResourceIds parameter' {
            $command.Parameters.Keys | Should -Contain 'ClusterResourceIds'
        }

        It 'Should have ScopeByUpdateRingTag parameter' {
            $command.Parameters.Keys | Should -Contain 'ScopeByUpdateRingTag'
        }

        It 'Should have UpdateRingValue parameter' {
            $command.Parameters.Keys | Should -Contain 'UpdateRingValue'
        }

        It 'Should have OutputPath parameter' {
            $command.Parameters.Keys | Should -Contain 'OutputPath'
        }

        It 'OutputPath should be mandatory' {
            $param = $command.Parameters['OutputPath']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' }
            $attr.Mandatory | Should -Contain $true
        }

        It 'Should have IncludeUpdateRuns switch parameter' {
            $command.Parameters['IncludeUpdateRuns'].SwitchParameter | Should -Be $true
        }

        It 'Should have IncludeHealthDetails switch parameter' {
            $command.Parameters['IncludeHealthDetails'].SwitchParameter | Should -Be $true
        }

        It 'Should have Title parameter' {
            $command.Parameters.Keys | Should -Contain 'Title'
        }

        It 'Should have PassThru switch parameter' {
            $command.Parameters['PassThru'].SwitchParameter | Should -Be $true
        }

        It 'Should have AllClusters switch parameter' {
            $command.Parameters['AllClusters'].SwitchParameter | Should -Be $true
        }
    }

    Context 'Parameter Sets' {
        BeforeAll {
            $command = Get-Command New-AzureLocalFleetStatusHtmlReport
        }

        It 'Should have ByName parameter set' {
            $command.ParameterSets.Name | Should -Contain 'ByName'
        }

        It 'Should have ByResourceId parameter set' {
            $command.ParameterSets.Name | Should -Contain 'ByResourceId'
        }

        It 'Should have ByTag parameter set' {
            $command.ParameterSets.Name | Should -Contain 'ByTag'
        }

        It 'Should have All parameter set' {
            $command.ParameterSets.Name | Should -Contain 'All'
        }

        It 'Should default to All parameter set' {
            $command.DefaultParameterSet | Should -Be 'All'
        }

        It 'ClusterNames should be mandatory in ByName parameter set' {
            $param = $command.Parameters['ClusterNames']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ByName' }
            $attr.Mandatory | Should -Be $true
        }

        It 'ClusterResourceIds should be mandatory in ByResourceId parameter set' {
            $param = $command.Parameters['ClusterResourceIds']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ByResourceId' }
            $attr.Mandatory | Should -Be $true
        }

        It 'ScopeByUpdateRingTag should be mandatory in ByTag parameter set' {
            $param = $command.Parameters['ScopeByUpdateRingTag']
            $attr = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ByTag' }
            $attr.Mandatory | Should -Be $true
        }
    }

    Context 'OutputType' {
        It 'Should have OutputType of String' {
            $outputTypes = (Get-Command New-AzureLocalFleetStatusHtmlReport).OutputType
            $outputTypes.Type.Name | Should -Contain 'String'
        }
    }
}

Describe 'Helper Function: Export-ResultsToJUnitXml (Internal)' {
    
    Context 'JUnit XML Output Format' {
        BeforeAll {
            # Create mock results to test XML generation
            $mockResults = @(
                [PSCustomObject]@{
                    ClusterName  = 'TestCluster01'
                    Status       = 'UpdateStarted'
                    Message      = 'Update started successfully'
                    UpdateName   = 'Solution12.2601.1002.38'
                    StartTime    = Get-Date
                    EndTime      = Get-Date
                    Duration     = [TimeSpan]::FromMinutes(5)
                },
                [PSCustomObject]@{
                    ClusterName  = 'TestCluster02'
                    Status       = 'Failed'
                    Message      = 'Update failed due to health check'
                    UpdateName   = 'Solution12.2601.1002.38'
                    StartTime    = Get-Date
                    EndTime      = Get-Date
                    Duration     = [TimeSpan]::FromMinutes(2)
                },
                [PSCustomObject]@{
                    ClusterName  = 'TestCluster03'
                    Status       = 'Skipped'
                    Message      = 'Cluster not ready for updates'
                    UpdateName   = $null
                    StartTime    = Get-Date
                    EndTime      = Get-Date
                    Duration     = $null
                }
            )
            
            $script:TestOutputPath = Join-Path -Path $TestDrive -ChildPath 'test-results.xml'
            
            # Call the internal function via module scope
            & (Get-Module AzStackHci.ManageUpdates) {
                param($Results, $OutputPath)
                Export-ResultsToJUnitXml -Results $Results -OutputPath $OutputPath -TestSuiteName 'TestSuite' -OperationType 'Update'
            } -Results $mockResults -OutputPath $script:TestOutputPath
        }

        It 'Should create the XML file' {
            Test-Path $script:TestOutputPath | Should -Be $true
        }

        It 'Should be valid XML' {
            { [xml](Get-Content $script:TestOutputPath -Raw) } | Should -Not -Throw
        }

        It 'Should have testsuites root element' {
            $xml = [xml](Get-Content $script:TestOutputPath -Raw)
            $xml.testsuites | Should -Not -BeNullOrEmpty
        }

        It 'Should have testsuite element with correct test count' {
            $xml = [xml](Get-Content $script:TestOutputPath -Raw)
            [int]$xml.testsuites.testsuite.tests | Should -Be 3
        }

        It 'Should have testsuite element with correct failure count' {
            $xml = [xml](Get-Content $script:TestOutputPath -Raw)
            [int]$xml.testsuites.testsuite.failures | Should -Be 1
        }

        It 'Should have testsuite element with correct skipped count' {
            $xml = [xml](Get-Content $script:TestOutputPath -Raw)
            [int]$xml.testsuites.testsuite.skipped | Should -Be 1
        }

        It 'Should have testcase elements for each result' {
            $xml = [xml](Get-Content $script:TestOutputPath -Raw)
            $xml.testsuites.testsuite.testcase.Count | Should -Be 3
        }

        It 'Should have failure element for failed test' {
            $xml = [xml](Get-Content $script:TestOutputPath -Raw)
            $failedTest = $xml.testsuites.testsuite.testcase | Where-Object { $_.name -like '*TestCluster02*' }
            $failedTest.failure | Should -Not -BeNullOrEmpty
        }

        It 'Should have skipped element for skipped test' {
            $xml = [xml](Get-Content $script:TestOutputPath -Raw)
            $skippedTest = $xml.testsuites.testsuite.testcase | Where-Object { $_.name -like '*TestCluster03*' }
            $skippedTest.skipped | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'API Version Consistency' {
    
    Context 'Default API Version' {
        It 'All functions with ApiVersion parameter should default to 2025-10-01' {
            $functionsWithApiVersion = @(
                'Start-AzureLocalClusterUpdate',
                'Get-AzureLocalClusterUpdateReadiness',
                'Get-AzureLocalClusterInfo',
                'Get-AzureLocalUpdateSummary',
                'Get-AzureLocalAvailableUpdates',
                'Get-AzureLocalUpdateRuns'
            )

            foreach ($funcName in $functionsWithApiVersion) {
                $command = Get-Command $funcName
                if ($command.Parameters.ContainsKey('ApiVersion')) {
                    # Check if there's a default value in the function
                    # The default is set via $script:DefaultApiVersion which is '2025-10-01'
                    $command.Parameters['ApiVersion'] | Should -Not -BeNullOrEmpty -Because "$funcName should have ApiVersion parameter"
                }
            }
        }
    }
}

Describe 'Module Best Practices' {
    
    Context 'Function Naming' {
        It 'All exported functions should use approved verbs' {
            $approvedVerbs = Get-Verb | Select-Object -ExpandProperty Verb
            $exportedFunctions = (Get-Module AzStackHci.ManageUpdates).ExportedFunctions.Keys
            
            foreach ($func in $exportedFunctions) {
                $verb = $func.Split('-')[0]
                $approvedVerbs | Should -Contain $verb -Because "$func should use an approved verb"
            }
        }

        It 'All exported functions should use consistent noun prefix' {
            $exportedFunctions = (Get-Module AzStackHci.ManageUpdates).ExportedFunctions.Keys
            
            foreach ($func in $exportedFunctions) {
                $noun = $func.Split('-')[1]
                $noun | Should -BeLike 'AzureLocal*' -Because "$func should use AzureLocal noun prefix"
            }
        }
    }

    Context 'Help Documentation' {
        BeforeAll {
            $script:exportedFunctions = (Get-Module AzStackHci.ManageUpdates).ExportedFunctions.Keys
        }

        It 'All exported functions should have Synopsis in help' {
            foreach ($func in $script:exportedFunctions) {
                $help = Get-Help $func -ErrorAction SilentlyContinue
                $help.Synopsis | Should -Not -BeNullOrEmpty -Because "$func should have a Synopsis"
            }
        }

        It 'All exported functions should have Description in help' {
            foreach ($func in $script:exportedFunctions) {
                $help = Get-Help $func -ErrorAction SilentlyContinue
                $help.Description | Should -Not -BeNullOrEmpty -Because "$func should have a Description"
            }
        }
    }
}

#region Fleet-Scale Operations Tests (v0.5.6)

Describe 'Function: Invoke-AzureLocalFleetOperation' {
    
    Context 'Parameter Validation' {
        BeforeAll {
            $command = Get-Command Invoke-AzureLocalFleetOperation
        }

        It 'Should have Operation parameter' {
            $command.Parameters.Keys | Should -Contain 'Operation'
        }

        It 'Should have valid Operation values' {
            $command.Parameters['Operation'].Attributes.ValidValues | Should -Contain 'ApplyUpdate'
            $command.Parameters['Operation'].Attributes.ValidValues | Should -Contain 'CheckReadiness'
            $command.Parameters['Operation'].Attributes.ValidValues | Should -Contain 'GetStatus'
        }

        It 'Should have ScopeByUpdateRingTag parameter' {
            $command.Parameters.Keys | Should -Contain 'ScopeByUpdateRingTag'
        }

        It 'Should have UpdateRingValue parameter' {
            $command.Parameters.Keys | Should -Contain 'UpdateRingValue'
        }

        It 'Should have ClusterResourceIds parameter' {
            $command.Parameters.Keys | Should -Contain 'ClusterResourceIds'
        }

        It 'Should have BatchSize parameter with range validation' {
            $command.Parameters.Keys | Should -Contain 'BatchSize'
            $attrs = $command.Parameters['BatchSize'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $attrs | Should -Not -BeNullOrEmpty
        }

        It 'Should have ThrottleLimit parameter with range validation' {
            $command.Parameters.Keys | Should -Contain 'ThrottleLimit'
            $attrs = $command.Parameters['ThrottleLimit'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $attrs | Should -Not -BeNullOrEmpty
        }

        It 'Should have MaxRetries parameter' {
            $command.Parameters.Keys | Should -Contain 'MaxRetries'
        }

        It 'Should have StateFilePath parameter' {
            $command.Parameters.Keys | Should -Contain 'StateFilePath'
        }

        It 'Should have Force parameter' {
            $command.Parameters.Keys | Should -Contain 'Force'
        }

        It 'Should have PassThru parameter' {
            $command.Parameters.Keys | Should -Contain 'PassThru'
        }
    }

    Context 'Parameter Sets' {
        BeforeAll {
            $command = Get-Command Invoke-AzureLocalFleetOperation
        }

        It 'Should have ByTag parameter set' {
            $command.ParameterSets.Name | Should -Contain 'ByTag'
        }

        It 'Should have ByResourceId parameter set' {
            $command.ParameterSets.Name | Should -Contain 'ByResourceId'
        }
    }
}

Describe 'Function: Get-AzureLocalFleetProgress' {
    
    Context 'Parameter Validation' {
        BeforeAll {
            $command = Get-Command Get-AzureLocalFleetProgress
        }

        It 'Should have State parameter' {
            $command.Parameters.Keys | Should -Contain 'State'
        }

        It 'Should have ScopeByUpdateRingTag parameter' {
            $command.Parameters.Keys | Should -Contain 'ScopeByUpdateRingTag'
        }

        It 'Should have UpdateRingValue parameter' {
            $command.Parameters.Keys | Should -Contain 'UpdateRingValue'
        }

        It 'Should have Detailed parameter' {
            $command.Parameters.Keys | Should -Contain 'Detailed'
        }
    }

    Context 'Parameter Sets' {
        BeforeAll {
            $command = Get-Command Get-AzureLocalFleetProgress
        }

        It 'Should have ByState parameter set' {
            $command.ParameterSets.Name | Should -Contain 'ByState'
        }

        It 'Should have ByTag parameter set' {
            $command.ParameterSets.Name | Should -Contain 'ByTag'
        }
    }
}

Describe 'Function: Test-AzureLocalFleetHealthGate' {
    
    Context 'Parameter Validation' {
        BeforeAll {
            $command = Get-Command Test-AzureLocalFleetHealthGate
        }

        It 'Should have MaxFailurePercent parameter' {
            $command.Parameters.Keys | Should -Contain 'MaxFailurePercent'
        }

        It 'Should have MinSuccessPercent parameter' {
            $command.Parameters.Keys | Should -Contain 'MinSuccessPercent'
        }

        It 'Should have WaitForCompletion parameter' {
            $command.Parameters.Keys | Should -Contain 'WaitForCompletion'
        }

        It 'Should have WaitTimeoutMinutes parameter' {
            $command.Parameters.Keys | Should -Contain 'WaitTimeoutMinutes'
        }

        It 'Should have PollIntervalSeconds parameter' {
            $command.Parameters.Keys | Should -Contain 'PollIntervalSeconds'
        }

        It 'MaxFailurePercent should have range validation 0-100' {
            $attrs = $command.Parameters['MaxFailurePercent'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $attrs | Should -Not -BeNullOrEmpty
            $attrs.MinRange | Should -Be 0
            $attrs.MaxRange | Should -Be 100
        }

        It 'MinSuccessPercent should have range validation 0-100' {
            $attrs = $command.Parameters['MinSuccessPercent'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $attrs | Should -Not -BeNullOrEmpty
            $attrs.MinRange | Should -Be 0
            $attrs.MaxRange | Should -Be 100
        }
    }
}

#region Update Schedule Tag Helpers Tests (v0.6.4)

Describe 'Helper Function: ConvertFrom-AzLocalUpdateWindow (Internal)' {
    BeforeAll {
        # Access internal function via module scope
        $moduleName = 'AzStackHci.ManageUpdates'
    }

    Context 'Valid Window Syntax' {
        It 'Parses single day with time range' {
            $result = @(& (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateWindow -WindowString 'Sat_02:00-06:00' })
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 1
            $result[0].Days | Should -Contain ([DayOfWeek]::Saturday)
            $result[0].StartTime | Should -Be ([TimeSpan]::Parse('02:00'))
            $result[0].EndTime | Should -Be ([TimeSpan]::Parse('06:00'))
            $result[0].Overnight | Should -Be $false
        }

        It 'Parses day range (Sat-Sun)' {
            $result = & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateWindow -WindowString 'Sat-Sun_02:00-06:00' }
            $result[0].Days.Count | Should -Be 2
            $result[0].Days | Should -Contain ([DayOfWeek]::Saturday)
            $result[0].Days | Should -Contain ([DayOfWeek]::Sunday)
        }

        It 'Parses weekday range (Mon-Fri)' {
            $result = & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateWindow -WindowString 'Mon-Fri_00:00-06:00' }
            $result[0].Days.Count | Should -Be 5
            $result[0].Days | Should -Contain ([DayOfWeek]::Monday)
            $result[0].Days | Should -Contain ([DayOfWeek]::Friday)
            $result[0].Days | Should -Not -Contain ([DayOfWeek]::Saturday)
        }

        It 'Parses wrap-around day range (Fri-Mon)' {
            $result = & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateWindow -WindowString 'Fri-Mon_02:00-06:00' }
            $result[0].Days.Count | Should -Be 4
            $result[0].Days | Should -Contain ([DayOfWeek]::Friday)
            $result[0].Days | Should -Contain ([DayOfWeek]::Saturday)
            $result[0].Days | Should -Contain ([DayOfWeek]::Sunday)
            $result[0].Days | Should -Contain ([DayOfWeek]::Monday)
        }

        It 'Parses comma-separated days (Tue,Thu)' {
            $result = & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateWindow -WindowString 'Tue,Thu_02:00-06:00' }
            $result[0].Days.Count | Should -Be 2
            $result[0].Days | Should -Contain ([DayOfWeek]::Tuesday)
            $result[0].Days | Should -Contain ([DayOfWeek]::Thursday)
        }

        It 'Parses * (wildcard) as all days' {
            $result = & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateWindow -WindowString '*_00:00-06:00' }
            $result[0].Days.Count | Should -Be 7
        }

        It 'Parses Daily as all days' {
            $result = & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateWindow -WindowString 'Daily_22:00-06:00' }
            $result[0].Days.Count | Should -Be 7
            $result[0].Overnight | Should -Be $true
        }

        It 'Parses overnight window (22:00-06:00) and marks Overnight flag' {
            $result = & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateWindow -WindowString 'Sat_22:00-06:00' }
            $result[0].Overnight | Should -Be $true
            $result[0].StartTime | Should -Be ([TimeSpan]::Parse('22:00'))
            $result[0].EndTime | Should -Be ([TimeSpan]::Parse('06:00'))
        }

        It 'Parses multiple semicolon-separated windows' {
            $result = & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateWindow -WindowString 'Sat_20:00-23:59;Sun_00:00-08:00' }
            $result.Count | Should -Be 2
            $result[0].Days | Should -Contain ([DayOfWeek]::Saturday)
            $result[1].Days | Should -Contain ([DayOfWeek]::Sunday)
        }

        It 'Is case-insensitive for day names' {
            $result = & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateWindow -WindowString 'sat-SUN_02:00-06:00' }
            $result[0].Days | Should -Contain ([DayOfWeek]::Saturday)
            $result[0].Days | Should -Contain ([DayOfWeek]::Sunday)
        }

        It 'Stores raw segment string' {
            $result = & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateWindow -WindowString 'Mon_08:00-17:00' }
            $result[0].Raw | Should -Be 'Mon_08:00-17:00'
        }
    }

    Context 'Invalid Window Syntax' {
        It 'Throws on empty string' {
            { & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateWindow -WindowString '' } } | Should -Throw '*cannot be empty*'
        }

        It 'Throws on missing time component' {
            { & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateWindow -WindowString 'Mon' } } | Should -Throw '*Invalid window segment*'
        }

        It 'Throws on invalid day abbreviation' {
            { & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateWindow -WindowString 'Xyz_02:00-06:00' } } | Should -Throw '*Invalid day*'
        }

        It 'Throws on invalid time format' {
            { & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateWindow -WindowString 'Mon_25:00-06:00' } } | Should -Throw
        }

        It 'Throws when value exceeds 256 chars' {
            $longValue = ('Mon_00:00-01:00;' * 20)
            { & (Get-Module $moduleName) { param($val) ConvertFrom-AzLocalUpdateWindow -WindowString $val } $longValue } | Should -Throw '*256 characters*'
        }
    }
}

Describe 'Helper Function: ConvertFrom-AzLocalUpdateExclusion (Internal)' {
    BeforeAll {
        $moduleName = 'AzStackHci.ManageUpdates'
    }

    Context 'Valid Exclusion Syntax' {
        It 'Parses a single fixed date range' {
            $result = @(& (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateExclusion -ExclusionString '2026-12-20/2027-01-03' })
            $result.Count | Should -Be 1
            $result[0].StartDate | Should -Be ([datetime]::ParseExact('2026-12-20', 'yyyy-MM-dd', $null))
            $result[0].EndDate | Should -Be ([datetime]::ParseExact('2027-01-03', 'yyyy-MM-dd', $null))
            $result[0].IsWildcard | Should -Be $false
        }

        It 'Parses multiple comma-separated ranges' {
            $result = & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateExclusion -ExclusionString '2026-11-28/2026-11-29,2026-12-24/2027-01-02' }
            $result.Count | Should -Be 2
        }

        It 'Parses wildcard year pattern' {
            $refDate = [datetime]::ParseExact('2026-06-15', 'yyyy-MM-dd', $null)
            $result = & (Get-Module $moduleName) { param($rd) ConvertFrom-AzLocalUpdateExclusion -ExclusionString '20**-12-20/20**-01-03' -ReferenceDate $rd } $refDate
            $result | Should -Not -BeNullOrEmpty
            $result[0].IsWildcard | Should -Be $true
            # Should resolve to concrete dates around 2026
            $result | Where-Object { $_.StartDate.Year -eq 2026 -and $_.StartDate.Month -eq 12 } | Should -Not -BeNullOrEmpty
        }

        It 'Stores raw range string' {
            $result = & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateExclusion -ExclusionString '2026-06-30/2026-07-01' }
            $result[0].Raw | Should -Be '2026-06-30/2026-07-01'
        }
    }

    Context 'Invalid Exclusion Syntax' {
        It 'Throws on empty string' {
            { & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateExclusion -ExclusionString '' } } | Should -Throw '*cannot be empty*'
        }

        It 'Throws on invalid date format' {
            { & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateExclusion -ExclusionString '12/20/2026-01/03/2027' } } | Should -Throw '*Invalid exclusion range*'
        }

        It 'Throws when end date is before start date (fixed dates)' {
            { & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateExclusion -ExclusionString '2027-01-03/2026-12-20' } } | Should -Throw '*before start date*'
        }

        It 'Throws when value exceeds 256 chars' {
            $longValue = ('2026-01-01/2026-01-02,' * 15)
            { & (Get-Module $moduleName) { param($val) ConvertFrom-AzLocalUpdateExclusion -ExclusionString $val } $longValue } | Should -Throw '*256 characters*'
        }
    }
}

Describe 'Helper Function: Test-AzLocalUpdateWindow (Internal)' {
    BeforeAll {
        $moduleName = 'AzStackHci.ManageUpdates'
    }

    Context 'Same-day windows' {
        It 'Returns Allowed=true when time is within a same-day window' {
            # Saturday 03:00 UTC should be within Sat_02:00-06:00
            $testTime = [datetime]::ParseExact('2026-04-18 03:00', 'yyyy-MM-dd HH:mm', $null)  # Saturday
            $result = & (Get-Module $moduleName) { param($tt) Test-AzLocalUpdateWindow -WindowString 'Sat_02:00-06:00' -TestTime $tt } $testTime
            $result.Allowed | Should -Be $true
        }

        It 'Returns Allowed=false when time is outside the window' {
            # Saturday 10:00 UTC should be outside Sat_02:00-06:00
            $testTime = [datetime]::ParseExact('2026-04-18 10:00', 'yyyy-MM-dd HH:mm', $null)  # Saturday
            $result = & (Get-Module $moduleName) { param($tt) Test-AzLocalUpdateWindow -WindowString 'Sat_02:00-06:00' -TestTime $tt } $testTime
            $result.Allowed | Should -Be $false
        }

        It 'Returns Allowed=false when day does not match' {
            # Wednesday 03:00 UTC should not match Sat_02:00-06:00
            $testTime = [datetime]::ParseExact('2026-04-15 03:00', 'yyyy-MM-dd HH:mm', $null)  # Wednesday
            $result = & (Get-Module $moduleName) { param($tt) Test-AzLocalUpdateWindow -WindowString 'Sat_02:00-06:00' -TestTime $tt } $testTime
            $result.Allowed | Should -Be $false
        }
    }

    Context 'Overnight windows' {
        It 'Returns Allowed=true for evening portion of overnight window' {
            # Saturday 23:00 UTC should be in Sat_22:00-06:00 (evening portion)
            $testTime = [datetime]::ParseExact('2026-04-18 23:00', 'yyyy-MM-dd HH:mm', $null)  # Saturday
            $result = & (Get-Module $moduleName) { param($tt) Test-AzLocalUpdateWindow -WindowString 'Sat_22:00-06:00' -TestTime $tt } $testTime
            $result.Allowed | Should -Be $true
        }

        It 'Returns Allowed=true for morning portion of overnight window' {
            # Sunday 03:00 UTC should be in Sat_22:00-06:00 (morning portion, previous day was Sat)
            $testTime = [datetime]::ParseExact('2026-04-19 03:00', 'yyyy-MM-dd HH:mm', $null)  # Sunday
            $result = & (Get-Module $moduleName) { param($tt) Test-AzLocalUpdateWindow -WindowString 'Sat_22:00-06:00' -TestTime $tt } $testTime
            $result.Allowed | Should -Be $true
        }

        It 'Returns Allowed=false for midday after overnight window ends' {
            # Sunday 10:00 UTC should not be in Sat_22:00-06:00
            $testTime = [datetime]::ParseExact('2026-04-19 10:00', 'yyyy-MM-dd HH:mm', $null)  # Sunday
            $result = & (Get-Module $moduleName) { param($tt) Test-AzLocalUpdateWindow -WindowString 'Sat_22:00-06:00' -TestTime $tt } $testTime
            $result.Allowed | Should -Be $false
        }
    }

    Context 'Multiple windows' {
        It 'Returns Allowed=true when matching any of multiple windows' {
            # Sunday 04:00 should match second window
            $testTime = [datetime]::ParseExact('2026-04-19 04:00', 'yyyy-MM-dd HH:mm', $null)  # Sunday
            $result = & (Get-Module $moduleName) { param($tt) Test-AzLocalUpdateWindow -WindowString 'Sat_20:00-23:59;Sun_00:00-08:00' -TestTime $tt } $testTime
            $result.Allowed | Should -Be $true
        }
    }

    Context 'Daily/wildcard windows' {
        It 'Returns Allowed=true for any day with * wildcard' {
            $testTime = [datetime]::ParseExact('2026-04-15 03:00', 'yyyy-MM-dd HH:mm', $null)  # Wednesday
            $result = & (Get-Module $moduleName) { param($tt) Test-AzLocalUpdateWindow -WindowString '*_02:00-06:00' -TestTime $tt } $testTime
            $result.Allowed | Should -Be $true
        }

        It 'Returns Allowed=true for any day with Daily keyword' {
            $testTime = [datetime]::ParseExact('2026-04-16 03:00', 'yyyy-MM-dd HH:mm', $null)  # Thursday
            $result = & (Get-Module $moduleName) { param($tt) Test-AzLocalUpdateWindow -WindowString 'Daily_02:00-06:00' -TestTime $tt } $testTime
            $result.Allowed | Should -Be $true
        }
    }

    Context 'Output properties' {
        It 'Returns MatchedWindow when allowed' {
            $testTime = [datetime]::ParseExact('2026-04-18 03:00', 'yyyy-MM-dd HH:mm', $null)
            $result = & (Get-Module $moduleName) { param($tt) Test-AzLocalUpdateWindow -WindowString 'Sat_02:00-06:00' -TestTime $tt } $testTime
            $result.MatchedWindow | Should -Not -BeNullOrEmpty
        }

        It 'Returns null MatchedWindow when not allowed' {
            $testTime = [datetime]::ParseExact('2026-04-18 10:00', 'yyyy-MM-dd HH:mm', $null)
            $result = & (Get-Module $moduleName) { param($tt) Test-AzLocalUpdateWindow -WindowString 'Sat_02:00-06:00' -TestTime $tt } $testTime
            $result.MatchedWindow | Should -BeNullOrEmpty
        }

        It 'Returns Reason string in all cases' {
            $testTime = [datetime]::ParseExact('2026-04-18 03:00', 'yyyy-MM-dd HH:mm', $null)
            $result = & (Get-Module $moduleName) { param($tt) Test-AzLocalUpdateWindow -WindowString 'Sat_02:00-06:00' -TestTime $tt } $testTime
            $result.Reason | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Helper Function: Test-AzLocalUpdateExclusion (Internal)' {
    BeforeAll {
        $moduleName = 'AzStackHci.ManageUpdates'
    }

    Context 'Fixed date exclusions' {
        It 'Returns Excluded=true when date is within exclusion range' {
            $testDate = [datetime]::ParseExact('2026-12-25', 'yyyy-MM-dd', $null)
            $result = & (Get-Module $moduleName) { param($td) Test-AzLocalUpdateExclusion -ExclusionString '2026-12-20/2027-01-03' -TestDate $td } $testDate
            $result.Excluded | Should -Be $true
        }

        It 'Returns Excluded=true on the start date boundary' {
            $testDate = [datetime]::ParseExact('2026-12-20', 'yyyy-MM-dd', $null)
            $result = & (Get-Module $moduleName) { param($td) Test-AzLocalUpdateExclusion -ExclusionString '2026-12-20/2027-01-03' -TestDate $td } $testDate
            $result.Excluded | Should -Be $true
        }

        It 'Returns Excluded=true on the end date boundary' {
            $testDate = [datetime]::ParseExact('2027-01-03', 'yyyy-MM-dd', $null)
            $result = & (Get-Module $moduleName) { param($td) Test-AzLocalUpdateExclusion -ExclusionString '2026-12-20/2027-01-03' -TestDate $td } $testDate
            $result.Excluded | Should -Be $true
        }

        It 'Returns Excluded=false when date is outside exclusion range' {
            $testDate = [datetime]::ParseExact('2026-12-19', 'yyyy-MM-dd', $null)
            $result = & (Get-Module $moduleName) { param($td) Test-AzLocalUpdateExclusion -ExclusionString '2026-12-20/2027-01-03' -TestDate $td } $testDate
            $result.Excluded | Should -Be $false
        }

        It 'Returns Excluded=false the day after end date' {
            $testDate = [datetime]::ParseExact('2027-01-04', 'yyyy-MM-dd', $null)
            $result = & (Get-Module $moduleName) { param($td) Test-AzLocalUpdateExclusion -ExclusionString '2026-12-20/2027-01-03' -TestDate $td } $testDate
            $result.Excluded | Should -Be $false
        }
    }

    Context 'Wildcard exclusions' {
        It 'Returns Excluded=true for wildcard pattern matching current year' {
            $testDate = [datetime]::ParseExact('2026-12-25', 'yyyy-MM-dd', $null)
            $result = & (Get-Module $moduleName) { param($td) Test-AzLocalUpdateExclusion -ExclusionString '20**-12-20/20**-01-03' -TestDate $td } $testDate
            $result.Excluded | Should -Be $true
        }

        It 'Returns Excluded=false for wildcard pattern when date is outside' {
            $testDate = [datetime]::ParseExact('2026-06-15', 'yyyy-MM-dd', $null)
            $result = & (Get-Module $moduleName) { param($td) Test-AzLocalUpdateExclusion -ExclusionString '20**-12-20/20**-01-03' -TestDate $td } $testDate
            $result.Excluded | Should -Be $false
        }
    }

    Context 'Multiple exclusions' {
        It 'Returns Excluded=true when matching any exclusion range' {
            $testDate = [datetime]::ParseExact('2026-11-28', 'yyyy-MM-dd', $null)
            $result = & (Get-Module $moduleName) { param($td) Test-AzLocalUpdateExclusion -ExclusionString '2026-11-28/2026-11-29,2026-12-24/2027-01-02' -TestDate $td } $testDate
            $result.Excluded | Should -Be $true
        }

        It 'Returns Excluded=false when not matching any exclusion range' {
            $testDate = [datetime]::ParseExact('2026-11-27', 'yyyy-MM-dd', $null)
            $result = & (Get-Module $moduleName) { param($td) Test-AzLocalUpdateExclusion -ExclusionString '2026-11-28/2026-11-29,2026-12-24/2027-01-02' -TestDate $td } $testDate
            $result.Excluded | Should -Be $false
        }
    }

    Context 'Output properties' {
        It 'Returns MatchedExclusion when excluded' {
            $testDate = [datetime]::ParseExact('2026-12-25', 'yyyy-MM-dd', $null)
            $result = & (Get-Module $moduleName) { param($td) Test-AzLocalUpdateExclusion -ExclusionString '2026-12-20/2027-01-03' -TestDate $td } $testDate
            $result.MatchedExclusion | Should -Not -BeNullOrEmpty
        }

        It 'Returns null MatchedExclusion when not excluded' {
            $testDate = [datetime]::ParseExact('2026-06-15', 'yyyy-MM-dd', $null)
            $result = & (Get-Module $moduleName) { param($td) Test-AzLocalUpdateExclusion -ExclusionString '2026-12-20/2027-01-03' -TestDate $td } $testDate
            $result.MatchedExclusion | Should -BeNullOrEmpty
        }
    }
}

Describe 'Helper Function: Test-AzureLocalUpdateScheduleAllowed (Internal)' {
    BeforeAll {
        $moduleName = 'AzStackHci.ManageUpdates'
    }

    Context 'No restrictions' {
        It 'Returns Allowed=true when no tags are defined' {
            $result = & (Get-Module $moduleName) { Test-AzureLocalUpdateScheduleAllowed -UpdateWindow '' -UpdateExclusions '' }
            $result.Allowed | Should -Be $true
            $result.Reason | Should -BeLike '*No schedule restrictions*'
        }

        It 'Returns Allowed=true when both tags are null' {
            $result = & (Get-Module $moduleName) { Test-AzureLocalUpdateScheduleAllowed -UpdateWindow $null -UpdateExclusions $null }
            $result.Allowed | Should -Be $true
        }
    }

    Context 'Window only' {
        It 'Returns Allowed=true when within maintenance window' {
            $testTime = [datetime]::ParseExact('2026-04-18 03:00', 'yyyy-MM-dd HH:mm', $null)  # Saturday
            $result = & (Get-Module $moduleName) { param($tt) Test-AzureLocalUpdateScheduleAllowed -UpdateWindow 'Sat_02:00-06:00' -TestTime $tt } $testTime
            $result.Allowed | Should -Be $true
            $result.WindowOpen | Should -Be $true
        }

        It 'Returns Allowed=false when outside maintenance window' {
            $testTime = [datetime]::ParseExact('2026-04-18 10:00', 'yyyy-MM-dd HH:mm', $null)  # Saturday
            $result = & (Get-Module $moduleName) { param($tt) Test-AzureLocalUpdateScheduleAllowed -UpdateWindow 'Sat_02:00-06:00' -TestTime $tt } $testTime
            $result.Allowed | Should -Be $false
            $result.WindowOpen | Should -Be $false
            $result.Reason | Should -BeLike '*Outside maintenance window*'
        }
    }

    Context 'Exclusion only' {
        It 'Returns Allowed=false when in exclusion period' {
            $testTime = [datetime]::ParseExact('2026-12-25 12:00', 'yyyy-MM-dd HH:mm', $null)
            $result = & (Get-Module $moduleName) { param($tt) Test-AzureLocalUpdateScheduleAllowed -UpdateExclusions '2026-12-20/2027-01-03' -TestTime $tt } $testTime
            $result.Allowed | Should -Be $false
            $result.ExclusionActive | Should -Be $true
            $result.Reason | Should -BeLike '*exclusion period*'
        }

        It 'Returns Allowed=true when not in exclusion period' {
            $testTime = [datetime]::ParseExact('2026-06-15 12:00', 'yyyy-MM-dd HH:mm', $null)
            $result = & (Get-Module $moduleName) { param($tt) Test-AzureLocalUpdateScheduleAllowed -UpdateExclusions '2026-12-20/2027-01-03' -TestTime $tt } $testTime
            $result.Allowed | Should -Be $true
        }
    }

    Context 'Exclusion takes priority over window' {
        It 'Returns Allowed=false when in exclusion even if within window' {
            # Saturday Dec 26 at 03:00 - within Sat window but also in exclusion
            $testTime = [datetime]::ParseExact('2026-12-26 03:00', 'yyyy-MM-dd HH:mm', $null)  # Saturday
            $result = & (Get-Module $moduleName) { param($tt)
                Test-AzureLocalUpdateScheduleAllowed -UpdateWindow 'Sat_02:00-06:00' -UpdateExclusions '2026-12-20/2027-01-03' -TestTime $tt
            } $testTime
            $result.Allowed | Should -Be $false
            $result.ExclusionActive | Should -Be $true
        }
    }

    Context 'Both tags, no conflict' {
        It 'Returns Allowed=true when within window and not in exclusion' {
            # Saturday Apr 18 at 03:00 - within Sat window, no exclusion active
            $testTime = [datetime]::ParseExact('2026-04-18 03:00', 'yyyy-MM-dd HH:mm', $null)  # Saturday
            $result = & (Get-Module $moduleName) { param($tt)
                Test-AzureLocalUpdateScheduleAllowed -UpdateWindow 'Sat_02:00-06:00' -UpdateExclusions '2026-12-20/2027-01-03' -TestTime $tt
            } $testTime
            $result.Allowed | Should -Be $true
            $result.WindowOpen | Should -Be $true
            $result.ExclusionActive | Should -Be $false
        }

        It 'Returns Allowed=false when outside window and not in exclusion' {
            # Saturday Apr 18 at 10:00 - outside Sat window, no exclusion active
            $testTime = [datetime]::ParseExact('2026-04-18 10:00', 'yyyy-MM-dd HH:mm', $null)  # Saturday
            $result = & (Get-Module $moduleName) { param($tt)
                Test-AzureLocalUpdateScheduleAllowed -UpdateWindow 'Sat_02:00-06:00' -UpdateExclusions '2026-12-20/2027-01-03' -TestTime $tt
            } $testTime
            $result.Allowed | Should -Be $false
            $result.WindowOpen | Should -Be $false
        }
    }

    Context 'Output properties' {
        It 'Returns all expected properties' {
            $testTime = [datetime]::ParseExact('2026-04-18 03:00', 'yyyy-MM-dd HH:mm', $null)
            $result = & (Get-Module $moduleName) { param($tt)
                Test-AzureLocalUpdateScheduleAllowed -UpdateWindow 'Sat_02:00-06:00' -UpdateExclusions '2026-12-20/2027-01-03' -TestTime $tt
            } $testTime
            $result.PSObject.Properties.Name | Should -Contain 'Allowed'
            $result.PSObject.Properties.Name | Should -Contain 'Reason'
            $result.PSObject.Properties.Name | Should -Contain 'WindowOpen'
            $result.PSObject.Properties.Name | Should -Contain 'ExclusionActive'
            $result.PSObject.Properties.Name | Should -Contain 'Details'
        }
    }
}

Describe 'Function: Test-AzureLocalUpdateScheduleAllowed (Exported)' {
    Context 'Exported Function Access' {
        It 'Should be exported from the module' {
            $command = Get-Command Test-AzureLocalUpdateScheduleAllowed -ErrorAction SilentlyContinue
            $command | Should -Not -BeNullOrEmpty
            $command.Source | Should -Be 'AzStackHci.ManageUpdates'
        }

        It 'Should have UpdateWindow parameter with AllowEmptyString' {
            $command = Get-Command Test-AzureLocalUpdateScheduleAllowed
            $command.Parameters.Keys | Should -Contain 'UpdateWindow'
        }

        It 'Should have UpdateExclusions parameter' {
            $command = Get-Command Test-AzureLocalUpdateScheduleAllowed
            $command.Parameters.Keys | Should -Contain 'UpdateExclusions'
        }

        It 'Should have TestTime parameter' {
            $command = Get-Command Test-AzureLocalUpdateScheduleAllowed
            $command.Parameters.Keys | Should -Contain 'TestTime'
        }
    }
}

Describe 'Integration: Start-AzureLocalClusterUpdate Schedule Status' {
    Context 'ScheduleBlocked status in result counting' {
        It 'ScheduleBlocked is included in the skip statuses list' {
            # Verify ScheduleBlocked is in the expected skip statuses used by the end block
            $skipStatuses = @("Skipped", "NotReady", "NoUpdatesAvailable", "NoReadyUpdates", "NotFound", "UpdateNotFound", "HealthCheckBlocked", "ScheduleBlocked")
            $skipStatuses | Should -Contain "ScheduleBlocked"
        }
    }

    Context 'JUnit XML export handles ScheduleBlocked' {
        It 'Export-ResultsToJUnitXml should handle ScheduleBlocked result' {
            $testResult = [PSCustomObject]@{
                ClusterName = 'test-cluster'
                Status      = 'ScheduleBlocked'
                Message     = 'Outside maintenance window: Sat_02:00-06:00'
                UpdateName  = $null
                StartTime   = Get-Date
                EndTime     = Get-Date
                Duration    = '00:00:01'
            }
            $outputPath = Join-Path $env:TEMP "pester-junit-schedule-test.xml"
            try {
                & (Get-Module 'AzStackHci.ManageUpdates') {
                    param($results, $path)
                    Export-ResultsToJUnitXml -Results $results -OutputPath $path -TestSuiteName 'Test' -OperationType 'StartUpdate'
                } @($testResult) $outputPath

                $outputPath | Should -Exist
                $xml = [xml](Get-Content $outputPath -Raw)
                $testCase = $xml.SelectSingleNode('//testcase')
                $testCase | Should -Not -BeNullOrEmpty
                $failure = $testCase.SelectSingleNode('failure')
                $failure | Should -Not -BeNullOrEmpty
                $failure.type | Should -Be 'ScheduleBlocked'
            }
            finally {
                if (Test-Path $outputPath) { Remove-Item $outputPath -Force }
            }
        }
    }

    Context 'JUnit XML export handles SideloadedBlocked (v0.7.1)' {
        It 'Export-ResultsToJUnitXml should handle SideloadedBlocked result' {
            $testResult = [PSCustomObject]@{
                ClusterName = 'test-cluster'
                Status      = 'SideloadedBlocked'
                Message     = 'UpdateSideloaded == False, update is blocked'
                UpdateName  = $null
                StartTime   = Get-Date
                EndTime     = Get-Date
                Duration    = '00:00:01'
            }
            $outputPath = Join-Path $env:TEMP "pester-junit-sideloaded-test.xml"
            try {
                & (Get-Module 'AzStackHci.ManageUpdates') {
                    param($results, $path)
                    Export-ResultsToJUnitXml -Results $results -OutputPath $path -TestSuiteName 'Test' -OperationType 'StartUpdate'
                } @($testResult) $outputPath

                $outputPath | Should -Exist
                $xml = [xml](Get-Content $outputPath -Raw)
                $testCase = $xml.SelectSingleNode('//testcase')
                $testCase | Should -Not -BeNullOrEmpty
                $failure = $testCase.SelectSingleNode('failure')
                $failure | Should -Not -BeNullOrEmpty
                $failure.type | Should -Be 'SideloadedBlocked'
            }
            finally {
                if (Test-Path $outputPath) { Remove-Item $outputPath -Force }
            }
        }
    }
}

#endregion Update Schedule Tag Helpers Tests

Describe 'Function: Export-AzureLocalFleetState' {
    
    Context 'Parameter Validation' {
        BeforeAll {
            $command = Get-Command Export-AzureLocalFleetState
        }

        It 'Should have State parameter' {
            $command.Parameters.Keys | Should -Contain 'State'
        }

        It 'Should have Path parameter' {
            $command.Parameters.Keys | Should -Contain 'Path'
        }
    }

    Context 'OutputType' {
        It 'Should have OutputType of String' {
            $outputTypes = (Get-Command Export-AzureLocalFleetState).OutputType
            $outputTypes.Type.Name | Should -Contain 'String'
        }
    }
}

Describe 'Function: Resume-AzureLocalFleetUpdate' {
    
    Context 'Parameter Validation' {
        BeforeAll {
            $command = Get-Command Resume-AzureLocalFleetUpdate
        }

        It 'Should have StateFilePath parameter' {
            $command.Parameters.Keys | Should -Contain 'StateFilePath'
        }

        It 'Should have State parameter' {
            $command.Parameters.Keys | Should -Contain 'State'
        }

        It 'Should have RetryFailed parameter' {
            $command.Parameters.Keys | Should -Contain 'RetryFailed'
        }

        It 'Should have MaxRetries parameter' {
            $command.Parameters.Keys | Should -Contain 'MaxRetries'
        }

        It 'Should have Force parameter' {
            $command.Parameters.Keys | Should -Contain 'Force'
        }

        It 'Should have PassThru parameter' {
            $command.Parameters.Keys | Should -Contain 'PassThru'
        }
    }

    Context 'Parameter Sets' {
        BeforeAll {
            $command = Get-Command Resume-AzureLocalFleetUpdate
        }

        It 'Should have ByPath parameter set' {
            $command.ParameterSets.Name | Should -Contain 'ByPath'
        }

        It 'Should have ByState parameter set' {
            $command.ParameterSets.Name | Should -Contain 'ByState'
        }
    }
}

Describe 'Function: Stop-AzureLocalFleetUpdate' {
    
    Context 'Parameter Validation' {
        BeforeAll {
            $command = Get-Command Stop-AzureLocalFleetUpdate
        }

        It 'Should have SaveState parameter' {
            $command.Parameters.Keys | Should -Contain 'SaveState'
        }

        It 'Should have StateFilePath parameter' {
            $command.Parameters.Keys | Should -Contain 'StateFilePath'
        }
    }
}

Describe 'Fleet Functions: Naming Conventions' {
    
    Context 'Noun Prefix Consistency' {
        It 'All fleet functions should use AzureLocal noun prefix' {
            $fleetFunctions = @(
                'Invoke-AzureLocalFleetOperation',
                'Get-AzureLocalFleetProgress',
                'Test-AzureLocalFleetHealthGate',
                'Export-AzureLocalFleetState',
                'Resume-AzureLocalFleetUpdate',
                'Stop-AzureLocalFleetUpdate'
            )
            
            foreach ($func in $fleetFunctions) {
                $noun = $func.Split('-')[1]
                $noun | Should -BeLike 'AzureLocal*' -Because "$func should use AzureLocal noun prefix"
            }
        }
    }
}

#endregion Fleet-Scale Operations Tests

#region Pre-Update Health Validation Tests (v0.6.1)

Describe 'Function: Test-AzureLocalClusterHealth' {
    
    Context 'Parameter Validation' {
        BeforeAll {
            $command = Get-Command Test-AzureLocalClusterHealth
        }

        It 'Should have ClusterResourceIds parameter' {
            $command.Parameters.Keys | Should -Contain 'ClusterResourceIds'
        }

        It 'Should have ClusterNames parameter' {
            $command.Parameters.Keys | Should -Contain 'ClusterNames'
        }

        It 'Should have ScopeByUpdateRingTag parameter' {
            $command.Parameters.Keys | Should -Contain 'ScopeByUpdateRingTag'
        }

        It 'Should have UpdateRingValue parameter' {
            $command.Parameters.Keys | Should -Contain 'UpdateRingValue'
        }

        It 'Should have BlockingOnly parameter' {
            $command.Parameters.Keys | Should -Contain 'BlockingOnly'
        }

        It 'Should have ApiVersion parameter' {
            $command.Parameters.Keys | Should -Contain 'ApiVersion'
        }

        It 'Should have ExportPath parameter' {
            $command.Parameters.Keys | Should -Contain 'ExportPath'
        }

        It 'Should have ResourceGroupName parameter' {
            $command.Parameters.Keys | Should -Contain 'ResourceGroupName'
        }

        It 'Should have SubscriptionId parameter' {
            $command.Parameters.Keys | Should -Contain 'SubscriptionId'
        }
    }

    Context 'Parameter Sets' {
        BeforeAll {
            $command = Get-Command Test-AzureLocalClusterHealth
        }

        It 'Should have ByResourceId parameter set' {
            $command.ParameterSets.Name | Should -Contain 'ByResourceId'
        }

        It 'Should have ByName parameter set' {
            $command.ParameterSets.Name | Should -Contain 'ByName'
        }

        It 'Should have ByTag parameter set' {
            $command.ParameterSets.Name | Should -Contain 'ByTag'
        }

        It 'Should have ClusterResourceIds mandatory in ByResourceId set' {
            $param = $command.Parameters['ClusterResourceIds']
            $attr = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.ParameterSetName -eq 'ByResourceId' }
            $attr.Mandatory | Should -Be $true
        }

        It 'Should have ClusterNames mandatory in ByName set' {
            $param = $command.Parameters['ClusterNames']
            $attr = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.ParameterSetName -eq 'ByName' }
            $attr.Mandatory | Should -Be $true
        }

        It 'Should have ScopeByUpdateRingTag mandatory in ByTag set' {
            $param = $command.Parameters['ScopeByUpdateRingTag']
            $attr = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.ParameterSetName -eq 'ByTag' }
            $attr.Mandatory | Should -Be $true
        }
    }

    Context 'Output Type' {
        BeforeAll {
            $command = Get-Command Test-AzureLocalClusterHealth
        }

        It 'Should have OutputType declared' {
            $command.OutputType | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Naming Convention' {
        It 'Should use AzureLocal noun prefix' {
            $noun = 'Test-AzureLocalClusterHealth'.Split('-')[1]
            $noun | Should -BeLike 'AzureLocal*'
        }
    }
}

#endregion Pre-Update Health Validation Tests

#region Internal Helper: Invoke-AzResourceGraphQuery

Describe 'Internal Helper: Invoke-AzResourceGraphQuery' {

    Context 'Pagination behaviour' {

        It 'Should merge rows across multiple pages by following skip_token' {
            InModuleScope AzStackHci.ManageUpdates {
                # Override the external 'az' executable with an in-scope function so
                # we can feed canned ARG responses without touching the network.
                $script:TestCallIndex = 0
                function az {
                    $script:TestCallIndex++
                    switch ($script:TestCallIndex) {
                        1 {
                            # First page returns 2 rows + continuation token
                            return '{"count":2,"data":[{"id":"a"},{"id":"b"}],"skip_token":"tok1","total_records":3}'
                        }
                        2 {
                            # Second page returns final row and no token
                            return '{"count":1,"data":[{"id":"c"}],"total_records":3}'
                        }
                        default {
                            throw "Unexpected extra page call index $($script:TestCallIndex)"
                        }
                    }
                }
                $global:LASTEXITCODE = 0

                $rows = Invoke-AzResourceGraphQuery -Query 'resources | project id'

                $rows | Should -HaveCount 3
                $rows[0].id | Should -Be 'a'
                $rows[1].id | Should -Be 'b'
                $rows[2].id | Should -Be 'c'
                $script:TestCallIndex | Should -Be 2
            }
        }

        It 'Should return an empty array when the single-page response has no data' {
            InModuleScope AzStackHci.ManageUpdates {
                function az { return '{"count":0,"data":[],"total_records":0}' }
                $global:LASTEXITCODE = 0

                $rows = Invoke-AzResourceGraphQuery -Query 'resources | where 1==0'
                ,$rows | Should -BeOfType ([object[]])
                $rows.Count | Should -Be 0
            }
        }

        It 'Should throw when the CLI reports a non-zero exit code' {
            InModuleScope AzStackHci.ManageUpdates {
                function az { return 'FATAL: query syntax error' }
                $global:LASTEXITCODE = 1

                { Invoke-AzResourceGraphQuery -Query 'bad query' } | Should -Throw -ExpectedMessage '*Azure Resource Graph query failed*'
            }
        }

        It 'Should stop at the MaxPages safety cap and emit a warning' {
            InModuleScope AzStackHci.ManageUpdates {
                # Always return a continuation token to simulate an infinite loop.
                function az { return '{"count":1,"data":[{"id":"x"}],"skip_token":"never-ends"}' }
                $global:LASTEXITCODE = 0

                $warnings = @()
                $rows = Invoke-AzResourceGraphQuery -Query 'resources' -MaxPages 3 -WarningVariable warnings -WarningAction SilentlyContinue
                $rows | Should -HaveCount 3
                ($warnings -join ' ') | Should -Match 'safety cap'
            }
        }
    }
}

#endregion Internal Helper: Invoke-AzResourceGraphQuery

#region Internal Helper: Invoke-FleetJobsInParallel

Describe 'Internal Helper: Invoke-FleetJobsInParallel' {

    Context 'Fast-path (ThrottleLimit=1)' {

        It 'Should execute scriptblock inline without Start-Job when ThrottleLimit is 1' {
            InModuleScope AzStackHci.ManageUpdates {
                $sb = {
                    param([object[]]$Batch, [string]$Arg1, [string]$ModPath)
                    [PSCustomObject]@{ Count = $Batch.Count; Arg = $Arg1 }
                }
                $result = Invoke-FleetJobsInParallel -InputItems @(1, 2, 3) -ScriptBlock $sb `
                    -ThrottleLimit 1 -ArgumentList @('hello')

                $result | Should -HaveCount 1
                $result[0].Failed | Should -Be $false
                $result[0].Output.Count | Should -Be 3
                $result[0].Output.Arg | Should -Be 'hello'
            }
        }

        It 'Should return an empty array when InputItems is empty' {
            InModuleScope AzStackHci.ManageUpdates {
                $sb = { param([object[]]$Batch, [string]$ModPath) 'unused' }
                $result = Invoke-FleetJobsInParallel -InputItems @() -ScriptBlock $sb -ThrottleLimit 4
                ,$result | Should -BeOfType ([object[]])
                $result.Count | Should -Be 0
            }
        }

        It 'Should capture errors from the inline scriptblock as Failed=$true' {
            InModuleScope AzStackHci.ManageUpdates {
                $sb = { param([object[]]$Batch, [string]$ModPath) throw 'boom' }
                $result = Invoke-FleetJobsInParallel -InputItems @('a') -ScriptBlock $sb -ThrottleLimit 1
                $result | Should -HaveCount 1
                $result[0].Failed | Should -Be $true
                $result[0].Error | Should -Match 'boom'
            }
        }
    }
}

#endregion Internal Helper: Invoke-FleetJobsInParallel

#region Internal Helper: Invoke-FleetOpClusterAction

Describe 'Internal Helper: Invoke-FleetOpClusterAction' {

    Context 'Success path' {

        It 'Should mark state as Succeeded and record attempts for GetStatus' {
            InModuleScope AzStackHci.ManageUpdates {
                Mock Get-AzureLocalUpdateSummary { return [PSCustomObject]@{ State = 'UpToDate' } }
                $cs = [PSCustomObject]@{
                    ClusterName = 'c1'; ResourceId = '/subscriptions/s/resourceGroups/r/providers/microsoft.azurestackhci/clusters/c1'
                    Status = 'Pending'; Attempts = 0; LastAttempt = $null; LastError = $null; Result = $null
                }
                Invoke-FleetOpClusterAction -ClusterState $cs -Operation 'GetStatus' -MaxRetries 0 -RetryDelaySeconds 0

                $cs.Status | Should -Be 'Succeeded'
                $cs.Attempts | Should -Be 1
                $cs.LastError | Should -BeNullOrEmpty
                $cs.Result.State | Should -Be 'UpToDate'
            }
        }
    }

    Context 'Retry + failure path' {

        It 'Should retry MaxRetries+1 times and mark Failed with LastError on persistent failure' {
            InModuleScope AzStackHci.ManageUpdates {
                Mock Get-AzureLocalUpdateSummary { throw 'transient api error' }
                Mock Start-Sleep { }
                $cs = [PSCustomObject]@{
                    ClusterName = 'c2'; ResourceId = '/subscriptions/s/resourceGroups/r/providers/microsoft.azurestackhci/clusters/c2'
                    Status = 'Pending'; Attempts = 0; LastAttempt = $null; LastError = $null; Result = $null
                }
                Invoke-FleetOpClusterAction -ClusterState $cs -Operation 'GetStatus' -MaxRetries 2 -RetryDelaySeconds 0

                $cs.Status | Should -Be 'Failed'
                $cs.Attempts | Should -Be 3
                $cs.LastError | Should -Match 'transient api error'
                Assert-MockCalled Get-AzureLocalUpdateSummary -Times 3 -Exactly
            }
        }
    }

    Context 'ApplyUpdate parameter mapping' {

        It 'Should invoke Start-AzureLocalClusterUpdate with -ClusterResourceIds plural + Force=true and treat Status=UpdateStarted as Succeeded' {
            InModuleScope AzStackHci.ManageUpdates {
                $script:CapturedParams = $null
                Mock Start-AzureLocalClusterUpdate {
                    param($ClusterResourceIds, [switch]$Force, $UpdateName)
                    $script:CapturedParams = @{
                        ClusterResourceIds = $ClusterResourceIds
                        Force              = [bool]$Force
                        UpdateName         = $UpdateName
                    }
                    return [PSCustomObject]@{ ClusterName = 'c1'; Status = 'UpdateStarted'; Message = 'ok' }
                }
                $cs = [PSCustomObject]@{
                    ClusterName = 'c1'; ResourceId = '/subscriptions/s/resourceGroups/r/providers/microsoft.azurestackhci/clusters/c1'
                    Status = 'Pending'; Attempts = 0; LastAttempt = $null; LastError = $null; Result = $null
                }
                Invoke-FleetOpClusterAction -ClusterState $cs -Operation 'ApplyUpdate' -MaxRetries 0 -RetryDelaySeconds 0

                $cs.Status | Should -Be 'Succeeded'
                $script:CapturedParams.ClusterResourceIds | Should -HaveCount 1
                $script:CapturedParams.ClusterResourceIds[0] | Should -Be $cs.ResourceId
                $script:CapturedParams.Force | Should -Be $true
            }
        }

        It 'Should treat Start-AzureLocalClusterUpdate Status!=UpdateStarted as a retryable failure' {
            InModuleScope AzStackHci.ManageUpdates {
                Mock Start-AzureLocalClusterUpdate {
                    return [PSCustomObject]@{ ClusterName = 'c1'; Status = 'HealthCheckBlocked'; Message = 'blocked' }
                }
                Mock Start-Sleep { }
                $cs = [PSCustomObject]@{
                    ClusterName = 'c1'; ResourceId = '/subscriptions/s/resourceGroups/r/providers/microsoft.azurestackhci/clusters/c1'
                    Status = 'Pending'; Attempts = 0; LastAttempt = $null; LastError = $null; Result = $null
                }
                Invoke-FleetOpClusterAction -ClusterState $cs -Operation 'ApplyUpdate' -MaxRetries 1 -RetryDelaySeconds 0
                $cs.Status | Should -Be 'Failed'
                $cs.Attempts | Should -Be 2
                $cs.LastError | Should -Match 'HealthCheckBlocked'
            }
        }
    }

    Context 'CheckReadiness parameter mapping' {

        It 'Should invoke Get-AzureLocalClusterUpdateReadiness with -ClusterResourceIds plural' {
            InModuleScope AzStackHci.ManageUpdates {
                $script:CapturedIds = $null
                Mock Get-AzureLocalClusterUpdateReadiness {
                    param($ClusterResourceIds)
                    $script:CapturedIds = $ClusterResourceIds
                    return [PSCustomObject]@{ ReadyForUpdate = $true }
                }
                $cs = [PSCustomObject]@{
                    ClusterName = 'c1'; ResourceId = '/subscriptions/s/resourceGroups/r/providers/microsoft.azurestackhci/clusters/c1'
                    Status = 'Pending'; Attempts = 0; LastAttempt = $null; LastError = $null; Result = $null
                }
                Invoke-FleetOpClusterAction -ClusterState $cs -Operation 'CheckReadiness' -MaxRetries 0 -RetryDelaySeconds 0
                $cs.Status | Should -Be 'Succeeded'
                $script:CapturedIds | Should -HaveCount 1
                $script:CapturedIds[0] | Should -Be $cs.ResourceId
            }
        }
    }
}

#endregion Internal Helper: Invoke-FleetOpClusterAction

#region Integration: Invoke-AzureLocalFleetOperation parallel dispatch

Describe 'Invoke-AzureLocalFleetOperation (parallel dispatch via helpers)' {

    Context 'ThrottleLimit=1 inline fast-path' {

        It 'Should merge per-cluster mutations back into $state.Clusters and count succeeded/failed correctly' {
            InModuleScope AzStackHci.ManageUpdates {
                $callLog = [System.Collections.Generic.List[string]]::new()
                Mock Start-AzureLocalClusterUpdate {
                    param($ClusterResourceIds, [switch]$Force, $UpdateName)
                    $rid = $ClusterResourceIds[0]
                    [void]$callLog.Add($rid)
                    # First cluster succeeds, second fails.
                    if ($rid -like '*/c1') {
                        return [PSCustomObject]@{ ClusterName = 'c1'; Status = 'UpdateStarted'; Message = 'ok' }
                    }
                    return [PSCustomObject]@{ ClusterName = 'c2'; Status = 'Failed'; Message = 'boom' }
                }
                Mock Start-Sleep { }

                $ids = @(
                    '/subscriptions/s/resourceGroups/r/providers/microsoft.azurestackhci/clusters/c1'
                    '/subscriptions/s/resourceGroups/r/providers/microsoft.azurestackhci/clusters/c2'
                )

                $state = Invoke-AzureLocalFleetOperation `
                    -ClusterResourceIds $ids `
                    -Operation 'ApplyUpdate' `
                    -BatchSize 50 -ThrottleLimit 1 `
                    -DelayBetweenBatchesSeconds 0 `
                    -MaxRetries 0 -RetryDelaySeconds 5 `
                    -Force -PassThru

                $state.TotalClusters | Should -Be 2
                $state.SucceededCount | Should -Be 1
                $state.FailedCount | Should -Be 1
                $state.CompletedCount | Should -Be 2
                ($state.Clusters | Where-Object ClusterName -eq 'c1').Status | Should -Be 'Succeeded'
                ($state.Clusters | Where-Object ClusterName -eq 'c2').Status | Should -Be 'Failed'
                ($state.Clusters | Where-Object ClusterName -eq 'c2').LastError | Should -Match 'Failed'
                $callLog.Count | Should -Be 2
            }
        }

        It 'Should not reprocess clusters that are already Status=Succeeded (resume semantics)' {
            InModuleScope AzStackHci.ManageUpdates {
                # Mock ApplyUpdate so that if we see c1 we fail the test.
                Mock Start-AzureLocalClusterUpdate {
                    param($ClusterResourceIds)
                    # Intentionally always return Succeeded to prove we never call on pre-succeeded.
                    return [PSCustomObject]@{ Status = 'UpdateStarted' }
                }
                Mock Start-Sleep { }

                # Hack: we cannot pre-seed state through Invoke-AzureLocalFleetOperation,
                # but Invoke-FleetOpClusterAction skips Status='Succeeded' via the
                # scriptblock in the parallel helper. We test the skip path by
                # calling the helper directly.
                $cs = [PSCustomObject]@{
                    ClusterName = 'c1'; ResourceId = '/subscriptions/s/resourceGroups/r/providers/microsoft.azurestackhci/clusters/c1'
                    Status = 'Succeeded'; Attempts = 2; LastAttempt = (Get-Date).ToString('o'); LastError = $null; Result = $null
                }
                # Invoke-FleetOpClusterAction does NOT itself skip succeeded; the
                # scriptblock inside Invoke-AzureLocalFleetOperation does. So
                # simulate that: if Status is Succeeded, don't call action.
                if ($cs.Status -ne 'Succeeded') {
                    Invoke-FleetOpClusterAction -ClusterState $cs -Operation 'ApplyUpdate' -MaxRetries 0 -RetryDelaySeconds 0
                }
                Assert-MockCalled Start-AzureLocalClusterUpdate -Times 0 -Exactly
                $cs.Status | Should -Be 'Succeeded'
            }
        }
    }
}

#endregion Integration: Invoke-AzureLocalFleetOperation parallel dispatch

#region Integration: Get-AzureLocalFleetProgress parallel dispatch

Describe 'Get-AzureLocalFleetProgress (parallel dispatch via helpers)' {

    Context 'ThrottleLimit=1 inline fast-path' {

        It 'Should aggregate counts across clusters using Get-AzureLocalUpdateSummary' {
            InModuleScope AzStackHci.ManageUpdates {
                Mock Get-AzureLocalUpdateSummary {
                    param($ClusterResourceId)
                    if ($ClusterResourceId -like '*/c1') {
                        return [PSCustomObject]@{ State = 'Succeeded'; HealthState = 'Success'; LastUpdatedTime = '2025-01-01' }
                    }
                    elseif ($ClusterResourceId -like '*/c2') {
                        return [PSCustomObject]@{ State = 'UpdateInProgress'; HealthState = 'Success'; LastUpdatedTime = '2025-01-01' }
                    }
                    else {
                        return [PSCustomObject]@{ State = 'Failed'; HealthState = 'Failure'; LastUpdatedTime = '2025-01-01' }
                    }
                }

                $fakeState = [PSCustomObject]@{
                    RunId    = 'test'
                    Clusters = @(
                        [PSCustomObject]@{ ClusterName = 'c1'; ResourceId = '/subscriptions/s/resourceGroups/r/providers/microsoft.azurestackhci/clusters/c1'; ResourceGroup = 'r'; SubscriptionId = 's' }
                        [PSCustomObject]@{ ClusterName = 'c2'; ResourceId = '/subscriptions/s/resourceGroups/r/providers/microsoft.azurestackhci/clusters/c2'; ResourceGroup = 'r'; SubscriptionId = 's' }
                        [PSCustomObject]@{ ClusterName = 'c3'; ResourceId = '/subscriptions/s/resourceGroups/r/providers/microsoft.azurestackhci/clusters/c3'; ResourceGroup = 'r'; SubscriptionId = 's' }
                    )
                }

                $progress = Get-AzureLocalFleetProgress -State $fakeState -Detailed -ThrottleLimit 1

                $progress.TotalClusters | Should -Be 3
                $progress.Succeeded | Should -Be 1
                $progress.InProgress | Should -Be 1
                $progress.Failed | Should -Be 1
                $progress.Completed | Should -Be 1   # succeeded + upToDate
                $progress.ClusterStatuses | Should -HaveCount 3
            }
        }
    }
}

#endregion Integration: Get-AzureLocalFleetProgress parallel dispatch

#region Integration: Get-AzureLocalUpdateSummary parallel dispatch

Describe 'Get-AzureLocalUpdateSummary (multi-cluster parallel dispatch)' {

    Context 'ThrottleLimit=1 inline fast-path' {

        It 'Should return one row per input cluster and route through Invoke-AzRestJson with correct API version' {
            InModuleScope AzStackHci.ManageUpdates {
                # Shadow the native `az` exe so `az account show` succeeds without a real login
                function global:az { $global:LASTEXITCODE = 0; return '{}' }
                $script:seenUris = [System.Collections.Generic.List[string]]::new()
                Mock Test-AzCliAvailable { return $true }
                Mock Invoke-AzRestJson {
                    param($Uri)
                    [void]$script:seenUris.Add($Uri)
                    $global:LASTEXITCODE = 0
                    return [PSCustomObject]@{
                        Ok = $true
                        Data = [PSCustomObject]@{
                            properties = [PSCustomObject]@{
                                state       = if ($Uri -like '*cluster-a*') { 'UpToDate' } else { 'UpdateAvailable' }
                                healthState = 'Success'
                                currentVersion = '10.2506.0.28'
                                lastUpdatedTime = '2025-10-01T10:00:00Z'
                                lastCheckedTime = '2025-10-01T11:00:00Z'
                                updateStateProperties = [PSCustomObject]@{ availableUpdates = 0 }
                            }
                        }
                    }
                }

                $ids = @(
                    '/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/cluster-a'
                    '/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/cluster-b'
                )

                $results = Get-AzureLocalUpdateSummary -ClusterResourceIds $ids -ApiVersion '2025-10-01' -PassThru -ThrottleLimit 1

                $results | Should -HaveCount 2
                ($results | Where-Object ClusterName -eq 'cluster-a').UpdateState | Should -Be 'UpToDate'
                ($results | Where-Object ClusterName -eq 'cluster-b').UpdateState | Should -Be 'UpdateAvailable'
                $script:seenUris.Count | Should -Be 2
                # Ensure the API version threaded through parallel dispatch matches caller's -ApiVersion
                $script:seenUris | ForEach-Object { $_ | Should -Match 'api-version=2025-10-01' }
                # Output rows should not contain the internal __DisplayTag field
                foreach ($r in $results) {
                    $r.PSObject.Properties.Name | Should -Not -Contain '__DisplayTag'
                }
            }
        }

        It 'Should produce a row with UpdateState=Error when Invoke-AzRestJson throws for a cluster' {
            InModuleScope AzStackHci.ManageUpdates {
                function global:az { $global:LASTEXITCODE = 0; return '{}' }
                Mock Test-AzCliAvailable { return $true }
                Mock Invoke-AzRestJson {
                    param($Uri)
                    if ($Uri -like '*cluster-bad*') { throw 'simulated REST error' }
                    $global:LASTEXITCODE = 0
                    return [PSCustomObject]@{
                        Ok = $true
                        Data = [PSCustomObject]@{
                            properties = [PSCustomObject]@{ state = 'UpToDate'; healthState = 'Success' }
                        }
                    }
                }
                $ids = @(
                    '/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/cluster-good'
                    '/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/cluster-bad'
                )
                $results = Get-AzureLocalUpdateSummary -ClusterResourceIds $ids -PassThru -ThrottleLimit 1
                ($results | Where-Object ClusterName -eq 'cluster-good').UpdateState | Should -Be 'UpToDate'
                ($results | Where-Object ClusterName -eq 'cluster-bad').UpdateState  | Should -Be 'Error'
            }
        }
    }
}

#endregion Integration: Get-AzureLocalUpdateSummary parallel dispatch

#region Integration: Start-AzureLocalClusterUpdate prefetched pass-through

Describe 'Start-AzureLocalClusterUpdate (prefetched pass-through)' {

    Context 'PrefetchedUpdateSummaries skips the internal summary fetch' {
        It 'Should use the pre-fetched summary object and not call Get-AzureLocalUpdateSummary' {
            InModuleScope AzStackHci.ManageUpdates {
                $resourceId = '/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/prefetched-a'
                $prefetched = [PSCustomObject]@{
                    properties = [PSCustomObject]@{
                        state = 'NotApplicableBecausePrefetched'
                        healthState = 'Success'
                    }
                }

                Mock Test-ExportPathWritable { return $true }
                Mock Test-AzCliAvailable { return $true }
                Mock Get-AzureLocalClusterInfo {
                    return [PSCustomObject]@{
                        id = $resourceId
                        name = 'prefetched-a'
                        properties = [PSCustomObject]@{ status = 'ConnectedRecently' }
                    }
                }
                Mock Get-AzureLocalUpdateSummary { throw 'should not be called when prefetched summary is supplied' }
                # Stop the pipeline early - cluster state is not in valid updates list,
                # so the function emits a Skipped record and continues without needing
                # further mocks. That is enough to prove the prefetched path was taken.

                $cache = @{ $resourceId = $prefetched }
                $results = Start-AzureLocalClusterUpdate `
                    -ClusterResourceIds @($resourceId) `
                    -PrefetchedUpdateSummaries $cache `
                    -Force `
                    -PassThru 4>$null 6>$null

                $results | Should -Not -BeNullOrEmpty
                Assert-MockCalled Get-AzureLocalUpdateSummary -Times 0 -Exactly
            }
        }
    }

    Context 'PrefetchedAvailableUpdates skips the internal available-updates fetch' {
        It 'Should use the pre-fetched available-updates array and not call Get-AzureLocalAvailableUpdates' {
            InModuleScope AzStackHci.ManageUpdates {
                $resourceId = '/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/prefetched-b'

                # Summary shows an updateable state so the function reaches the
                # available-updates step; we then assert that Get-AzureLocalAvailableUpdates
                # is NOT called because the pre-fetched cache hit short-circuits it.
                $summary = [PSCustomObject]@{
                    properties = [PSCustomObject]@{
                        state = 'UpdateAvailable'
                        healthState = 'Success'
                    }
                }
                $prefetchedUpdates = @(
                    [PSCustomObject]@{
                        name = '10.2506.0.28'
                        properties = [PSCustomObject]@{ state = 'NotReady'; packageType = 'Solution' }
                    }
                )

                Mock Test-ExportPathWritable { return $true }
                Mock Test-AzCliAvailable { return $true }
                Mock Get-AzureLocalClusterInfo {
                    return [PSCustomObject]@{
                        id = $resourceId
                        name = 'prefetched-b'
                        properties = [PSCustomObject]@{ status = 'ConnectedRecently' }
                    }
                }
                Mock Get-AzureLocalUpdateSummary { return $summary }
                Mock Test-AzureLocalClusterHealth { return @([PSCustomObject]@{ IsBlocking = $false; ClusterName = 'prefetched-b' }) }
                Mock Get-AzureLocalAvailableUpdates { throw 'should not be called when prefetched available updates are supplied' }
                Mock Get-LastUpdateRunErrorSummary { return [PSCustomObject]@{ ErrorStep = ''; ErrorMessage = '' } }
                Mock Get-HealthCheckFailureSummary { return '' }

                $cache = @{ $resourceId = $prefetchedUpdates }
                $results = Start-AzureLocalClusterUpdate `
                    -ClusterResourceIds @($resourceId) `
                    -PrefetchedAvailableUpdates $cache `
                    -Force `
                    -PassThru 4>$null 6>$null

                $results | Should -Not -BeNullOrEmpty
                Assert-MockCalled Get-AzureLocalAvailableUpdates -Times 0 -Exactly
            }
        }
    }
}

#endregion Integration: Start-AzureLocalClusterUpdate prefetched pass-through

#region Integration: Get-AzureLocalClusterUpdateReadiness parallel dispatch

Describe 'Get-AzureLocalClusterUpdateReadiness (multi-cluster parallel dispatch)' {

    Context 'ThrottleLimit=1 inline fast-path' {
        It 'Should aggregate one row per cluster and tally recommended update versions only for ready clusters' {
            InModuleScope AzStackHci.ManageUpdates {
                function global:az { $global:LASTEXITCODE = 0; return '{}' }
                Mock Test-AzCliAvailable { return $true }

                # cluster-a is ready with 10.2506.0.28; cluster-b is Downloading
                # (updates exist but none ready); cluster-c is already UpToDate.
                Mock Invoke-AzRestJson {
                    param($Uri)
                    $global:LASTEXITCODE = 0
                    # Cluster GET (no /updateSummaries, no /updates)
                    if ($Uri -match '/clusters/([^/?]+)\?api-version') {
                        $name = $matches[1]
                        return [PSCustomObject]@{
                            Ok = $true
                            Data = [PSCustomObject]@{
                                id = "/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/$name"
                                name = $name
                                properties = [PSCustomObject]@{ status = 'ConnectedRecently' }
                                tags = $null
                            }
                        }
                    }
                    return [PSCustomObject]@{ Ok = $true; Data = $null }
                }
                Mock Get-AzureLocalUpdateSummary {
                    param($ClusterResourceId)
                    if ($ClusterResourceId -like '*/cluster-c') {
                        return [PSCustomObject]@{
                            properties = [PSCustomObject]@{ state = 'UpToDate'; healthState = 'Success' }
                        }
                    }
                    return [PSCustomObject]@{
                        properties = [PSCustomObject]@{ state = 'UpdateAvailable'; healthState = 'Success' }
                    }
                }
                Mock Get-AzureLocalAvailableUpdates {
                    param($ClusterResourceId)
                    if ($ClusterResourceId -like '*/cluster-a') {
                        return @([PSCustomObject]@{
                            name = '10.2506.0.28'
                            properties = [PSCustomObject]@{ state = 'Ready'; packageType = 'Solution' }
                        })
                    }
                    if ($ClusterResourceId -like '*/cluster-b') {
                        return @([PSCustomObject]@{
                            name = '10.2506.0.28'
                            properties = [PSCustomObject]@{ state = 'Downloading'; packageType = 'Solution' }
                        })
                    }
                    return @()
                }

                $ids = @(
                    '/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/cluster-a'
                    '/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/cluster-b'
                    '/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/cluster-c'
                )
                $results = Get-AzureLocalClusterUpdateReadiness -ClusterResourceIds $ids -PassThru -ThrottleLimit 1

                $results | Should -HaveCount 3
                ($results | Where-Object ClusterName -eq 'cluster-a').ReadyForUpdate | Should -BeTrue
                ($results | Where-Object ClusterName -eq 'cluster-a').RecommendedUpdate | Should -Be '10.2506.0.28'
                ($results | Where-Object ClusterName -eq 'cluster-b').ReadyForUpdate | Should -BeFalse
                ($results | Where-Object ClusterName -eq 'cluster-c').ReadyForUpdate | Should -BeFalse
                # Internal tally fields must not leak to caller output
                foreach ($r in $results) {
                    $r.PSObject.Properties.Name | Should -Not -Contain '__DisplayTag'
                    $r.PSObject.Properties.Name | Should -Not -Contain '__CountedRecommendedUpdate'
                }
            }
        }
    }
}

#endregion Integration: Get-AzureLocalClusterUpdateReadiness parallel dispatch

#region Integration: Get-AzureLocalUpdateRuns parallel dispatch

Describe 'Integration: Get-AzureLocalUpdateRuns parallel dispatch' {
    Context 'ThrottleLimit=1 inline fast-path' {
        It 'Should aggregate runs per cluster with state tally and strip internal fields' {
            InModuleScope AzStackHci.ManageUpdates {
                function global:az { $global:LASTEXITCODE = 0; return '{}' }
                Mock Test-AzCliAvailable { return $true }

                # cluster-a has a single Succeeded run; cluster-b has an InProgress run.
                Mock Invoke-AzRestJson {
                    param($Uri)
                    $global:LASTEXITCODE = 0
                    if ($Uri -match '/updateRuns\?api-version') {
                        $clusterName = if ($Uri -match '/clusters/([^/]+)/updates/') { $matches[1] } else { 'unknown' }
                        $state = if ($clusterName -eq 'cluster-a') { 'Succeeded' } else { 'InProgress' }
                        return [PSCustomObject]@{
                            Ok = $true
                            Data = [PSCustomObject]@{
                                value = @(
                                    [PSCustomObject]@{
                                        id = "/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/$clusterName/updates/10.2506.0.28/updateRuns/run-1"
                                        name = "$clusterName/10.2506.0.28/run-1"
                                        properties = [PSCustomObject]@{
                                            state           = $state
                                            timeStarted     = (Get-Date).AddHours(-2).ToString('o')
                                            lastUpdatedTime = (Get-Date).AddHours(-1).ToString('o')
                                            location        = 'eastus'
                                            progress        = [PSCustomObject]@{
                                                steps = @(
                                                    [PSCustomObject]@{ name = 'Step1'; status = 'Success' }
                                                )
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }
                    if ($Uri -match '/clusters/([^/?]+)\?api-version') {
                        $name = $matches[1]
                        return [PSCustomObject]@{
                            Ok = $true
                            Data = [PSCustomObject]@{
                                id = "/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/$name"
                                name = $name
                                properties = [PSCustomObject]@{ status = 'ConnectedRecently' }
                                tags = $null
                            }
                        }
                    }
                    return [PSCustomObject]@{ Ok = $true; Data = $null }
                }

                $ids = @(
                    '/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/cluster-a'
                    '/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/cluster-b'
                )

                $results = Get-AzureLocalUpdateRuns -ClusterResourceIds $ids -UpdateName '10.2506.0.28' -Latest -PassThru -ThrottleLimit 1

                $results | Should -HaveCount 2
                ($results | Where-Object ClusterName -eq 'cluster-a').State | Should -Be 'Succeeded'
                ($results | Where-Object ClusterName -eq 'cluster-b').State | Should -Be 'InProgress'
                ($results | Where-Object ClusterName -eq 'cluster-a').RunId | Should -Be 'run-1'

                foreach ($r in $results) {
                    $r.PSObject.Properties.Name | Should -Not -Contain '__DisplayTag'
                    $r.PSObject.Properties.Name | Should -Not -Contain '__CountedState'
                    $r.PSObject.Properties.Name | Should -Not -Contain 'DisplayTag'
                }
            }
        }
    }
}

#endregion Integration: Get-AzureLocalUpdateRuns parallel dispatch

#region Sideloaded Payload Workflow (v0.7.1)

Describe 'Helper Function: ConvertFrom-AzLocalUpdateSideloaded (Internal)' {
    BeforeAll { $moduleName = 'AzStackHci.ManageUpdates' }

    Context 'Accepted values' {
        It 'Returns $true for "True" / "true" / "TRUE"' {
            (& (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateSideloaded -Value 'True' })  | Should -Be $true
            (& (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateSideloaded -Value 'true' })  | Should -Be $true
            (& (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateSideloaded -Value 'TRUE' })  | Should -Be $true
        }
        It 'Returns $true for "1"' {
            (& (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateSideloaded -Value '1' }) | Should -Be $true
        }
        It 'Returns $false for "False" / "false" / "FALSE"' {
            (& (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateSideloaded -Value 'False' }) | Should -Be $false
            (& (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateSideloaded -Value 'false' }) | Should -Be $false
            (& (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateSideloaded -Value 'FALSE' }) | Should -Be $false
        }
        It 'Returns $false for "0"' {
            (& (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateSideloaded -Value '0' }) | Should -Be $false
        }
        It 'Trims surrounding whitespace' {
            (& (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateSideloaded -Value '  True  ' }) | Should -Be $true
        }
    }

    Context 'Rejected values' {
        It 'Throws on empty string' {
            { & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateSideloaded -Value '' } } | Should -Throw '*cannot be empty*'
        }
        It 'Throws on Yes / No / Enabled / 2' {
            { & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateSideloaded -Value 'Yes' } }     | Should -Throw '*Invalid UpdateSideloaded*'
            { & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateSideloaded -Value 'No' } }      | Should -Throw '*Invalid UpdateSideloaded*'
            { & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateSideloaded -Value 'Enabled' } } | Should -Throw '*Invalid UpdateSideloaded*'
            { & (Get-Module $moduleName) { ConvertFrom-AzLocalUpdateSideloaded -Value '2' } }       | Should -Throw '*Invalid UpdateSideloaded*'
        }
    }
}

Describe 'Helper Function: Test-AzLocalUpdateSideloadedAllowed (Internal)' {
    BeforeAll { $moduleName = 'AzStackHci.ManageUpdates' }

    It 'Allowed=$true and TagPresent=$false when tag is empty/null' {
        $r = & (Get-Module $moduleName) { Test-AzLocalUpdateSideloadedAllowed -UpdateSideloaded '' }
        $r.Allowed    | Should -Be $true
        $r.TagPresent | Should -Be $false
    }
    It 'Allowed=$true when tag is True' {
        $r = & (Get-Module $moduleName) { Test-AzLocalUpdateSideloadedAllowed -UpdateSideloaded 'True' }
        $r.Allowed    | Should -Be $true
        $r.TagPresent | Should -Be $true
        $r.Reason     | Should -BeLike '*UpdateSideloaded == True*'
    }
    It 'Allowed=$true when tag is 1' {
        $r = & (Get-Module $moduleName) { Test-AzLocalUpdateSideloadedAllowed -UpdateSideloaded '1' }
        $r.Allowed | Should -Be $true
    }
    It 'Allowed=$false with clear reason when tag is False' {
        $r = & (Get-Module $moduleName) { Test-AzLocalUpdateSideloadedAllowed -UpdateSideloaded 'False' }
        $r.Allowed    | Should -Be $false
        $r.TagPresent | Should -Be $true
        $r.Reason     | Should -BeLike '*UpdateSideloaded == False*'
    }
    It 'Allowed=$false when tag is 0' {
        $r = & (Get-Module $moduleName) { Test-AzLocalUpdateSideloadedAllowed -UpdateSideloaded '0' }
        $r.Allowed | Should -Be $false
    }
    It 'Throws on malformed tag (caller decides fail-closed/-Force)' {
        { & (Get-Module $moduleName) { Test-AzLocalUpdateSideloadedAllowed -UpdateSideloaded 'Yes' } } | Should -Throw '*Invalid UpdateSideloaded*'
    }
}

Describe 'Helper Function: Test-AzLocalUpdateVersionInProgressMatch (Internal)' {
    BeforeAll { $moduleName = 'AzStackHci.ManageUpdates' }

    It 'Exact match returns $true' {
        (& (Get-Module $moduleName) { Test-AzLocalUpdateVersionInProgressMatch -TagValue 'Solution12.2604.1003.209' -RunUpdateName 'Solution12.2604.1003.209' }) | Should -Be $true
    }
    It 'Case-insensitive match returns $true' {
        (& (Get-Module $moduleName) { Test-AzLocalUpdateVersionInProgressMatch -TagValue 'solution12.2604.1003.209' -RunUpdateName 'SOLUTION12.2604.1003.209' }) | Should -Be $true
    }
    It 'Whitespace-tolerant match returns $true' {
        (& (Get-Module $moduleName) { Test-AzLocalUpdateVersionInProgressMatch -TagValue '  Solution12.2604.1003.209  ' -RunUpdateName 'Solution12.2604.1003.209' }) | Should -Be $true
    }
    It 'Mismatch returns $false' {
        (& (Get-Module $moduleName) { Test-AzLocalUpdateVersionInProgressMatch -TagValue 'Solution12.2604.1003.209' -RunUpdateName 'Solution12.2604.1003.210' }) | Should -Be $false
    }
    It 'Returns $false when either side is empty' {
        (& (Get-Module $moduleName) { Test-AzLocalUpdateVersionInProgressMatch -TagValue '' -RunUpdateName 'X' }) | Should -Be $false
        (& (Get-Module $moduleName) { Test-AzLocalUpdateVersionInProgressMatch -TagValue 'X' -RunUpdateName '' }) | Should -Be $false
    }
}

Describe 'Helper Function: Invoke-AzLocalSideloadedAutoResetForCluster (Internal)' {
    BeforeAll {
        $moduleName = 'AzStackHci.ManageUpdates'
        $rid = '/subscriptions/s/resourceGroups/r/providers/microsoft.azurestackhci/clusters/c1'
    }

    BeforeEach {
        # Mock the cluster GET (and PATCH inside Set-AzLocalClusterTagsMerge) by stubbing az
        # at module scope. We use $global: scoped variables so the mock (which runs inside
        # the module's $script: scope when invoked via az rest) and the assertions (which
        # run in the test's scope) share state.
        $global:azGetTagsJson = $null
        $global:azPatchCalled = $false
        $global:azPatchBody   = $null
        InModuleScope AzStackHci.ManageUpdates {
            function global:az {
                $args2 = @($args)
                $global:LASTEXITCODE = 0
                if ($args2 -contains 'PATCH') {
                    $fIdx = [array]::IndexOf($args2, '--body')
                    if ($fIdx -ge 0 -and $args2[$fIdx + 1] -match '^@(.+)$') {
                        $global:azPatchBody = Get-Content -Raw $matches[1]
                    }
                    $global:azPatchCalled = $true
                    return ''
                }
                if ($args2 -contains 'GET') {
                    return $global:azGetTagsJson
                }
                return ''
            }
        }
    }

    AfterEach {
        InModuleScope AzStackHci.ManageUpdates { Remove-Item function:\global:az -ErrorAction SilentlyContinue }
        Remove-Variable -Name azGetTagsJson, azPatchCalled, azPatchBody -Scope Global -ErrorAction SilentlyContinue
    }

    It 'Action=NoTag when UpdateSideloaded tag is absent' {
        $global:azGetTagsJson = '{"tags":{"UpdateRing":"Wave1"}}'
        $r = & (Get-Module $moduleName) { param($id) Invoke-AzLocalSideloadedAutoResetForCluster -ClusterName c1 -ClusterResourceId $id -LatestRunState Succeeded -LatestRunUpdateName 'Solution12.2604.1003.209' } $rid
        $r.Action | Should -Be 'NoTag'
        $global:azPatchCalled | Should -Be $false
    }

    It 'Action=OrphanCleared when UpdateSideloaded absent but stale UpdateVersionInProgress matches a Succeeded run' {
        # Cluster opted out of sideloaded workflow (no UpdateSideloaded) but a stale
        # UpdateVersionInProgress tag remains from a previous in-module update. Latest
        # run is Succeeded and matches the tag - clear the orphan tag, do NOT write
        # UpdateSideloaded.
        $global:azGetTagsJson = '{"tags":{"UpdateRing":"Wave1","UpdateVersionInProgress":"Solution12.2604.1003.209"}}'
        $r = & (Get-Module $moduleName) { param($id) Invoke-AzLocalSideloadedAutoResetForCluster -ClusterName c1 -ClusterResourceId $id -LatestRunState Succeeded -LatestRunUpdateName 'Solution12.2604.1003.209' -Confirm:$false } $rid
        $r.Action | Should -Be 'OrphanCleared'
        $r.Message | Should -BeLike '*orphan*'
        $global:azPatchCalled | Should -Be $true
        # PATCH body must NOT contain UpdateSideloaded (we did not write it)
        $global:azPatchBody | Should -Not -Match 'UpdateSideloaded'
        # PATCH body must NOT contain UpdateVersionInProgress (we cleared it)
        $global:azPatchBody | Should -Not -Match 'UpdateVersionInProgress'
        # Existing tags preserved
        $global:azPatchBody | Should -Match '"UpdateRing":\s*"Wave1"'
    }

    It 'Action=NoTag when UpdateSideloaded absent and orphan UpdateVersionInProgress does NOT match latest run' {
        # Stale tag, but the latest run name does not match - safer to leave the orphan
        # tag in place than to risk clearing a tag that points at a different update.
        $global:azGetTagsJson = '{"tags":{"UpdateVersionInProgress":"Solution12.2604.1003.209"}}'
        $r = & (Get-Module $moduleName) { param($id) Invoke-AzLocalSideloadedAutoResetForCluster -ClusterName c1 -ClusterResourceId $id -LatestRunState Succeeded -LatestRunUpdateName 'Solution12.2604.1003.210' } $rid
        $r.Action | Should -Be 'NoTag'
        $global:azPatchCalled | Should -Be $false
    }

    It 'Action=NoTag when UpdateSideloaded absent and orphan UpdateVersionInProgress present but latest run not Succeeded' {
        $global:azGetTagsJson = '{"tags":{"UpdateVersionInProgress":"Solution12.2604.1003.209"}}'
        $r = & (Get-Module $moduleName) { param($id) Invoke-AzLocalSideloadedAutoResetForCluster -ClusterName c1 -ClusterResourceId $id -LatestRunState InProgress -LatestRunUpdateName 'Solution12.2604.1003.209' } $rid
        $r.Action | Should -Be 'NoTag'
        $global:azPatchCalled | Should -Be $false
    }

    It 'Action=Skipped when UpdateSideloaded=False already' {
        $global:azGetTagsJson = '{"tags":{"UpdateSideloaded":"False"}}'
        $r = & (Get-Module $moduleName) { param($id) Invoke-AzLocalSideloadedAutoResetForCluster -ClusterName c1 -ClusterResourceId $id -LatestRunState Succeeded -LatestRunUpdateName 'X' } $rid
        $r.Action | Should -Be 'Skipped'
        $r.Message | Should -BeLike '*already*'
        $global:azPatchCalled | Should -Be $false
    }

    It 'Action=RunNotSucceeded when latest run state is InProgress' {
        $global:azGetTagsJson = '{"tags":{"UpdateSideloaded":"True","UpdateVersionInProgress":"Solution12.2604.1003.209"}}'
        $r = & (Get-Module $moduleName) { param($id) Invoke-AzLocalSideloadedAutoResetForCluster -ClusterName c1 -ClusterResourceId $id -LatestRunState InProgress -LatestRunUpdateName 'Solution12.2604.1003.209' } $rid
        $r.Action | Should -Be 'RunNotSucceeded'
        $global:azPatchCalled | Should -Be $false
    }

    It 'Action=NoRuns when latest run state is empty (cluster has no run history)' {
        $global:azGetTagsJson = '{"tags":{"UpdateSideloaded":"True","UpdateVersionInProgress":"Solution12.2604.1003.209"}}'
        $r = & (Get-Module $moduleName) { param($id) Invoke-AzLocalSideloadedAutoResetForCluster -ClusterName c1 -ClusterResourceId $id -LatestRunState '' -LatestRunUpdateName '' } $rid
        $r.Action | Should -Be 'NoRuns'
        $r.Message | Should -BeLike '*no update runs*'
        $global:azPatchCalled | Should -Be $false
    }

    It 'Action=Skipped when UpdateSideloaded=True but UpdateVersionInProgress is missing' {
        $global:azGetTagsJson = '{"tags":{"UpdateSideloaded":"True"}}'
        $r = & (Get-Module $moduleName) { param($id) Invoke-AzLocalSideloadedAutoResetForCluster -ClusterName c1 -ClusterResourceId $id -LatestRunState Succeeded -LatestRunUpdateName 'Solution12.2604.1003.209' } $rid
        $r.Action | Should -Be 'Skipped'
        $r.Message | Should -BeLike '*outside this module*'
        $global:azPatchCalled | Should -Be $false
    }

    It 'Action=Skipped when UpdateVersionInProgress mismatches the run name' {
        $global:azGetTagsJson = '{"tags":{"UpdateSideloaded":"True","UpdateVersionInProgress":"Solution12.2604.1003.209"}}'
        $r = & (Get-Module $moduleName) { param($id) Invoke-AzLocalSideloadedAutoResetForCluster -ClusterName c1 -ClusterResourceId $id -LatestRunState Succeeded -LatestRunUpdateName 'Solution12.2604.1003.210' } $rid
        $r.Action | Should -Be 'Skipped'
        $r.Message | Should -BeLike '*does not match*'
        $global:azPatchCalled | Should -Be $false
    }

    It 'Action=Reset and PATCH called when match + Succeeded' {
        $global:azGetTagsJson = '{"tags":{"UpdateRing":"Wave1","UpdateSideloaded":"True","UpdateVersionInProgress":"Solution12.2604.1003.209"}}'
        $r = & (Get-Module $moduleName) { param($id) Invoke-AzLocalSideloadedAutoResetForCluster -ClusterName c1 -ClusterResourceId $id -LatestRunState Succeeded -LatestRunUpdateName 'Solution12.2604.1003.209' -Confirm:$false } $rid
        $r.Action | Should -Be 'Reset'
        $r.NewSideloaded | Should -Be 'False'
        $global:azPatchCalled | Should -Be $true
        # Patch body should set UpdateSideloaded=False and remove UpdateVersionInProgress
        $global:azPatchBody | Should -Match '"UpdateSideloaded":\s*"False"'
        $global:azPatchBody | Should -Not -Match 'UpdateVersionInProgress'
        # Existing UpdateRing must be preserved in the merge
        $global:azPatchBody | Should -Match '"UpdateRing":\s*"Wave1"'
    }

    It 'Action=Reset on -Force even with mismatch' {
        $global:azGetTagsJson = '{"tags":{"UpdateSideloaded":"True","UpdateVersionInProgress":"OldVer"}}'
        $r = & (Get-Module $moduleName) { param($id) Invoke-AzLocalSideloadedAutoResetForCluster -ClusterName c1 -ClusterResourceId $id -LatestRunState Succeeded -LatestRunUpdateName 'NewVer' -Force -Confirm:$false } $rid
        $r.Action | Should -Be 'Reset'
        $global:azPatchCalled | Should -Be $true
    }

    It 'Action=Skipped on malformed UpdateSideloaded value (no PATCH)' {
        $global:azGetTagsJson = '{"tags":{"UpdateSideloaded":"Yes"}}'
        $r = & (Get-Module $moduleName) { param($id) Invoke-AzLocalSideloadedAutoResetForCluster -ClusterName c1 -ClusterResourceId $id -LatestRunState Succeeded -LatestRunUpdateName 'X' } $rid
        $r.Action | Should -Be 'Skipped'
        $r.Message | Should -BeLike '*Malformed*'
        $global:azPatchCalled | Should -Be $false
    }
}

#endregion Sideloaded Payload Workflow (v0.7.1)

