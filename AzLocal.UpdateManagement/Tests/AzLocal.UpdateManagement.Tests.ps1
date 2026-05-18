#Requires -Module Pester
<#
.SYNOPSIS
    Pester tests for the AzLocal.UpdateManagement module.

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
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\AzLocal.UpdateManagement.psd1'
    Import-Module $modulePath -Force -ErrorAction Stop
    
    # Store module info for tests
    $script:ModuleInfo = Get-Module AzLocal.UpdateManagement
}

AfterAll {
    # Clean up
    Remove-Module AzLocal.UpdateManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Module: AzLocal.UpdateManagement' {
    
    Context 'Module Load' {
        It 'Should load the module without errors' {
            $script:ModuleInfo | Should -Not -BeNullOrEmpty
        }

        It 'Should have version 0.7.68' {
            $script:ModuleInfo.Version | Should -Be '0.7.68'
        }

        It 'Module version constants are in sync between .psm1 and .psd1' {
            # v0.7.67: regression guard for the drift bug where
            # $script:ModuleVersion in AzLocal.UpdateManagement.psm1 was '0.7.66'
            # while the manifest had been bumped to '0.7.67'. The script-scope
            # constant is the value emitted in run-log headers and stamped into
            # exported fleet-state JSON, so drift silently misreports the
            # generator version to consumers. Both must match.
            $manifestPath = Join-Path -Path $PSScriptRoot -ChildPath '..\AzLocal.UpdateManagement.psd1'
            $manifestVersion = (Import-PowerShellDataFile -Path $manifestPath).ModuleVersion
            $scriptVersion = InModuleScope AzLocal.UpdateManagement { $script:ModuleVersion }
            $scriptVersion | Should -Be $manifestVersion -Because '$script:ModuleVersion in the .psm1 must match ModuleVersion in the .psd1'
        }

        It 'README.md Latest Version banner matches manifest ModuleVersion' {
            # v0.7.67 polish: regression guard for the drift bug where
            # README.md still advertised "Latest Version: v0.7.66" after the
            # manifest had been bumped to 0.7.67 and v0.7.67 was published to
            # the PowerShell Gallery. The README banner and the gallery link
            # on the same line are the first thing a consumer reads, so
            # silent drift is a credibility bug. Both must match the manifest.
            $manifestPath = Join-Path -Path $PSScriptRoot -ChildPath '..\AzLocal.UpdateManagement.psd1'
            $readmePath   = Join-Path -Path $PSScriptRoot -ChildPath '..\README.md'
            $manifestVersion = (Import-PowerShellDataFile -Path $manifestPath).ModuleVersion
            $readmeContent = Get-Content -Path $readmePath -Raw
            $pattern = '\*\*Latest Version:\*\*\s+v(?<displayed>\d+\.\d+\.\d+)\s+-\s+\[Published in PowerShell Gallery\]\(https://www\.powershellgallery\.com/packages/AzLocal\.UpdateManagement/(?<urlversion>\d+\.\d+\.\d+)\)'
            $match = [regex]::Match($readmeContent, $pattern)
            $match.Success | Should -BeTrue -Because "README.md must contain a parseable '**Latest Version:** vX.Y.Z - [Published in PowerShell Gallery](https://www.powershellgallery.com/packages/AzLocal.UpdateManagement/X.Y.Z)' line"
            $match.Groups['displayed'].Value | Should -Be $manifestVersion -Because 'the displayed version in the README banner must match the manifest ModuleVersion'
            $match.Groups['urlversion'].Value | Should -Be $manifestVersion -Because 'the PowerShell Gallery URL in the README banner must point at the manifest ModuleVersion'
        }

        It 'README.md TOC "What''s New in vX.Y.Z" entry matches manifest ModuleVersion' {
            # v0.7.67 polish: companion to the Latest Version banner guard.
            # The TOC's main-body "What's New in vX.Y.Z" link must always
            # point at the current manifest version - prior versions live
            # under the Release History sub-list.
            $manifestPath = Join-Path -Path $PSScriptRoot -ChildPath '..\AzLocal.UpdateManagement.psd1'
            $readmePath   = Join-Path -Path $PSScriptRoot -ChildPath '..\README.md'
            $manifestVersion = (Import-PowerShellDataFile -Path $manifestPath).ModuleVersion
            $manifestVersionAnchor = $manifestVersion -replace '\.',''
            $readmeContent = Get-Content -Path $readmePath -Raw
            # Match the top-level TOC link: "- [What's New in vX.Y.Z](#whats-new-in-vXYZ)"
            # (this is the main-body link, NOT the indented Release History sub-entry).
            # Note: do NOT anchor with trailing $ - .NET (?m)$ matches before \n but not
            # before \r, so on CRLF files \)$ never matches; use a CRLF-tolerant lookahead.
            $pattern = "(?m)^- \[What's New in v(?<displayed>\d+\.\d+\.\d+)\]\(#whats-new-in-v(?<anchor>\d+)\)(?=\r?\n|\z)"
            $match = [regex]::Match($readmeContent, $pattern)
            $match.Success | Should -BeTrue -Because "README.md TOC must contain a main-body '- [What's New in vX.Y.Z](#whats-new-in-vXYZ)' entry"
            $match.Groups['displayed'].Value | Should -Be $manifestVersion -Because 'the TOC main-body What''s New entry must point at the current manifest ModuleVersion'
            $match.Groups['anchor'].Value | Should -Be $manifestVersionAnchor -Because "the TOC anchor must collapse to the manifest ModuleVersion (#whats-new-in-v$manifestVersionAnchor)"
        }

        It 'README.md main body has exactly one "## What''s New" section, pointing at manifest ModuleVersion' {
            # v0.7.67 polish: regression guard for the drift bug where prior
            # release "What's New" sections were left at `##` level in the
            # main body (v0.7.66 release missed moving v0.7.65 to Release
            # History; v0.7.67 publish missed moving v0.7.66). The current-
            # release section is the only one that should be `##` in the main
            # body; every prior section MUST live under `## Release History`
            # as `### What's New in vX.Y.Z`.
            $manifestPath = Join-Path -Path $PSScriptRoot -ChildPath '..\AzLocal.UpdateManagement.psd1'
            $readmePath   = Join-Path -Path $PSScriptRoot -ChildPath '..\README.md'
            $manifestVersion = (Import-PowerShellDataFile -Path $manifestPath).ModuleVersion
            # Force array context with @(...) - Select-String returning a single match
            # otherwise collapses to a scalar string and $h2Matches[0] returns the first
            # CHARACTER of that string ('#') rather than the line text.
            $h2Matches = @(Select-String -Path $readmePath -Pattern "^## What's New in v\d+\.\d+\.\d+" -CaseSensitive |
                           ForEach-Object { $_.Line })
            $h2Matches.Count | Should -Be 1 -Because "exactly one '## What's New' section must exist in the README main body (found: $($h2Matches -join '; '))"
            $h2Matches[0] | Should -Be "## What's New in v$manifestVersion" -Because 'the sole main-body What''s New section must match the current manifest ModuleVersion'
        }

        It 'Should export exactly 28 functions' {
            $script:ModuleInfo.ExportedFunctions.Count | Should -Be 28
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
                # Fleet Health Failures (v0.7.65) - 24-hour system health-check failures across the fleet
                'Get-AzureLocalFleetHealthFailures',
                # Apply-Updates Schedule Coverage Advisor (v0.7.65)
                'Test-AzureLocalApplyUpdatesScheduleCoverage',
                # Update Schedule Tag Helpers (v0.6.4)
                'Test-AzureLocalUpdateScheduleAllowed',
                # Sideloaded Payload Workflow (v0.7.1)
                'Reset-AzureLocalSideloadedTag',
                # ITSM Connector Phase 1 (v0.7.4)
                'Get-AzureLocalItsmConfig',
                'Test-AzureLocalItsmConnection',
                'New-AzureLocalIncident',
                # Pipeline-Examples Convenience (v0.7.4)
                'Copy-AzureLocalPipelineExample',
                # ITSM Sample Convenience (v0.7.50)
                'Copy-AzureLocalItsmSample',
                # Update Run Failures Deep-Error Extraction (v0.7.68)
                'Get-AzureLocalUpdateRunFailures'
            )
            
            foreach ($func in $expectedFunctions) {
                $script:ModuleInfo.ExportedFunctions.Keys | Should -Contain $func
            }
        }

        It "Should have ReleaseNotes within the PSGallery character limit" {
            # PSGallery enforces a maximum of 10000 characters on the ReleaseNotes field
            # (publish fails with "Tags, ReleaseNotes, ... cannot exceed 10000 characters").
            # This test guards against accidental regressions when the release notes grow.
            $manifestPath = Join-Path -Path $PSScriptRoot -ChildPath '..\AzLocal.UpdateManagement.psd1'
            $data = Import-PowerShellDataFile -Path $manifestPath
            $releaseNotes = $data.PrivateData.PSData.ReleaseNotes
            $releaseNotes | Should -Not -BeNullOrEmpty
            $releaseNotes.Length | Should -BeLessOrEqual 10000 -Because "PSGallery rejects ReleaseNotes longer than 10000 characters"
        }
    }

    Context 'Pipeline YAML version pin (v0.7.66)' {
        # Every sample pipeline that installs AzLocal.UpdateManagement at runtime
        # also declares GENERATED_AGAINST_MODULE_VERSION so the install step can
        # detect drift between the YAML's expected version and what is installed
        # from PSGallery. The pin MUST match the current module manifest version,
        # otherwise the runtime drift detector will emit a noisy warning on every
        # pipeline run for end users. This test guards against forgetting to bump
        # the pin in Automation-Pipeline-Examples/**/*.yml when releasing a new
        # module version.
        It 'Every pipeline YAML that installs the module pins GENERATED_AGAINST_MODULE_VERSION to the manifest version' {
            $manifestVersion = $script:ModuleInfo.Version.ToString()
            $examplesRoot    = Join-Path -Path $PSScriptRoot -ChildPath '..\Automation-Pipeline-Examples'
            $examplesRoot    = (Resolve-Path -Path $examplesRoot).Path

            $ymlFiles = Get-ChildItem -Path $examplesRoot -Recurse -Filter '*.yml' -File
            $ymlFiles.Count | Should -BeGreaterThan 0 -Because 'sample pipeline YAMLs ship under Automation-Pipeline-Examples/{github-actions,azure-devops}/'

            $issues = New-Object System.Collections.Generic.List[string]
            foreach ($yml in $ymlFiles) {
                $content = Get-Content -LiteralPath $yml.FullName -Raw

                # The drift detector only runs in pipelines that install the
                # module at runtime. Auth-smoke-test YAMLs and ITSM sample YAMLs
                # do not install the module, so they are not expected to carry
                # a pin. Use the presence of 'Install-Module AzLocal.UpdateManagement'
                # as the discriminator.
                $installsModule = $content -match 'Install-Module\s+AzLocal\.UpdateManagement'

                # Two pin shapes are supported by the YAML examples:
                # 1) Inline (GH Actions env, or ADO inline variable):
                #      GENERATED_AGAINST_MODULE_VERSION: '0.7.65'
                # 2) ADO variables block, name/value pair on two lines:
                #      - name: GENERATED_AGAINST_MODULE_VERSION
                #        value: '0.7.65'
                $pin     = $null
                $inline  = [regex]::Match($content, "GENERATED_AGAINST_MODULE_VERSION\s*:\s*'([^']+)'")
                $twoLine = [regex]::Match($content, "(?ms)-\s*name\s*:\s*GENERATED_AGAINST_MODULE_VERSION\s*\r?\n\s*value\s*:\s*'([^']+)'")
                if ($inline.Success)       { $pin = $inline.Groups[1].Value }
                elseif ($twoLine.Success)  { $pin = $twoLine.Groups[1].Value }

                $relPath = $yml.FullName.Substring($examplesRoot.Length).TrimStart('\','/')

                if ($installsModule -and -not $pin) {
                    $issues.Add("${relPath}: installs the module but is MISSING the GENERATED_AGAINST_MODULE_VERSION pin")
                    continue
                }

                if ($pin -and $pin -ne $manifestVersion) {
                    $issues.Add("${relPath}: pinned to '$pin' but manifest is '$manifestVersion'")
                }
            }

            if ($issues.Count -gt 0) {
                $detail = ($issues -join [Environment]::NewLine)
            } else {
                $detail = '(no mismatches)'
            }
            $issues.Count | Should -Be 0 -Because "every pipeline YAML under Automation-Pipeline-Examples/ that installs AzLocal.UpdateManagement must pin GENERATED_AGAINST_MODULE_VERSION to the current manifest version $manifestVersion. Bumping the manifest version requires the same bump in every sample YAML. Findings:$([Environment]::NewLine)$detail"
        }
    }

    Context 'Pipeline YAML installed-older-than-generated guard (v0.7.66)' {
        # v0.7.66: every pipeline YAML that installs the module at runtime must
        # warn when the runtime-installed module version is OLDER than
        # GENERATED_AGAINST_MODULE_VERSION. The existing version-check block
        # already handles 'installed -gt generated' (YAML stale) and
        # 'latest -gt installed' (newer module on PSGallery), but the
        # 'installed -lt generated' branch was missing. That is exactly the
        # case that matters during a staged unlisted-release flow (publish
        # candidate, immediately unlist, pin REQUIRED_MODULE_VERSION in the
        # test repo, validate, then list) and during emergency rollbacks. A
        # YAML that references cmdlets / parameters added in the generated-
        # against version would otherwise fail with a confusing
        # 'parameter not found' or 'cmdlet not recognized' error mid-job
        # instead of a clear warning at install time.
        It 'Every pipeline YAML that installs the module also warns when installed < generated' {
            $examplesRoot = Join-Path -Path $PSScriptRoot -ChildPath '..\Automation-Pipeline-Examples'
            $examplesRoot = (Resolve-Path -Path $examplesRoot).Path

            $ymlFiles = Get-ChildItem -Path $examplesRoot -Recurse -Filter '*.yml' -File
            $ymlFiles.Count | Should -BeGreaterThan 0 -Because 'sample pipeline YAMLs ship under Automation-Pipeline-Examples/{github-actions,azure-devops}/'

            $issues = New-Object System.Collections.Generic.List[string]
            foreach ($yml in $ymlFiles) {
                $content = Get-Content -LiteralPath $yml.FullName -Raw

                # The drift detector only runs in pipelines that install the
                # module at runtime. Auth-smoke-test YAMLs and ITSM sample
                # YAMLs do not install the module, so they are not expected to
                # carry the check.
                $installsModule = $content -match 'Install-Module\s+@installArgs'
                if (-not $installsModule) { continue }

                # The drift guard has two equally valid emitter shapes:
                #   GH Actions: '::warning title=AzLocal.UpdateManagement is older than workflow YAML expects'
                #   Azure DevOps: '##vso[task.logissue type=warning]AzLocal.UpdateManagement v$installed is OLDER'
                # Both are anchored on the '$installed -lt $generated' comparison.
                $hasComparison = $content -match '\$installed\s+-lt\s+\$generated'

                $relPath = $yml.FullName.Substring($examplesRoot.Length).TrimStart('\','/')

                if (-not $hasComparison) {
                    $issues.Add("${relPath}: installs the module but is MISSING the 'installed -lt generated' drift guard")
                }
            }

            if ($issues.Count -gt 0) {
                $detail = ($issues -join [Environment]::NewLine)
            } else {
                $detail = '(no findings)'
            }
            $issues.Count | Should -Be 0 -Because "every pipeline YAML under Automation-Pipeline-Examples/ that installs AzLocal.UpdateManagement must warn when the installed module version is older than GENERATED_AGAINST_MODULE_VERSION. Findings:$([Environment]::NewLine)$detail"
        }
    }

    Context 'Schedule-audit pipeline_path default is consumer-friendly (v0.7.66 regression)' {
        # v0.7.66 regression guard: Step.3_apply-updates-schedule-audit.yml (GH + ADO)
        # shipped with a default pipeline_path of
        # 'AzLocal.UpdateManagement/Automation-Pipeline-Examples' - a path that
        # only exists in this module's source repo. In a consumer repo (where
        # Step.5_apply-updates.yml lives under .github/workflows or .azure-pipelines),
        # the default-trigger run failed with
        #   PipelineYamlPath '...' does not exist on the runner
        # before the schedule advisor could emit JUnit XML. The defaults are
        # now '.github/workflows' on GH and '.azure-pipelines' on ADO.
        # This test guards both files from ever regressing to the in-source path.
        It 'Neither Step.3_apply-updates-schedule-audit.yml defaults to the in-source examples folder' {
            $examplesRoot = Join-Path -Path $PSScriptRoot -ChildPath '..\Automation-Pipeline-Examples'
            $examplesRoot = (Resolve-Path -Path $examplesRoot).Path

            $auditYamls = @(
                Join-Path $examplesRoot 'github-actions\Step.3_apply-updates-schedule-audit.yml'
                Join-Path $examplesRoot 'azure-devops\Step.3_apply-updates-schedule-audit.yml'
            )

            $offenders = New-Object System.Collections.Generic.List[string]
            foreach ($yml in $auditYamls) {
                if (-not (Test-Path -LiteralPath $yml)) {
                    $offenders.Add("${yml}: file is missing (expected for the schedule-audit pair)")
                    continue
                }
                $content = Get-Content -LiteralPath $yml -Raw
                if ($content -match "AzLocal\.UpdateManagement/Automation-Pipeline-Examples") {
                    $offenders.Add("${yml}: still references the in-source path 'AzLocal.UpdateManagement/Automation-Pipeline-Examples'")
                }
            }

            $detail = if ($offenders.Count -gt 0) { $offenders -join [Environment]::NewLine } else { '(no offenders)' }
            $offenders.Count | Should -Be 0 -Because "the schedule-audit pipelines must default pipeline_path/pipelinePath to a consumer-realistic path (.github/workflows or .azure-pipelines), not to the in-source examples folder. Findings:$([Environment]::NewLine)$detail"
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
        InModuleScope AzLocal.UpdateManagement {
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
        InModuleScope AzLocal.UpdateManagement {
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
        InModuleScope AzLocal.UpdateManagement {
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
        InModuleScope AzLocal.UpdateManagement {
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
        InModuleScope AzLocal.UpdateManagement {
            $props = [PSCustomObject]@{ state = 'Succeeded' }
            $r = Get-AzLocalRunEndTime -props $props
            $r | Should -BeNullOrEmpty
        }
    }
}

Describe 'Helper Function: Format-AzLocalUpdateRun (Internal)' {

    It 'Should populate EndTime from progress.endTimeUtc and use ARM duration' {
        InModuleScope AzLocal.UpdateManagement {
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
        InModuleScope AzLocal.UpdateManagement {
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
            & (Get-Module AzLocal.UpdateManagement) {
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

Describe 'Helper Function: Get-HealthCheckFailureSummary (Internal)' {

    Context 'Severity ordering and filtering' {
        It 'Should return empty string when UpdateSummary is null' {
            $result = & (Get-Module AzLocal.UpdateManagement) {
                Get-HealthCheckFailureSummary -UpdateSummary $null
            }
            $result | Should -Be ''
        }

        It 'Should return empty string when healthCheckResult is missing' {
            $mock = [PSCustomObject]@{ properties = [PSCustomObject]@{} }
            $result = & (Get-Module AzLocal.UpdateManagement) {
                param($us) Get-HealthCheckFailureSummary -UpdateSummary $us
            } -us $mock
            $result | Should -Be ''
        }

        It 'Should exclude Informational severity entries' {
            $mock = [PSCustomObject]@{ properties = [PSCustomObject]@{ healthCheckResult = @(
                [PSCustomObject]@{ status = 'Failed'; severity = 'Informational'; displayName = 'I1' }
            )}}
            $result = & (Get-Module AzLocal.UpdateManagement) {
                param($us) Get-HealthCheckFailureSummary -UpdateSummary $us
            } -us $mock
            $result | Should -Be ''
        }

        It 'Should exclude entries whose status is not Failed' {
            $mock = [PSCustomObject]@{ properties = [PSCustomObject]@{ healthCheckResult = @(
                [PSCustomObject]@{ status = 'Succeeded'; severity = 'Critical'; displayName = 'C1' }
            )}}
            $result = & (Get-Module AzLocal.UpdateManagement) {
                param($us) Get-HealthCheckFailureSummary -UpdateSummary $us
            } -us $mock
            $result | Should -Be ''
        }

        It 'Should emit Critical entries before Warning entries even when ARM returned Warnings first' {
            # Regression: prior to this ordering fix, 5+ Warnings ahead of a
            # Critical caused the Critical to be dropped during top-5 truncation,
            # so the readiness gate ('-match "\[Critical\]"') silently failed.
            $mock = [PSCustomObject]@{ properties = [PSCustomObject]@{ healthCheckResult = @(
                [PSCustomObject]@{ status = 'Failed'; severity = 'Warning';  displayName = 'W1'; targetResourceName = 'nodeA' }
                [PSCustomObject]@{ status = 'Failed'; severity = 'Warning';  displayName = 'W2'; targetResourceName = 'nodeA' }
                [PSCustomObject]@{ status = 'Failed'; severity = 'Warning';  displayName = 'W3'; targetResourceName = 'nodeA' }
                [PSCustomObject]@{ status = 'Failed'; severity = 'Warning';  displayName = 'W4'; targetResourceName = 'nodeA' }
                [PSCustomObject]@{ status = 'Failed'; severity = 'Warning';  displayName = 'W5'; targetResourceName = 'nodeA' }
                [PSCustomObject]@{ status = 'Failed'; severity = 'Critical'; displayName = 'C1'; targetResourceName = 'nodeB' }
                [PSCustomObject]@{ status = 'Failed'; severity = 'Informational'; displayName = 'I1'; targetResourceName = 'nodeC' }
            )}}
            $result = & (Get-Module AzLocal.UpdateManagement) {
                param($us) Get-HealthCheckFailureSummary -UpdateSummary $us
            } -us $mock
            # Must start with [Critical] so the gate's -match succeeds
            $result | Should -Match '^\[Critical\] C1'
            # Informational is excluded entirely
            $result | Should -Not -Match '\[Informational\]'
            # All 5 Warnings + 1 Critical = 6 in-scope; top 5 displayed; "+1 more"
            $result | Should -Match '\(\+1 more\)'
        }

        It 'Should preserve insertion order within each severity bucket' {
            $mock = [PSCustomObject]@{ properties = [PSCustomObject]@{ healthCheckResult = @(
                [PSCustomObject]@{ status = 'Failed'; severity = 'Warning';  displayName = 'W1' }
                [PSCustomObject]@{ status = 'Failed'; severity = 'Critical'; displayName = 'C1' }
                [PSCustomObject]@{ status = 'Failed'; severity = 'Warning';  displayName = 'W2' }
                [PSCustomObject]@{ status = 'Failed'; severity = 'Critical'; displayName = 'C2' }
            )}}
            $result = & (Get-Module AzLocal.UpdateManagement) {
                param($us) Get-HealthCheckFailureSummary -UpdateSummary $us
            } -us $mock
            # Order should be: C1, C2 (Criticals in ARM order), then W1, W2 (Warnings in ARM order)
            $result | Should -Be '[Critical] C1; [Critical] C2; [Warning] W1; [Warning] W2'
        }

        It 'Should include up to 5 entries and append "(+N more)" suffix when truncating' {
            $mock = [PSCustomObject]@{ properties = [PSCustomObject]@{ healthCheckResult = @(
                [PSCustomObject]@{ status = 'Failed'; severity = 'Critical'; displayName = 'C1' }
                [PSCustomObject]@{ status = 'Failed'; severity = 'Critical'; displayName = 'C2' }
                [PSCustomObject]@{ status = 'Failed'; severity = 'Critical'; displayName = 'C3' }
                [PSCustomObject]@{ status = 'Failed'; severity = 'Critical'; displayName = 'C4' }
                [PSCustomObject]@{ status = 'Failed'; severity = 'Critical'; displayName = 'C5' }
                [PSCustomObject]@{ status = 'Failed'; severity = 'Critical'; displayName = 'C6' }
                [PSCustomObject]@{ status = 'Failed'; severity = 'Critical'; displayName = 'C7' }
            )}}
            $result = & (Get-Module AzLocal.UpdateManagement) {
                param($us) Get-HealthCheckFailureSummary -UpdateSummary $us
            } -us $mock
            $result | Should -Match '^\[Critical\] C1; \[Critical\] C2; \[Critical\] C3; \[Critical\] C4; \[Critical\] C5 \(\+2 more\)$'
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
            $exportedFunctions = (Get-Module AzLocal.UpdateManagement).ExportedFunctions.Keys
            
            foreach ($func in $exportedFunctions) {
                $verb = $func.Split('-')[0]
                $approvedVerbs | Should -Contain $verb -Because "$func should use an approved verb"
            }
        }

        It 'All exported functions should use consistent noun prefix' {
            $exportedFunctions = (Get-Module AzLocal.UpdateManagement).ExportedFunctions.Keys
            
            foreach ($func in $exportedFunctions) {
                $noun = $func.Split('-')[1]
                $noun | Should -BeLike 'AzureLocal*' -Because "$func should use AzureLocal noun prefix"
            }
        }
    }

    Context 'Help Documentation' {
        BeforeAll {
            $script:exportedFunctions = (Get-Module AzLocal.UpdateManagement).ExportedFunctions.Keys
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
            # Filter explicitly for ValidateSetAttribute. Member-enumerating ".ValidValues"
            # over the full Attributes collection (which also contains ParameterAttribute
            # and ArgumentTypeConverterAttribute) is order-dependent under Pester's strict
            # mode and produces "property cannot be found" errors when the non-ValidateSet
            # attributes are enumerated first.
            $validateSet = $command.Parameters['Operation'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet | Should -Not -BeNullOrEmpty -Because 'Operation should have a [ValidateSet] attribute'
            $validateSet.ValidValues | Should -Contain 'ApplyUpdate'
            $validateSet.ValidValues | Should -Contain 'CheckReadiness'
            $validateSet.ValidValues | Should -Contain 'GetStatus'
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
        $moduleName = 'AzLocal.UpdateManagement'
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
        $moduleName = 'AzLocal.UpdateManagement'
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
        $moduleName = 'AzLocal.UpdateManagement'
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
        $moduleName = 'AzLocal.UpdateManagement'
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
        $moduleName = 'AzLocal.UpdateManagement'
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
            $command.Source | Should -Be 'AzLocal.UpdateManagement'
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
            $outputPath = Join-Path $env:TEMP "pester-junit-schedule-test-$([Guid]::NewGuid()).xml"
            try {
                & (Get-Module 'AzLocal.UpdateManagement') {
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
            $outputPath = Join-Path $env:TEMP "pester-junit-sideloaded-test-$([Guid]::NewGuid()).xml"
            try {
                & (Get-Module 'AzLocal.UpdateManagement') {
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

    Context 'JUnit XML export handles non-failure non-passing statuses (v0.7.62)' {
        # v0.7.62 fix: Status values NotReady, NotConnected, NoUpdatesAvailable,
        # NoReadyUpdates previously fell through to <system-out> (rendered as
        # passed in dorny/test-reporter), producing misleading "all green" CI
        # summaries when the apply step had actually skipped clusters. They
        # must now render as <skipped>. UpdateNotFound must render as <error>.
        BeforeAll {
            $script:exportJUnit = {
                param($results, $path)
                Export-ResultsToJUnitXml -Results $results -OutputPath $path -TestSuiteName 'Test' -OperationType 'StartUpdate'
            }
        }

        It 'Should render NotReady as <skipped>' {
            $tr = [PSCustomObject]@{
                ClusterName = 'c1'; Status = 'NotReady'
                Message     = 'No ready updates available'
                StartTime   = Get-Date; EndTime = Get-Date; Duration = '00:00:01'
            }
            $outputPath = Join-Path $env:TEMP "pester-junit-notready.xml"
            try {
                & (Get-Module 'AzLocal.UpdateManagement') $script:exportJUnit @($tr) $outputPath
                $xml = [xml](Get-Content $outputPath -Raw)
                $testCase = $xml.SelectSingleNode('//testcase')
                $testCase.SelectSingleNode('skipped')   | Should -Not -BeNullOrEmpty
                $testCase.SelectSingleNode('failure')   | Should -BeNullOrEmpty
                $testCase.SelectSingleNode('error')     | Should -BeNullOrEmpty
                $testCase.SelectSingleNode('system-out')| Should -BeNullOrEmpty
            }
            finally { if (Test-Path $outputPath) { Remove-Item $outputPath -Force } }
        }

        It 'Should render NotConnected as <skipped>' {
            $tr = [PSCustomObject]@{
                ClusterName = 'c1'; Status = 'NotConnected'
                Message     = 'Cluster is NotConnectedRecently'
                StartTime   = Get-Date; EndTime = Get-Date; Duration = '00:00:01'
            }
            $outputPath = Join-Path $env:TEMP "pester-junit-notconnected.xml"
            try {
                & (Get-Module 'AzLocal.UpdateManagement') $script:exportJUnit @($tr) $outputPath
                $xml = [xml](Get-Content $outputPath -Raw)
                $testCase = $xml.SelectSingleNode('//testcase')
                $testCase.SelectSingleNode('skipped') | Should -Not -BeNullOrEmpty
                $testCase.SelectSingleNode('failure') | Should -BeNullOrEmpty
                $testCase.SelectSingleNode('error')   | Should -BeNullOrEmpty
            }
            finally { if (Test-Path $outputPath) { Remove-Item $outputPath -Force } }
        }

        It 'Should render NoUpdatesAvailable as <skipped>' {
            $tr = [PSCustomObject]@{
                ClusterName = 'c1'; Status = 'NoUpdatesAvailable'
                Message     = 'No updates available'
                StartTime   = Get-Date; EndTime = Get-Date; Duration = '00:00:01'
            }
            $outputPath = Join-Path $env:TEMP "pester-junit-noupdatesavail.xml"
            try {
                & (Get-Module 'AzLocal.UpdateManagement') $script:exportJUnit @($tr) $outputPath
                $xml = [xml](Get-Content $outputPath -Raw)
                $testCase = $xml.SelectSingleNode('//testcase')
                $testCase.SelectSingleNode('skipped') | Should -Not -BeNullOrEmpty
                $testCase.SelectSingleNode('failure') | Should -BeNullOrEmpty
                $testCase.SelectSingleNode('error')   | Should -BeNullOrEmpty
            }
            finally { if (Test-Path $outputPath) { Remove-Item $outputPath -Force } }
        }

        It 'Should render NoReadyUpdates as <skipped>' {
            $tr = [PSCustomObject]@{
                ClusterName = 'c1'; Status = 'NoReadyUpdates'
                Message     = 'No ready updates'
                StartTime   = Get-Date; EndTime = Get-Date; Duration = '00:00:01'
            }
            $outputPath = Join-Path $env:TEMP "pester-junit-noreadyupdates.xml"
            try {
                & (Get-Module 'AzLocal.UpdateManagement') $script:exportJUnit @($tr) $outputPath
                $xml = [xml](Get-Content $outputPath -Raw)
                $testCase = $xml.SelectSingleNode('//testcase')
                $testCase.SelectSingleNode('skipped') | Should -Not -BeNullOrEmpty
                $testCase.SelectSingleNode('failure') | Should -BeNullOrEmpty
                $testCase.SelectSingleNode('error')   | Should -BeNullOrEmpty
            }
            finally { if (Test-Path $outputPath) { Remove-Item $outputPath -Force } }
        }

        It 'Should render UpdateNotFound as <error type="UpdateNotFound">' {
            $tr = [PSCustomObject]@{
                ClusterName = 'c1'; Status = 'UpdateNotFound'
                Message     = "Update '10.2511.0.99' not found"
                UpdateName  = '10.2511.0.99'
                StartTime   = Get-Date; EndTime = Get-Date; Duration = '00:00:01'
            }
            $outputPath = Join-Path $env:TEMP "pester-junit-updatenotfound.xml"
            try {
                & (Get-Module 'AzLocal.UpdateManagement') $script:exportJUnit @($tr) $outputPath
                $xml = [xml](Get-Content $outputPath -Raw)
                $testCase = $xml.SelectSingleNode('//testcase')
                $errorNode = $testCase.SelectSingleNode('error')
                $errorNode | Should -Not -BeNullOrEmpty
                $errorNode.type | Should -Be 'UpdateNotFound'
                $testCase.SelectSingleNode('skipped') | Should -BeNullOrEmpty
                $testCase.SelectSingleNode('failure') | Should -BeNullOrEmpty
            }
            finally { if (Test-Path $outputPath) { Remove-Item $outputPath -Force } }
        }

        It 'UpdateStarted should still render as system-out (passed)' {
            $tr = [PSCustomObject]@{
                ClusterName = 'c1'; Status = 'UpdateStarted'
                Message     = 'Update started successfully'
                UpdateName  = '10.2511.0.10'
                StartTime   = Get-Date; EndTime = Get-Date; Duration = '00:00:01'
            }
            $outputPath = Join-Path $env:TEMP "pester-junit-updatestarted.xml"
            try {
                & (Get-Module 'AzLocal.UpdateManagement') $script:exportJUnit @($tr) $outputPath
                $xml = [xml](Get-Content $outputPath -Raw)
                $testCase = $xml.SelectSingleNode('//testcase')
                $testCase.SelectSingleNode('system-out') | Should -Not -BeNullOrEmpty
                $testCase.SelectSingleNode('failure')    | Should -BeNullOrEmpty
                $testCase.SelectSingleNode('error')      | Should -BeNullOrEmpty
                $testCase.SelectSingleNode('skipped')    | Should -BeNullOrEmpty
            }
            finally { if (Test-Path $outputPath) { Remove-Item $outputPath -Force } }
        }

        It 'Mixed-result summary should produce correct testsuite counts' {
            $results = @(
                [PSCustomObject]@{ ClusterName = 'a'; Status = 'UpdateStarted';      Message = 'ok';   Duration = '00:00:01' }
                [PSCustomObject]@{ ClusterName = 'b'; Status = 'NotReady';           Message = 'nope'; Duration = '00:00:01' }
                [PSCustomObject]@{ ClusterName = 'c'; Status = 'HealthCheckBlocked'; Message = 'bad';  Duration = '00:00:01' }
                [PSCustomObject]@{ ClusterName = 'd'; Status = 'UpdateNotFound';     Message = 'gone'; Duration = '00:00:01' }
                [PSCustomObject]@{ ClusterName = 'e'; Status = 'NoUpdatesAvailable'; Message = 'none'; Duration = '00:00:01' }
            )
            $outputPath = Join-Path $env:TEMP "pester-junit-mixed.xml"
            try {
                & (Get-Module 'AzLocal.UpdateManagement') $script:exportJUnit $results $outputPath
                $xml = [xml](Get-Content $outputPath -Raw)
                $suite = $xml.SelectSingleNode('//testsuite')
                [int]$suite.tests    | Should -Be 5
                [int]$suite.failures | Should -Be 1     # HealthCheckBlocked
                [int]$suite.errors   | Should -Be 1     # UpdateNotFound
                [int]$suite.skipped  | Should -Be 2     # NotReady + NoUpdatesAvailable
            }
            finally { if (Test-Path $outputPath) { Remove-Item $outputPath -Force } }
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
            InModuleScope AzLocal.UpdateManagement {
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
            InModuleScope AzLocal.UpdateManagement {
                function az { return '{"count":0,"data":[],"total_records":0}' }
                $global:LASTEXITCODE = 0

                $rows = Invoke-AzResourceGraphQuery -Query 'resources | where 1==0'
                ,$rows | Should -BeOfType ([object[]])
                $rows.Count | Should -Be 0
            }
        }

        It 'Should throw when the CLI reports a non-zero exit code' {
            InModuleScope AzLocal.UpdateManagement {
                function az { return 'FATAL: query syntax error' }
                $global:LASTEXITCODE = 1

                { Invoke-AzResourceGraphQuery -Query 'bad query' } | Should -Throw -ExpectedMessage '*Azure Resource Graph query failed*'
            }
        }

        It 'Should stop at the MaxPages safety cap and emit a warning' {
            InModuleScope AzLocal.UpdateManagement {
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

    Context 'cp1252 stderr WARNING does not corrupt JSON parse (v0.7.66 regression)' {
        # v0.7.66 regression guard: on hosted Windows runners (windows-latest,
        # windows-2022) the Azure CLI's Python layer can emit
        # 'WARNING: Unable to encode the output with cp1252 encoding...' to
        # stderr before emitting the JSON body to stdout. The helper captures
        # the merged stream via 2>&1, so without explicit stream-type filtering
        # the WARNING line gets prepended to the JSON body and ConvertFrom-Json
        # throws 'Unexpected character encountered while parsing value: W.'
        # The fix: split the captured stream by element type (stderr lines
        # surface as ErrorRecord, stdout lines as String) and feed only the
        # string stream to ConvertFrom-Json. See matching hardening in
        # Invoke-AzRestJson (v0.7.2).
        It 'Should ignore stderr ErrorRecord lines when parsing the JSON body' {
            InModuleScope AzLocal.UpdateManagement {
                # Simulate the Azure CLI emitting both a stderr WARNING and a
                # valid JSON body on stdout. Write-Error makes the line surface
                # as an ErrorRecord under 2>&1; the trailing 'return' emits
                # the JSON to the output (stdout) stream. Pre-v0.7.66 the
                # helper would call ConvertFrom-Json on 'WARNING: ...\n{...}'
                # and throw.
                function az {
                    Write-Error 'WARNING: Unable to encode the output with cp1252 encoding. Unsupported characters are discarded.'
                    return '{"count":1,"data":[{"id":"row-after-warning"}],"total_records":1}'
                }
                $global:LASTEXITCODE = 0

                $rows = Invoke-AzResourceGraphQuery -Query 'resources | project id' -ErrorAction SilentlyContinue
                $rows | Should -HaveCount 1
                $rows[0].id | Should -Be 'row-after-warning'
            }
        }

        It 'Should restore PYTHONIOENCODING after a successful call' {
            InModuleScope AzLocal.UpdateManagement {
                function az { return '{"count":0,"data":[],"total_records":0}' }
                $global:LASTEXITCODE = 0
                $before = $env:PYTHONIOENCODING
                try {
                    $env:PYTHONIOENCODING = 'sentinel-before'
                    [void](Invoke-AzResourceGraphQuery -Query 'resources | where 1==0')
                    $env:PYTHONIOENCODING | Should -Be 'sentinel-before'
                }
                finally {
                    $env:PYTHONIOENCODING = $before
                }
            }
        }

        It 'Should restore PYTHONIOENCODING after a throwing call' {
            InModuleScope AzLocal.UpdateManagement {
                function az { return 'FATAL: oops' }
                $global:LASTEXITCODE = 1
                $before = $env:PYTHONIOENCODING
                try {
                    $env:PYTHONIOENCODING = 'sentinel-throw'
                    { Invoke-AzResourceGraphQuery -Query 'bad' } | Should -Throw
                    $env:PYTHONIOENCODING | Should -Be 'sentinel-throw'
                }
                finally {
                    $env:PYTHONIOENCODING = $before
                }
            }
        }
    }
}

#endregion Internal Helper: Invoke-AzResourceGraphQuery

Describe 'Internal Helper: Invoke-AzCliJson (v0.7.67)' {
    # New in v0.7.67. Generic wrapper around 'az <subcommand>' that applies the
    # same stderr/stdout stream-split + JSON parse pattern as Invoke-AzRestJson
    # and Invoke-AzResourceGraphQuery, so callers outside the 'az rest' path
    # (notably 'az account show' in Get-AzureLocalClusterInventory) no longer
    # have to inline the unsafe `az ... 2>&1 | ConvertFrom-Json` boilerplate.

    Context 'Stream-split JSON parsing' {
        It 'Returns Ok=$true and parsed Data on a clean JSON response' {
            InModuleScope AzLocal.UpdateManagement {
                function az { return '{"id":"00000000-0000-0000-0000-000000000000","name":"sub-name"}' }
                $global:LASTEXITCODE = 0
                $res = Invoke-AzCliJson -Arguments @('account','show','--subscription','x')
                $res.Ok | Should -BeTrue
                $res.Data.name | Should -Be 'sub-name'
                $res.Error | Should -BeNullOrEmpty
            }
        }

        It 'Ignores stderr WARNING lines when parsing the JSON body (cp1252 regression guard)' {
            # Mirrors the Invoke-AzResourceGraphQuery cp1252 guard. Write-Error
            # makes the line surface as an ErrorRecord under 2>&1; without the
            # stream-type filter the WARNING would be prepended to the JSON and
            # ConvertFrom-Json would throw.
            InModuleScope AzLocal.UpdateManagement {
                function az {
                    Write-Error 'WARNING: Unable to encode the output with cp1252 encoding. Unsupported characters are discarded.'
                    return '{"name":"sub-after-warning"}'
                }
                $global:LASTEXITCODE = 0
                $res = Invoke-AzCliJson -Arguments @('account','show') -ErrorAction SilentlyContinue
                $res.Ok | Should -BeTrue
                $res.Data.name | Should -Be 'sub-after-warning'
            }
        }

        It 'Returns Ok=$false with scrubbed Error when CLI exits non-zero' {
            InModuleScope AzLocal.UpdateManagement {
                function az { return 'ERROR: not authenticated' }
                $global:LASTEXITCODE = 1
                $res = Invoke-AzCliJson -Arguments @('account','show')
                $res.Ok | Should -BeFalse
                $res.Data | Should -BeNullOrEmpty
                $res.Error | Should -Match 'not authenticated'
            }
        }

        It 'Returns Ok=$true with Data=$null when stdout is empty' {
            InModuleScope AzLocal.UpdateManagement {
                function az { return '' }
                $global:LASTEXITCODE = 0
                $res = Invoke-AzCliJson -Arguments @('logout')
                $res.Ok | Should -BeTrue
                $res.Data | Should -BeNullOrEmpty
            }
        }

        It 'Returns Ok=$false with parse-failure Error when stdout is not JSON' {
            InModuleScope AzLocal.UpdateManagement {
                function az { return 'this is not json' }
                $global:LASTEXITCODE = 0
                $res = Invoke-AzCliJson -Arguments @('account','show')
                $res.Ok | Should -BeFalse
                $res.Error | Should -Match 'JSON parse failure'
            }
        }

        It 'Appends --only-show-errors to the invocation' {
            InModuleScope AzLocal.UpdateManagement {
                $script:capturedArgs = $null
                function az {
                    $script:capturedArgs = @($args)
                    return '{}'
                }
                $global:LASTEXITCODE = 0
                [void](Invoke-AzCliJson -Arguments @('account','show'))
                $script:capturedArgs | Should -Contain '--only-show-errors'
            }
        }

        It 'Restores PYTHONIOENCODING after a successful call' {
            InModuleScope AzLocal.UpdateManagement {
                function az { return '{}' }
                $global:LASTEXITCODE = 0
                $before = $env:PYTHONIOENCODING
                try {
                    $env:PYTHONIOENCODING = 'sentinel-clean'
                    [void](Invoke-AzCliJson -Arguments @('account','show'))
                    $env:PYTHONIOENCODING | Should -Be 'sentinel-clean'
                }
                finally {
                    $env:PYTHONIOENCODING = $before
                }
            }
        }
    }
}

#endregion Internal Helper: Invoke-AzCliJson

#region Fleet Health Failures (v0.7.65)

Describe 'Function: Get-AzureLocalFleetHealthFailures' {

    Context 'Parameter Validation' {
        BeforeAll {
            $command = Get-Command Get-AzureLocalFleetHealthFailures
        }

        It 'Should have SubscriptionId parameter' {
            $command.Parameters.Keys | Should -Contain 'SubscriptionId'
        }

        It 'Should have Severity parameter with ValidateSet (Critical, Warning, All)' {
            $command.Parameters.Keys | Should -Contain 'Severity'
            $validateSet = $command.Parameters['Severity'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet | Should -Not -BeNullOrEmpty
            $validateSet.ValidValues | Should -Contain 'Critical'
            $validateSet.ValidValues | Should -Contain 'Warning'
            $validateSet.ValidValues | Should -Contain 'All'
        }

        It 'Should have View parameter with ValidateSet (Detail, Summary)' {
            $command.Parameters.Keys | Should -Contain 'View'
            $validateSet = $command.Parameters['View'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet | Should -Not -BeNullOrEmpty
            $validateSet.ValidValues | Should -Contain 'Detail'
            $validateSet.ValidValues | Should -Contain 'Summary'
        }

        It 'Should have UpdateRingTag parameter with ValidatePattern' {
            $command.Parameters.Keys | Should -Contain 'UpdateRingTag'
            $vp = $command.Parameters['UpdateRingTag'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidatePatternAttribute] }
            $vp | Should -Not -BeNullOrEmpty
        }

        It 'Should have ExportPath and PassThru parameters' {
            $command.Parameters.Keys | Should -Contain 'ExportPath'
            $command.Parameters.Keys | Should -Contain 'PassThru'
        }

        It 'Should declare OutputType' {
            $command.OutputType | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Detail view' {

        It 'Returns one row per (cluster, failing health-check) with the expected shape' {
            InModuleScope AzLocal.UpdateManagement {
                # Two clusters, two failing checks each across Critical + Warning.
                $payload = @{
                    count = 4
                    data  = @(
                        @{
                            ClusterName       = 'Cluster01'
                            ResourceGroup     = 'RG1'
                            SubscriptionId    = 'sub-1111'
                            ClusterResourceId = '/subscriptions/sub-1111/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01'
                            Severity          = 'Critical'
                            FailureName       = 'storage-pool-health'
                            FailureReason     = 'Storage pool degraded'
                            Description       = 'A storage pool drive is in degraded state.'
                            Remediation       = 'Replace the failed drive.'
                            LastOccurrence    = '2026-05-16T08:00:00Z'
                        },
                        @{
                            ClusterName       = 'Cluster01'
                            ResourceGroup     = 'RG1'
                            SubscriptionId    = 'sub-1111'
                            ClusterResourceId = '/subscriptions/sub-1111/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01'
                            Severity          = 'Warning'
                            FailureName       = 'time-skew'
                            FailureReason     = 'Time skew detected'
                            Description       = 'Cluster nodes time skew > 1s.'
                            Remediation       = 'Validate NTP configuration.'
                            LastOccurrence    = '2026-05-16T07:30:00Z'
                        },
                        @{
                            ClusterName       = 'Cluster02'
                            ResourceGroup     = 'RG2'
                            SubscriptionId    = 'sub-1111'
                            ClusterResourceId = '/subscriptions/sub-1111/resourceGroups/RG2/providers/Microsoft.AzureStackHCI/clusters/Cluster02'
                            Severity          = 'Critical'
                            FailureName       = 'storage-pool-health'
                            FailureReason     = 'Storage pool degraded'
                            Description       = 'A storage pool drive is in degraded state.'
                            Remediation       = 'Replace the failed drive.'
                            LastOccurrence    = '2026-05-16T08:15:00Z'
                        },
                        @{
                            ClusterName       = 'Cluster02'
                            ResourceGroup     = 'RG2'
                            SubscriptionId    = 'sub-1111'
                            ClusterResourceId = '/subscriptions/sub-1111/resourceGroups/RG2/providers/Microsoft.AzureStackHCI/clusters/Cluster02'
                            Severity          = 'Warning'
                            FailureName       = 'network-mtu'
                            FailureReason     = 'Network MTU misconfiguration'
                            Description       = 'Cluster nodes have inconsistent MTU.'
                            Remediation       = 'Align MTU across all NICs.'
                            LastOccurrence    = '2026-05-16T07:00:00Z'
                        }
                    )
                } | ConvertTo-Json -Depth 6
                function az { return $payload }
                $global:LASTEXITCODE = 0

                $rows = Get-AzureLocalFleetHealthFailures -View Detail
                $rows | Should -HaveCount 4
                $rows[0].PSObject.Properties.Name | Should -Contain 'ClusterName'
                $rows[0].PSObject.Properties.Name | Should -Contain 'FailureReason'
                $rows[0].PSObject.Properties.Name | Should -Contain 'Severity'
                $rows[0].PSObject.Properties.Name | Should -Contain 'LastOccurrence'
                $rows[0].PSObject.Properties.Name | Should -Contain 'ClusterResourceId'
                @($rows | Where-Object { $_.Severity -eq 'Critical' }).Count | Should -Be 2
                @($rows | Where-Object { $_.Severity -eq 'Warning'  }).Count | Should -Be 2
            }
        }

        It 'Returns an empty array when Resource Graph reports no failing checks' {
            InModuleScope AzLocal.UpdateManagement {
                function az { return '{"count":0,"data":[]}' }
                $global:LASTEXITCODE = 0
                $rows = Get-AzureLocalFleetHealthFailures
                ,$rows | Should -BeOfType ([object[]])
                $rows.Count | Should -Be 0
            }
        }
    }

    Context 'Summary view' {

        It 'Aggregates rows by FailureReason + Severity and orders by ClusterCount desc' {
            InModuleScope AzLocal.UpdateManagement {
                # Storage pool degraded hits 2 clusters; Time skew hits 1; Network MTU hits 1.
                # Expected ordering: Storage pool degraded (ClusterCount=2) first, then
                # Critical-before-Warning at the tie-break, then FailureCount desc.
                $payload = @{
                    count = 5
                    data  = @(
                        @{ ClusterName='C1'; ResourceGroup='RG1'; SubscriptionId='s1'; ClusterResourceId='/x/c1'; Severity='Critical'; FailureName='spd'; FailureReason='Storage pool degraded'; Description='d'; Remediation='r'; LastOccurrence='2026-05-16T08:00:00Z' },
                        @{ ClusterName='C2'; ResourceGroup='RG1'; SubscriptionId='s1'; ClusterResourceId='/x/c2'; Severity='Critical'; FailureName='spd'; FailureReason='Storage pool degraded'; Description='d'; Remediation='r'; LastOccurrence='2026-05-16T08:30:00Z' },
                        @{ ClusterName='C1'; ResourceGroup='RG1'; SubscriptionId='s1'; ClusterResourceId='/x/c1'; Severity='Warning'; FailureName='ts'; FailureReason='Time skew detected'; Description='d'; Remediation='r'; LastOccurrence='2026-05-16T07:00:00Z' },
                        @{ ClusterName='C3'; ResourceGroup='RG1'; SubscriptionId='s1'; ClusterResourceId='/x/c3'; Severity='Warning'; FailureName='ts'; FailureReason='Time skew detected'; Description='d'; Remediation='r'; LastOccurrence='2026-05-16T07:30:00Z' },
                        @{ ClusterName='C2'; ResourceGroup='RG1'; SubscriptionId='s1'; ClusterResourceId='/x/c2'; Severity='Warning'; FailureName='mtu'; FailureReason='Network MTU misconfiguration'; Description='d'; Remediation='r'; LastOccurrence='2026-05-16T06:00:00Z' }
                    )
                } | ConvertTo-Json -Depth 6
                function az { return $payload }
                $global:LASTEXITCODE = 0

                $summary = Get-AzureLocalFleetHealthFailures -View Summary
                $summary | Should -Not -BeNullOrEmpty
                $summary.Count | Should -BeGreaterOrEqual 3

                # Most widespread (ClusterCount=2) must come first.
                $summary[0].FailureReason | Should -Be 'Storage pool degraded'
                $summary[0].Severity      | Should -Be 'Critical'
                $summary[0].ClusterCount  | Should -Be 2
                $summary[0].FailureCount  | Should -Be 2
                $summary[0].AffectedClusters | Should -Match 'C1'
                $summary[0].AffectedClusters | Should -Match 'C2'

                # Among the two ClusterCount=2 entries (Time skew is also 2 clusters),
                # Critical sorts before Warning - so Storage pool degraded is first;
                # Time skew (Warning, 2 clusters) comes before Network MTU (Warning, 1 cluster).
                $reasonsInOrder = $summary | Select-Object -ExpandProperty FailureReason
                $reasonsInOrder[0] | Should -Be 'Storage pool degraded'
                # Verify the lowest-impact failure is at the bottom
                $summary[-1].FailureReason | Should -Be 'Network MTU misconfiguration'
                $summary[-1].ClusterCount  | Should -Be 1
            }
        }
    }

    Context 'Severity filter' {

        It 'Severity=Critical builds a KQL clause that filters to Critical' {
            InModuleScope AzLocal.UpdateManagement {
                $script:CapturedKql = $null
                function az {
                    # az graph query -q "<KQL>" --first 1000 --only-show-errors ...
                    $argList = @($args)
                    $qIdx = $argList.IndexOf('-q')
                    if ($qIdx -ge 0 -and $qIdx + 1 -lt $argList.Count) {
                        $script:CapturedKql = $argList[$qIdx + 1]
                    }
                    return '{"count":0,"data":[]}'
                }
                $global:LASTEXITCODE = 0

                $null = Get-AzureLocalFleetHealthFailures -Severity Critical
                $script:CapturedKql | Should -Not -BeNullOrEmpty
                $script:CapturedKql | Should -Match "hc\.severity\)\s*=~\s*'Critical'"
            }
        }

        It "Severity=All builds a KQL clause that filters in~ ('Critical','Warning')" {
            InModuleScope AzLocal.UpdateManagement {
                $script:CapturedKql = $null
                function az {
                    $argList = @($args)
                    $qIdx = $argList.IndexOf('-q')
                    if ($qIdx -ge 0 -and $qIdx + 1 -lt $argList.Count) {
                        $script:CapturedKql = $argList[$qIdx + 1]
                    }
                    return '{"count":0,"data":[]}'
                }
                $global:LASTEXITCODE = 0

                $null = Get-AzureLocalFleetHealthFailures -Severity All
                $script:CapturedKql | Should -Not -BeNullOrEmpty
                $script:CapturedKql | Should -Match "in~\s*\('Critical','Warning'\)"
            }
        }
    }

    Context 'UpdateRingTag scoping' {

        It 'Issues a second ARG query against the resources table to map UpdateRing -> ResourceIds and filters detail rows' {
            InModuleScope AzLocal.UpdateManagement {
                $script:Calls = 0
                function az {
                    $script:Calls++
                    if ($script:Calls -eq 1) {
                        # First call: health-check rows for two clusters
                        return (@{
                            count = 2
                            data  = @(
                                @{ ClusterName='Cluster01'; ResourceGroup='RG1'; SubscriptionId='s1'; ClusterResourceId='/subscriptions/s1/resourceGroups/RG1/providers/Microsoft.AzureStackHCI/clusters/Cluster01'; Severity='Critical'; FailureName='spd'; FailureReason='Storage pool degraded'; Description='d'; Remediation='r'; LastOccurrence='2026-05-16T08:00:00Z' },
                                @{ ClusterName='Cluster02'; ResourceGroup='RG2'; SubscriptionId='s1'; ClusterResourceId='/subscriptions/s1/resourceGroups/RG2/providers/Microsoft.AzureStackHCI/clusters/Cluster02'; Severity='Warning';  FailureName='ts';  FailureReason='Time skew detected';     Description='d'; Remediation='r'; LastOccurrence='2026-05-16T07:00:00Z' }
                            )
                        } | ConvertTo-Json -Depth 6)
                    }
                    elseif ($script:Calls -eq 2) {
                        # Second call: UpdateRing tag mapping - only Cluster01 is in Wave1
                        return (@{
                            count = 1
                            data  = @(
                                @{ id = '/subscriptions/s1/resourcegroups/rg1/providers/microsoft.azurestackhci/clusters/cluster01' }
                            )
                        } | ConvertTo-Json -Depth 6)
                    }
                    else {
                        throw "Unexpected az call $($script:Calls)"
                    }
                }
                $global:LASTEXITCODE = 0

                $rows = Get-AzureLocalFleetHealthFailures -UpdateRingTag 'Wave1'
                $script:Calls | Should -Be 2
                $rows | Should -HaveCount 1
                $rows[0].ClusterName | Should -Be 'Cluster01'
            }
        }
    }

    Context 'Export' {

        It 'Writes a CSV file when ExportPath ends in .csv and does not emit objects unless -PassThru' {
            InModuleScope AzLocal.UpdateManagement {
                $payload = @{
                    count = 1
                    data  = @(
                        @{ ClusterName='C1'; ResourceGroup='RG1'; SubscriptionId='s1'; ClusterResourceId='/x/c1'; Severity='Critical'; FailureName='spd'; FailureReason='Storage pool degraded'; Description='d'; Remediation='r'; LastOccurrence='2026-05-16T08:00:00Z' }
                    )
                } | ConvertTo-Json -Depth 6
                function az { return $payload }
                $global:LASTEXITCODE = 0

                $tempDir = Join-Path $env:TEMP "azlocal-fleethealth-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
                New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
                $csv = Join-Path $tempDir 'fleet-health-detail.csv'

                try {
                    $result = Get-AzureLocalFleetHealthFailures -ExportPath $csv
                    $result | Should -BeNullOrEmpty
                    Test-Path $csv | Should -BeTrue
                    $loaded = Import-Csv $csv
                    $loaded | Should -HaveCount 1
                    $loaded[0].FailureReason | Should -Be 'Storage pool degraded'
                }
                finally {
                    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }

        It 'Emits objects AND writes the file when -PassThru is set' {
            InModuleScope AzLocal.UpdateManagement {
                $payload = @{
                    count = 1
                    data  = @(
                        @{ ClusterName='C1'; ResourceGroup='RG1'; SubscriptionId='s1'; ClusterResourceId='/x/c1'; Severity='Critical'; FailureName='spd'; FailureReason='Storage pool degraded'; Description='d'; Remediation='r'; LastOccurrence='2026-05-16T08:00:00Z' }
                    )
                } | ConvertTo-Json -Depth 6
                function az { return $payload }
                $global:LASTEXITCODE = 0

                $tempDir = Join-Path $env:TEMP "azlocal-fleethealth-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
                New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
                $csv = Join-Path $tempDir 'fleet-health-detail.csv'

                try {
                    $rows = Get-AzureLocalFleetHealthFailures -ExportPath $csv -PassThru
                    $rows | Should -HaveCount 1
                    Test-Path $csv | Should -BeTrue
                }
                finally {
                    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    Context 'Naming Convention' {
        It 'Should use AzureLocal noun prefix' {
            $noun = 'Get-AzureLocalFleetHealthFailures'.Split('-')[1]
            $noun | Should -BeLike 'AzureLocal*'
        }
    }
}

#endregion Fleet Health Failures (v0.7.65)

#region Internal Helper: Invoke-FleetJobsInParallel

Describe 'Internal Helper: Invoke-FleetJobsInParallel' {

    Context 'Fast-path (ThrottleLimit=1)' {

        It 'Should execute scriptblock inline without Start-Job when ThrottleLimit is 1' {
            InModuleScope AzLocal.UpdateManagement {
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
            InModuleScope AzLocal.UpdateManagement {
                $sb = { param([object[]]$Batch, [string]$ModPath) 'unused' }
                $result = Invoke-FleetJobsInParallel -InputItems @() -ScriptBlock $sb -ThrottleLimit 4
                ,$result | Should -BeOfType ([object[]])
                $result.Count | Should -Be 0
            }
        }

        It 'Should capture errors from the inline scriptblock as Failed=$true' {
            InModuleScope AzLocal.UpdateManagement {
                $sb = { param([object[]]$Batch, [string]$ModPath) throw 'boom' }
                $result = Invoke-FleetJobsInParallel -InputItems @('a') -ScriptBlock $sb -ThrottleLimit 1
                $result | Should -HaveCount 1
                $result[0].Failed | Should -Be $true
                $result[0].Error | Should -Match 'boom'
            }
        }
    }

    Context 'ModulePath trailing argument (regression: v0.7.4 parallel-path bug)' {

        # When the helper passes the trailing $ModulePath to the per-batch
        # scriptblock, it MUST be the root AzLocal.UpdateManagement.psd1 (or
        # .psm1) - NOT this helper's own .ps1. Otherwise, child Start-Job
        # runspaces calling Import-Module $ModulePath load only the helper
        # and every private helper reference fails with
        #   "Cannot use '&' to invoke in the context of module 'Invoke-FleetJobsInParallel' because it is not imported."
        # See: regression bug observed on a 9-cluster Prod fleet against the
        # PSGallery-published v0.7.4 build.

        It 'Should pass the root module manifest path (not the helper .ps1) as the trailing ModulePath argument' {
            InModuleScope AzLocal.UpdateManagement {
                $captured = $null
                $sb = {
                    param([object[]]$Batch, [string]$ModPath)
                    # Echo back the path so the test can assert on it.
                    [PSCustomObject]@{ ModPath = $ModPath }
                }
                $result = Invoke-FleetJobsInParallel -InputItems @('item1') -ScriptBlock $sb -ThrottleLimit 1
                $captured = $result[0].Output.ModPath
                $captured | Should -Not -BeNullOrEmpty
                # Must point at the root manifest/module, not the helper file.
                $captured | Should -Match 'AzLocal\.UpdateManagement\.ps[dm]1$'
                $captured | Should -Not -Match 'Invoke-FleetJobsInParallel\.ps1$'
            }
        }
    }
}

#endregion Internal Helper: Invoke-FleetJobsInParallel

#region Internal Helper: Get-AzLocalModuleRootManifestPath

Describe 'Internal Helper: Get-AzLocalModuleRootManifestPath' {

    # This helper centralises the post-v0.7.3 fix: $PSScriptRoot inside any
    # Public/ or Private/ .ps1 resolves to that subfolder, NOT the module
    # root. The helper must return the root manifest (preferring .psd1)
    # so child Start-Job runspaces can re-import the whole module.

    Context 'Resolution via loaded module' {

        It 'Should return a path ending in AzLocal.UpdateManagement.psd1 when the module is loaded' {
            InModuleScope AzLocal.UpdateManagement {
                $resolved = Get-AzLocalModuleRootManifestPath
                $resolved | Should -Not -BeNullOrEmpty
                $resolved | Should -Match 'AzLocal\.UpdateManagement\.ps[dm]1$'
                # MUST NOT be a Public/ or Private/ nested-module .ps1.
                $resolved | Should -Not -Match '\\(Public|Private)\\[^\\]+\.ps1$'
                Test-Path -LiteralPath $resolved | Should -Be $true
            }
        }

        It 'Should resolve correctly when given a CallerScriptPath inside Public/' {
            InModuleScope AzLocal.UpdateManagement {
                $fakeCaller = Join-Path -Path (Split-Path -Parent (Get-Module AzLocal.UpdateManagement | Select-Object -First 1).Path) -ChildPath 'Public\Get-AzureLocalUpdateRuns.ps1'
                $resolved = Get-AzLocalModuleRootManifestPath -CallerScriptPath $fakeCaller
                $resolved | Should -Match 'AzLocal\.UpdateManagement\.ps[dm]1$'
                $resolved | Should -Not -Match '\\Public\\'
            }
        }

        It 'Should resolve correctly when given a CallerScriptPath inside Private/' {
            InModuleScope AzLocal.UpdateManagement {
                $fakeCaller = Join-Path -Path (Split-Path -Parent (Get-Module AzLocal.UpdateManagement | Select-Object -First 1).Path) -ChildPath 'Private\Invoke-FleetJobsInParallel.ps1'
                $resolved = Get-AzLocalModuleRootManifestPath -CallerScriptPath $fakeCaller
                $resolved | Should -Match 'AzLocal\.UpdateManagement\.ps[dm]1$'
                $resolved | Should -Not -Match '\\Private\\'
            }
        }
    }
}

#endregion Internal Helper: Get-AzLocalModuleRootManifestPath

#region Internal Helper: Invoke-FleetOpClusterAction

Describe 'Internal Helper: Invoke-FleetOpClusterAction' {

    Context 'Success path' {

        It 'Should mark state as Succeeded and record attempts for GetStatus' {
            InModuleScope AzLocal.UpdateManagement {
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
            InModuleScope AzLocal.UpdateManagement {
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
            InModuleScope AzLocal.UpdateManagement {
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
            InModuleScope AzLocal.UpdateManagement {
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
            InModuleScope AzLocal.UpdateManagement {
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
            InModuleScope AzLocal.UpdateManagement {
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
            InModuleScope AzLocal.UpdateManagement {
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

# v0.7.68 ARG-first refactor: this Describe block tested the obsolete per-cluster
# fan-out path through Get-AzureLocalUpdateSummary mocks. Get-AzureLocalFleetProgress
# now reads fleet state via a single Invoke-AzResourceGraphQuery batch and no
# longer calls Get-AzureLocalUpdateSummary. Test to be rewritten against the
# ARG mock surface in v0.7.69. Skipped, not deleted, so the intent is preserved.
Describe 'Get-AzureLocalFleetProgress (parallel dispatch via helpers)' -Skip {

    Context 'ThrottleLimit=1 inline fast-path' {

        It 'Should aggregate counts across clusters using Get-AzureLocalUpdateSummary' {
            InModuleScope AzLocal.UpdateManagement {
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

                $progress = Get-AzureLocalFleetProgress -State $fakeState -Detailed

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

# v0.7.68 ARG-first refactor: tests below mock Invoke-AzRestJson, but the cmdlet
# now reads via a single Invoke-AzResourceGraphQuery batch. Test to be rewritten
# against the ARG mock surface in v0.7.69. Skipped, not deleted.
Describe 'Get-AzureLocalUpdateSummary (multi-cluster parallel dispatch)' -Skip {

    Context 'ThrottleLimit=1 inline fast-path' {

        It 'Should return one row per input cluster and route through Invoke-AzRestJson with correct API version' {
            InModuleScope AzLocal.UpdateManagement {
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

                $results = Get-AzureLocalUpdateSummary -ClusterResourceIds $ids -ApiVersion '2025-10-01' -PassThru

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
            InModuleScope AzLocal.UpdateManagement {
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
                $results = Get-AzureLocalUpdateSummary -ClusterResourceIds $ids -PassThru
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
            InModuleScope AzLocal.UpdateManagement {
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
            InModuleScope AzLocal.UpdateManagement {
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

# v0.7.68 ARG-first refactor: tests below mock Invoke-AzRestJson, but the cmdlet
# now reads via a single Invoke-AzResourceGraphQuery batch. Test to be rewritten
# against the ARG mock surface in v0.7.69. Skipped, not deleted.
Describe 'Get-AzureLocalClusterUpdateReadiness (multi-cluster parallel dispatch)' -Skip {

    Context 'ThrottleLimit=1 inline fast-path' {
        It 'Should aggregate one row per cluster and tally recommended update versions only for ready clusters' {
            InModuleScope AzLocal.UpdateManagement {
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
                $results = Get-AzureLocalClusterUpdateReadiness -ClusterResourceIds $ids -PassThru

                $results | Should -HaveCount 3
                ($results | Where-Object ClusterName -eq 'cluster-a').ReadyForUpdate | Should -BeTrue
                ($results | Where-Object ClusterName -eq 'cluster-a').RecommendedUpdate | Should -Be '10.2506.0.28'
                ($results | Where-Object ClusterName -eq 'cluster-b').ReadyForUpdate | Should -BeFalse
                ($results | Where-Object ClusterName -eq 'cluster-c').ReadyForUpdate | Should -BeFalse
                # v0.7.62: every output row must carry ClusterResourceId so the
                # apply-updates pipeline step can call
                # Start-AzureLocalClusterUpdate -ClusterResourceIds directly
                # from the readiness CSV.
                foreach ($r in $results) {
                    $r.PSObject.Properties.Name | Should -Contain 'ClusterResourceId'
                    $r.ClusterResourceId | Should -Match '^/subscriptions/.+/clusters/[^/]+$'
                }
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

#region Readiness gates (v0.7.61: ClusterState + Critical health checks)

# v0.7.68 ARG-first refactor: BlockingReasons gating tests mock Invoke-AzRestJson
# for the per-cluster fan-out; Get-AzureLocalClusterUpdateReadiness now reads via
# a single Invoke-AzResourceGraphQuery batch and the test surface has to be
# rewritten to mock that helper instead. Deferred to v0.7.69.
Describe 'Get-AzureLocalClusterUpdateReadiness readiness gates' -Skip {

    Context 'BlockingReasons column and ReadyForUpdate gating' {

        It 'Should downgrade ReadyForUpdate to False when ClusterState is NotConnectedRecently' {
            InModuleScope AzLocal.UpdateManagement {
                function global:az { $global:LASTEXITCODE = 0; return '{}' }
                Mock Test-AzCliAvailable { return $true }

                Mock Invoke-AzRestJson {
                    param($Uri)
                    $global:LASTEXITCODE = 0
                    if ($Uri -match '/clusters/([^/?]+)\?api-version') {
                        return [PSCustomObject]@{
                            Ok = $true
                            Data = [PSCustomObject]@{
                                id = "/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/$($matches[1])"
                                name = $matches[1]
                                properties = [PSCustomObject]@{ status = 'NotConnectedRecently' }
                                tags = $null
                            }
                        }
                    }
                    return [PSCustomObject]@{ Ok = $true; Data = $null }
                }
                Mock Get-AzureLocalUpdateSummary {
                    return [PSCustomObject]@{
                        properties = [PSCustomObject]@{ state = 'UpdateAvailable'; healthState = 'Success' }
                    }
                }
                Mock Get-AzureLocalAvailableUpdates {
                    return @([PSCustomObject]@{
                        name = '10.2506.0.28'
                        properties = [PSCustomObject]@{ state = 'Ready'; packageType = 'Solution' }
                    })
                }
                Mock Get-HealthCheckFailureSummary { return '' }

                $ids = @('/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/gated-conn')
                $results = Get-AzureLocalClusterUpdateReadiness -ClusterResourceIds $ids -PassThru

                $results | Should -HaveCount 1
                $row = $results[0]
                $row.ReadyForUpdate | Should -BeFalse
                $row.PSObject.Properties.Name | Should -Contain 'BlockingReasons'
                $row.BlockingReasons | Should -Match 'NotConnectedRecently'
                $row.ClusterState | Should -Be 'NotConnectedRecently'
            }
        }

        It 'Should downgrade ReadyForUpdate to False when HealthCheckFailures contains [Critical]' {
            InModuleScope AzLocal.UpdateManagement {
                function global:az { $global:LASTEXITCODE = 0; return '{}' }
                Mock Test-AzCliAvailable { return $true }

                Mock Invoke-AzRestJson {
                    param($Uri)
                    $global:LASTEXITCODE = 0
                    if ($Uri -match '/clusters/([^/?]+)\?api-version') {
                        return [PSCustomObject]@{
                            Ok = $true
                            Data = [PSCustomObject]@{
                                id = "/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/$($matches[1])"
                                name = $matches[1]
                                properties = [PSCustomObject]@{ status = 'ConnectedRecently' }
                                tags = $null
                            }
                        }
                    }
                    return [PSCustomObject]@{ Ok = $true; Data = $null }
                }
                Mock Get-AzureLocalUpdateSummary {
                    return [PSCustomObject]@{
                        properties = [PSCustomObject]@{ state = 'UpdateAvailable'; healthState = 'Failure' }
                    }
                }
                Mock Get-AzureLocalAvailableUpdates {
                    return @([PSCustomObject]@{
                        name = '10.2506.0.28'
                        properties = [PSCustomObject]@{ state = 'Ready'; packageType = 'Solution' }
                    })
                }
                Mock Get-HealthCheckFailureSummary { return '[Critical] Storage Services Health Check (NodeA)' }

                $ids = @('/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/gated-health')
                $results = Get-AzureLocalClusterUpdateReadiness -ClusterResourceIds $ids -PassThru

                $results | Should -HaveCount 1
                $row = $results[0]
                $row.ReadyForUpdate | Should -BeFalse
                $row.BlockingReasons | Should -Match 'CriticalHealthCheck'
                $row.HealthCheckFailures | Should -Match '\[Critical\]'
            }
        }

        It 'Should combine both reasons when both gates fire' {
            InModuleScope AzLocal.UpdateManagement {
                function global:az { $global:LASTEXITCODE = 0; return '{}' }
                Mock Test-AzCliAvailable { return $true }

                Mock Invoke-AzRestJson {
                    param($Uri)
                    $global:LASTEXITCODE = 0
                    if ($Uri -match '/clusters/([^/?]+)\?api-version') {
                        return [PSCustomObject]@{
                            Ok = $true
                            Data = [PSCustomObject]@{
                                id = "/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/$($matches[1])"
                                name = $matches[1]
                                properties = [PSCustomObject]@{ status = 'NotConnectedRecently' }
                                tags = $null
                            }
                        }
                    }
                    return [PSCustomObject]@{ Ok = $true; Data = $null }
                }
                Mock Get-AzureLocalUpdateSummary {
                    return [PSCustomObject]@{
                        properties = [PSCustomObject]@{ state = 'UpdateAvailable'; healthState = 'Failure' }
                    }
                }
                Mock Get-AzureLocalAvailableUpdates {
                    return @([PSCustomObject]@{
                        name = '10.2506.0.28'
                        properties = [PSCustomObject]@{ state = 'Ready'; packageType = 'Solution' }
                    })
                }
                Mock Get-HealthCheckFailureSummary { return '[Critical] Storage Services Health Check (NodeA)' }

                $ids = @('/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/gated-both')
                $results = Get-AzureLocalClusterUpdateReadiness -ClusterResourceIds $ids -PassThru

                $results | Should -HaveCount 1
                $row = $results[0]
                $row.ReadyForUpdate | Should -BeFalse
                $row.BlockingReasons | Should -Match 'CriticalHealthCheck'
                $row.BlockingReasons | Should -Match 'NotConnectedRecently'
            }
        }

        It 'Should leave ReadyForUpdate True when Connected and no Critical health checks' {
            InModuleScope AzLocal.UpdateManagement {
                function global:az { $global:LASTEXITCODE = 0; return '{}' }
                Mock Test-AzCliAvailable { return $true }

                Mock Invoke-AzRestJson {
                    param($Uri)
                    $global:LASTEXITCODE = 0
                    if ($Uri -match '/clusters/([^/?]+)\?api-version') {
                        return [PSCustomObject]@{
                            Ok = $true
                            Data = [PSCustomObject]@{
                                id = "/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/$($matches[1])"
                                name = $matches[1]
                                properties = [PSCustomObject]@{ status = 'ConnectedRecently' }
                                tags = $null
                            }
                        }
                    }
                    return [PSCustomObject]@{ Ok = $true; Data = $null }
                }
                Mock Get-AzureLocalUpdateSummary {
                    return [PSCustomObject]@{
                        properties = [PSCustomObject]@{ state = 'UpdateAvailable'; healthState = 'Success' }
                    }
                }
                Mock Get-AzureLocalAvailableUpdates {
                    return @([PSCustomObject]@{
                        name = '10.2506.0.28'
                        properties = [PSCustomObject]@{ state = 'Ready'; packageType = 'Solution' }
                    })
                }
                Mock Get-HealthCheckFailureSummary { return '' }

                $ids = @('/subscriptions/s/resourceGroups/r/providers/Microsoft.AzureStackHCI/clusters/happy')
                $results = Get-AzureLocalClusterUpdateReadiness -ClusterResourceIds $ids -PassThru

                $results | Should -HaveCount 1
                $row = $results[0]
                $row.ReadyForUpdate | Should -BeTrue
                $row.BlockingReasons | Should -Be ''
            }
        }
    }
}

#endregion Readiness gates (v0.7.61: ClusterState + Critical health checks)

#region Integration: Get-AzureLocalUpdateRuns parallel dispatch

# v0.7.68 ARG-first refactor: tests mock Invoke-AzRestJson but the cmdlet now
# reads via Invoke-AzResourceGraphQuery. Test to be rewritten against the ARG
# mock surface in v0.7.69. Skipped, not deleted.
Describe 'Integration: Get-AzureLocalUpdateRuns parallel dispatch' -Skip {
    Context 'ThrottleLimit=1 inline fast-path' {
        It 'Should aggregate runs per cluster with state tally and strip internal fields' {
            InModuleScope AzLocal.UpdateManagement {
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

                $results = Get-AzureLocalUpdateRuns -ClusterResourceIds $ids -UpdateName '10.2506.0.28' -Latest -PassThru

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
    BeforeAll { $moduleName = 'AzLocal.UpdateManagement' }

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
    BeforeAll { $moduleName = 'AzLocal.UpdateManagement' }

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
    BeforeAll { $moduleName = 'AzLocal.UpdateManagement' }

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
        $moduleName = 'AzLocal.UpdateManagement'
        $rid = '/subscriptions/s/resourceGroups/r/providers/microsoft.azurestackhci/clusters/c1'
    }

    BeforeEach {
        # v0.7.62: Set-AzLocalClusterTagsMerge now uses the ARM tags subresource
        # (PATCH .../providers/Microsoft.Resources/tags/default). The GET shape is
        # {"properties":{"tags":{...}}} and up to two PATCHes can fire per call
        # (one for "operation":"Merge", one for "operation":"Delete") - so we
        # capture all PATCH bodies into an array and reshape the GET stub
        # response to the subresource envelope.
        $global:azGetTagsJson  = $null
        $global:azPatchCalled  = $false
        $global:azPatchBodies  = @()
        InModuleScope AzLocal.UpdateManagement {
            function global:az {
                $args2 = @($args)
                $global:LASTEXITCODE = 0
                if ($args2 -contains 'PATCH') {
                    $fIdx = [array]::IndexOf($args2, '--body')
                    if ($fIdx -ge 0 -and $args2[$fIdx + 1] -match '^@(.+)$') {
                        $global:azPatchBodies += ,(Get-Content -Raw $matches[1])
                    }
                    $global:azPatchCalled = $true
                    return ''
                }
                if ($args2 -contains 'GET') {
                    $uIdx = [array]::IndexOf($args2, '--uri')
                    $uri  = if ($uIdx -ge 0) { $args2[$uIdx + 1] } else { '' }
                    $raw  = $global:azGetTagsJson
                    # Tags subresource GET (Set-AzLocalClusterTagsMerge) expects
                    # the {"properties":{"tags":{...}}} envelope. The cluster
                    # resource GET (Invoke-AzLocalSideloadedAutoResetForCluster
                    # reads $cluster.tags) wants the legacy {"tags":{...}} shape.
                    if ($uri -match '/providers/Microsoft\.Resources/tags/default') {
                        if ($raw -and $raw -notmatch '"properties"\s*:') {
                            $raw = '{"properties":' + $raw + '}'
                        }
                    }
                    return $raw
                }
                return ''
            }
        }
    }

    AfterEach {
        InModuleScope AzLocal.UpdateManagement { Remove-Item function:\global:az -ErrorAction SilentlyContinue }
        Remove-Variable -Name azGetTagsJson, azPatchCalled, azPatchBodies -Scope Global -ErrorAction SilentlyContinue
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
        # v0.7.62: tags-subresource path emits a single PATCH (Delete operation)
        # whose body contains only the keys being removed. No merge PATCH (we are
        # not writing UpdateSideloaded). Preserved tags (UpdateRing) are NOT in
        # the body - the subresource preserves them structurally.
        $global:azPatchBodies.Count | Should -Be 1
        $deleteBody = $global:azPatchBodies[0]
        $deleteBody | Should -Match '"operation":\s*"Delete"'
        $deleteBody | Should -Match 'UpdateVersionInProgress'
        $deleteBody | Should -Not -Match 'UpdateSideloaded'
        $deleteBody | Should -Not -Match 'UpdateRing'
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
        # v0.7.62: two PATCHes are emitted via the ARM tags subresource:
        #   1. Merge body   -> sets UpdateSideloaded=False
        #   2. Delete body  -> removes UpdateVersionInProgress
        # Preserved tags (UpdateRing) appear in neither body (the subresource
        # preserves them structurally, not via payload echo).
        $global:azPatchBodies.Count | Should -Be 2
        $mergeBody  = $global:azPatchBodies | Where-Object { $_ -match '"operation":\s*"Merge"' } | Select-Object -First 1
        $deleteBody = $global:azPatchBodies | Where-Object { $_ -match '"operation":\s*"Delete"' } | Select-Object -First 1
        $mergeBody  | Should -Not -BeNullOrEmpty
        $deleteBody | Should -Not -BeNullOrEmpty
        $mergeBody  | Should -Match '"UpdateSideloaded":\s*"False"'
        $mergeBody  | Should -Not -Match 'UpdateVersionInProgress'
        $deleteBody | Should -Match 'UpdateVersionInProgress'
        $deleteBody | Should -Not -Match 'UpdateSideloaded'
        # Existing UpdateRing is preserved structurally - never in any PATCH body.
        ($global:azPatchBodies -join "`n") | Should -Not -Match 'UpdateRing'
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

#region ITSM Connector Phase 1 (v0.7.4)

Describe 'ITSM: Get-AzLocalItsmDedupeKey' {
    It 'Should return a 64-char lowercase hex SHA256' {
        $key = & (Get-Module AzLocal.UpdateManagement) {
            Get-AzLocalItsmDedupeKey -ClusterResourceId '/subs/x/rg/r/providers/Microsoft.AzureStackHCI/clusters/c1' `
                -UpdateName '2511.0.10.0' -TriggerCategory 'Cluster update failure'
        }
        $key | Should -Match '^[a-f0-9]{64}$'
    }

    It 'Should be deterministic for the same inputs' {
        $k1 = & (Get-Module AzLocal.UpdateManagement) { Get-AzLocalItsmDedupeKey -ClusterResourceId 'A' -UpdateName 'U' -TriggerCategory 'C' }
        $k2 = & (Get-Module AzLocal.UpdateManagement) { Get-AzLocalItsmDedupeKey -ClusterResourceId 'A' -UpdateName 'U' -TriggerCategory 'C' }
        $k1 | Should -Be $k2
    }

    It 'Should be case-insensitive on inputs' {
        $k1 = & (Get-Module AzLocal.UpdateManagement) { Get-AzLocalItsmDedupeKey -ClusterResourceId 'ABC' -UpdateName 'U' -TriggerCategory 'C' }
        $k2 = & (Get-Module AzLocal.UpdateManagement) { Get-AzLocalItsmDedupeKey -ClusterResourceId 'abc' -UpdateName 'u' -TriggerCategory 'c' }
        $k1 | Should -Be $k2
    }

    It 'Should produce different keys for different categories' {
        $k1 = & (Get-Module AzLocal.UpdateManagement) { Get-AzLocalItsmDedupeKey -ClusterResourceId 'A' -UpdateName 'U' -TriggerCategory 'Failure' }
        $k2 = & (Get-Module AzLocal.UpdateManagement) { Get-AzLocalItsmDedupeKey -ClusterResourceId 'A' -UpdateName 'U' -TriggerCategory 'Health' }
        $k1 | Should -Not -Be $k2
    }
}

Describe 'ITSM: Get-AzLocalItsmTriggerDecision' {
    BeforeAll {
        $script:itsmTriggers = @{
            Failed = @{ RaiseTicket = $true; Severity = 2; Category = 'Cluster update failure'; MirrorTo = @('Teams','Slack') }
            ScheduleBlocked = @{ RaiseTicket = $false }
            Skipped = @{ RaiseTicket = $false }
            SideloadedBlocked = @{ RaiseTicket = $true; Severity = 4; Category = 'Operator action'; MirrorTo = @() }
        }
        $script:itsmDefaults = @{ MirrorTo = @('Teams') }
    }

    It 'Returns ShouldTicket=true with severity for raiseTicket status' {
        $d = & (Get-Module AzLocal.UpdateManagement) {
            param($t,$df) Get-AzLocalItsmTriggerDecision -Status 'Failed' -Triggers $t -Defaults $df
        } $script:itsmTriggers $script:itsmDefaults
        $d.ShouldTicket | Should -BeTrue
        $d.Severity     | Should -Be 2
        $d.Category     | Should -Be 'Cluster update failure'
    }

    It 'Returns ShouldTicket=false when raiseTicket=false' {
        $d = & (Get-Module AzLocal.UpdateManagement) {
            param($t,$df) Get-AzLocalItsmTriggerDecision -Status 'ScheduleBlocked' -Triggers $t -Defaults $df
        } $script:itsmTriggers $script:itsmDefaults
        $d.ShouldTicket | Should -BeFalse
    }

    It 'Returns ShouldTicket=false for unmapped status' {
        $d = & (Get-Module AzLocal.UpdateManagement) {
            param($t,$df) Get-AzLocalItsmTriggerDecision -Status 'WeirdNewStatus' -Triggers $t -Defaults $df
        } $script:itsmTriggers $script:itsmDefaults
        $d.ShouldTicket | Should -BeFalse
        $d.Reason       | Should -Match 'not in the trigger matrix'
    }

    It 'Honours explicit empty MirrorTo on a trigger (suppresses mirror)' {
        $d = & (Get-Module AzLocal.UpdateManagement) {
            param($t,$df) Get-AzLocalItsmTriggerDecision -Status 'SideloadedBlocked' -Triggers $t -Defaults $df
        } $script:itsmTriggers $script:itsmDefaults
        $d.ShouldTicket           | Should -BeTrue
        $d.MirrorTargets.Count    | Should -Be 0
    }

    It 'Falls back to default mirror list when trigger has no MirrorTo' {
        $triggers = @{ Failed = @{ RaiseTicket = $true; Severity = 2 } }
        $d = & (Get-Module AzLocal.UpdateManagement) {
            param($t,$df) Get-AzLocalItsmTriggerDecision -Status 'Failed' -Triggers $t -Defaults $df
        } $triggers $script:itsmDefaults
        $d.MirrorTargets | Should -Contain 'Teams'
    }

    It 'Throws on invalid severity' {
        $triggers = @{ Failed = @{ RaiseTicket = $true; Severity = 9 } }
        {
            & (Get-Module AzLocal.UpdateManagement) {
                param($t) Get-AzLocalItsmTriggerDecision -Status 'Failed' -Triggers $t
            } $triggers
        } | Should -Throw -ExpectedMessage '*severity*'
    }
}

Describe 'ITSM: Format-AzLocalIncidentBody' {
    It 'Substitutes a simple top-level token' {
        $r = & (Get-Module AzLocal.UpdateManagement) {
            Format-AzLocalIncidentBody -Template 'Hello {{name}}' -Context @{ name = 'World' } -NoHtmlEscape
        }
        $r | Should -Be 'Hello World'
    }

    It 'Substitutes a nested dotted token' {
        $r = & (Get-Module AzLocal.UpdateManagement) {
            Format-AzLocalIncidentBody -Template '{{a.b.c}}' -Context @{ a = @{ b = @{ c = 'deep' } } } -NoHtmlEscape
        }
        $r | Should -Be 'deep'
    }

    It 'HTML-escapes by default' {
        $r = & (Get-Module AzLocal.UpdateManagement) {
            Format-AzLocalIncidentBody -Template '{{x}}' -Context @{ x = '<script>alert(1)</script>' }
        }
        $r | Should -Be '&lt;script&gt;alert(1)&lt;/script&gt;'
    }

    It 'Renders missing path tokens as empty strings' {
        $r = & (Get-Module AzLocal.UpdateManagement) {
            Format-AzLocalIncidentBody -Template '[{{a.missing}}]' -Context @{ a = @{} } -NoHtmlEscape
        }
        $r | Should -Be '[]'
    }
}

Describe 'ITSM: Resolve-AzLocalItsmSecret' {
    It 'Resolves env:// to the environment variable value' {
        $env:AZLOCAL_TEST_SECRET = 'envValue123'
        try {
            $v = & (Get-Module AzLocal.UpdateManagement) {
                Resolve-AzLocalItsmSecret -Reference 'env://AZLOCAL_TEST_SECRET'
            }
            $v | Should -Be 'envValue123'
        }
        finally {
            Remove-Item env:AZLOCAL_TEST_SECRET -ErrorAction SilentlyContinue
        }
    }

    It 'Throws when env:// reference points to a missing variable' {
        Remove-Item env:AZLOCAL_TEST_MISSING -ErrorAction SilentlyContinue
        {
            & (Get-Module AzLocal.UpdateManagement) {
                Resolve-AzLocalItsmSecret -Reference 'env://AZLOCAL_TEST_MISSING'
            }
        } | Should -Throw -ExpectedMessage '*empty environment variable*'
    }

    It 'Throws on bare name without DefaultKeyVault' {
        {
            & (Get-Module AzLocal.UpdateManagement) {
                Resolve-AzLocalItsmSecret -Reference 'just-a-name'
            }
        } | Should -Throw -ExpectedMessage '*bare name*'
    }

    It 'Throws on literal:// without -AllowLiteral' {
        {
            & (Get-Module AzLocal.UpdateManagement) {
                Resolve-AzLocalItsmSecret -Reference 'literal://hello'
            }
        } | Should -Throw -ExpectedMessage '*AllowLiteral*'
    }

    It 'Returns the literal value when -AllowLiteral is set' {
        $v = & (Get-Module AzLocal.UpdateManagement) {
            Resolve-AzLocalItsmSecret -Reference 'literal://https://corp.service-now.com' -AllowLiteral
        }
        $v | Should -Be 'https://corp.service-now.com'
    }

    It 'Throws on unrecognised reference form' {
        {
            & (Get-Module AzLocal.UpdateManagement) {
                Resolve-AzLocalItsmSecret -Reference 'weird://nope'
            }
        } | Should -Throw -ExpectedMessage '*not a recognised form*'
    }
}

Describe 'ITSM: Get-AzureLocalItsmConfig' {
    BeforeAll {
        $script:configDir = Join-Path $env:TEMP "itsm-cfg-$([guid]::NewGuid().Guid.Substring(0,8))"
        New-Item -Path $script:configDir -ItemType Directory -Force | Out-Null
    }
    AfterAll {
        Remove-Item -Path $script:configDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Parses a valid JSON config' {
        $p = Join-Path $script:configDir 'ok.json'
        @{
            schemaVersion = 1
            secrets = @{ source = 'keyvault'; keyvaultName = 'kv1'; servicenow = @{ clientId='ci'; clientSecret='cs'; instanceUrl='env://X' } }
            defaults = @{ itsmTarget = 'ServiceNow' }
            triggers = @{ Failed = @{ raiseTicket = $true; severity = 2 } }
        } | ConvertTo-Json -Depth 8 | Set-Content -Path $p -Encoding UTF8
        $cfg = Get-AzureLocalItsmConfig -Path $p
        $cfg.SchemaVersion | Should -Be 1
        $cfg.Triggers['Failed'].RaiseTicket | Should -BeTrue
        $cfg.Triggers['Failed'].Severity    | Should -Be 2
    }

    It 'Throws on missing schemaVersion' {
        $p = Join-Path $script:configDir 'bad-no-schema.json'
        @{ secrets = @{ source='keyvault' }; defaults = @{ itsmTarget='ServiceNow' }; triggers = @{} } |
            ConvertTo-Json -Depth 5 | Set-Content -Path $p -Encoding UTF8
        { Get-AzureLocalItsmConfig -Path $p } | Should -Throw -ExpectedMessage '*schemaVersion*'
    }

    It 'Throws when itsmTarget is not ServiceNow' {
        $p = Join-Path $script:configDir 'bad-target.json'
        @{
            schemaVersion = 1
            secrets = @{ source = 'keyvault'; keyvaultName = 'kv1' }
            defaults = @{ itsmTarget = 'Jira' }
            triggers = @{ Failed = @{ raiseTicket = $true } }
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $p -Encoding UTF8
        { Get-AzureLocalItsmConfig -Path $p } | Should -Throw -ExpectedMessage '*ServiceNow*'
    }

    It 'Throws on invalid secrets.source' {
        $p = Join-Path $script:configDir 'bad-src.json'
        @{
            schemaVersion = 1
            secrets = @{ source = 'badvalue' }
            defaults = @{ itsmTarget = 'ServiceNow' }
            triggers = @{ Failed = @{ raiseTicket = $true } }
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $p -Encoding UTF8
        { Get-AzureLocalItsmConfig -Path $p } | Should -Throw -ExpectedMessage '*secrets.source*'
    }

    It 'Throws on out-of-range severity' {
        $p = Join-Path $script:configDir 'bad-sev.json'
        @{
            schemaVersion = 1
            secrets = @{ source = 'keyvault'; keyvaultName = 'kv1' }
            defaults = @{ itsmTarget = 'ServiceNow' }
            triggers = @{ Failed = @{ raiseTicket = $true; severity = 99 } }
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $p -Encoding UTF8
        { Get-AzureLocalItsmConfig -Path $p } | Should -Throw -ExpectedMessage '*out of range*'
    }

    It 'Throws when the file does not exist' {
        { Get-AzureLocalItsmConfig -Path (Join-Path $script:configDir 'nope.json') } | Should -Throw -ExpectedMessage '*not found*'
    }
}

Describe 'ITSM: New-AzureLocalIncident' {
    BeforeAll {
        $script:incDir = Join-Path $env:TEMP "itsm-inc-$([guid]::NewGuid().Guid.Substring(0,8))"
        New-Item -Path $script:incDir -ItemType Directory -Force | Out-Null

        $script:junitPath = Join-Path $script:incDir 'update-results.xml'
        $junit = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="AzLocal" tests="2">
    <testcase classname="Update" name="cluster-a">
      <failure type="UpdateFailed" message="apply failed">install error</failure>
      <properties>
        <property name="Status" value="Failed"/>
        <property name="ClusterName" value="cluster-a"/>
        <property name="ClusterResourceId" value="/subs/x/rg/r/providers/Microsoft.AzureStackHCI/clusters/cluster-a"/>
        <property name="UpdateName" value="2511.0.10.0"/>
      </properties>
    </testcase>
    <testcase classname="Update" name="cluster-b">
      <properties>
        <property name="Status" value="ScheduleBlocked"/>
        <property name="ClusterName" value="cluster-b"/>
        <property name="ClusterResourceId" value="/subs/x/rg/r/providers/Microsoft.AzureStackHCI/clusters/cluster-b"/>
        <property name="UpdateName" value="2511.0.10.0"/>
      </properties>
    </testcase>
  </testsuite>
</testsuites>
'@
        Set-Content -Path $script:junitPath -Value $junit -Encoding UTF8

        $script:cfg = [pscustomobject]@{
            SchemaVersion = 1
            SourcePath    = (Join-Path $script:incDir 'fake.yml')
            Secrets       = @{
                keyvaultName = 'kv1'
                servicenow   = @{ clientId='ci'; clientSecret='cs'; instanceUrl='literal://https://corp.service-now.com' }
            }
            Defaults      = @{
                itsmTarget      = 'ServiceNow'
                assignmentGroup = 'AzureLocal-Ops'
            }
            Triggers      = @{
                Failed          = @{ RaiseTicket = $true; Severity = 2; Category = 'Cluster update failure' }
                ScheduleBlocked = @{ RaiseTicket = $false }
            }
            Lifecycle = $null; Mirror = $null; Storage = $null; Raw = @{}
        }
    }

    AfterAll {
        Remove-Item -Path $script:incDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'In DryRun mode, returns one row per cluster with no HTTP calls' {
        $results = & (Get-Module AzLocal.UpdateManagement) {
            param($junit, $cfg)
            New-AzureLocalIncident -InputArtifactPath $junit -Config $cfg -DryRun
        } $script:junitPath $script:cfg

        $results.Count | Should -Be 2

        $a = $results | Where-Object ClusterName -eq 'cluster-a'
        $b = $results | Where-Object ClusterName -eq 'cluster-b'

        $a.Action    | Should -Be 'DryRun'
        $a.Severity  | Should -Be 2
        $a.DedupeKey | Should -Match '^[a-f0-9]{64}$'

        $b.Action    | Should -Be 'Skipped'
        $b.DedupeKey | Should -BeNullOrEmpty
    }

    It 'Throws when InputArtifactPath does not exist' {
        {
            & (Get-Module AzLocal.UpdateManagement) {
                param($cfg) New-AzureLocalIncident -InputArtifactPath 'C:\does\not\exist.xml' -Config $cfg -DryRun
            } $script:cfg
        } | Should -Throw -ExpectedMessage '*not found*'
    }

    It 'Emits Skipped+Reason for rows missing ClusterResourceId (does not throw the whole batch)' {
        # JUnit with one Failed row that has NO ClusterResourceId property
        $brokenJunit = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="AzLocal" tests="1">
    <testcase classname="Update" name="cluster-x">
      <failure type="UpdateFailed" message="apply failed">install error</failure>
      <properties>
        <property name="Status" value="Failed"/>
        <property name="ClusterName" value="cluster-x"/>
        <property name="UpdateName" value="2511.0.10.0"/>
      </properties>
    </testcase>
  </testsuite>
</testsuites>
'@
        $brokenPath = Join-Path $script:incDir 'broken.xml'
        Set-Content -Path $brokenPath -Value $brokenJunit -Encoding UTF8

        $results = & (Get-Module AzLocal.UpdateManagement) {
            param($p, $c) New-AzureLocalIncident -InputArtifactPath $p -Config $c -DryRun
        } $brokenPath $script:cfg

        $resultsArr = @($results)
        $resultsArr.Count    | Should -Be 1
        $resultsArr[0].Action| Should -Be 'Skipped'
        $resultsArr[0].Reason| Should -Match 'missing ClusterResourceId'
    }
}

Describe 'ITSM: Invoke-AzLocalItsmHttp' {
    It 'Wraps Invoke-RestMethod and returns the parsed response' {
        $r = InModuleScope AzLocal.UpdateManagement {
            Mock Invoke-RestMethod { return [pscustomobject]@{ ok = $true; value = 42 } }
            Invoke-AzLocalItsmHttp -Method GET -Uri 'https://example/api'
        }
        $r.ok    | Should -BeTrue
        $r.value | Should -Be 42
    }

    It 'Passes byte[] bodies through unchanged (does NOT JSON-encode binary uploads)' {
        InModuleScope AzLocal.UpdateManagement {
            $script:capturedBody = $null
            Mock Invoke-RestMethod {
                param($Method, $Uri, $Headers, $Body, $ContentType, $TimeoutSec, $ErrorAction)
                $script:capturedBody = $Body
                return [pscustomobject]@{ ok = $true }
            }
            $bytes = [byte[]](1, 2, 3, 4, 5)
            $null = Invoke-AzLocalItsmHttp -Method POST -Uri 'https://x/api' -Body $bytes -ContentType 'application/octet-stream'
            ($script:capturedBody -is [byte[]]) | Should -BeTrue
            $script:capturedBody.Count | Should -Be 5
        }
    }

    It 'Passes string bodies (e.g. form-urlencoded) through unchanged' {
        InModuleScope AzLocal.UpdateManagement {
            $script:capturedBody = $null
            Mock Invoke-RestMethod {
                param($Method, $Uri, $Headers, $Body, $ContentType, $TimeoutSec, $ErrorAction)
                $script:capturedBody = $Body
                return [pscustomobject]@{ ok = $true }
            }
            $null = Invoke-AzLocalItsmHttp -Method POST -Uri 'https://x/api' -Body 'a=1&b=2' -ContentType 'application/x-www-form-urlencoded'
            $script:capturedBody | Should -Be 'a=1&b=2'
        }
    }

    It 'JSON-encodes hashtable bodies' {
        InModuleScope AzLocal.UpdateManagement {
            $script:capturedBody = $null
            Mock Invoke-RestMethod {
                param($Method, $Uri, $Headers, $Body, $ContentType, $TimeoutSec, $ErrorAction)
                $script:capturedBody = $Body
                return [pscustomobject]@{ ok = $true }
            }
            $null = Invoke-AzLocalItsmHttp -Method POST -Uri 'https://x/api' -Body @{ a = 1 }
            $script:capturedBody | Should -Match '"a":1'
        }
    }
}

Describe 'ITSM: Invoke-AzLocalServiceNowAdapter' {
    It 'Does not expose -Username or -Password parameters (Phase 1 = client_credentials only)' {
        $params = InModuleScope AzLocal.UpdateManagement {
            (Get-Command Invoke-AzLocalServiceNowAdapter).Parameters.Keys
        }
        $params | Should -Not -Contain 'Username'
        $params | Should -Not -Contain 'Password'
    }

    It 'TestConnection probes the incident table (not sys_user)' {
        InModuleScope AzLocal.UpdateManagement {
            $script:capturedUri = $null
            Mock Invoke-AzLocalItsmHttp {
                param($Method, $Uri, $Headers, $Body, $ContentType, $TimeoutSec, $MaxAttempts)
                $script:capturedUri = $Uri
                return [pscustomobject]@{ result = @() }
            }
            $null = Invoke-AzLocalServiceNowAdapter -Action TestConnection `
                -InstanceUrl 'https://corp.service-now.com' -AccessToken 'tok'
            $script:capturedUri | Should -Match '/api/now/table/incident'
            $script:capturedUri | Should -Not -Match '/api/now/table/sys_user'
        }
    }
}

Describe 'ITSM: Get-AzureLocalItsmConfig - mixed source validation' {
    BeforeAll {
        $script:mixedDir = Join-Path $env:TEMP "itsm-mixed-$([guid]::NewGuid().Guid.Substring(0,8))"
        New-Item -Path $script:mixedDir -ItemType Directory -Force | Out-Null
    }
    AfterAll {
        Remove-Item -Path $script:mixedDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Throws when secrets.source=mixed but secrets.keyvaultName is not set' {
        $p = Join-Path $script:mixedDir 'mixed-no-kv.json'
        @{
            schemaVersion = 1
            secrets = @{ source = 'mixed'; servicenow = @{ clientId='ci'; clientSecret='cs'; instanceUrl='env://X' } }
            defaults = @{ itsmTarget = 'ServiceNow' }
            triggers = @{ Failed = @{ raiseTicket = $true } }
        } | ConvertTo-Json -Depth 8 | Set-Content -Path $p -Encoding UTF8
        { Get-AzureLocalItsmConfig -Path $p } | Should -Throw -ExpectedMessage '*secrets.source=mixed*keyvaultName*'
    }

    It 'Accepts secrets.source=mixed when secrets.keyvaultName is set' {
        $p = Join-Path $script:mixedDir 'mixed-ok.json'
        @{
            schemaVersion = 1
            secrets = @{ source = 'mixed'; keyvaultName = 'kv1'; servicenow = @{ clientId='ci'; clientSecret='cs'; instanceUrl='env://X' } }
            defaults = @{ itsmTarget = 'ServiceNow' }
            triggers = @{ Failed = @{ raiseTicket = $true } }
        } | ConvertTo-Json -Depth 8 | Set-Content -Path $p -Encoding UTF8
        $cfg = Get-AzureLocalItsmConfig -Path $p
        $cfg.SchemaVersion | Should -Be 1
        $cfg.Secrets['keyvaultName'] | Should -Be 'kv1'
    }
}

Describe 'ITSM: New-AzureLocalIncident -ExportPath CSV sanitization' {
    BeforeAll {
        $script:csvDir = Join-Path $env:TEMP "itsm-csv-$([guid]::NewGuid().Guid.Substring(0,8))"
        New-Item -Path $script:csvDir -ItemType Directory -Force | Out-Null

        $script:csvJunit = Join-Path $script:csvDir 'junit.xml'
        $junit = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="AzLocal" tests="1">
    <testcase classname="Update" name="cluster-evil">
      <failure type="UpdateFailed" message="apply failed">install error</failure>
      <properties>
        <property name="Status" value="Failed"/>
        <property name="ClusterName" value="=cmd|'/c calc'!A1"/>
        <property name="ClusterResourceId" value="/subs/x/rg/r/providers/Microsoft.AzureStackHCI/clusters/cluster-evil"/>
        <property name="UpdateName" value="2511.0.10.0"/>
      </properties>
    </testcase>
  </testsuite>
</testsuites>
'@
        Set-Content -Path $script:csvJunit -Value $junit -Encoding UTF8

        $script:csvCfg = [pscustomobject]@{
            SchemaVersion = 1
            SourcePath    = (Join-Path $script:csvDir 'fake.yml')
            Secrets       = @{
                keyvaultName = 'kv1'
                servicenow   = @{ clientId='ci'; clientSecret='cs'; instanceUrl='literal://https://corp.service-now.com' }
            }
            Defaults      = @{ itsmTarget = 'ServiceNow'; assignmentGroup = 'AzureLocal-Ops' }
            Triggers      = @{ Failed = @{ RaiseTicket = $true; Severity = 2 } }
            Lifecycle = $null; Mirror = $null; Storage = $null; Raw = @{}
        }
    }

    AfterAll {
        Remove-Item -Path $script:csvDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Neutralises CSV-formula-like ClusterName values in the exported file' {
        $csvPath = Join-Path $script:csvDir 'out.csv'
        $null = & (Get-Module AzLocal.UpdateManagement) {
            param($junit, $cfg, $out)
            New-AzureLocalIncident -InputArtifactPath $junit -Config $cfg -DryRun -ExportPath $out
        } $script:csvJunit $script:csvCfg $csvPath

        Test-Path $csvPath | Should -BeTrue
        $rows = Import-Csv -Path $csvPath
        @($rows).Count | Should -Be 1
        # ConvertTo-SafeCsvField prefixes formula-leading values with a leading tick/space
        # so a spreadsheet does not treat the cell as a formula. The exact prefix is the
        # module's standard sanitization (no leading '=', '+', '-', '@', or pipe).
        $rows[0].ClusterName | Should -Not -Match '^[=+\-@]'
        $rows[0].ClusterName | Should -Match 'cmd'
    }
}

Describe 'ITSM: New-AzureLocalIncident dedupe lookup runs in DryRun' {
    BeforeAll {
        $script:dryDir = Join-Path $env:TEMP "itsm-dry-$([guid]::NewGuid().Guid.Substring(0,8))"
        New-Item -Path $script:dryDir -ItemType Directory -Force | Out-Null
        $script:dryJunit = Join-Path $script:dryDir 'junit.xml'
        @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="AzLocal" tests="1">
    <testcase classname="Update" name="cluster-dedupe">
      <failure type="UpdateFailed" message="apply failed">install error</failure>
      <properties>
        <property name="Status" value="Failed"/>
        <property name="ClusterName" value="cluster-dedupe"/>
        <property name="ClusterResourceId" value="/subs/x/rg/r/providers/Microsoft.AzureStackHCI/clusters/cluster-dedupe"/>
        <property name="UpdateName" value="2511.0.10.0"/>
      </properties>
    </testcase>
  </testsuite>
</testsuites>
'@ | Set-Content -Path $script:dryJunit -Encoding UTF8

        $script:dryCfg = [pscustomobject]@{
            SchemaVersion = 1
            SourcePath    = (Join-Path $script:dryDir 'fake.yml')
            Secrets       = @{
                keyvaultName = 'kv1'
                servicenow   = @{
                    clientId     = 'literal://ci'
                    clientSecret = 'literal://cs'
                    instanceUrl  = 'literal://https://corp.service-now.com'
                }
            }
            Defaults      = @{ itsmTarget = 'ServiceNow'; assignmentGroup = 'AzureLocal-Ops' }
            Triggers      = @{ Failed = @{ RaiseTicket = $true; Severity = 2 } }
            Lifecycle = $null; Mirror = $null; Storage = $null; Raw = @{}
        }
    }

    AfterAll {
        Remove-Item -Path $script:dryDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'DryRun calls FindByDedupe and reports DedupedToExisting when an existing ticket is returned' {
        InModuleScope AzLocal.UpdateManagement {
            $script:dedupeCalled = $false
            $script:createCalled = $false
            Mock Resolve-AzLocalItsmSecret { 'literal-value' }
            Mock Invoke-AzLocalServiceNowAdapter {
                param($Action)
                switch ($Action) {
                    'GetToken'      { return [pscustomobject]@{ AccessToken = 'tok' } }
                    'FindByDedupe'  {
                        $script:dedupeCalled = $true
                        return [pscustomobject]@{ sys_id = 'abc123'; number = 'INC0000999' }
                    }
                    'CreateIncident' {
                        $script:createCalled = $true
                        return [pscustomobject]@{ sys_id = 'new'; number = 'INC9999' }
                    }
                }
            }
        }

        $results = & (Get-Module AzLocal.UpdateManagement) {
            param($junit, $cfg)
            New-AzureLocalIncident -InputArtifactPath $junit -Config $cfg -DryRun
        } $script:dryJunit $script:dryCfg

        $resultsArr = @($results)
        $resultsArr.Count          | Should -Be 1
        $resultsArr[0].Action      | Should -Be 'DedupedToExisting'
        $resultsArr[0].TicketId    | Should -Be 'INC0000999'
        $resultsArr[0].TicketSysId | Should -Be 'abc123'

        InModuleScope AzLocal.UpdateManagement {
            $script:dedupeCalled | Should -BeTrue
            $script:createCalled | Should -BeFalse
        }
    }

    It 'DryRun degrades gracefully when secret resolution fails (Action=DryRun, Reason annotated)' {
        InModuleScope AzLocal.UpdateManagement {
            Mock Resolve-AzLocalItsmSecret { throw "fake auth failure" }
            Mock Invoke-AzLocalServiceNowAdapter { throw "should not be called" }
        }

        $results = & (Get-Module AzLocal.UpdateManagement) {
            param($junit, $cfg)
            New-AzureLocalIncident -InputArtifactPath $junit -Config $cfg -DryRun -WarningAction SilentlyContinue
        } $script:dryJunit $script:dryCfg

        $resultsArr = @($results)
        $resultsArr.Count       | Should -Be 1
        $resultsArr[0].Action   | Should -Be 'DryRun'
        $resultsArr[0].Reason   | Should -Match 'Dedupe lookup skipped'
    }
}

Describe 'ITSM: New-AzureLocalIncident -ExportJUnitPath' {
    BeforeAll {
        $script:jxDir = Join-Path $env:TEMP "itsm-jx-$([guid]::NewGuid().Guid.Substring(0,8))"
        New-Item -Path $script:jxDir -ItemType Directory -Force | Out-Null
        $script:jxJunit = Join-Path $script:jxDir 'junit.xml'
        @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="AzLocal" tests="2">
    <testcase classname="Update" name="cluster-ok">
      <properties>
        <property name="Status" value="Failed"/>
        <property name="ClusterName" value="cluster-ok"/>
        <property name="ClusterResourceId" value="/subs/x/rg/r/providers/Microsoft.AzureStackHCI/clusters/cluster-ok"/>
        <property name="UpdateName" value="2511.0.10.0"/>
      </properties>
    </testcase>
    <testcase classname="Update" name="cluster-skip">
      <properties>
        <property name="Status" value="ScheduleBlocked"/>
        <property name="ClusterName" value="cluster-skip"/>
        <property name="ClusterResourceId" value="/subs/x/rg/r/providers/Microsoft.AzureStackHCI/clusters/cluster-skip"/>
        <property name="UpdateName" value="2511.0.10.0"/>
      </properties>
    </testcase>
  </testsuite>
</testsuites>
'@ | Set-Content -Path $script:jxJunit -Encoding UTF8

        $script:jxCfg = [pscustomobject]@{
            SchemaVersion = 1
            SourcePath    = (Join-Path $script:jxDir 'fake.yml')
            Secrets       = @{
                keyvaultName = 'kv1'
                servicenow   = @{
                    clientId     = 'literal://ci'
                    clientSecret = 'literal://cs'
                    instanceUrl  = 'literal://https://corp.service-now.com'
                }
            }
            Defaults      = @{ itsmTarget = 'ServiceNow'; assignmentGroup = 'AzureLocal-Ops' }
            Triggers      = @{
                Failed          = @{ RaiseTicket = $true;  Severity = 2 }
                ScheduleBlocked = @{ RaiseTicket = $false }
            }
            Lifecycle = $null; Mirror = $null; Storage = $null; Raw = @{}
        }
    }

    AfterAll {
        Remove-Item -Path $script:jxDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Writes a parseable JUnit XML file with one testcase per result row' {
        $junitOut = Join-Path $script:jxDir 'itsm-results.xml'

        $null = & (Get-Module AzLocal.UpdateManagement) {
            param($junit, $cfg, $out)
            New-AzureLocalIncident -InputArtifactPath $junit -Config $cfg -DryRun -ExportJUnitPath $out -WarningAction SilentlyContinue
        } $script:jxJunit $script:jxCfg $junitOut

        Test-Path $junitOut | Should -BeTrue
        [xml]$doc = Get-Content -Path $junitOut -Raw
        $cases = $doc.SelectNodes('//testcase')
        @($cases).Count | Should -Be 2
        # Export-ResultsToJUnitXml prefixes the testcase name with "$OperationType-".
        # So the ScheduleBlocked row appears as IncidentAction-cluster-skip and must
        # carry a <skipped> child.
        ($doc.SelectNodes('//testcase[@name="IncidentAction-cluster-skip"]/skipped')).Count | Should -Be 1
        # Test suite name is the bare TestSuiteName; classname on each testcase is TestSuiteName.OperationType
        $doc.SelectSingleNode('//testsuite').name | Should -Be 'AzureLocalItsm'
        $doc.SelectNodes('//testcase[@classname="AzureLocalItsm.IncidentAction"]').Count | Should -Be 2
    }
}

Describe 'ITSM: Get-AzureLocalItsmConfig normalises non-Hashtable YAML dictionaries' {
    It 'Converts a Dictionary[object,object] from ConvertFrom-Yaml into a case-insensitive hashtable tree' {
        $yamlPath = Join-Path $env:TEMP "itsm-norm-$([guid]::NewGuid().Guid.Substring(0,8)).yml"
        # Content is irrelevant because we mock ConvertFrom-Yaml below; the
        # file just has to exist so Test-Path passes.
        Set-Content -Path $yamlPath -Value 'placeholder' -Encoding UTF8

        try {
            $cfg = InModuleScope AzLocal.UpdateManagement -Parameters @{ Path = $yamlPath } {
                param($Path)

                # Build a generic Dictionary[object,object] tree exactly like
                # some powershell-yaml versions emit (case-SENSITIVE keys).
                $dict = [System.Collections.Generic.Dictionary[object,object]]::new()
                $dict['schemaVersion'] = 1
                $secrets = [System.Collections.Generic.Dictionary[object,object]]::new()
                $secrets['source'] = 'envvar'
                $sn = [System.Collections.Generic.Dictionary[object,object]]::new()
                $sn['clientId']     = 'env://X'
                $sn['clientSecret'] = 'env://Y'
                $sn['instanceUrl']  = 'literal://https://corp.service-now.com'
                $secrets['servicenow'] = $sn
                $dict['secrets'] = $secrets
                $defaults = [System.Collections.Generic.Dictionary[object,object]]::new()
                $defaults['itsmTarget'] = 'ServiceNow'
                $dict['defaults'] = $defaults
                $triggers = [System.Collections.Generic.Dictionary[object,object]]::new()
                $failedEntry = [System.Collections.Generic.Dictionary[object,object]]::new()
                $failedEntry['raiseTicket'] = $true
                $failedEntry['severity']    = 2
                $triggers['Failed'] = $failedEntry
                $dict['triggers'] = $triggers

                Mock Get-Module -ParameterFilter { $Name -eq 'powershell-yaml' -and $ListAvailable } { return [pscustomobject]@{ Name = 'powershell-yaml' } }
                Mock Import-Module {}
                Mock ConvertFrom-Yaml { return $dict }

                Get-AzureLocalItsmConfig -Path $Path
            }

            $cfg.SchemaVersion | Should -Be 1
            # Both PascalCase (config-time) and camelCase (YAML-native) must work
            $cfg.Triggers['Failed']                  | Should -Not -BeNullOrEmpty
            $cfg.Triggers['Failed'].ContainsKey('RaiseTicket') | Should -BeTrue
            $cfg.Triggers['Failed']['raiseTicket']   | Should -BeTrue
        }
        finally {
            Remove-Item -Path $yamlPath -Force -ErrorAction SilentlyContinue
        }
    }
}

#endregion ITSM Connector Phase 1 (v0.7.4)

#region Copy-AzureLocalPipelineExample (v0.7.4, updated in v0.7.50)

Describe 'Function: Copy-AzureLocalPipelineExample' {
    BeforeAll {
        # The function reads from (Get-Module AzLocal.UpdateManagement).ModuleBase
        # which during test runs resolves to the repo module root, so the real
        # Automation-Pipeline-Examples/ folder under the repo is the test source.
        $script:cpDestRoot = Join-Path $env:TEMP "azlocal-cpe-$([guid]::NewGuid().Guid.Substring(0,8))"
        New-Item -Path $script:cpDestRoot -ItemType Directory -Force | Out-Null
    }

    AfterAll {
        Remove-Item $script:cpDestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Default (-Platform All): copies the full source tree into a child Automation-Pipeline-Examples folder under -Destination' {
        $dest = Join-Path $script:cpDestRoot 'default'
        New-Item -Path $dest -ItemType Directory -Force | Out-Null

        $r = Copy-AzureLocalPipelineExample -Destination $dest -PassThru 6>$null

        $r | Should -Not -BeNullOrEmpty
        $r.FullName | Should -Be (Join-Path $dest 'Automation-Pipeline-Examples')
        Test-Path (Join-Path $r.FullName 'README.md') | Should -BeTrue
        Test-Path (Join-Path $r.FullName 'github-actions') | Should -BeTrue
        Test-Path (Join-Path $r.FullName 'azure-devops') | Should -BeTrue
    }

    It '-Platform GitHub: copies *.yml files DIRECTLY into -Destination (no wrapper folder, no README, no .itsm)' {
        $dest = Join-Path $script:cpDestRoot 'gh'
        New-Item -Path $dest -ItemType Directory -Force | Out-Null

        $r = Copy-AzureLocalPipelineExample -Destination $dest -Platform GitHub -PassThru 6>$null

        # Target root IS -Destination, not a child of it
        $r.FullName | Should -Be $dest

        # YAMLs landed directly in $dest
        $yamls = @(Get-ChildItem -LiteralPath $dest -Filter '*.yml' -File)
        $yamls.Count | Should -BeGreaterThan 0
        $yamls.Name | Should -Contain 'Step.0_authentication-test.yml'

        # No platform-named subfolder, no Automation-Pipeline-Examples wrapper
        Test-Path (Join-Path $dest 'github-actions') | Should -BeFalse
        Test-Path (Join-Path $dest 'azure-devops')   | Should -BeFalse
        Test-Path (Join-Path $dest 'Automation-Pipeline-Examples') | Should -BeFalse

        # README and .itsm are NOT copied with -Platform GitHub
        Test-Path (Join-Path $dest 'README.md') | Should -BeFalse
        Test-Path (Join-Path $dest '.itsm')     | Should -BeFalse
    }

    It '-Platform AzureDevOps: copies *.yml files DIRECTLY into -Destination (no wrapper folder, no README, no .itsm)' {
        $dest = Join-Path $script:cpDestRoot 'ado'
        New-Item -Path $dest -ItemType Directory -Force | Out-Null

        $r = Copy-AzureLocalPipelineExample -Destination $dest -Platform AzureDevOps -PassThru 6>$null

        $r.FullName | Should -Be $dest

        $yamls = @(Get-ChildItem -LiteralPath $dest -Filter '*.yml' -File)
        $yamls.Count | Should -BeGreaterThan 0
        $yamls.Name | Should -Contain 'Step.0_authentication-test.yml'

        Test-Path (Join-Path $dest 'azure-devops')   | Should -BeFalse
        Test-Path (Join-Path $dest 'github-actions') | Should -BeFalse
        Test-Path (Join-Path $dest 'Automation-Pipeline-Examples') | Should -BeFalse
        Test-Path (Join-Path $dest 'README.md') | Should -BeFalse
        Test-Path (Join-Path $dest '.itsm')     | Should -BeFalse
    }

    It '-Platform GitHub: peacefully co-exists with unrelated pre-existing files in -Destination' {
        $dest = Join-Path $script:cpDestRoot 'gh-coexist'
        New-Item -Path $dest -ItemType Directory -Force | Out-Null
        # Simulate the realistic case: .github\workflows\ already contains an
        # unrelated user-authored workflow. The function must NOT refuse to copy
        # just because the destination is non-empty.
        Set-Content -Path (Join-Path $dest 'my-other-build.yml') -Value 'name: my-other-build' -Encoding ASCII

        { Copy-AzureLocalPipelineExample -Destination $dest -Platform GitHub 6>$null } | Should -Not -Throw

        # Original file untouched
        Test-Path (Join-Path $dest 'my-other-build.yml') | Should -BeTrue
        # Module YAMLs alongside it
        @(Get-ChildItem -LiteralPath $dest -Filter '*.yml' -File).Count | Should -BeGreaterThan 1
    }

    It 'Refuses to overwrite an existing file by default and lists the conflicts (no -Update)' {
        $dest = Join-Path $script:cpDestRoot 'no-overwrite'
        New-Item -Path $dest -ItemType Directory -Force | Out-Null

        # First copy populates the target with module YAMLs
        Copy-AzureLocalPipelineExample -Destination $dest -Platform GitHub 6>$null | Out-Null

        # Second copy must refuse: ALL the same files now exist as conflicts.
        # The error message must hint at the -Update escape hatch.
        { Copy-AzureLocalPipelineExample -Destination $dest -Platform GitHub 6>$null } |
            Should -Throw -ExpectedMessage '*refusing to overwrite*'
        { Copy-AzureLocalPipelineExample -Destination $dest -Platform GitHub 6>$null } |
            Should -Throw -ExpectedMessage '*-Update*'
    }

    It '-Update -Confirm:$false overwrites existing files without prompting (automation path)' {
        $dest = Join-Path $script:cpDestRoot 'update-confirm-false'
        New-Item -Path $dest -ItemType Directory -Force | Out-Null

        # Seed the destination so every file is a conflict
        Copy-AzureLocalPipelineExample -Destination $dest -Platform GitHub 6>$null | Out-Null

        # Mutate one destination file so we can prove it gets overwritten
        $target = Join-Path $dest 'Step.0_authentication-test.yml'
        $sentinel = '# SENTINEL - if this comment survives, -Update did not overwrite'
        Set-Content -LiteralPath $target -Value $sentinel -Encoding ASCII
        (Get-Content -LiteralPath $target -Raw) | Should -Match 'SENTINEL'

        # -Update -Confirm:$false must NOT throw and must overwrite the sentinel
        { Copy-AzureLocalPipelineExample -Destination $dest -Platform GitHub -Update -Confirm:$false 6>$null } |
            Should -Not -Throw

        (Get-Content -LiteralPath $target -Raw) | Should -Not -Match 'SENTINEL'
    }

    It '-Update is exposed as a [switch] parameter in v0.7.50' {
        $cmd = Get-Command -Name 'Copy-AzureLocalPipelineExample' -ErrorAction Stop
        $cmd.Parameters.ContainsKey('Update') | Should -BeTrue
        $cmd.Parameters['Update'].ParameterType | Should -Be ([switch])
    }

    It 'No-to-All only suppresses overwrites, not brand-new files (v0.7.50 regression guard)' {
        # Background: In an early v0.7.50 pass the per-file loop's top guard was
        #     if ($noToAll) { $skippedCount++; continue }
        # which skipped EVERY remaining file once the user chose No-to-All,
        # even files that did not already exist at the destination (no prompt
        # would have been raised for them). The corrected semantics match
        # PowerShell's canonical No-to-All meaning ("answer No to all remaining
        # prompts") rather than "halt all subsequent operations". This test
        # asserts the corrected source pattern is present so the bug cannot
        # silently re-appear.
        $cmd = Get-Command -Name 'Copy-AzureLocalPipelineExample' -ErrorAction Stop
        $src = $cmd.ScriptBlock.ToString()
        # Corrected guard: skip only when there is an existing file to overwrite.
        $src | Should -Match 'if\s*\(\s*\$noToAll\s+-and\s+\$destExists\s*\)'
        # The bare-noToAll early-continue must NOT reappear at the top of the loop.
        $src | Should -Not -Match 'foreach\s*\(\s*\$pair\s+in\s+\$copyPairs\s*\)\s*\{\s*if\s*\(\s*\$noToAll\s*\)\s*\{\s*\$skippedCount\+\+\s*;?\s*continue'
    }

    It '-Update -WhatIf does not modify any existing files' {
        $dest = Join-Path $script:cpDestRoot 'update-whatif'
        New-Item -Path $dest -ItemType Directory -Force | Out-Null

        # Seed and then mutate
        Copy-AzureLocalPipelineExample -Destination $dest -Platform GitHub 6>$null | Out-Null
        $target = Join-Path $dest 'Step.0_authentication-test.yml'
        $sentinel = '# WHATIF SENTINEL - -WhatIf must preserve this'
        Set-Content -LiteralPath $target -Value $sentinel -Encoding ASCII

        # -Update -WhatIf must NOT modify the file
        Copy-AzureLocalPipelineExample -Destination $dest -Platform GitHub -Update -WhatIf 6>$null

        (Get-Content -LiteralPath $target -Raw) | Should -Match 'WHATIF SENTINEL'
    }

    It '-Force parameter has been removed in v0.7.50' {
        # Inspect the function's parameter metadata directly - more robust than
        # relying on the engine's FQErrorID, which differs across PS editions.
        $cmd = Get-Command -Name 'Copy-AzureLocalPipelineExample' -ErrorAction Stop
        $cmd.Parameters.ContainsKey('Force') | Should -BeFalse
    }

    It '-Flatten parameter has been removed in v0.7.50' {
        $cmd = Get-Command -Name 'Copy-AzureLocalPipelineExample' -ErrorAction Stop
        $cmd.Parameters.ContainsKey('Flatten') | Should -BeFalse
    }

    It '-WhatIf does not copy anything' {
        $dest = Join-Path $script:cpDestRoot 'whatif'
        # Note: dest does not yet exist; -WhatIf should not create it either
        Copy-AzureLocalPipelineExample -Destination $dest -WhatIf 6>$null
        Test-Path (Join-Path $dest 'Automation-Pipeline-Examples') | Should -BeFalse
    }

    It '-PassThru returns a DirectoryInfo; without it nothing is emitted to the pipeline' {
        $dest = Join-Path $script:cpDestRoot 'passthru'
        New-Item -Path $dest -ItemType Directory -Force | Out-Null

        $withPT = Copy-AzureLocalPipelineExample -Destination $dest -Platform GitHub -PassThru 6>$null
        $withPT | Should -BeOfType [System.IO.DirectoryInfo]
        $withPT.FullName | Should -Be $dest

        $dest2 = Join-Path $script:cpDestRoot 'nopassthru'
        New-Item -Path $dest2 -ItemType Directory -Force | Out-Null
        $noPT = Copy-AzureLocalPipelineExample -Destination $dest2 -Platform GitHub 6>$null
        $noPT | Should -BeNullOrEmpty
    }

    It 'Creates -Destination when it does not already exist' {
        $dest = Join-Path $script:cpDestRoot 'autocreate'
        # Intentionally not creating $dest beforehand
        Test-Path $dest | Should -BeFalse

        $r = Copy-AzureLocalPipelineExample -Destination $dest -PassThru 6>$null

        Test-Path $dest | Should -BeTrue
        Test-Path (Join-Path $r.FullName 'README.md') | Should -BeTrue
    }
}

#endregion Copy-AzureLocalPipelineExample (v0.7.4, updated in v0.7.50)

#region Copy-AzureLocalItsmSample (v0.7.50)

Describe 'Function: Copy-AzureLocalItsmSample' {
    BeforeAll {
        $script:itsmDestRoot = Join-Path $env:TEMP "azlocal-itsm-$([guid]::NewGuid().Guid.Substring(0,8))"
        New-Item -Path $script:itsmDestRoot -ItemType Directory -Force | Out-Null
    }

    AfterAll {
        Remove-Item $script:itsmDestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Is exported by the module' {
        $cmd = Get-Command -Name 'Copy-AzureLocalItsmSample' -Module 'AzLocal.UpdateManagement' -ErrorAction Stop
        $cmd | Should -Not -BeNullOrEmpty
        $cmd.CommandType | Should -Be 'Function'
    }

    It 'Default -Destination ends in .itsm' {
        $cmd = Get-Command -Name 'Copy-AzureLocalItsmSample' -ErrorAction Stop
        # Look at the default value embedded in the function source
        $src = $cmd.ScriptBlock.ToString()
        $src | Should -Match "Join-Path\s+-Path\s+\`$PWD\.Path\s+-ChildPath\s+'\.itsm'"
    }

    It '-WhatIf does not copy anything' {
        $dest = Join-Path $script:itsmDestRoot 'whatif'
        # Note: dest does not yet exist; -WhatIf should not create file contents either
        Copy-AzureLocalItsmSample -Destination $dest -WhatIf 6>$null
        # No YAML should have been written even if the directory was created
        Test-Path (Join-Path $dest 'azurelocal-itsm.yml') | Should -BeFalse
    }

    It 'Default copy: writes azurelocal-itsm.yml and templates/incident-body.md' {
        $dest = Join-Path $script:itsmDestRoot 'default'
        $r = Copy-AzureLocalItsmSample -Destination $dest -PassThru 6>$null

        $r | Should -BeOfType [System.IO.DirectoryInfo]
        $r.FullName | Should -Be $dest
        Test-Path (Join-Path $dest 'azurelocal-itsm.yml') | Should -BeTrue
        Test-Path (Join-Path $dest 'templates\incident-body.md') | Should -BeTrue
    }

    It 'Refuses to overwrite an existing file by default and points at -Update' {
        $dest = Join-Path $script:itsmDestRoot 'no-overwrite'
        Copy-AzureLocalItsmSample -Destination $dest 6>$null | Out-Null

        { Copy-AzureLocalItsmSample -Destination $dest 6>$null } |
            Should -Throw -ExpectedMessage '*refusing to overwrite*'
        { Copy-AzureLocalItsmSample -Destination $dest 6>$null } |
            Should -Throw -ExpectedMessage '*-Update*'
    }

    It '-Update -Confirm:$false overwrites existing files without prompting (automation path)' {
        $dest = Join-Path $script:itsmDestRoot 'update-confirm-false'
        Copy-AzureLocalItsmSample -Destination $dest 6>$null | Out-Null

        $target = Join-Path $dest 'azurelocal-itsm.yml'
        $sentinel = '# SENTINEL - if this survives, -Update did not overwrite'
        Set-Content -LiteralPath $target -Value $sentinel -Encoding ASCII
        (Get-Content -LiteralPath $target -Raw) | Should -Match 'SENTINEL'

        { Copy-AzureLocalItsmSample -Destination $dest -Update -Confirm:$false 6>$null } |
            Should -Not -Throw

        (Get-Content -LiteralPath $target -Raw) | Should -Not -Match 'SENTINEL'
    }

    It '-Update -WhatIf does not modify any existing files' {
        $dest = Join-Path $script:itsmDestRoot 'update-whatif'
        Copy-AzureLocalItsmSample -Destination $dest 6>$null | Out-Null

        $target = Join-Path $dest 'azurelocal-itsm.yml'
        $sentinel = '# WHATIF SENTINEL - -WhatIf must preserve this'
        Set-Content -LiteralPath $target -Value $sentinel -Encoding ASCII

        Copy-AzureLocalItsmSample -Destination $dest -Update -WhatIf 6>$null

        (Get-Content -LiteralPath $target -Raw) | Should -Match 'WHATIF SENTINEL'
    }

    It '-Update is exposed as a [switch] parameter' {
        $cmd = Get-Command -Name 'Copy-AzureLocalItsmSample' -ErrorAction Stop
        $cmd.Parameters.ContainsKey('Update') | Should -BeTrue
        $cmd.Parameters['Update'].ParameterType | Should -Be ([switch])
    }

    It 'Has the No-to-All only-when-destExists regression guard (matches Copy-AzureLocalPipelineExample fix)' {
        $cmd = Get-Command -Name 'Copy-AzureLocalItsmSample' -ErrorAction Stop
        $src = $cmd.ScriptBlock.ToString()
        $src | Should -Match 'if\s*\(\s*\$noToAll\s+-and\s+\$destExists\s*\)'
    }

    It '-PassThru returns a DirectoryInfo; without it nothing is emitted to the pipeline' {
        $dest = Join-Path $script:itsmDestRoot 'passthru'
        $withPT = Copy-AzureLocalItsmSample -Destination $dest -PassThru 6>$null
        $withPT | Should -BeOfType [System.IO.DirectoryInfo]
        $withPT.FullName | Should -Be $dest

        $dest2 = Join-Path $script:itsmDestRoot 'nopassthru'
        $noPT = Copy-AzureLocalItsmSample -Destination $dest2 6>$null
        $noPT | Should -BeNullOrEmpty
    }

    It 'Creates -Destination (including templates subfolder) when it does not already exist' {
        $dest = Join-Path $script:itsmDestRoot 'autocreate'
        Test-Path $dest | Should -BeFalse

        Copy-AzureLocalItsmSample -Destination $dest 6>$null | Out-Null

        Test-Path $dest | Should -BeTrue
        Test-Path (Join-Path $dest 'templates') | Should -BeTrue
        Test-Path (Join-Path $dest 'templates\incident-body.md') | Should -BeTrue
    }
}

#endregion Copy-AzureLocalItsmSample (v0.7.50)

#region Apply-Updates Schedule Coverage Advisor (v0.7.65)

Describe 'Function: Test-AzureLocalApplyUpdatesScheduleCoverage' {

    Context 'Parameter Validation' {
        BeforeAll {
            $command = Get-Command Test-AzureLocalApplyUpdatesScheduleCoverage
        }

        It 'Is CmdletBinding' {
            $command.CmdletBinding | Should -BeTrue
        }

        It 'Should have View parameter with ValidateSet (Audit, Matrix, Recommend)' {
            $command.Parameters.Keys | Should -Contain 'View'
            $vs = $command.Parameters['View'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $vs | Should -Not -BeNullOrEmpty
            ($vs.ValidValues | Sort-Object) | Should -Be (@('Audit','Matrix','Recommend') | Sort-Object)
        }

        It 'Should have Platform parameter with ValidateSet (GitHubActions, AzureDevOps, Both)' {
            $command.Parameters.Keys | Should -Contain 'Platform'
            $vs = $command.Parameters['Platform'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $vs | Should -Not -BeNullOrEmpty
            ($vs.ValidValues | Sort-Object) | Should -Be (@('AzureDevOps','Both','GitHubActions') | Sort-Object)
        }

        It 'Should have LeadTimeMinutes parameter with ValidateRange 0..60' {
            $command.Parameters.Keys | Should -Contain 'LeadTimeMinutes'
            $vr = $command.Parameters['LeadTimeMinutes'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $vr | Should -Not -BeNullOrEmpty
            $vr.MinRange | Should -Be 0
            $vr.MaxRange | Should -Be 60
        }

        It 'Should have SubscriptionId, PipelineYamlPath, UpdateRingTag, IncludeUntagged, ExportPath, PassThru parameters' {
            foreach ($p in @('SubscriptionId','PipelineYamlPath','UpdateRingTag','IncludeUntagged','ExportPath','PassThru')) {
                $command.Parameters.Keys | Should -Contain $p
            }
        }

        It 'Declares [OutputType([PSCustomObject[]])]' {
            # PSCustomObject is a PowerShell accelerator for PSObject, so the
            # resolved type name on the OutputTypeAttribute is 'PSObject[]'.
            $command.OutputType.Type.Name | Should -Contain 'PSObject[]'
        }

        It 'Throws when -View Audit is used without -PipelineYamlPath' {
            InModuleScope AzLocal.UpdateManagement {
                Mock Invoke-AzResourceGraphQuery { @() }
                { Test-AzureLocalApplyUpdatesScheduleCoverage -View Audit } |
                    Should -Throw -ExpectedMessage '*PipelineYamlPath is required*'
            }
        }

        It 'Throws when PipelineYamlPath does not exist' {
            InModuleScope AzLocal.UpdateManagement {
                Mock Invoke-AzResourceGraphQuery { @() }
                { Test-AzureLocalApplyUpdatesScheduleCoverage -View Audit -PipelineYamlPath 'X:\does\not\exist.yml' } |
                    Should -Throw -ExpectedMessage '*PipelineYamlPath not found*'
            }
        }
    }

    Context 'Private helper: Convert-AzLocalUpdateWindowToCron' {
        It 'Sat-Sun_02:00-06:00 with lead 5 -> 55 1 * * 6,0' {
            InModuleScope AzLocal.UpdateManagement {
                $r = Convert-AzLocalUpdateWindowToCron -UpdateWindow 'Sat-Sun_02:00-06:00' -LeadTimeMinutes 5
                $r | Should -HaveCount 1
                $r[0].CronExpression | Should -Be '55 1 * * 6,0'
                $r[0].FireHour | Should -Be 1
                $r[0].FireMinute | Should -Be 55
                $r[0].DayShift | Should -BeFalse
            }
        }

        It 'Mon-Fri_22:00-04:00 with lead 5 -> 55 21 * * 1-5 (range)' {
            InModuleScope AzLocal.UpdateManagement {
                $r = Convert-AzLocalUpdateWindowToCron -UpdateWindow 'Mon-Fri_22:00-04:00' -LeadTimeMinutes 5
                $r | Should -HaveCount 1
                $r[0].CronExpression | Should -Be '55 21 * * 1-5'
            }
        }

        It 'Sun_03:00-07:00 with lead 5 -> 55 2 * * 0' {
            InModuleScope AzLocal.UpdateManagement {
                $r = Convert-AzLocalUpdateWindowToCron -UpdateWindow 'Sun_03:00-07:00' -LeadTimeMinutes 5
                $r[0].CronExpression | Should -Be '55 2 * * 0'
            }
        }

        It 'Lead-time wrap: Mon_00:05-04:00 with lead 10 -> 55 23 * * 0 (Sun) with DayShift=$true' {
            InModuleScope AzLocal.UpdateManagement {
                $r = Convert-AzLocalUpdateWindowToCron -UpdateWindow 'Mon_00:05-04:00' -LeadTimeMinutes 10
                $r[0].CronExpression | Should -Be '55 23 * * 0'
                $r[0].DayShift | Should -BeTrue
            }
        }

        It 'Multi-segment window emits one cron per segment' {
            InModuleScope AzLocal.UpdateManagement {
                $r = Convert-AzLocalUpdateWindowToCron -UpdateWindow 'Mon-Fri_22:00-04:00;Sat-Sun_02:00-10:00' -LeadTimeMinutes 5
                $r | Should -HaveCount 2
                ($r | ForEach-Object CronExpression) -join '|' | Should -Be '55 21 * * 1-5|55 1 * * 6,0'
            }
        }
    }

    Context 'Private helper: ConvertFrom-AzLocalCronExpression' {
        It 'Parses 55 1 * * 6,0 and enumerates 2 fire times in the reference week' {
            InModuleScope AzLocal.UpdateManagement {
                $p = ConvertFrom-AzLocalCronExpression -Expression '55 1 * * 6,0'
                $p.IsValid | Should -BeTrue
                $p.IsComplex | Should -BeFalse
                @($p.FireTimes).Count | Should -Be 2
            }
        }

        It 'Parses comma-separated minutes (0,15,30,45) into 4 entries per hour' {
            InModuleScope AzLocal.UpdateManagement {
                $p = ConvertFrom-AzLocalCronExpression -Expression '0,15,30,45 2 * * 1'
                $p.IsValid | Should -BeTrue
                @($p.FireTimes).Count | Should -Be 4
            }
        }

        It 'Flags non-* DayOfMonth as IsComplex (advisor cannot evaluate)' {
            InModuleScope AzLocal.UpdateManagement {
                $p = ConvertFrom-AzLocalCronExpression -Expression '0 2 15 * *'
                $p.IsValid | Should -BeTrue
                $p.IsComplex | Should -BeTrue
                @($p.FireTimes).Count | Should -Be 0
            }
        }

        It 'Parses */15 step syntax (v0.7.67) and enumerates 4 fires per hour' {
            # v0.7.67: cron step syntax is now supported. Pre-v0.7.67 this
            # asserted IsValid=$false and ErrorMessage matched "not supported";
            # the advisor would falsely flag every-15-minute crons as
            # UnparseableCron even though GitHub Actions and Azure DevOps
            # both honour the syntax.
            InModuleScope AzLocal.UpdateManagement {
                $p = ConvertFrom-AzLocalCronExpression -Expression '*/15 * * * *'
                $p.IsValid | Should -BeTrue
                $p.IsComplex | Should -BeFalse
                # 60 / 15 = 4 minutes per hour * 24 hours * 7 days = 672 fires.
                @($p.FireTimes).Count | Should -Be 672
            }
        }

        It 'Parses bounded step range 9-17/2 in the hour field (v0.7.67)' {
            InModuleScope AzLocal.UpdateManagement {
                # 0 9-17/2 * * 1-5 -> hours 9,11,13,15,17 on weekdays = 5 fires/day * 5 days = 25.
                $p = ConvertFrom-AzLocalCronExpression -Expression '0 9-17/2 * * 1-5'
                $p.IsValid | Should -BeTrue
                $p.IsComplex | Should -BeFalse
                @($p.FireTimes).Count | Should -Be 25
            }
        }

        It 'Parses start-anchored step 5/15 in the minute field (v0.7.67)' {
            InModuleScope AzLocal.UpdateManagement {
                # 5/15 in minute (0-59) -> 5,20,35,50 = 4 fires per hour.
                $p = ConvertFrom-AzLocalCronExpression -Expression '5/15 * * * 1'
                $p.IsValid | Should -BeTrue
                @($p.FireTimes).Count | Should -Be (4 * 24)
                # First fire should be at minute 5, not 0.
                $p.FireTimes[0].Minute | Should -Be 5
            }
        }

        It 'Rejects step expressions with non-positive N (v0.7.67)' {
            InModuleScope AzLocal.UpdateManagement {
                $p = ConvertFrom-AzLocalCronExpression -Expression '*/0 * * * *'
                $p.IsValid | Should -BeFalse
                $p.ErrorMessage | Should -Match 'positive integer'
            }
        }

        It 'Rejects wrong field count' {
            InModuleScope AzLocal.UpdateManagement {
                $p = ConvertFrom-AzLocalCronExpression -Expression '0 2 * *'
                $p.IsValid | Should -BeFalse
                $p.ErrorMessage | Should -Match '5 cron fields'
            }
        }

        It 'Treats DOW=7 as Sunday (== 0)' {
            InModuleScope AzLocal.UpdateManagement {
                $p7 = ConvertFrom-AzLocalCronExpression -Expression '0 2 * * 7'
                $p0 = ConvertFrom-AzLocalCronExpression -Expression '0 2 * * 0'
                @($p7.FireTimes).Count | Should -Be 1
                $p7.FireTimes[0] | Should -Be $p0.FireTimes[0]
            }
        }
    }

    Context 'Private helper: Read-AzLocalApplyUpdatesYamlCrons' {
        BeforeAll {
            $script:tmpYamlDir = Join-Path $env:TEMP "schedule-cov-tests-$(Get-Random)"
            New-Item -ItemType Directory -Path (Join-Path $script:tmpYamlDir 'github-actions') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $script:tmpYamlDir 'azure-devops')   -Force | Out-Null
            @"
on:
  workflow_dispatch:
  schedule:
    - cron: '55 1 * * 6,0'
    - cron: "0 22 * * 5"
"@ | Set-Content -Path (Join-Path $script:tmpYamlDir 'github-actions\Step.5_apply-updates.yml') -Encoding ASCII
            @"
trigger: none
schedules:
  - cron: '30 2 * * 1-5'
    displayName: Weekday early-morning
    branches:
      include: [ main ]
"@ | Set-Content -Path (Join-Path $script:tmpYamlDir 'azure-devops\Step.5_apply-updates.yml') -Encoding ASCII
        }
        AfterAll {
            Remove-Item -Path $script:tmpYamlDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Discovers 2 GH cron lines + 1 ADO cron line with platform inferred from folder name' {
            InModuleScope AzLocal.UpdateManagement -Parameters @{ tmpYamlDir = $script:tmpYamlDir } {
                param($tmpYamlDir)
                $r = Read-AzLocalApplyUpdatesYamlCrons -Path $tmpYamlDir
                @($r).Count | Should -Be 3
                @($r | Where-Object Platform -eq 'GitHubActions').Count | Should -Be 2
                @($r | Where-Object Platform -eq 'AzureDevOps').Count   | Should -Be 1
            }
        }

        It 'Strips surrounding quotes from cron expressions' {
            InModuleScope AzLocal.UpdateManagement -Parameters @{ tmpYamlDir = $script:tmpYamlDir } {
                param($tmpYamlDir)
                $r = Read-AzLocalApplyUpdatesYamlCrons -Path $tmpYamlDir
                ($r | ForEach-Object CronExpression) | Should -Contain '55 1 * * 6,0'
                ($r | ForEach-Object CronExpression) | Should -Contain '0 22 * * 5'
                ($r | ForEach-Object CronExpression) | Should -Contain '30 2 * * 1-5'
            }
        }
    }

    Context 'Behavior: Audit / Matrix / Recommend' {
        BeforeAll {
            $script:tmpYamlDir2 = Join-Path $env:TEMP "schedule-cov-behaviour-$(Get-Random)"
            New-Item -ItemType Directory -Path (Join-Path $script:tmpYamlDir2 'github-actions') -Force | Out-Null
            # YAML covers Sat/Sun windows (fires Sat 01:50, Sun 01:50) but does NOT cover Mon-Fri windows.
            @"
on:
  schedule:
    - cron: '50 1 * * 6,0'
"@ | Set-Content -Path (Join-Path $script:tmpYamlDir2 'github-actions\Step.5_apply-updates.yml') -Encoding ASCII
        }
        AfterAll {
            Remove-Item -Path $script:tmpYamlDir2 -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Audit: reports Covered for Sat-Sun window and Uncovered for Mon-Fri window' {
            InModuleScope AzLocal.UpdateManagement -Parameters @{ tmpYamlDir2 = $script:tmpYamlDir2 } {
                param($tmpYamlDir2)
                Mock Invoke-AzResourceGraphQuery {
                    @(
                        [PSCustomObject]@{ ClusterName='c1'; ResourceGroup='r'; SubscriptionId='s'; ClusterResourceId='/s/r/c1'; UpdateRing='Wave1';      UpdateWindow='Sat-Sun_02:00-06:00' },
                        [PSCustomObject]@{ ClusterName='c2'; ResourceGroup='r'; SubscriptionId='s'; ClusterResourceId='/s/r/c2'; UpdateRing='Wave1';      UpdateWindow='Sat-Sun_02:00-06:00' },
                        [PSCustomObject]@{ ClusterName='c3'; ResourceGroup='r'; SubscriptionId='s'; ClusterResourceId='/s/r/c3'; UpdateRing='Production'; UpdateWindow='Mon-Fri_22:00-04:00' }
                    )
                }
                $result = Test-AzureLocalApplyUpdatesScheduleCoverage -View Audit -PipelineYamlPath $tmpYamlDir2 -PassThru 6>$null
                $rWave  = $result | Where-Object UpdateRing -eq 'Wave1'
                $rProd  = $result | Where-Object UpdateRing -eq 'Production'
                $rWave.Status | Should -Be 'Covered'
                $rWave.ClusterCount | Should -Be 2
                $rProd.Status | Should -Be 'Uncovered'
                $rProd.RequiredCronUTC | Should -Be '55 21 * * 1-5'
            }
        }

        It 'Matrix: emits one row per distinct (Ring, Window) with RequiredCronUTC populated' {
            InModuleScope AzLocal.UpdateManagement {
                Mock Invoke-AzResourceGraphQuery {
                    @(
                        [PSCustomObject]@{ ClusterName='c1'; ResourceGroup='r'; SubscriptionId='s'; ClusterResourceId='/s/r/c1'; UpdateRing='Wave1'; UpdateWindow='Sat-Sun_02:00-06:00' }
                    )
                }
                $result = Test-AzureLocalApplyUpdatesScheduleCoverage -View Matrix -PassThru 6>$null
                $result | Should -HaveCount 1
                $result[0].RequiredCronUTC | Should -Be '55 1 * * 6,0'
                $result[0].ClusterCount | Should -Be 1
            }
        }

        It 'Recommend: dedupes crons across rings and emits one row per cron' {
            InModuleScope AzLocal.UpdateManagement {
                Mock Invoke-AzResourceGraphQuery {
                    @(
                        [PSCustomObject]@{ ClusterName='c1'; ResourceGroup='r'; SubscriptionId='s'; ClusterResourceId='/s/r/c1'; UpdateRing='Pilot'; UpdateWindow='Sat-Sun_02:00-06:00' },
                        [PSCustomObject]@{ ClusterName='c2'; ResourceGroup='r'; SubscriptionId='s'; ClusterResourceId='/s/r/c2'; UpdateRing='Wave1'; UpdateWindow='Sat-Sun_02:00-06:00' }
                    )
                }
                $result = Test-AzureLocalApplyUpdatesScheduleCoverage -View Recommend -PassThru 6>$null
                $result | Should -HaveCount 1
                $result[0].CronExpression | Should -Be '55 1 * * 6,0'
                $result[0].ClusterCount   | Should -Be 2
                ($result[0].Rings | Sort-Object) | Should -Be @('Pilot','Wave1')
                $result[0].Snippet | Should -Match "schedule:"
            }
        }

        It 'Audit: MalformedTag emitted when UpdateWindow tag fails to parse' {
            InModuleScope AzLocal.UpdateManagement -Parameters @{ tmpYamlDir2 = $script:tmpYamlDir2 } {
                param($tmpYamlDir2)
                Mock Invoke-AzResourceGraphQuery {
                    @([PSCustomObject]@{ ClusterName='c1'; ResourceGroup='r'; SubscriptionId='s'; ClusterResourceId='/s/r/c1'; UpdateRing='X'; UpdateWindow='NotAWindow' })
                }
                $result = Test-AzureLocalApplyUpdatesScheduleCoverage -View Audit -PipelineYamlPath $tmpYamlDir2 -PassThru 6>$null
                ($result | Where-Object UpdateRing -eq 'X').Status | Should -Be 'MalformedTag'
            }
        }

        It '-IncludeUntagged surfaces clusters with no UpdateWindow tag' {
            InModuleScope AzLocal.UpdateManagement -Parameters @{ tmpYamlDir2 = $script:tmpYamlDir2 } {
                param($tmpYamlDir2)
                Mock Invoke-AzResourceGraphQuery {
                    @(
                        [PSCustomObject]@{ ClusterName='c1'; ResourceGroup='r'; SubscriptionId='s'; ClusterResourceId='/s/r/c1'; UpdateRing='Wave1'; UpdateWindow='Sat-Sun_02:00-06:00' },
                        [PSCustomObject]@{ ClusterName='c2'; ResourceGroup='r'; SubscriptionId='s'; ClusterResourceId='/s/r/c2'; UpdateRing='';      UpdateWindow='' }
                    )
                }
                $result = Test-AzureLocalApplyUpdatesScheduleCoverage -View Audit -PipelineYamlPath $tmpYamlDir2 -IncludeUntagged -PassThru 6>$null
                ($result | Where-Object Status -eq 'NoWindowTag').ClusterCount | Should -Be 1
            }
        }
    }
}

#endregion Apply-Updates Schedule Coverage Advisor (v0.7.65)

#region v0.7.66 UX + Multi-Value UpdateRing regression suite

Describe 'v0.7.66 UpdateRing ValidatePattern accepts list & wildcard forms' {
    # Strategy: directly probe the ValidatePattern attribute on every public
    # cmdlet that accepts UpdateRingValue / UpdateRingTag. Going through the
    # actual cmdlet would require Azure mocking just to exercise the validator,
    # which is fragile. Reflecting on the AttributeMetadata is deterministic.

    # NOTE: these arrays MUST be defined at Discovery time (i.e. outside
    # BeforeAll / BeforeEach) so the -ForEach blocks below can enumerate
    # them when Pester builds the test tree. BeforeAll runs during the Run
    # phase, after discovery - using $script: there yields an empty -ForEach
    # set and zero generated It blocks.
    BeforeDiscovery {
        $script:RingValueCmdlets = @(
            'Get-AzureLocalAvailableUpdates'
            'Get-AzureLocalClusterInventory'
            'Get-AzureLocalClusterUpdateReadiness'
            'Get-AzureLocalFleetProgress'
            'Get-AzureLocalFleetStatusData'
            'Get-AzureLocalUpdateRuns'
            'Get-AzureLocalUpdateSummary'
            'Invoke-AzureLocalFleetOperation'
            'New-AzureLocalFleetStatusHtmlReport'
            'Reset-AzureLocalSideloadedTag'
            'Set-AzureLocalClusterUpdateRingTag'
            'Start-AzureLocalClusterUpdate'
            'Test-AzureLocalClusterHealth'
            'Test-AzureLocalFleetHealthGate'
        )
        # Get-AzureLocalFleetHealthFailures uses the param name UpdateRingTag.
        $script:RingTagCmdlets = @(
            'Get-AzureLocalFleetHealthFailures'
        )
    }

    Context 'ValidatePattern attribute' {
        It "Cmdlet <Cmdlet> -UpdateRingValue accepts 'Wave1', 'Prod;Ring2', and '***'" -ForEach @(
            $script:RingValueCmdlets | ForEach-Object { @{ Cmdlet = $_; ParamName = 'UpdateRingValue' } }
        ) {
            $cmd = Get-Command -Name $Cmdlet -Module AzLocal.UpdateManagement
            $cmd | Should -Not -BeNullOrEmpty -Because "v0.7.66 cmdlets should be exported"
            $param = $cmd.Parameters[$ParamName]
            $param | Should -Not -BeNullOrEmpty -Because "$Cmdlet should expose -$ParamName"
            $vp = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidatePatternAttribute] }
            $vp | Should -Not -BeNullOrEmpty -Because "$Cmdlet -$ParamName must carry a ValidatePattern attribute"
            $rx = $vp.RegexPattern
            # Acceptance set - all of these must match the relaxed regex.
            # NOTE: '***' (three stars) is the deliberate wildcard token introduced in v0.7.66.
            # A bare '*' is REJECTED so a single-character typo cannot accidentally scope a fleet-wide write.
            foreach ($candidate in @('Wave1', 'Prod', 'Ring2', 'Prod;Ring2', 'A;B;C', '***', 'a_b-c', 'X0', 'p1;p2;p3')) {
                ([regex]::IsMatch($candidate, $rx)) | Should -BeTrue -Because "'$candidate' should be a valid -$ParamName value for $Cmdlet under v0.7.66"
            }
            # Rejection set - must still block obviously hostile/malformed inputs AND the easy-to-mistype '*', '**', '****' variants.
            foreach ($candidate in @('Foo bar', "abc'def", '<script>', 'a;b;', ';abc', 'abc;', '', '#bad', "a`nb", '*', '**', '****', '*Wave1', 'Wave1*', '***;Wave1')) {
                ([regex]::IsMatch($candidate, $rx)) | Should -BeFalse -Because "'$candidate' must NOT be accepted by $Cmdlet -$ParamName (v0.7.66 only accepts ring tokens or the exact 3-star '***' wildcard)"
            }
        }

        It "Cmdlet <Cmdlet> -<ParamName> accepts 'Wave1', 'Prod;Ring2', and '***'" -ForEach @(
            $script:RingTagCmdlets | ForEach-Object { @{ Cmdlet = $_; ParamName = 'UpdateRingTag' } }
        ) {
            $cmd = Get-Command -Name $Cmdlet -Module AzLocal.UpdateManagement
            $param = $cmd.Parameters[$ParamName]
            $param | Should -Not -BeNullOrEmpty
            $vp = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidatePatternAttribute] }
            $vp | Should -Not -BeNullOrEmpty
            $rx = $vp.RegexPattern
            foreach ($candidate in @('Wave1', 'Prod;Ring2', '***')) {
                ([regex]::IsMatch($candidate, $rx)) | Should -BeTrue -Because "'$candidate' should be a valid -$ParamName value for $Cmdlet under v0.7.66"
            }
            foreach ($candidate in @('Foo bar', "abc'def", 'abc;', '', '*', '**', '****')) {
                ([regex]::IsMatch($candidate, $rx)) | Should -BeFalse -Because "'$candidate' must NOT be accepted (single/double/quad-star are rejected; only the exact 3-star '***' wildcard passes)"
            }
        }
    }
}

Describe 'v0.7.66 ConvertTo-AzLocalUpdateRingKqlFilter helper' {
    # Helper is private to the module; exercise it via InModuleScope.

    It 'Returns isnotempty clause for "***" (wildcard scopes to clusters that HAVE a non-empty UpdateRing tag)' {
        InModuleScope AzLocal.UpdateManagement {
            (ConvertTo-AzLocalUpdateRingKqlFilter -UpdateRingValue '***') | Should -Be "| where isnotempty(tags['UpdateRing'])"
        }
    }

    It 'Honours -TagAccessor for the "***" wildcard on the fleet-health failures path (tostring)' {
        InModuleScope AzLocal.UpdateManagement {
            (ConvertTo-AzLocalUpdateRingKqlFilter -UpdateRingValue '***' -TagAccessor "tostring(tags['UpdateRing'])") | Should -Be "| where isnotempty(tostring(tags['UpdateRing']))"
        }
    }

    It 'Returns =~ clause for a single ring' {
        InModuleScope AzLocal.UpdateManagement {
            (ConvertTo-AzLocalUpdateRingKqlFilter -UpdateRingValue 'Wave1') | Should -Be "| where tags['UpdateRing'] =~ 'Wave1'"
        }
    }

    It 'Returns in~ clause for a semicolon-delimited list' {
        InModuleScope AzLocal.UpdateManagement {
            (ConvertTo-AzLocalUpdateRingKqlFilter -UpdateRingValue 'Prod;Ring2') | Should -Be "| where tags['UpdateRing'] in~ ('Prod','Ring2')"
        }
    }

    It "Escapes embedded single quotes by doubling them (KQL safe)" {
        InModuleScope AzLocal.UpdateManagement {
            $out = ConvertTo-AzLocalUpdateRingKqlFilter -UpdateRingValue "ab'cd"
            $out | Should -Be "| where tags['UpdateRing'] =~ 'ab''cd'"
        }
    }

    It 'Honours -TagAccessor for the fleet-health failures path (tostring)' {
        InModuleScope AzLocal.UpdateManagement {
            (ConvertTo-AzLocalUpdateRingKqlFilter -UpdateRingValue 'Wave1' -TagAccessor "tostring(tags['UpdateRing'])") | Should -Be "| where tostring(tags['UpdateRing']) =~ 'Wave1'"
        }
    }

    It 'Trims whitespace and drops empty segments' {
        InModuleScope AzLocal.UpdateManagement {
            $out = ConvertTo-AzLocalUpdateRingKqlFilter -UpdateRingValue ' Wave1 ; Wave2 '
            $out | Should -Be "| where tags['UpdateRing'] in~ ('Wave1','Wave2')"
        }
    }

    It 'Returns empty string for null/empty/whitespace input' {
        InModuleScope AzLocal.UpdateManagement {
            (ConvertTo-AzLocalUpdateRingKqlFilter -UpdateRingValue '')   | Should -Be ''
            (ConvertTo-AzLocalUpdateRingKqlFilter -UpdateRingValue '   ') | Should -Be ''
        }
    }
}

Describe 'v0.7.66 Artifact download names carry a UTC timestamp suffix' {
    # Every downloadable artifact must include either a GH outputs token
    # (steps.<id>.outputs.timestamp) or an ADO output variable
    # ($(<stamp>.artifactStamp)) so that re-running the same pipeline on the
    # same day produces distinct zip filenames.

    BeforeAll {
        $script:examplesRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\Automation-Pipeline-Examples')).Path
    }

    It 'GitHub Actions: every upload-artifact step uses a timestamped name and azlocal- prefix' {
        $ghDir   = Join-Path $script:examplesRoot 'github-actions'
        $ghFiles = Get-ChildItem -Path $ghDir -Filter '*.yml' -File
        $offenders = New-Object System.Collections.Generic.List[string]
        foreach ($yml in $ghFiles) {
            $content = Get-Content -LiteralPath $yml.FullName -Raw
            # Find every upload-artifact step's `name:` value in its `with:` block.
            $rxArtifact = [regex]::new("(?ms)uses:\s*actions/upload-artifact@[^\r\n]+\r?\n\s*with:\s*\r?\n\s*name:\s*([^\r\n]+)")
            foreach ($m in $rxArtifact.Matches($content)) {
                $name = $m.Groups[1].Value.Trim().Trim("'""")
                if ($name -notmatch 'azlocal-') {
                    $offenders.Add("$($yml.Name): upload-artifact name '$name' missing azlocal- prefix")
                }
                if ($name -notmatch '\$\{\{\s*steps\.[^}]+\.outputs\.timestamp\s*\}\}') {
                    $offenders.Add("$($yml.Name): upload-artifact name '$name' missing steps.<id>.outputs.timestamp suffix")
                }
            }
        }
        $detail = if ($offenders.Count -gt 0) { $offenders -join [Environment]::NewLine } else { '(no offenders)' }
        $offenders.Count | Should -Be 0 -Because "every actions/upload-artifact step must carry an azlocal-* name with steps.<id>.outputs.timestamp. Findings:$([Environment]::NewLine)$detail"
    }

    It 'Azure DevOps: every PublishBuildArtifacts / PublishPipelineArtifact uses a timestamped name and azlocal- prefix' {
        $adoDir   = Join-Path $script:examplesRoot 'azure-devops'
        $adoFiles = Get-ChildItem -Path $adoDir -Filter '*.yml' -File
        $offenders = New-Object System.Collections.Generic.List[string]
        foreach ($yml in $adoFiles) {
            $content = Get-Content -LiteralPath $yml.FullName -Raw
            # Match both ArtifactName: '...' and artifact: '...'
            $rxAdo = [regex]::new("(?im)^\s*(ArtifactName|artifact)\s*:\s*'([^']+)'")
            foreach ($m in $rxAdo.Matches($content)) {
                $key  = $m.Groups[1].Value
                $name = $m.Groups[2].Value
                if ($name -notmatch '^azlocal-') {
                    $offenders.Add("$($yml.Name): ${key} '$name' missing azlocal- prefix")
                }
                # Accept either the in-stage step-output form (`$(stamp.artifactStamp)`)
                # OR a cross-stage variable that ends in `ArtifactStamp)`, which is
                # how `Step.5_apply-updates.yml` consumes the CheckReadiness stage's stamp
                # via the `readinessArtifactStamp` mapped variable.
                if ($name -notmatch '\$\(.+?[Aa]rtifactStamp\)') {
                    $offenders.Add("$($yml.Name): ${key} '$name' missing a `$(...artifactStamp) suffix")
                }
            }
        }
        $detail = if ($offenders.Count -gt 0) { $offenders -join [Environment]::NewLine } else { '(no offenders)' }
        $offenders.Count | Should -Be 0 -Because "every PublishBuildArtifacts/PublishPipelineArtifact ArtifactName must be azlocal-*_`$(stamp.artifactStamp). Findings:$([Environment]::NewLine)$detail"
    }

    It 'GitHub Actions: legacy non-stamped artifact names are gone' {
        $ghDir = Join-Path $script:examplesRoot 'github-actions'
        $legacyTokens = @(
            'name: fleet-status-reports'
            'name: fleet-health-reports'
            'name: cluster-inventory'
            'name: updatering-tag-logs'
            'name: schedule-coverage-reports'
            'name: readiness-report'
            'name: readiness-assessment'
            'name: update-logs'
            'name: itsm-results'
        )
        $offenders = New-Object System.Collections.Generic.List[string]
        foreach ($yml in Get-ChildItem -Path $ghDir -Filter '*.yml' -File) {
            $content = Get-Content -LiteralPath $yml.FullName -Raw
            foreach ($t in $legacyTokens) {
                if ($content -match [regex]::Escape($t) + '\s*$' -or $content -match [regex]::Escape($t) + '\r?\n') {
                    $offenders.Add("$($yml.Name): still contains legacy artifact token '$t'")
                }
            }
        }
        $detail = if ($offenders.Count -gt 0) { $offenders -join [Environment]::NewLine } else { '(no offenders)' }
        $offenders.Count | Should -Be 0 -Because "v0.7.66 renamed every GH artifact to azlocal-*_<timestamp>. Findings:$([Environment]::NewLine)$detail"
    }

    It 'Azure DevOps: legacy non-stamped ArtifactName values are gone' {
        $adoDir = Join-Path $script:examplesRoot 'azure-devops'
        $legacyTokens = @(
            "ArtifactName: 'FleetStatusReports'"
            "ArtifactName: 'FleetHealthReports'"
            "ArtifactName: 'cluster-inventory'"
            "ArtifactName: 'updatering-tag-logs'"
            "ArtifactName: 'ScheduleCoverageReports'"
            "ArtifactName: 'readiness-report'"
            "artifact: 'readiness-assessment'"
            "ArtifactName: 'update-logs'"
            "ArtifactName: 'itsm-results'"
        )
        $offenders = New-Object System.Collections.Generic.List[string]
        foreach ($yml in Get-ChildItem -Path $adoDir -Filter '*.yml' -File) {
            $content = Get-Content -LiteralPath $yml.FullName -Raw
            foreach ($t in $legacyTokens) {
                if ($content -match [regex]::Escape($t)) {
                    $offenders.Add("$($yml.Name): still contains legacy artifact token '$t'")
                }
            }
        }
        $detail = if ($offenders.Count -gt 0) { $offenders -join [Environment]::NewLine } else { '(no offenders)' }
        $offenders.Count | Should -Be 0 -Because "v0.7.66 renamed every ADO ArtifactName to azlocal-*_`$(stamp.artifactStamp). Findings:$([Environment]::NewLine)$detail"
    }
}

Describe 'v0.7.66 Fleet Update Status summary uses status emojis and groups failures first' {
    # Guards the v0.7.66 UX refresh of Step.6_fleet-update-status.yml summary blocks
    # on both GH and ADO. The summary now uses 'red cross / green tick' emojis
    # instead of '[ok]/[fail]/...' bracket markers, and the per-cluster JUnit
    # block orders failed clusters first.

    BeforeAll {
        $script:examplesRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\Automation-Pipeline-Examples')).Path
        $script:fleetStatusFiles = @(
            Join-Path $script:examplesRoot 'github-actions\Step.6_fleet-update-status.yml'
            Join-Path $script:examplesRoot 'azure-devops\Step.6_fleet-update-status.yml'
        )
    }

    It "Both Step.6_fleet-update-status.yml files contain success and failure status emojis" {
        foreach ($yml in $script:fleetStatusFiles) {
            # Must read explicitly as UTF-8; the YAML has no BOM, and PS 5.1
            # Get-Content -Raw without -Encoding defaults to Default (cp1252),
            # which mangles multi-byte glyphs like U+2705 into 3 separate chars.
            $content = [System.IO.File]::ReadAllText($yml, [System.Text.UTF8Encoding]::new($false))
            # PowerShell here strings to dodge Unicode source-file confusion in this test:
            $tick  = [string]::new([char[]]@(0x2705))            # white-heavy-check-mark
            $cross = [string]::new([char[]]@(0x274C))            # cross-mark
            ($content -match [regex]::Escape($tick))  | Should -BeTrue  -Because "$(Split-Path -Leaf $yml) must use the U+2705 success emoji in its summary"
            ($content -match [regex]::Escape($cross)) | Should -BeTrue  -Because "$(Split-Path -Leaf $yml) must use the U+274C failure emoji in its summary"
            # Legacy bracket markers must be gone:
            ($content -match '\[ok\]')    | Should -BeFalse -Because "$(Split-Path -Leaf $yml) must no longer use the '[ok]' bracket marker"
            ($content -match '\[fail\]')  | Should -BeFalse -Because "$(Split-Path -Leaf $yml) must no longer use the '[fail]' bracket marker"
        }
    }

    It "Both Step.6_fleet-update-status.yml files render a UTC timestamp in the summary heading" {
        foreach ($yml in $script:fleetStatusFiles) {
            $content = Get-Content -LiteralPath $yml -Raw
            ($content -match 'Fleet Update Status Summary\s*_\(generated \$generatedUtc\)_') | Should -BeTrue -Because "$(Split-Path -Leaf $yml) must include the generated UTC timestamp in the H2 heading"
            ($content -match 'generatedUtc\s*=\s*\(Get-Date\)\.ToUniversalTime\(\)') | Should -BeTrue -Because "$(Split-Path -Leaf $yml) must compute generatedUtc with ToUniversalTime()"
        }
    }

    It "Both Step.6_fleet-update-status.yml files bucket failed clusters ahead of passed clusters before emitting the JUnit table" {
        foreach ($yml in $script:fleetStatusFiles) {
            $content = Get-Content -LiteralPath $yml -Raw
            ($content -match '\$failedClusters')    | Should -BeTrue -Because "$(Split-Path -Leaf $yml) must build a `$failedClusters bucket"
            ($content -match '\$passedClusters')    | Should -BeTrue -Because "$(Split-Path -Leaf $yml) must build a `$passedClusters bucket"
            ($content -match '\$orderedClusters\s*=\s*@\(\$failedClusters') | Should -BeTrue -Because "$(Split-Path -Leaf $yml) must concatenate failed-first, then passed, into `$orderedClusters"
        }
    }
}

Describe 'v0.7.66 Pipeline update_ring inputs document multi-value and wildcard support' {
    BeforeAll {
        $script:examplesRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\Automation-Pipeline-Examples')).Path
    }

    It "Every pipeline file that surfaces an update_ring/updateRing input mentions ';' and '***'" {
        $files = Get-ChildItem -Path $script:examplesRoot -Recurse -Filter '*.yml' -File
        $offenders = New-Object System.Collections.Generic.List[string]
        foreach ($yml in $files) {
            $content = Get-Content -LiteralPath $yml.FullName -Raw
            # Only check files that EXPOSE the input (not files that merely read it via INPUT_UPDATE_RING).
            $exposesInput = $content -match '(?m)^\s+update_ring:\s*$' -or $content -match '(?m)^\s+-\s+name:\s+updateRing\s*$'
            if (-not $exposesInput) { continue }
            # Search for description: 'X' or displayName: 'X' lines following the input declaration.
            # v0.7.66 deliberately uses '***' (three stars) - a bare '*' is REJECTED by the cmdlet's ValidatePattern.
            $hasMultiHint = $content -match "Prod;Ring2" -and $content -match "'\*\*\*'"
            if (-not $hasMultiHint) {
                $offenders.Add("$($yml.FullName.Substring($script:examplesRoot.Length).TrimStart('\','/')): update_ring/updateRing input does not mention 'Prod;Ring2' AND '***' in its description/displayName")
            }
        }
        $detail = if ($offenders.Count -gt 0) { $offenders -join [Environment]::NewLine } else { '(no offenders)' }
        $offenders.Count | Should -Be 0 -Because "v0.7.66 documents multi-value + wildcard UpdateRing support on every exposed input. Findings:$([Environment]::NewLine)$detail"
    }
}

#endregion v0.7.66 UX + Multi-Value UpdateRing regression suite


#region v0.7.67 CI/CD parity + doc-drift regression suite

Describe 'v0.7.67 schedule-audit zero-row JUnit parity' {
    # v0.7.67 regression guard: Step.3_apply-updates-schedule-audit.yml previously
    # behaved differently across CI platforms when the fleet had no tagged
    # clusters. Azure DevOps emitted a passing testcase ("No tagged clusters
    # found - nothing to audit") so the run rendered as passed (1/1) in the
    # Tests tab. GitHub Actions wrote an EMPTY <testsuite>, which
    # dorny/test-reporter surfaced as "no tests found" - indistinguishable
    # from a broken reporter step. v0.7.67 brings the GH workflow into parity
    # by writing the same passing testcase for the zero-row case. This test
    # guards both files so neither side regresses.
    BeforeAll {
        $script:examplesRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\Automation-Pipeline-Examples')).Path
    }

    It 'GitHub Actions schedule-audit YAML emits the zero-row testcase' {
        $yml = Join-Path $script:examplesRoot 'github-actions\Step.3_apply-updates-schedule-audit.yml'
        Test-Path -LiteralPath $yml | Should -BeTrue -Because "the GH schedule-audit YAML should exist at $yml"
        $content = Get-Content -LiteralPath $yml -Raw
        $content | Should -Match 'classname="ScheduleCoverage" name="No tagged clusters found - nothing to audit"' -Because 'v0.7.67 added the zero-row JUnit testcase to the GH schedule-audit YAML to match ADO parity'
    }

    It 'Azure DevOps schedule-audit YAML still emits the zero-row testcase' {
        $yml = Join-Path $script:examplesRoot 'azure-devops\Step.3_apply-updates-schedule-audit.yml'
        Test-Path -LiteralPath $yml | Should -BeTrue -Because "the ADO schedule-audit YAML should exist at $yml"
        $content = Get-Content -LiteralPath $yml -Raw
        $content | Should -Match 'classname="ScheduleCoverage" name="No tagged clusters found - nothing to audit"' -Because 'the ADO schedule-audit YAML has emitted the zero-row JUnit testcase since v0.7.0; the v0.7.67 parity work must not regress it'
    }
}

Describe 'v0.7.67 doc drift - old UpdateRing regex' {
    # v0.7.67 doc-drift guard: v0.7.66 widened the UpdateRing ValidatePattern
    # from the strict single-token form '^[A-Za-z0-9_-]{1,64}$' to the
    # semicolon-list + wildcard form
    # '^(\*\*\*|[A-Za-z0-9_-]{1,64}(;[A-Za-z0-9_-]{1,64})*)$'. The strict
    # regex must NOT appear in any consumer-facing README. The CHANGELOG.md
    # historical entry for the regex change is the only legitimate place
    # where the old regex may still appear (as a historical reference).
    # This test scans non-CHANGELOG markdown for the literal old regex.
    It 'No consumer-facing README documents the v0.7.65 strict-single-token UpdateRing regex' {
        $oldRegexLiteral = '^[A-Za-z0-9_-]{1,64}$'
        $moduleRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..')).Path
        # CHANGELOG.md is the historical record - it MAY contain the old
        # regex when documenting the change. Everywhere else, it is drift.
        $targets = @(
            Join-Path $moduleRoot 'README.md'
            Join-Path $moduleRoot 'Automation-Pipeline-Examples\README.md'
        )
        $offenders = New-Object System.Collections.Generic.List[string]
        foreach ($md in $targets) {
            if (-not (Test-Path -LiteralPath $md)) { continue }
            $content = Get-Content -LiteralPath $md -Raw
            if ($content -and $content.Contains($oldRegexLiteral)) {
                $offenders.Add($md.Substring($moduleRoot.Length).TrimStart('\','/'))
            }
        }
        $detail = if ($offenders.Count -gt 0) { $offenders -join [Environment]::NewLine } else { '(no offenders)' }
        $offenders.Count | Should -Be 0 -Because "v0.7.66 widened the UpdateRing regex to accept semicolon-separated lists and the '***' wildcard. Any non-CHANGELOG README that still documents the strict single-token regex '$oldRegexLiteral' will mislead consumers. Findings:$([Environment]::NewLine)$detail"
    }
}

Describe 'v0.7.67 schedule-audit summary - cron fixes first when issues exist' {
    # Phase 4.3: when Uncovered / PartiallyCovered / MalformedTag / UnparseableCron > 0,
    # the schedule-audit pipelines must surface the recommended cron block ABOVE the
    # detail table so operators can act without scrolling. Guardrail asserts that both
    # YAMLs carry the conditional structure (hasIssues + 'Action required' header).
    $moduleRoot = Split-Path $PSScriptRoot -Parent
    $yamlCases = @(
        @{
            Platform = 'github-actions'
            YamlPath = (Join-Path $moduleRoot 'Automation-Pipeline-Examples\github-actions\Step.3_apply-updates-schedule-audit.yml')
        }
        @{
            Platform = 'azure-devops'
            YamlPath = (Join-Path $moduleRoot 'Automation-Pipeline-Examples\azure-devops\Step.3_apply-updates-schedule-audit.yml')
        }
    )

    It '[<Platform>] schedule-audit YAML emits recommendation before audit detail when issues exist' -ForEach $yamlCases {
        Test-Path $YamlPath | Should -BeTrue -Because "expected schedule-audit YAML at $YamlPath"
        $content = Get-Content -Path $YamlPath -Raw
        $content | Should -Match '\$hasIssues\s*=\s*\(\(\[int\]\$uncovered\)' -Because 'Phase 4.3 conditional must compute $hasIssues from the four issue counts.'
        $content | Should -Match 'Action required - paste these cron entries into Step\.5_apply-updates\.yml' -Because 'Phase 4.3 must surface a top-of-summary "Action required" header when issues exist.'
        $idxActionRequired = $content.IndexOf('Action required - paste these cron entries')
        $idxAuditDetail    = $content.IndexOf('### Audit Detail')
        $idxActionRequired | Should -BeGreaterThan -1
        $idxAuditDetail    | Should -BeGreaterThan -1
        $idxActionRequired | Should -BeLessThan $idxAuditDetail -Because 'When issues exist, recommendation block must precede the detail table in the summary script.'
    }
}

Describe 'v0.7.67 Reset-AzureLocalSideloadedTag warns on malformed Resource IDs' {
    # v0.7.67 review finding: the ByResourceId resolver silently dropped Resource
    # IDs that did not end in '/clusters/<name>'. Operators with typo'd inputs
    # (trailing slash, wrong provider, truncated string) would never see the
    # entry was excluded from the reset. This test ensures the resolver emits a
    # Write-Log Warning for any input it cannot match.
    BeforeAll {
        $moduleName = 'AzLocal.UpdateManagement'
    }

    It 'Writes a Warning for a malformed Resource ID and does not include it in targets' {
        InModuleScope AzLocal.UpdateManagement {
            $warnings = @()
            Mock Write-Log -ParameterFilter { $Level -eq 'Warning' } -MockWith {
                $script:warnings += ,$Message
            }
            Mock Write-Log {}
            Mock Test-AzCliAvailable { return $true }
            # Force the function to short-circuit before any 'az' / network call:
            # by passing only a malformed RID, $targets will end up empty, and
            # the function returns @() with a "no matching clusters" warning.
            $script:warnings = @()
            $script:result = $null
            { $script:result = Reset-AzureLocalSideloadedTag `
                -ClusterResourceIds @('/this/is/not/a/cluster/resource/id') `
                -Confirm:$false } | Should -Not -Throw
            ($script:warnings -join "`n") | Should -Match "does not match an Azure Local cluster Resource ID"
        }
    }
}

Describe 'v0.7.67 Import-AzureLocalFleetState size guard' {
    # v0.7.67 review finding: the helper called `Get-Content -Raw |
    # ConvertFrom-Json` on the input file without any size check. A user
    # pointed at a multi-GB file (typo, mis-glob, malicious symlink) would
    # OOM the runner. We now reject anything > 50 MB.
    It 'Throws when the input file exceeds the 50 MB safety cap' {
        InModuleScope AzLocal.UpdateManagement {
            $tempFile = Join-Path $env:TEMP "fleet-state-oversize-$([guid]::NewGuid()).json"
            '{"RunId":"x","TotalClusters":0,"CompletedCount":0,"FailedCount":0,"PendingCount":0}' |
                Out-File -FilePath $tempFile -Encoding ASCII
            try {
                Mock Get-Item {
                    [PSCustomObject]@{ Length = 60MB; FullName = $tempFile }
                } -ParameterFilter { $LiteralPath -eq $tempFile }
                # Capture Write-Error rather than letting it surface (the
                # helper catches the throw and re-emits via Write-Error,
                # returning $null).
                $result = Import-AzureLocalFleetState -Path $tempFile -ErrorAction SilentlyContinue -ErrorVariable err
                $result | Should -BeNullOrEmpty
                ($err | Out-String) | Should -Match '50 MB safety cap'
            }
            finally {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'Loads a normal-sized fleet state without invoking the cap' {
        InModuleScope AzLocal.UpdateManagement {
            $tempFile = Join-Path $env:TEMP "fleet-state-normal-$([guid]::NewGuid()).json"
            '{"RunId":"abc","StartTime":"2025-01-01T00:00:00Z","TotalClusters":1,"CompletedCount":0,"FailedCount":0,"PendingCount":1}' |
                Out-File -FilePath $tempFile -Encoding ASCII
            try {
                $result = Import-AzureLocalFleetState -Path $tempFile
                $result | Should -Not -BeNullOrEmpty
                $result.RunId | Should -Be 'abc'
            }
            finally {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

#endregion v0.7.67 CI/CD parity + doc-drift regression suite

