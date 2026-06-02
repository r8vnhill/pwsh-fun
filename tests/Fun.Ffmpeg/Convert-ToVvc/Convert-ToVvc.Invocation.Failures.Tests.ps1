#Requires -Version 7.6
#Requires -Modules Pester

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Support' -AdditionalChildPath 'ConvertToVvc.InvocationSuite.ps1')
    $script:toolSupport = Initialize-ConvertToVvcInvocationSuite -TestDrivePath $TestDrive
}

AfterAll {
    Restore-ConvertToVvcInvocationSuite -ToolSupport $script:toolSupport
}

Describe 'Convert-ToVvc invocation failure handling' -Tag 'integration' {
    BeforeEach {
        Reset-ConvertToVvcInvocationSuite -ToolSupport $script:toolSupport
    }

    AfterEach {
        Reset-ConvertToVvcInvocationSuite -ToolSupport $script:toolSupport
    }

    Context 'when native tools fail' {
        It 'returns a failed result when input probing fails and does not invoke ffmpeg' {
            $scenarioParams = @{
                FileName         = 'asakawa-probe-fail.mkv'
                InputContent     = ('synthetic media payload' * 4096)
                FfprobeScenarios = @{
                    'asakawa-probe-fail.mkv' = @{
                        ProbeFailMessage = 'probe failure: unreadable source'
                    }
                }
            }
            $scenario = Invoke-ConvertScenario @scenarioParams

            $failParams = @{
                Scenario      = $scenario
                ReasonPattern = '^invalid input: probe failure: unreadable source$'
                FileName      = 'asakawa-probe-fail.mkv'
                OriginalMb    = 'positive'
            }
            Assert-ScenarioFailed @failParams

            Assert-FakeToolInvocationCount -MarkerPath $scenario.FfprobeMarker -ExpectedCount 1
            Assert-FakeToolInvocationCount -MarkerPath $scenario.FfmpegMarker -ExpectedCount 0
            Assert-ScenarioArtifactState -Scenario $scenario -ExpectOutput $false -ExpectPartialOutput $false
        }

        It 'returns a failed result when ffmpeg exits non-zero and cleans up partial output' {
            $scenarioParams = @{
                FileName         = 'ryuji-ffmpeg-fail.mkv'
                InputContent     = ('synthetic media payload' * 4096)
                FfprobeScenarios = New-ValidVvcScenarioSet -FileName 'ryuji-ffmpeg-fail.mkv'
                CreateOutput     = $true
                FfmpegExitCode   = 17
            }
            $scenario = Invoke-ConvertScenario @scenarioParams

            $failParams = @{
                Scenario      = $scenario
                ReasonPattern = '^ffmpeg exit 17$'
                FileName      = 'ryuji-ffmpeg-fail.mkv'
            }
            Assert-ScenarioFailed @failParams

            $toolStateParams = @{
                Scenario      = $scenario
                ExpectFfprobe = $true
                ExpectFfmpeg  = $true
            }
            Assert-ToolInvocationState @toolStateParams
            (Test-Path -LiteralPath $scenario.OutputPath) | Should -BeFalse
            (Test-Path -LiteralPath $scenario.PartialOutputPath) | Should -BeFalse
        }

        It 'returns a failed result when ffmpeg output fails post-validation and cleans up partial output' {
            $scenarioParams = @{
                FileName         = 'well-scene-bad-convert.mkv'
                InputContent     = ('synthetic media payload' * 4096)
                FfprobeScenarios = @{
                    'well-scene-bad-convert.mkv'                 = New-ValidProbeScenario -Codec 'h264'
                    'well-scene-bad-convert_vvc.__partial__.mkv' = New-ValidProbeScenario -Codec 'h264'
                }
                CreateOutput     = $true
            }
            $scenario = Invoke-ConvertScenario @scenarioParams

            $failParams = @{
                Scenario      = $scenario
                ReasonPattern = "^bad convert: unexpected codec: 'h264'$"
                FileName      = 'well-scene-bad-convert.mkv'
            }
            Assert-ScenarioFailed @failParams

            $toolStateParams = @{
                Scenario      = $scenario
                ExpectFfprobe = $true
                ExpectFfmpeg  = $true
            }
            Assert-ToolInvocationState @toolStateParams
            (Test-Path -LiteralPath $scenario.OutputPath) | Should -BeFalse
            (Test-Path -LiteralPath $scenario.PartialOutputPath) | Should -BeFalse
        }
    }

    Context 'when native streams contain noise' {
        It 'ignores native ffmpeg progress output leaked into the worker stream' {
            $scenarioParams = @{
                FileName           = 'shizuko-progress-noise.mkv'
                InputContent       = ('synthetic but non-empty media payload' * 4096)
                FfprobeScenarios   = New-ValidVvcScenarioSet -FileName 'shizuko-progress-noise.mkv'
                CreateOutput       = $true
                EmitFfmpegProgress = $true
            }
            $scenario = Invoke-ConvertScenario @scenarioParams

            Assert-ScenarioSucceeded -Scenario $scenario -FileName 'shizuko-progress-noise.mkv'
            $scenario.Result.Count | Should -Be 1

            $toolStateParams = @{
                Scenario      = $scenario
                ExpectFfprobe = $true
                ExpectFfmpeg  = $true
            }
            Assert-ToolInvocationState @toolStateParams
            (Test-Path -LiteralPath $scenario.OutputPath) | Should -BeTrue
            (Test-Path -LiteralPath $scenario.PartialOutputPath) | Should -BeFalse
        }
    }
}
