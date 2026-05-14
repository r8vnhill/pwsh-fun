using module ..\..\modules\Fun.Ffmpeg\internal\ConvertToVvc.Types.psm1

#Requires -Version 7.5
#Requires -Modules Pester

Describe 'Convert-ToVvc domain invariants' {
    Context 'VVC conversion enums' {
        It 'defines the expected status names' {
            [enum]::GetNames([VvcConversionStatus]) | Should -Be @(
                'Converted'
                'Skipped'
                'Failed'
            )
        }

        It 'defines the expected action names' {
            [enum]::GetNames([VvcConversionAction]) | Should -Be @(
                'Convert'
                'Skip'
                'Fail'
            )
        }

        It 'defines the expected reason names' {
            [enum]::GetNames([VvcConversionReason]) | Should -Be @(
                'None'
                'InvalidInput'
                'ExistingOutputValid'
                'EncodeFailed'
                'EncodedOutputMissing'
                'ProbeFailed'
                'UnexpectedCodec'
                'DurationUnavailable'
                'DurationDrift'
                'DecodeFailed'
                'PromoteFailed'
                'SizeUnavailable'
                'UnexpectedFailure'
            )
        }
    }

    Context 'ConvertToVvcResult' {
        It 'creates a converted result with enum-backed status and reason' {
            InModuleScope Fun.Ffmpeg {
                $result = [ConvertToVvcResult]::Converted(
                    'episode.mkv',
                    'C:\videos\episode.mkv',
                    'C:\videos\episode_vvc.mkv',
                    100.25,
                    40.5,
                    0.4
                )

                $result.Status.GetType().Name | Should -Be 'VvcConversionStatus'
                $result.Status.ToString() | Should -Be 'Converted'
                $result.Reason.GetType().Name | Should -Be 'VvcConversionReason'
                $result.Reason.ToString() | Should -Be 'None'
                $result.Ok | Should -BeTrue
                $result.Skipped | Should -BeFalse
            }
        }

        It 'rejects invalid converted result states' {
            InModuleScope Fun.Ffmpeg {
                {
                    [ConvertToVvcResult]::new(
                        'episode.mkv',
                        'C:\videos\episode.mkv',
                        'C:\videos\episode_vvc.mkv',
                        [VvcConversionStatus]::Converted,
                        [VvcConversionReason]::EncodeFailed,
                        100.0,
                        40.0,
                        0.4,
                        $null,
                        $null
                    )
                } | Should -Throw -ExceptionType ([VvcConversionInvariantException])

                {
                    [ConvertToVvcResult]::Converted(
                        'episode.mkv',
                        'C:\videos\episode.mkv',
                        '',
                        100.0,
                        40.0,
                        0.4
                    )
                } | Should -Throw -ExceptionType ([VvcConversionInvariantException])

                {
                    [ConvertToVvcResult]::Converted(
                        'episode.mkv',
                        'C:\videos\episode.mkv',
                        'C:\videos\episode_vvc.mkv',
                        100.0,
                        0.0,
                        0.4
                    )
                } | Should -Throw -ExceptionType ([VvcConversionInvariantException])
            }
        }

        It 'requires explicit reasons for skipped and failed results' {
            InModuleScope Fun.Ffmpeg {
                $skipped = [ConvertToVvcResult]::Skipped(
                    'episode.mkv',
                    'C:\videos\episode.mkv',
                    [VvcConversionReason]::ExistingOutputValid,
                    '  existing output is valid  '
                )
                $failed = [ConvertToVvcResult]::Failed(
                    'episode.mkv',
                    'C:\videos\episode.mkv',
                    [VvcConversionReason]::EncodeFailed,
                    17,
                    '  ffmpeg failed  '
                )

                $skipped.Status.ToString() | Should -Be 'Skipped'
                $skipped.Reason.ToString() | Should -Be 'ExistingOutputValid'
                $skipped.Ok | Should -BeTrue
                $skipped.Skipped | Should -BeTrue
                $skipped.Diagnostic | Should -Be 'existing output is valid'
                $failed.Status.ToString() | Should -Be 'Failed'
                $failed.Reason.ToString() | Should -Be 'EncodeFailed'
                $failed.Ok | Should -BeFalse
                $failed.Skipped | Should -BeFalse
                $failed.ExitCode | Should -Be 17

                {
                    [ConvertToVvcResult]::Skipped(
                        'episode.mkv',
                        'C:\videos\episode.mkv',
                        [VvcConversionReason]::None,
                        $null
                    )
                } | Should -Throw -ExceptionType ([VvcConversionInvariantException])

                {
                    [ConvertToVvcResult]::Failed(
                        'episode.mkv',
                        'C:\videos\episode.mkv',
                        [VvcConversionReason]::None,
                        $null,
                        $null
                    )
                } | Should -Throw -ExceptionType ([VvcConversionInvariantException])
            }
        }

        It 'rejects negative ratios and normalizes blank diagnostics' {
            InModuleScope Fun.Ffmpeg {
                {
                    [ConvertToVvcResult]::Converted(
                        'episode.mkv',
                        'C:\videos\episode.mkv',
                        'C:\videos\episode_vvc.mkv',
                        100.0,
                        40.0,
                        -0.1
                    )
                } | Should -Throw -ExceptionType ([VvcConversionInvariantException])

                $failed = [ConvertToVvcResult]::Failed(
                    'episode.mkv',
                    'C:\videos\episode.mkv',
                    [VvcConversionReason]::ProbeFailed,
                    $null,
                    '   '
                )
                $failed.Diagnostic | Should -BeNullOrEmpty
            }
        }
    }

    Context 'VvcConversionRequest' {
        It 'preserves valid worker boundary data' {
            InModuleScope Fun.Ffmpeg {
                $request = [VvcConversionRequest]::new(
                    'C:\videos\episode.mkv',
                    'C:\encoded',
                    '_vvc',
                    28,
                    'medium',
                    $true,
                    'quick',
                    1.5,
                    'C:\tools\ffmpeg.exe',
                    'C:\tools\ffprobe.exe',
                    2
                )

                $request.InputPath | Should -Be 'C:\videos\episode.mkv'
                $request.OutputDir | Should -Be 'C:\encoded'
                $request.Suffix | Should -Be '_vvc'
                $request.Qp | Should -Be 28
                $request.Overwrite | Should -BeTrue
                $request.VerifyMode | Should -Be 'quick'
                $request.EncoderThreads | Should -Be 2
            }
        }

        It 'rejects invalid request values' -ForEach @(
            @{ Name = 'blank input'; InputPath = ''; OutputDir = 'C:\out'; Suffix = '_vvc'; Qp = 28; Preset = 'medium'; VerifyMode = 'quick'; MaxDriftSec = 1.0; FfmpegPath = 'ffmpeg'; FfprobePath = 'ffprobe'; EncoderThreads = 0 }
            @{ Name = 'blank output'; InputPath = 'C:\in\a.mkv'; OutputDir = ''; Suffix = '_vvc'; Qp = 28; Preset = 'medium'; VerifyMode = 'quick'; MaxDriftSec = 1.0; FfmpegPath = 'ffmpeg'; FfprobePath = 'ffprobe'; EncoderThreads = 0 }
            @{ Name = 'blank suffix'; InputPath = 'C:\in\a.mkv'; OutputDir = 'C:\out'; Suffix = ''; Qp = 28; Preset = 'medium'; VerifyMode = 'quick'; MaxDriftSec = 1.0; FfmpegPath = 'ffmpeg'; FfprobePath = 'ffprobe'; EncoderThreads = 0 }
            @{ Name = 'blank preset'; InputPath = 'C:\in\a.mkv'; OutputDir = 'C:\out'; Suffix = '_vvc'; Qp = 28; Preset = ''; VerifyMode = 'quick'; MaxDriftSec = 1.0; FfmpegPath = 'ffmpeg'; FfprobePath = 'ffprobe'; EncoderThreads = 0 }
            @{ Name = 'bad qp'; InputPath = 'C:\in\a.mkv'; OutputDir = 'C:\out'; Suffix = '_vvc'; Qp = 64; Preset = 'medium'; VerifyMode = 'quick'; MaxDriftSec = 1.0; FfmpegPath = 'ffmpeg'; FfprobePath = 'ffprobe'; EncoderThreads = 0 }
            @{ Name = 'bad verify'; InputPath = 'C:\in\a.mkv'; OutputDir = 'C:\out'; Suffix = '_vvc'; Qp = 28; Preset = 'medium'; VerifyMode = 'full'; MaxDriftSec = 1.0; FfmpegPath = 'ffmpeg'; FfprobePath = 'ffprobe'; EncoderThreads = 0 }
            @{ Name = 'negative drift'; InputPath = 'C:\in\a.mkv'; OutputDir = 'C:\out'; Suffix = '_vvc'; Qp = 28; Preset = 'medium'; VerifyMode = 'quick'; MaxDriftSec = -1.0; FfmpegPath = 'ffmpeg'; FfprobePath = 'ffprobe'; EncoderThreads = 0 }
            @{ Name = 'blank ffmpeg'; InputPath = 'C:\in\a.mkv'; OutputDir = 'C:\out'; Suffix = '_vvc'; Qp = 28; Preset = 'medium'; VerifyMode = 'quick'; MaxDriftSec = 1.0; FfmpegPath = ''; FfprobePath = 'ffprobe'; EncoderThreads = 0 }
            @{ Name = 'blank ffprobe'; InputPath = 'C:\in\a.mkv'; OutputDir = 'C:\out'; Suffix = '_vvc'; Qp = 28; Preset = 'medium'; VerifyMode = 'quick'; MaxDriftSec = 1.0; FfmpegPath = 'ffmpeg'; FfprobePath = ''; EncoderThreads = 0 }
            @{ Name = 'negative threads'; InputPath = 'C:\in\a.mkv'; OutputDir = 'C:\out'; Suffix = '_vvc'; Qp = 28; Preset = 'medium'; VerifyMode = 'quick'; MaxDriftSec = 1.0; FfmpegPath = 'ffmpeg'; FfprobePath = 'ffprobe'; EncoderThreads = -1 }
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

    Context 'VvcConversionPathSet' {
        It 'accepts related conversion paths without requiring them to exist' {
            InModuleScope Fun.Ffmpeg {
                $paths = [VvcConversionPathSet]::new(
                    'C:\in\episode.mkv',
                    'C:\out\episode_vvc.mkv',
                    'C:\out\episode_vvc.partial.mkv'
                )

                $paths.InputPath | Should -Be 'C:\in\episode.mkv'
                $paths.OutputPath | Should -Be 'C:\out\episode_vvc.mkv'
                $paths.TempPath | Should -Be 'C:\out\episode_vvc.partial.mkv'
            }
        }

        It 'rejects invalid path relationships' -ForEach @(
            @{ Name = 'blank input'; InputPath = ''; OutputPath = 'C:\out\a.mkv'; TempPath = 'C:\out\a.tmp.mkv' }
            @{ Name = 'blank output'; InputPath = 'C:\in\a.mkv'; OutputPath = ''; TempPath = 'C:\out\a.tmp.mkv' }
            @{ Name = 'blank temp'; InputPath = 'C:\in\a.mkv'; OutputPath = 'C:\out\a.mkv'; TempPath = '' }
            @{ Name = 'same output and temp'; InputPath = 'C:\in\a.mkv'; OutputPath = 'C:\out\a.mkv'; TempPath = 'C:\out\a.mkv' }
            @{ Name = 'different temp directory'; InputPath = 'C:\in\a.mkv'; OutputPath = 'C:\out\a.mkv'; TempPath = 'C:\other\a.tmp.mkv' }
            @{ Name = 'different temp extension'; InputPath = 'C:\in\a.mkv'; OutputPath = 'C:\out\a.mkv'; TempPath = 'C:\out\a.tmp.mp4' }
        ) {
            InModuleScope Fun.Ffmpeg -Parameters $_ {
                {
                    [VvcConversionPathSet]::new($InputPath, $OutputPath, $TempPath)
                } | Should -Throw -ExceptionType ([VvcConversionInvariantException])
            }
        }
    }

    Context 'VvcNativeResult' {
        It 'derives success from exit code' {
            InModuleScope Fun.Ffmpeg {
                $success = [VvcNativeResult]::new('ffmpeg', @('-version'), 0, ' out ', ' ')
                $failure = [VvcNativeResult]::new('ffmpeg', @('-bad'), 1, '', ' error ')

                $success.Succeeded | Should -BeTrue
                $success.Stdout | Should -Be 'out'
                $success.Stderr | Should -BeNullOrEmpty
                $failure.Succeeded | Should -BeFalse
                $failure.Stderr | Should -Be 'error'
            }
        }

        It 'rejects missing tool identity or argument list' {
            InModuleScope Fun.Ffmpeg {
                { [VvcNativeResult]::new('', @('-version'), 0, '', '') } |
                    Should -Throw -ExceptionType ([VvcConversionInvariantException])
                { [VvcNativeResult]::new('ffmpeg', $null, 0, '', '') } |
                    Should -Throw -ExceptionType ([VvcConversionInvariantException])
            }
        }
    }

    Context 'VvcMediaProbe' {
        It 'models valid and invalid probe states with enum-backed reasons' {
            InModuleScope Fun.Ffmpeg {
                $valid = [VvcMediaProbe]::new(
                    $true,
                    [VvcConversionReason]::None,
                    ' vvc ',
                    120.5,
                    ' '
                )
                $invalid = [VvcMediaProbe]::new(
                    $false,
                    [VvcConversionReason]::ProbeFailed,
                    '',
                    $null,
                    ' failed '
                )

                $valid.Reason.GetType().Name | Should -Be 'VvcConversionReason'
                $valid.Reason.ToString() | Should -Be 'None'
                $valid.Codec | Should -Be 'vvc'
                $valid.Diagnostic | Should -BeNullOrEmpty
                $invalid.Reason.ToString() | Should -Be 'ProbeFailed'
                $invalid.Diagnostic | Should -Be 'failed'
            }
        }

        It 'rejects contradictory probe states' {
            InModuleScope Fun.Ffmpeg {
                { [VvcMediaProbe]::new($true, [VvcConversionReason]::ProbeFailed, 'vvc', 1.0, '') } |
                    Should -Throw -ExceptionType ([VvcConversionInvariantException])
                { [VvcMediaProbe]::new($false, [VvcConversionReason]::None, '', $null, '') } |
                    Should -Throw -ExceptionType ([VvcConversionInvariantException])
                { [VvcMediaProbe]::new($true, [VvcConversionReason]::None, '', 1.0, '') } |
                    Should -Throw -ExceptionType ([VvcConversionInvariantException])
                { [VvcMediaProbe]::new($true, [VvcConversionReason]::None, 'vvc', -1.0, '') } |
                    Should -Throw -ExceptionType ([VvcConversionInvariantException])
            }
        }
    }

    Context 'VvcOutputValidation' {
        It 'models valid and invalid validation states' {
            InModuleScope Fun.Ffmpeg {
                $valid = [VvcOutputValidation]::new(
                    $true,
                    [VvcConversionReason]::None,
                    0.4,
                    ' '
                )
                $invalid = [VvcOutputValidation]::new(
                    $false,
                    [VvcConversionReason]::DecodeFailed,
                    $null,
                    ' decode failed '
                )

                $valid.Reason.ToString() | Should -Be 'None'
                $valid.DurationDriftSec | Should -Be 0.4
                $valid.Diagnostic | Should -BeNullOrEmpty
                $invalid.Reason.ToString() | Should -Be 'DecodeFailed'
                $invalid.Diagnostic | Should -Be 'decode failed'
            }
        }

        It 'rejects contradictory validation states' {
            InModuleScope Fun.Ffmpeg {
                { [VvcOutputValidation]::new($true, [VvcConversionReason]::DecodeFailed, 0.1, '') } |
                    Should -Throw -ExceptionType ([VvcConversionInvariantException])
                { [VvcOutputValidation]::new($false, [VvcConversionReason]::None, 0.1, '') } |
                    Should -Throw -ExceptionType ([VvcConversionInvariantException])
                { [VvcOutputValidation]::new($true, [VvcConversionReason]::None, -0.1, '') } |
                    Should -Throw -ExceptionType ([VvcConversionInvariantException])
            }
        }
    }

    Context 'VvcConversionDecision' {
        It 'creates enum-backed convert skip and fail decisions' {
            InModuleScope Fun.Ffmpeg {
                $convert = [VvcConversionDecision]::Convert()
                $skipResult = [ConvertToVvcResult]::Skipped(
                    'episode.mkv',
                    'C:\videos\episode.mkv',
                    [VvcConversionReason]::ExistingOutputValid,
                    $null
                )
                $failResult = [ConvertToVvcResult]::Failed(
                    'episode.mkv',
                    'C:\videos\episode.mkv',
                    [VvcConversionReason]::InvalidInput,
                    $null,
                    'invalid'
                )
                $skip = [VvcConversionDecision]::Skip(
                    [VvcConversionReason]::ExistingOutputValid,
                    $skipResult
                )
                $fail = [VvcConversionDecision]::Fail(
                    [VvcConversionReason]::InvalidInput,
                    $failResult
                )

                $convert.Action.GetType().Name | Should -Be 'VvcConversionAction'
                $convert.Action.ToString() | Should -Be 'Convert'
                $convert.Reason.ToString() | Should -Be 'None'
                $skip.Action.ToString() | Should -Be 'Skip'
                $skip.Result.Status.ToString() | Should -Be 'Skipped'
                $fail.Action.ToString() | Should -Be 'Fail'
                $fail.Result.Status.ToString() | Should -Be 'Failed'
            }
        }

        It 'rejects contradictory decisions' {
            InModuleScope Fun.Ffmpeg {
                $result = [ConvertToVvcResult]::Skipped(
                    'episode.mkv',
                    'C:\videos\episode.mkv',
                    [VvcConversionReason]::ExistingOutputValid,
                    $null
                )

                {
                    [VvcConversionDecision]::new(
                        [VvcConversionAction]::Convert,
                        [VvcConversionReason]::ExistingOutputValid,
                        $null,
                        $null
                    )
                } | Should -Throw -ExceptionType ([VvcConversionInvariantException])

                {
                    [VvcConversionDecision]::new(
                        [VvcConversionAction]::Convert,
                        [VvcConversionReason]::None,
                        $result,
                        $null
                    )
                } | Should -Throw -ExceptionType ([VvcConversionInvariantException])

                {
                    [VvcConversionDecision]::new(
                        [VvcConversionAction]::Skip,
                        [VvcConversionReason]::None,
                        $result,
                        $null
                    )
                } | Should -Throw -ExceptionType ([VvcConversionInvariantException])

                {
                    [VvcConversionDecision]::new(
                        [VvcConversionAction]::Fail,
                        [VvcConversionReason]::InvalidInput,
                        $null,
                        $null
                    )
                } | Should -Throw -ExceptionType ([VvcConversionInvariantException])
            }
        }
    }
}
