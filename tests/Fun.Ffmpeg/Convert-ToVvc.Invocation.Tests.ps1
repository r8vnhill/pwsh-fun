#Requires -Version 7.5
#Requires -Modules Pester

BeforeAll {
    . (Join-Path $PSScriptRoot 'Support\FakeMediaTools.ps1')
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
    Restore-FakeMediaToolSupport -Context $script:toolSupport
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

    It 'advertises ConvertToVvcResult as OutputType metadata' {
        $command = Get-Command Convert-ToVvc

        @($command.OutputType).Type.Name | Should -Contain 'ConvertToVvcResult'
    }

    It 'invokes ffmpeg and returns a success-shaped result for a valid input' {
        $scenarioParams = @{
            FileName         = 'good.mkv'
            InputContent     = ('synthetic but non-empty media payload' * 4096)
            FfprobeScenarios = New-ValidVvcScenarioSet -FileName 'good.mkv'
            CreateOutput     = $true
        }
        $scenario = Invoke-ConvertScenario @scenarioParams

        Assert-ScenarioSucceeded -Scenario $scenario -FileName 'good.mkv'

        $toolStateParams = @{
            Scenario      = $scenario
            ExpectFfprobe = $true
            ExpectFfmpeg  = $true
        }
        Assert-ToolInvocationState @toolStateParams
        (Test-Path -LiteralPath $scenario.OutputPath) | Should -BeTrue
    }

    It 'passes encoder thread settings to ffmpeg' -ForEach @(
        @{ Name = 'automatic threads'; EncoderThreads = 0 }
        @{ Name = 'bounded threads'; EncoderThreads = 2 }
    ) {
        $scenarioParams = @{
            FileName         = 'threads.mkv'
            InputContent     = ('threaded media payload' * 4096)
            FfprobeScenarios = New-ValidVvcScenarioSet -FileName 'threads.mkv'
            CreateOutput     = $true
            EncoderThreads   = $EncoderThreads
        }
        $scenario = Invoke-ConvertScenario @scenarioParams

        Assert-ScenarioSucceeded -Scenario $scenario -FileName 'threads.mkv'

        $ffmpegArgs = Get-Content -LiteralPath $scenario.FfmpegMarker -Raw
        $ffmpegArgs | Should -Match ('-threads {0}' -f $EncoderThreads)
    }

    It 'imports the module and invokes the internal worker entrypoint in parallel mode' {
        $scenarioParams = @{
            FileName         = 'parallel.mkv'
            InputContent     = ('parallel media payload' * 4096)
            FfprobeScenarios = New-ValidVvcScenarioSet -FileName 'parallel.mkv'
            CreateOutput     = $true
            MaxParallel      = 2
        }
        $scenario = Invoke-ConvertScenario @scenarioParams

        Assert-ScenarioSucceeded -Scenario $scenario -FileName 'parallel.mkv'

        $toolStateParams = @{
            Scenario      = $scenario
            ExpectFfprobe = $true
            ExpectFfmpeg  = $true
        }
        Assert-ToolInvocationState @toolStateParams
    }

    It 'ignores native ffmpeg progress output leaked into the worker stream' {
        $scenarioParams = @{
            FileName             = 'progress.mkv'
            InputContent         = ('synthetic but non-empty media payload' * 4096)
            FfprobeScenarios     = New-ValidVvcScenarioSet -FileName 'progress.mkv'
            CreateOutput         = $true
            EmitFfmpegProgress   = $true
        }
        $scenario = Invoke-ConvertScenario @scenarioParams

        Assert-ScenarioSucceeded -Scenario $scenario -FileName 'progress.mkv'
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

    It 'supports LiteralPath and pipeline path input' -ForEach @(
        @{ Name = 'explicit LiteralPath'; UseLiteralPath = $true; UsePipelinePath = $false }
        @{ Name = 'pipeline LiteralPath'; UseLiteralPath = $false; UsePipelinePath = $true }
    ) {
        $scenarioParams = @{
            FileName         = 'literal.mkv'
            InputContent     = ('literal path media payload' * 4096)
            FfprobeScenarios = New-ValidVvcScenarioSet -FileName 'literal.mkv'
            CreateOutput     = $true
            UseLiteralPath   = $UseLiteralPath
            UsePipelinePath  = $UsePipelinePath
        }
        $scenario = Invoke-ConvertScenario @scenarioParams

        Assert-ScenarioSucceeded -Scenario $scenario -FileName 'literal.mkv'

        $toolStateParams = @{
            Scenario      = $scenario
            ExpectFfprobe = $true
            ExpectFfmpeg  = $true
        }
        Assert-ToolInvocationState @toolStateParams
        (Test-Path -LiteralPath $scenario.OutputPath) | Should -BeTrue
    }

    It 'returns a skipped result when a valid output already exists and Overwrite is not set' {
        $scenarioParams = @{
            FileName             = 'exists.mkv'
            InputContent         = ('valid source media' * 4096)
            FfprobeScenarios     = @{
                'exists.mkv'     = New-ValidProbeScenario -Codec 'h264'
                'exists_vvc.mkv' = New-ValidProbeScenario -Codec 'vvc'
            }
            CreateExistingOutput = $true
        }
        $scenario = Invoke-ConvertScenario @scenarioParams

        $skipParams = @{
            Scenario = $scenario
            Reason   = 'exists (valid)'
            FileName = 'exists.mkv'
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

    It 'returns no results under WhatIf and does not invoke ffmpeg' {
        $scenarioParams = @{
            FileName        = 'whatif.mkv'
            InputContent    = ('whatif source media' * 4096)
            UseWhatIf       = $true
            CreateOutputDir = $true
            FfprobeScenarios = @{
                'whatif.mkv' = New-ValidProbeScenario -Codec 'h264'
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
            FileName         = 'nomatch.mkv'
            InputContent     = ('unsupported extension for this run' * 4096)
            Extensions       = @('.mp4')
            FfprobeScenarios = @{
                'nomatch.mkv' = New-ValidProbeScenario -Codec 'h264'
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

    It 'returns a failed result when ffmpeg exits non-zero and cleans up partial output' {
        $scenarioParams = @{
            FileName         = 'ffmpeg-fail.mkv'
            InputContent     = ('synthetic media payload' * 4096)
            FfprobeScenarios = New-ValidVvcScenarioSet -FileName 'ffmpeg-fail.mkv'
            CreateOutput     = $true
            FfmpegExitCode   = 17
        }
        $scenario = Invoke-ConvertScenario @scenarioParams

        $failParams = @{
            Scenario      = $scenario
            ReasonPattern = '^ffmpeg exit 17$'
            FileName      = 'ffmpeg-fail.mkv'
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
            FileName         = 'bad-convert.mkv'
            InputContent     = ('synthetic media payload' * 4096)
            FfprobeScenarios = @{
                'bad-convert.mkv'                  = New-ValidProbeScenario -Codec 'h264'
                'bad-convert_vvc.__partial__.mkv' = New-ValidProbeScenario -Codec 'h264'
            }
            CreateOutput     = $true
        }
        $scenario = Invoke-ConvertScenario @scenarioParams

        $failParams = @{
            Scenario      = $scenario
            ReasonPattern = "^bad convert: unexpected codec: 'h264'$"
            FileName      = 'bad-convert.mkv'
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
