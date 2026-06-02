#Requires -Version 7.6
#Requires -Modules Pester

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Support' -AdditionalChildPath 'ConvertToVvc.InvocationSuite.ps1')
    $script:toolSupport = Initialize-ConvertToVvcInvocationSuite -TestDrivePath $TestDrive
}

AfterAll {
    Restore-ConvertToVvcInvocationSuite -ToolSupport $script:toolSupport
}

Describe 'Convert-ToVvc invocation parallel execution' -Tag 'integration' {
    BeforeEach {
        Reset-ConvertToVvcInvocationSuite -ToolSupport $script:toolSupport
    }

    AfterEach {
        Reset-ConvertToVvcInvocationSuite -ToolSupport $script:toolSupport
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

        It 'converts multiple inputs in one parallel invocation with isolated markers and artifacts' {
            $scenario = Invoke-MultiConvertScenario `
                -FileNames 'sadako-parallel-one.mkv', 'ryuji-parallel-two.mkv' `
                -MaxParallel 2

            $scenario.Result.Count | Should -Be 2
            $scenario.Result.File | Should -Contain 'sadako-parallel-one.mkv'
            $scenario.Result.File | Should -Contain 'ryuji-parallel-two.mkv'
            $scenario.Result.Ok | Should -Not -Contain $false
            $scenario.Result.Skipped | Should -Not -Contain $true

            foreach ($input in $scenario.Inputs) {
                Test-Path -LiteralPath $input.OutputPath |
                    Should -BeTrue
                Test-Path -LiteralPath $input.PartialOutputPath |
                    Should -BeFalse
                Assert-FakeToolInvokedWithPath -MarkerPath $scenario.FfmpegMarker -ExpectedPath $input.InputPath
                Assert-FakeToolInvokedWithPath -MarkerPath $scenario.FfprobeMarker -ExpectedPath $input.InputPath
            }

            Assert-FakeToolInvocationCount -MarkerPath $scenario.FfmpegMarker -ExpectedCount 2
            Assert-FakeToolInvocationCount -MarkerPath $scenario.FfprobeMarker -ExpectedCount 8
        }
    }
}
