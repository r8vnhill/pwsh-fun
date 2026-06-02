#Requires -Version 7.6
#Requires -Modules Pester

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Support' -AdditionalChildPath 'ConvertToVvc.InvocationSuite.ps1')
    $script:toolSupport = Initialize-ConvertToVvcInvocationSuite -TestDrivePath $TestDrive
}

AfterAll {
    Restore-ConvertToVvcInvocationSuite -ToolSupport $script:toolSupport
}

Describe 'Convert-ToVvc invocation path binding' -Tag 'integration' {
    BeforeEach {
        Reset-ConvertToVvcInvocationSuite -ToolSupport $script:toolSupport
    }

    AfterEach {
        Reset-ConvertToVvcInvocationSuite -ToolSupport $script:toolSupport
    }

    Context 'when paths are bound explicitly or through the pipeline' {
        It 'supports path binding mode: <Name>' -ForEach @(
            @{ Name = 'explicit LiteralPath'; UseLiteralPath = $true; UsePipelinePath = $false }
            @{ Name = 'pipeline LiteralPath'; UseLiteralPath = $false; UsePipelinePath = $true }
        ) {
            $scenarioParams = New-ValidConvertScenarioParams -FileName 'asakawa-literal-path.mkv' -Override @{
                InputContent    = ('literal path media payload' * 4096)
                UseLiteralPath  = $UseLiteralPath
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

        It 'treats path-sensitive filenames as literal paths: <Name>' -ForEach @(
            @{
                Name     = 'spaces'
                FileName = 'asakawa interview.mkv'
                Converts = $true
            }
            @{
                Name     = 'brackets'
                FileName = 'cursed-tape[copy].mkv'
                Converts = $true
            }
            @{
                Name     = 'uppercase extension is currently filtered out'
                FileName = 'ryuji-source.MKV'
                Converts = $false
            }
        ) {
            $scenarioParams = New-ValidConvertScenarioParams -FileName $FileName -Override @{
                InputContent   = ('path-sensitive media payload' * 4096)
                UseLiteralPath = $true
            }
            $scenario = Invoke-ConvertScenario @scenarioParams

            if (-not $Converts) {
                Assert-ScenarioHasNoResults -Scenario $scenario
                Assert-ToolInvocationState -Scenario $scenario -ExpectFfprobe $false -ExpectFfmpeg $false
                return
            }

            Assert-ScenarioSucceeded -Scenario $scenario -FileName $FileName

            $expectedOutputName = '{0}_vvc.mkv' -f [IO.Path]::GetFileNameWithoutExtension($FileName)
            [IO.Path]::GetFileName($scenario.OutputPath) | Should -Be $expectedOutputName

            $ffmpegInvocation = Read-LatestFakeToolInvocation -MarkerPath $scenario.FfmpegMarker
            $ffmpegInvocation.Argv | Should -Contain $scenario.InputPath

            Assert-ScenarioArtifactState -Scenario $scenario -ExpectOutput $true -ExpectPartialOutput $false
        }
    }
}
