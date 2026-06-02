#Requires -Version 7.6
#Requires -Modules Pester

<#
.SYNOPSIS
Core public invocation characterization for `Convert-ToVvc`.

.DESCRIPTION
This suite verifies the smallest “happy path plus encoder configuration” surface of `Convert-ToVvc` through the public 
command boundary. It intentionally exercises the same lifecycle used by the narrower sibling invocation suites.

Sibling suites should own more specialized behavior:
- marker accounting
- path binding edge cases
- existing-output decisions
- execution bypass
- native-tool failures
- stream-noise filtering
- parallel execution

This file should remain focused on the baseline public invocation contract: a valid input is converted, fake native 
tools are invoked, output artifacts are created, and encoder options reach ffmpeg as structured argv tokens.

The shared invocation-suite lifecycle is loaded from: `tests/Fun.Ffmpeg/Support/ConvertToVvc.InvocationSuite.ps1`
#>

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Support' -AdditionalChildPath 'ConvertToVvc.InvocationSuite.ps1')

    $script:toolSupport = Initialize-ConvertToVvcInvocationSuite -TestDrivePath $TestDrive
}

AfterAll {
    if ($script:toolSupport) {
        Restore-ConvertToVvcInvocationSuite -ToolSupport $script:toolSupport
    }
}

Describe 'Convert-ToVvc invocation' -Tag 'integration' {
    <## 
     # Reset before and after each example because the suite mutates fake native-tool state, marker directories, 
     # environment/path state, and temporary media artifacts.
     # Keeping both resets makes each example resilient to failures in the previous one.
     ##>
    BeforeEach {
        Reset-ConvertToVvcInvocationSuite -ToolSupport $script:toolSupport
    }

    AfterEach {
        Reset-ConvertToVvcInvocationSuite -ToolSupport $script:toolSupport
    }

    Context 'when inputs are convertible' {
        It 'invokes ffmpeg and returns a success-shaped result for a valid input' {
            $scenarioParams = New-ValidConvertScenarioParams -FileName 'asakawa-source.mkv' -Override @{
                InputContent = ('Ringu archive source payload' * 4096)
            }

            $scenario = Invoke-ConvertScenario @scenarioParams

            Assert-ScenarioSucceeded -Scenario $scenario -FileName 'asakawa-source.mkv'

            Assert-ToolInvocationState -Scenario $scenario -ExpectFfprobe $true -ExpectFfmpeg $true

            Assert-ScenarioArtifactState -Scenario $scenario -ExpectOutput $true -ExpectPartialOutput $false
        }
    }

    Context 'when encoder configuration is supplied' {
        It 'passes encoder thread settings to ffmpeg: <Name>' -ForEach @(
            @{
                Name           = 'automatic threads'
                EncoderThreads = 0
            }
            @{
                Name           = 'bounded threads'
                EncoderThreads = 2
            }
        ) {
            $scenarioParams = New-ValidConvertScenarioParams -FileName 'ryuji-threaded-encode.mkv' -Override @{
                InputContent   = ('Ryuji threaded media payload' * 4096)
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
