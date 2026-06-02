#Requires -Version 7.6
#Requires -Modules Pester

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Support' -AdditionalChildPath 'ConvertToVvc.InvocationSuite.ps1')
    $script:toolSupport = Initialize-ConvertToVvcInvocationSuite -TestDrivePath $TestDrive
}

AfterAll {
    Restore-ConvertToVvcInvocationSuite -ToolSupport $script:toolSupport
}

Describe 'Convert-ToVvc invocation' -Tag 'integration' {
    BeforeEach {
        # Precondition cleanup: restore the fake-tool environment before each example.
        Reset-ConvertToVvcInvocationSuite -ToolSupport $script:toolSupport
    }

    AfterEach {
        # Postcondition cleanup: avoid marker or scenario leakage across examples.
        Reset-ConvertToVvcInvocationSuite -ToolSupport $script:toolSupport
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

    Context 'when encoder configuration is supplied' {
        It 'passes encoder thread settings to ffmpeg: <Name>' -ForEach @(
            @{ Name = 'automatic threads'; EncoderThreads = 0 }
            @{ Name = 'bounded threads'; EncoderThreads = 2 }
        ) {
            $scenarioParams = New-ValidConvertScenarioParams -FileName 'ryuji-threaded-encode.mkv' -Override @{
                InputContent   = ('threaded media payload' * 4096)
                EncoderThreads = $EncoderThreads
            }
            $scenario = Invoke-ConvertScenario @scenarioParams

            Assert-ScenarioSucceeded -Scenario $scenario -FileName 'ryuji-threaded-encode.mkv'

            $ffmpegInvocation = Read-LatestFakeToolInvocation -MarkerPath $scenario.FfmpegMarker
            $fakeToolParameters = @{
                Argv          = $ffmpegInvocation.Argv
                Name          = '-threads'
                ExpectedValue = [string] $EncoderThreads
            }
            Assert-FakeToolArgumentValue @fakeToolParameters
        }
    }

}
