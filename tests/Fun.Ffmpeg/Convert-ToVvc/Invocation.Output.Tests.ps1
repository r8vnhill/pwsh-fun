#Requires -Version 7.6
#Requires -Modules Pester

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Support' -AdditionalChildPath 'ConvertToVvc.InvocationSuite.ps1')
    $script:toolSupport = Initialize-ConvertToVvcInvocationSuite -TestDrivePath $TestDrive
}

AfterAll {
    Restore-ConvertToVvcInvocationSuite -ToolSupport $script:toolSupport
}

Describe 'Convert-ToVvc invocation output handling' -Tag 'integration' {
    BeforeEach {
        Reset-ConvertToVvcInvocationSuite -ToolSupport $script:toolSupport
    }

    AfterEach {
        Reset-ConvertToVvcInvocationSuite -ToolSupport $script:toolSupport
    }

    Context 'when output already exists' {
        It 'returns a skipped result when a valid output already exists and Overwrite is not set' {
            $scenarioParams = @{
                FileName             = 'cursed-tape-existing-output.mkv'
                InputContent         = ('valid source media' * 4096)
                FfprobeScenarios     = @{
                    'cursed-tape-existing-output.mkv'     = New-ValidProbeScenario -Codec 'h264'
                    'cursed-tape-existing-output_vvc.mkv' = New-ValidProbeScenario -Codec 'vvc'
                }
                CreateExistingOutput = $true
            }
            $scenario = Invoke-ConvertScenario @scenarioParams

            $skipParams = @{
                Scenario = $scenario
                Reason   = 'exists (valid)'
                FileName = 'cursed-tape-existing-output.mkv'
            }
            Assert-ScenarioSkipped @skipParams

            $toolStateParams = @{
                Scenario      = $scenario
                ExpectFfprobe = $true
                ExpectFfmpeg  = $false
            }
            Assert-ToolInvocationState @toolStateParams
            (Test-Path -LiteralPath $scenario.OutputPath) | Should -BeTrue
        }

        It 're-encodes when a valid output already exists and Overwrite is set' {
            $scenarioParams = @{
                FileName             = 'sadako-overwrite-output.mkv'
                InputContent         = ('valid source media' * 4096)
                CreateOutput         = $true
                FfprobeScenarios     = @{
                    'sadako-overwrite-output.mkv'     = New-ValidProbeScenario -Codec 'h264'
                    'sadako-overwrite-output_vvc.mkv' = New-ValidProbeScenario -Codec 'vvc'
                }
                CreateExistingOutput = $true
                Overwrite            = $true
            }
            $scenario = Invoke-ConvertScenario @scenarioParams

            Assert-ScenarioSucceeded -Scenario $scenario -FileName 'sadako-overwrite-output.mkv'

            $toolStateParams = @{
                Scenario      = $scenario
                ExpectFfprobe = $true
                ExpectFfmpeg  = $true
            }
            Assert-ToolInvocationState @toolStateParams
            (Test-Path -LiteralPath $scenario.OutputPath) | Should -BeTrue
            (Test-Path -LiteralPath $scenario.PartialOutputPath) | Should -BeFalse
        }

        It 're-encodes when an invalid output already exists and Overwrite is not set' {
            $scenarioParams = @{
                FileName             = 'tomoko-invalid-existing-output.mkv'
                InputContent         = ('valid source media' * 4096)
                CreateOutput         = $true
                FfprobeScenarios     = @{
                    'tomoko-invalid-existing-output.mkv'                 = New-ValidProbeScenario -Codec 'h264'
                    'tomoko-invalid-existing-output_vvc.mkv'             = New-ValidProbeScenario -Codec 'h264'
                    'tomoko-invalid-existing-output_vvc.__partial__.mkv' = New-ValidProbeScenario -Codec 'vvc'
                }
                CreateExistingOutput = $true
            }
            $scenario = Invoke-ConvertScenario @scenarioParams

            Assert-ScenarioSucceeded -Scenario $scenario -FileName 'tomoko-invalid-existing-output.mkv'

            Assert-FakeToolInvocationCount -MarkerPath $scenario.FfmpegMarker -ExpectedCount 1
            Assert-FakeToolInvocationCount -MarkerPath $scenario.FfprobeMarker -ExpectedCount 5
            Assert-ScenarioArtifactState -Scenario $scenario -ExpectOutput $true -ExpectPartialOutput $false
        }
    }

    Context 'when execution is bypassed' {
        It 'returns no results under WhatIf and does not invoke ffmpeg' {
            $scenarioParams = @{
                FileName         = 'asakawa-whatif.mkv'
                InputContent     = ('whatif source media' * 4096)
                UseWhatIf        = $true
                CreateOutputDir  = $true
                FfprobeScenarios = @{
                    'asakawa-whatif.mkv' = New-ValidProbeScenario -Codec 'h264'
                }
            }
            $scenario = Invoke-ConvertScenario @scenarioParams

            Assert-ScenarioHasNoResults -Scenario $scenario

            $toolStateParams = @{
                Scenario      = $scenario
                ExpectFfprobe = $false
                ExpectFfmpeg  = $false
            }
            Assert-ToolInvocationState @toolStateParams
            (Test-Path -LiteralPath $scenario.OutputPath) | Should -BeFalse
        }

        It 'returns no results when no files match the requested extensions' {
            $scenarioParams = @{
                FileName         = 'sadako-extension-filter.mkv'
                InputContent     = ('unsupported extension for this run' * 4096)
                Extensions       = @('.mp4')
                FfprobeScenarios = @{
                    'sadako-extension-filter.mkv' = New-ValidProbeScenario -Codec 'h264'
                }
            }
            $scenario = Invoke-ConvertScenario @scenarioParams

            Assert-ScenarioHasNoResults -Scenario $scenario

            $toolStateParams = @{
                Scenario      = $scenario
                ExpectFfprobe = $false
                ExpectFfmpeg  = $false
            }
            Assert-ToolInvocationState @toolStateParams
        }
    }
}
