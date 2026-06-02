using module ..\..\..\modules\Fun.Ffmpeg\internal\ConvertToVvc.Types.psm1

#Requires -Version 7.5
#Requires -Modules Pester

Describe 'VvcConversionRequest' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1" -Force
    }

    Context 'VvcConversionRequest' {
        It 'preserves valid worker boundary data' {
            InModuleScope Fun.Ffmpeg {
                $request = [VvcConversionRequest]::new(
                    'E:\Media\Seguchi_Source.mkv',
                    'E:\Media\encoded',
                    '.vvc',
                    28,
                    'medium',
                    $false,
                    'quick',
                    1.5,
                    'E:\Tools\Seguchi\ffmpeg.exe',
                    'E:\Tools\Seguchi\ffprobe.exe',
                    2
                )

                $request.InputPath | Should -Be 'E:\Media\Seguchi_Source.mkv'
                $request.OutputDir | Should -Be 'E:\Media\encoded'
                $request.Suffix | Should -Be '.vvc'
                $request.Qp | Should -Be 28
                $request.Overwrite | Should -BeFalse
                $request.VerifyMode | Should -Be 'quick'
                $request.MaxDriftSec | Should -Be 1.5
                $request.FfmpegPath | Should -Be 'E:\Tools\Seguchi\ffmpeg.exe'
                $request.FfprobePath | Should -Be 'E:\Tools\Seguchi\ffprobe.exe'
                $request.EncoderThreads | Should -Be 2
            }
        }

        It 'rejects invalid request values' -ForEach @(
            @{ Name = 'blank input'; InputPath = ''; OutputDir = 'E:\Media\encoded'; Suffix = '.vvc'; Qp = 28; Preset = 'medium'; VerifyMode = 'quick'; MaxDriftSec = 1.0; FfmpegPath = 'E:\Tools\Seguchi\ffmpeg.exe'; FfprobePath = 'E:\Tools\Seguchi\ffprobe.exe'; EncoderThreads = 0 }
            @{ Name = 'blank output'; InputPath = 'E:\Media\Seguchi_Source.mkv'; OutputDir = ''; Suffix = '.vvc'; Qp = 28; Preset = 'medium'; VerifyMode = 'quick'; MaxDriftSec = 1.0; FfmpegPath = 'E:\Tools\Seguchi\ffmpeg.exe'; FfprobePath = 'E:\Tools\Seguchi\ffprobe.exe'; EncoderThreads = 0 }
            @{ Name = 'blank suffix'; InputPath = 'E:\Media\Seguchi_Source.mkv'; OutputDir = 'E:\Media\encoded'; Suffix = ''; Qp = 28; Preset = 'medium'; VerifyMode = 'quick'; MaxDriftSec = 1.0; FfmpegPath = 'E:\Tools\Seguchi\ffmpeg.exe'; FfprobePath = 'E:\Tools\Seguchi\ffprobe.exe'; EncoderThreads = 0 }
            @{ Name = 'blank preset'; InputPath = 'E:\Media\Seguchi_Source.mkv'; OutputDir = 'E:\Media\encoded'; Suffix = '.vvc'; Qp = 28; Preset = ''; VerifyMode = 'quick'; MaxDriftSec = 1.0; FfmpegPath = 'E:\Tools\Seguchi\ffmpeg.exe'; FfprobePath = 'E:\Tools\Seguchi\ffprobe.exe'; EncoderThreads = 0 }
            @{ Name = 'bad qp'; InputPath = 'E:\Media\Seguchi_Source.mkv'; OutputDir = 'E:\Media\encoded'; Suffix = '.vvc'; Qp = 64; Preset = 'medium'; VerifyMode = 'quick'; MaxDriftSec = 1.0; FfmpegPath = 'E:\Tools\Seguchi\ffmpeg.exe'; FfprobePath = 'E:\Tools\Seguchi\ffprobe.exe'; EncoderThreads = 0 }
            @{ Name = 'bad verify'; InputPath = 'E:\Media\Seguchi_Source.mkv'; OutputDir = 'E:\Media\encoded'; Suffix = '.vvc'; Qp = 28; Preset = 'medium'; VerifyMode = 'full'; MaxDriftSec = 1.0; FfmpegPath = 'E:\Tools\Seguchi\ffmpeg.exe'; FfprobePath = 'E:\Tools\Seguchi\ffprobe.exe'; EncoderThreads = 0 }
            @{ Name = 'negative drift'; InputPath = 'E:\Media\Seguchi_Source.mkv'; OutputDir = 'E:\Media\encoded'; Suffix = '.vvc'; Qp = 28; Preset = 'medium'; VerifyMode = 'quick'; MaxDriftSec = -1.0; FfmpegPath = 'E:\Tools\Seguchi\ffmpeg.exe'; FfprobePath = 'E:\Tools\Seguchi\ffprobe.exe'; EncoderThreads = 0 }
            @{ Name = 'blank ffmpeg'; InputPath = 'E:\Media\Seguchi_Source.mkv'; OutputDir = 'E:\Media\encoded'; Suffix = '.vvc'; Qp = 28; Preset = 'medium'; VerifyMode = 'quick'; MaxDriftSec = 1.0; FfmpegPath = ''; FfprobePath = 'E:\Tools\Seguchi\ffprobe.exe'; EncoderThreads = 0 }
            @{ Name = 'blank ffprobe'; InputPath = 'E:\Media\Seguchi_Source.mkv'; OutputDir = 'E:\Media\encoded'; Suffix = '.vvc'; Qp = 28; Preset = 'medium'; VerifyMode = 'quick'; MaxDriftSec = 1.0; FfmpegPath = 'E:\Tools\Seguchi\ffmpeg.exe'; FfprobePath = ''; EncoderThreads = 0 }
            @{ Name = 'negative threads'; InputPath = 'E:\Media\Seguchi_Source.mkv'; OutputDir = 'E:\Media\encoded'; Suffix = '.vvc'; Qp = 28; Preset = 'medium'; VerifyMode = 'quick'; MaxDriftSec = 1.0; FfmpegPath = 'E:\Tools\Seguchi\ffmpeg.exe'; FfprobePath = 'E:\Tools\Seguchi\ffprobe.exe'; EncoderThreads = -1 }
        ) {
            InModuleScope Fun.Ffmpeg -Parameters $_ {
                {
                    [VvcConversionRequest]::new(
                        $InputPath,
                        $OutputDir,
                        $Suffix,
                        $Qp,
                        $Preset,
                        $false,
                        $VerifyMode,
                        $MaxDriftSec,
                        $FfmpegPath,
                        $FfprobePath,
                        $EncoderThreads
                    )
                } | Should -Throw -ExceptionType ([VvcConversionInvariantException])
            }
        }
    }
}