using module ..\..\modules\Fun.Ffmpeg\internal\ConvertToVvc.Types.psm1

#Requires -Version 7.5
#Requires -Modules Pester

Describe 'ConvertToVvcResult' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1" -Force
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
}