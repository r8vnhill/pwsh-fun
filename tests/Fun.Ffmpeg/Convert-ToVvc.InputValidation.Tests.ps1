#Requires -Version 7.5
#Requires -Modules Pester

BeforeAll {
    . (Join-Path $PSScriptRoot 'Support\FakeMediaTools.ps1')
    . (Join-Path $PSScriptRoot 'Support\ConvertToVvc.SpecSupport.ps1')

    $toolSupportParams = @{
        TestDrivePath = $TestDrive
        MockDirName   = 'ffmpeg-convert-input-validation-mocks'
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

Describe 'Convert-ToVvc input validation' -Tag 'integration' {
    BeforeEach {
        # Precondition cleanup: restore the fake-tool environment before each example.
        Reset-FakeMediaToolEnvironment -Context $script:toolSupport
    }

    AfterEach {
        # Postcondition cleanup: avoid marker or scenario leakage across examples.
        Reset-FakeMediaToolEnvironment -Context $script:toolSupport
    }

    It 'fails early for invalid inputs without invoking ffmpeg' -ForEach @(
        @{
            Name                  = 'corrupt container'
            FileName              = 'broken.mkv'
            InputContent          = ('not a real matroska file' * 2048)
            CreateEmptyFile       = $false
            FfprobeScenarios      = @{
                'broken.mkv' = @{
                    ProbeFailMessage = '[in#0 @ 0000000000000000] EBML header parsing failed'
                }
            }
            ExpectedReasonPattern = 'EBML header parsing failed'
            ExpectFfprobeInvoked  = $true
            ExpectedOriginalMb    = 'positive'
        }
        @{
            Name                  = 'empty file'
            FileName              = 'empty.mkv'
            CreateEmptyFile       = $true
            FfprobeScenarios      = @{}
            ExpectedReasonPattern = '^invalid input: input file is empty\.$'
            ExpectFfprobeInvoked  = $false
            ExpectedOriginalMb    = 'zero'
        }
    ) {
        $scenarioParams = @{
            FileName         = $FileName
            InputContent     = $InputContent
            CreateEmptyFile  = $CreateEmptyFile
            FfprobeScenarios = $FfprobeScenarios
        }
        $scenario = Invoke-ConvertScenario @scenarioParams

        $failParams = @{
            Scenario      = $scenario
            ReasonPattern = '^invalid input: '
            FileName      = $FileName
            OriginalMb    = $ExpectedOriginalMb
        }
        Assert-ScenarioFailed @failParams
        $scenario.Result[0].Reason | Should -Match $ExpectedReasonPattern

        $toolStateParams = @{
            Scenario      = $scenario
            ExpectFfprobe = $ExpectFfprobeInvoked
            ExpectFfmpeg  = $false
        }
        Assert-ToolInvocationState @toolStateParams
        (Test-Path -LiteralPath $scenario.OutputPath) | Should -BeFalse
    }
}
