#Requires -Version 7.6
#Requires -Modules Pester

BeforeAll {
    . (Join-Path $PSScriptRoot 'Support\FakeMediaTools.ps1')
    . (Join-Path $PSScriptRoot 'Support\FakeToolArgumentSupport.ps1')
    . (Join-Path $PSScriptRoot 'Support\ConvertToVvc.SpecSupport.ps1')

    $toolSupportParams = @{
        TestDrivePath = $TestDrive
        MockDirName   = 'ffmpeg-convert-invocation-mocks'
    }
    $script:toolSupport = Initialize-FakeMediaToolSupport @toolSupportParams

    Enable-FakeMediaToolSupport -Context $script:toolSupport

    Import-Module -Name (
        Join-Path $PSScriptRoot '..\..\modules\Fun.Ffmpeg\Fun.Ffmpeg.psd1'
    ) -Force -ErrorAction Stop
}

AfterAll {
    if ($script:toolSupport) {
        Restore-FakeMediaToolSupport -Context $script:toolSupport
    }
}

Describe 'Convert-ToVvc invocation' -Tag 'integration' {
    BeforeEach {
        # Precondition cleanup: restore the fake-tool environment before each example.
        Reset-FakeMediaToolEnvironment -Context $script:toolSupport
    }

    AfterEach {
        # Postcondition cleanup: avoid marker or scenario leakage across examples.
        Reset-FakeMediaToolEnvironment -Context $script:toolSupport
    }

    Context 'when inputs are convertible' {
        It 'invokes ffmpeg and returns a success-shaped result for a valid input' {
            $scenarioParams = New-ValidConvertScenarioParams -FileName 'asakawa-source.mkv' -Override @{
                InputContent = ('synthetic but non-empty media payload' * 4096)
            }
            $scenario = Invoke-ConvertScenario @scenarioParams

            Assert-ScenarioSucceeded -Scenario $scenario -FileName 'asakawa-source.mkv'

            $toolStateParams = @{
                Scenario      = $scenario
                ExpectFfprobe = $true
                ExpectFfmpeg  = $true
            }
            Assert-ToolInvocationState @toolStateParams
            Assert-ScenarioArtifactState -Scenario $scenario -ExpectOutput $true -ExpectPartialOutput $false
        }
    }

    Context 'when fake-tool markers are read through support helpers' {
        It 'reads legacy raw marker text as compatibility argv tokens' {
            $markerPath = Join-Path $TestDrive 'legacy-fake-tool-marker.txt'
            Set-Content -LiteralPath $markerPath -Value '-i asakawa-source.mkv -threads 2 output.mkv' -NoNewline

            $marker = Read-FakeToolArguments -MarkerPath $markerPath

            $marker.Format | Should -Be 'LegacyRaw'
            $marker.Raw | Should -Be '-i asakawa-source.mkv -threads 2 output.mkv'
            Assert-FakeToolArgumentValue -Argv $marker.Argv -Name '-threads' -ExpectedValue '2'
        }

        It 'reads future JSON marker text as argv tokens' {
            $markerPath = Join-Path $TestDrive 'json-fake-tool-marker.txt'
            $markerJson = @{
                tool             = 'ffmpeg'
                argv             = @('-i', 'asakawa-source.mkv', '-threads', '2', 'output.mkv')
                workingDirectory = 'Nenya'
            } | ConvertTo-Json -Compress
            Set-Content -LiteralPath $markerPath -Value $markerJson -NoNewline

            $marker = Read-FakeToolArguments -MarkerPath $markerPath

            $marker.Format | Should -Be 'Json'
            $marker.ToolName | Should -Be 'ffmpeg'
            $marker.WorkingDirectory | Should -Be 'Nenya'
            Assert-FakeToolArgumentValue -Argv $marker.Argv -Name '-threads' -ExpectedValue '2'
        }
    }

    Context 'when encoder configuration is supplied' {
        It 'passes encoder thread settings to ffmpeg' -ForEach @(
            @{ Name = 'automatic threads'; EncoderThreads = 0 }
            @{ Name = 'bounded threads'; EncoderThreads = 2 }
        ) {
            $scenarioParams = New-ValidConvertScenarioParams -FileName 'ryuji-threaded-encode.mkv' -Override @{
                InputContent   = ('threaded media payload' * 4096)
                EncoderThreads = $EncoderThreads
            }
            $scenario = Invoke-ConvertScenario @scenarioParams

            Assert-ScenarioSucceeded -Scenario $scenario -FileName 'ryuji-threaded-encode.mkv'

            $ffmpegArgs = Read-FakeToolArguments -MarkerPath $scenario.FfmpegMarker
            Assert-FakeToolArgumentValue -Argv $ffmpegArgs.Argv -Name '-threads' -ExpectedValue ([string] $EncoderThreads)
        }
    }

    Context 'when paths are bound explicitly or through the pipeline' {
        It 'supports LiteralPath and pipeline path input' -ForEach @(
            @{ Name = 'explicit LiteralPath'; UseLiteralPath = $true; UsePipelinePath = $false }
            @{ Name = 'pipeline LiteralPath'; UseLiteralPath = $false; UsePipelinePath = $true }
        ) {
            $scenarioParams = New-ValidConvertScenarioParams -FileName 'asakawa-literal-path.mkv' -Override @{
                InputContent   = ('literal path media payload' * 4096)
                UseLiteralPath = $UseLiteralPath
                UsePipelinePath = $UsePipelinePath
            }
            $scenario = Invoke-ConvertScenario @scenarioParams

            Assert-ScenarioSucceeded -Scenario $scenario -FileName 'asakawa-literal-path.mkv'

            $toolStateParams = @{
                Scenario      = $scenario
                ExpectFfprobe = $true
                ExpectFfmpeg  = $true
            }
            Assert-ToolInvocationState @toolStateParams
            Assert-ScenarioArtifactState -Scenario $scenario -ExpectOutput $true -ExpectPartialOutput $false
        }
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
    }

    Context 'when execution is bypassed' {
        It 'returns no results under WhatIf and does not invoke ffmpeg' {
            $scenarioParams = @{
                FileName        = 'asakawa-whatif.mkv'
                InputContent    = ('whatif source media' * 4096)
                UseWhatIf       = $true
                CreateOutputDir = $true
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

    Context 'when native tools fail' {
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
                    'well-scene-bad-convert.mkv'                  = New-ValidProbeScenario -Codec 'h264'
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

    Context 'when conversion runs in parallel' {
        It 'imports the module and invokes the internal worker entrypoint in parallel mode' {
            $scenarioParams = @{
                FileName         = 'sadako-parallel-run.mkv'
                InputContent     = ('parallel media payload' * 4096)
                FfprobeScenarios = New-ValidVvcScenarioSet -FileName 'sadako-parallel-run.mkv'
                CreateOutput     = $true
                MaxParallel      = 2
            }
            $scenario = Invoke-ConvertScenario @scenarioParams

            Assert-ScenarioSucceeded -Scenario $scenario -FileName 'sadako-parallel-run.mkv'

            $toolStateParams = @{
                Scenario      = $scenario
                ExpectFfprobe = $true
                ExpectFfmpeg  = $true
            }
            Assert-ToolInvocationState @toolStateParams
        }
    }
}
