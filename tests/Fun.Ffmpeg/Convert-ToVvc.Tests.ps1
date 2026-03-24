#Requires -Version 7.5
#Requires -Modules Pester
using namespace IO

<#
.SYNOPSIS
    Integration-style tests for `Convert-ToVvc`.

.DESCRIPTION
    Exercises `Convert-ToVvc` end to end through PowerShell command resolution using fake
    `ffprobe` and `ffmpeg` wrappers injected into `PATH`.

    These tests focus on workflow guardrails and tool invocation rather than the internal
    implementation of the command. In particular, they verify two high-value contracts:

    - invalid inputs fail before conversion and never reach `ffmpeg`
    - valid inputs reach `ffmpeg` and produce a success-shaped result

    The fake-tool lifecycle is delegated to `tests/Fun.Ffmpeg/Support/FakeMediaTools.ps1`,
    which is responsible for:

    - creating the fake tool directory
    - placing wrapper scripts on `PATH`
    - configuring per-test behavior
    - exposing marker files so tests can observe tool invocation
    - restoring process environment state after the suite completes

.NOTES
    These are intentionally integration-style tests. They validate observable behavior
    across tool discovery, input preparation, command execution, and output shaping.
#>
BeforeAll {
    . (Join-Path $PSScriptRoot 'Support\FakeMediaTools.ps1')

    $toolSupportParams = @{
        TestDrivePath = $TestDrive
        MockDirName   = 'ffmpeg-mocks'
    }
    $script:toolSupport = Initialize-FakeMediaToolSupport @toolSupportParams

    Enable-FakeMediaToolSupport -Context $script:toolSupport

    Import-Module -Name (
        Join-Path $PSScriptRoot '..\..\modules\Fun.Ffmpeg\Fun.Ffmpeg.psd1'
    ) -Force -ErrorAction Stop

    <#
    .SYNOPSIS
        Create an isolated temporary root for one test scenario.

    .DESCRIPTION
        Generates a unique directory beneath `TestDrive` so each scenario gets an
        independent filesystem layout and marker files cannot collide across tests.

    .OUTPUTS
        System.String
        Full path to the newly created scenario root directory.
    #>
    function New-VvcTestRoot {
        $root = Join-Path $TestDrive ([guid]::NewGuid().Guid)
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        $root
    }

    <#
    .SYNOPSIS
        Build and execute one isolated `Convert-ToVvc` scenario.

    .DESCRIPTION
        Prepares a per-test directory structure, configures the fake `ffprobe` and
        `ffmpeg` wrappers, creates the requested input file, executes `Convert-ToVvc`, and
        returns a compact scenario object containing the resulting output plus the
        important filesystem paths and invocation markers.

        This helper exists to keep test bodies short and focused on assertions rather than
        setup mechanics.

    .PARAMETER FileName
        Name of the input media file to create in the scenario input directory.

    .PARAMETER InputContent
        File content written to the input file when `CreateEmptyFile` is not used.

    .PARAMETER CreateEmptyFile
        Creates a zero-byte input file instead of writing `InputContent`.

    .PARAMETER FfprobeScenarios
        Hashtable describing how the fake `ffprobe` wrapper should respond for specific
        file names.

    .PARAMETER CreateOutput
        Instructs the fake `ffmpeg` wrapper to create the expected output file.

    .PARAMETER FfmpegExitCode
        Exit code returned by the fake `ffmpeg` wrapper.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Scenario descriptor containing input/output paths, marker paths, and the collected
        command result array.
    #>
    function Invoke-ConvertScenario {
        param(
            [Parameter(Mandatory)]
            [string] $FileName,

            [string] $InputContent,

            [switch] $CreateEmptyFile,

            [hashtable] $FfprobeScenarios = @{},

            [switch] $CreateOutput,

            [int] $FfmpegExitCode = 0
        )

        $testRoot = New-VvcTestRoot
        $inputDir = New-Item -ItemType Directory -Path (
            Join-Path $testRoot 'input'
        ) -Force
        $outputDir = Join-Path $testRoot 'out'
        $inputPath = Join-Path $inputDir.FullName $FileName
        $ffprobeMarkerPath = Join-Path $testRoot 'ffprobe-invoked.txt'
        $ffmpegMarkerPath = Join-Path $testRoot 'ffmpeg-invoked.txt'
        $outputPath = Join-Path $outputDir (
            '{0}_vvc.mkv' -f [Path]::GetFileNameWithoutExtension($FileName)
        )

        $markerParams = @{
            FfprobeMarker = $ffprobeMarkerPath
            FfmpegMarker  = $ffmpegMarkerPath
        }
        Set-FakeMediaToolMarkers @markerParams

        Set-FakeFfprobeScenarios -Scenarios $FfprobeScenarios

        $ffmpegBehaviorParams = @{
            ExitCode     = $FfmpegExitCode
            CreateOutput = $CreateOutput
        }
        Set-FakeFfmpegBehavior @ffmpegBehaviorParams

        if ($CreateEmptyFile) {
            New-Item -ItemType File -Path $inputPath -Force | Out-Null
        }
        else {
            Set-Content -LiteralPath $inputPath -Value $InputContent
        }

        $result = @(Convert-ToVvc -InputDir $inputDir.FullName -OutputDir $outputDir)

        [pscustomobject]@{
            TestRoot      = $testRoot
            InputDir      = $inputDir.FullName
            OutputDir     = $outputDir
            InputPath     = $inputPath
            OutputPath    = $outputPath
            FfprobeMarker = $ffprobeMarkerPath
            FfmpegMarker  = $ffmpegMarkerPath
            Result        = $result
        }
    }
}

AfterAll {
    Restore-FakeMediaToolSupport -Context $script:toolSupport
}

Describe 'Convert-ToVvc' {
    BeforeEach {
        # Reset fake-tool state so each test starts from a clean environment.
        Reset-FakeMediaToolEnvironment -Context $script:toolSupport
    }

    AfterEach {
        # Reset again after each example to avoid marker or scenario leakage.
        Reset-FakeMediaToolEnvironment -Context $script:toolSupport
    }

    Context 'input validation' {
        <# These cases verify that invalid inputs are rejected before conversion. The key
        contract is not only the failure result itself, but also the absence of `ffmpeg`
        invocation and output-file creation. #>
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

            $scenario.Result.Count | Should -Be 1
            $scenario.Result[0].Ok | Should -BeFalse
            $scenario.Result[0].Skipped | Should -BeFalse
            $scenario.Result[0].Reason | Should -Match '^invalid input: '
            $scenario.Result[0].Reason | Should -Match $ExpectedReasonPattern

            if ($ExpectedOriginalMb -eq 'positive') {
                $scenario.Result[0].OriginalMB | Should -BeGreaterThan 0
            }
            else {
                $scenario.Result[0].OriginalMB | Should -Be 0
            }

            if ($ExpectFfprobeInvoked) {
                (Test-Path -LiteralPath $scenario.FfprobeMarker) | Should -BeTrue
            }
            else {
                (Test-Path -LiteralPath $scenario.FfprobeMarker) | Should -BeFalse
            }

            (Test-Path -LiteralPath $scenario.FfmpegMarker) | Should -BeFalse
            (Test-Path -LiteralPath $scenario.OutputPath) | Should -BeFalse
        }
    }

    Context 'conversion invocation' {
        <# Keep one end-to-end smoke test for the happy path so the suite proves that a
        valid input actually flows through `ffmpeg` and yields a success-shaped result
        object. #>
        It 'invokes ffmpeg and returns a success-shaped result for a valid input' {
            $scenarioParams = @{
                FileName         = 'good.mkv'
                InputContent     = ('synthetic but non-empty media payload' * 4096)
                FfprobeScenarios = @{
                    'good.mkv'                 = @{
                        FormatName = 'matroska,webm'
                        CodecName  = 'h264'
                        Duration   = '1440.0'
                    }
                    'good_vvc.mkv'             = @{
                        FormatName = 'matroska,webm'
                        CodecName  = 'vvc'
                        Duration   = '1440.0'
                    }
                    'good_vvc.__partial__.mkv' = @{
                        FormatName = 'matroska,webm'
                        CodecName  = 'vvc'
                        Duration   = '1440.0'
                    }
                }
                CreateOutput     = $true
            }
            $scenario = Invoke-ConvertScenario @scenarioParams

            $scenario.Result.Count | Should -Be 1
            $scenario.Result[0].Ok | Should -BeTrue
            $scenario.Result[0].Skipped | Should -BeFalse
            $scenario.Result[0].Reason | Should -Be ''
            $scenario.Result[0].File | Should -Be 'good.mkv'
            $scenario.Result[0].OriginalMB | Should -BeGreaterThan 0
            $scenario.Result[0].NewMB | Should -BeGreaterThan 0
            $scenario.Result[0].Ratio | Should -BeGreaterThan 0
            (Test-Path -LiteralPath $scenario.FfprobeMarker) | Should -BeTrue
            (Test-Path -LiteralPath $scenario.FfmpegMarker) | Should -BeTrue
            (Test-Path -LiteralPath $scenario.OutputPath) | Should -BeTrue
        }
    }
}
