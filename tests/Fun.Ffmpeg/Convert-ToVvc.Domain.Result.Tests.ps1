using module ..\..\modules\Fun.Ffmpeg\internal\ConvertToVvc.Types.psm1

#Requires -Version 7.5
#Requires -Modules Pester

Describe 'ConvertToVvcResult' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1" -Force
    }

    Context 'Converted factory' {
        It 'creates a Converted result with Reason None' {
            InModuleScope Fun.Ffmpeg {
                $result = [ConvertToVvcResult]::Converted(
                    'gintoki-input.mkv',
                    'E:\Yorozuya\gintoki-input.mkv',
                    'E:\Yorozuya\gintoki-output.mkv',
                    100.25,
                    40.5,
                    0.4
                )

                $result.Status.ToString() | Should -Be 'Converted'
                $result.Reason.ToString() | Should -Be 'None'
                $result.InputPath | Should -Be 'E:\Yorozuya\gintoki-input.mkv'
                $result.OutputPath | Should -Be 'E:\Yorozuya\gintoki-output.mkv'
            }
        }

        It 'requires a nonblank output path' {
            InModuleScope Fun.Ffmpeg {
                {
                    [ConvertToVvcResult]::Converted(
                        'gintoki-input.mkv',
                        'E:\Yorozuya\gintoki-input.mkv',
                        '   ',
                        100.0,
                        40.0,
                        0.4
                    )
                } | Should -Throw -ExceptionType ([VvcConversionInvariantException])
            }
        }

        It 'rejects invalid size values according to the live contract' {
            InModuleScope Fun.Ffmpeg {
                {
                    [ConvertToVvcResult]::Converted(
                        'gintoki-input.mkv',
                        'E:\Yorozuya\gintoki-input.mkv',
                        'E:\Yorozuya\gintoki-output.mkv',
                        100.0,
                        0.0,
                        0.4
                    )
                } | Should -Throw -ExceptionType ([VvcConversionInvariantException])

                {
                    [ConvertToVvcResult]::Converted(
                        'gintoki-input.mkv',
                        'E:\Yorozuya\gintoki-input.mkv',
                        'E:\Yorozuya\gintoki-output.mkv',
                        100.0,
                        -1.0,
                        0.4
                    )
                } | Should -Throw -ExceptionType ([VvcConversionInvariantException])
            }
        }

        It 'sets Ok true and Skipped false as derived compatibility fields' {
            InModuleScope Fun.Ffmpeg {
                $result = [ConvertToVvcResult]::Converted(
                    'gintoki-input.mkv',
                    'E:\Yorozuya\gintoki-input.mkv',
                    'E:\Yorozuya\gintoki-output.mkv',
                    100.25,
                    40.5,
                    0.4
                )

                $result.Ok | Should -BeTrue
                $result.Skipped | Should -BeFalse
            }
        }
    }

    Context 'Skipped factory' {
        It 'creates a Skipped result with a non-None reason' {
            InModuleScope Fun.Ffmpeg {
                $result = [ConvertToVvcResult]::Skipped(
                    'gintoki-input.mkv',
                    'E:\Yorozuya\gintoki-input.mkv',
                    [VvcConversionReason]::ExistingOutputValid,
                    '  Shinsengumi existing output already valid  '
                )

                $result.Status.ToString() | Should -Be 'Skipped'
                $result.Reason.ToString() | Should -Be 'ExistingOutputValid'
                $result.InputPath | Should -Be 'E:\Yorozuya\gintoki-input.mkv'
                $result.OutputPath | Should -BeNullOrEmpty
            }
        }

        It 'rejects Reason None' {
            InModuleScope Fun.Ffmpeg {
                {
                    [ConvertToVvcResult]::Skipped(
                        'gintoki-input.mkv',
                        'E:\Yorozuya\gintoki-input.mkv',
                        [VvcConversionReason]::None,
                        '  Shinsengumi existing output already valid  '
                    )
                } | Should -Throw -ExceptionType ([VvcConversionInvariantException])
            }
        }

        It 'normalizes diagnostics' {
            InModuleScope Fun.Ffmpeg {
                $result = [ConvertToVvcResult]::Skipped(
                    'gintoki-input.mkv',
                    'E:\Yorozuya\gintoki-input.mkv',
                    [VvcConversionReason]::ExistingOutputValid,
                    '  Shinsengumi existing output already valid  '
                )

                $result.Diagnostic | Should -Be 'Shinsengumi existing output already valid'
            }
        }

        It 'keeps native exit code null unless the live contract says otherwise' {
            InModuleScope Fun.Ffmpeg {
                $result = [ConvertToVvcResult]::Skipped(
                    'gintoki-input.mkv',
                    'E:\Yorozuya\gintoki-input.mkv',
                    [VvcConversionReason]::ExistingOutputValid,
                    $null
                )

                $result.ExitCode | Should -BeNullOrEmpty
            }
        }

        It 'sets Ok true and Skipped true as derived compatibility fields' {
            InModuleScope Fun.Ffmpeg {
                $result = [ConvertToVvcResult]::Skipped(
                    'gintoki-input.mkv',
                    'E:\Yorozuya\gintoki-input.mkv',
                    [VvcConversionReason]::ExistingOutputValid,
                    '  Shinsengumi existing output already valid  '
                )

                $result.Ok | Should -BeTrue
                $result.Skipped | Should -BeTrue
            }
        }
    }

    Context 'Failed factory' {
        It 'creates a Failed result with a non-None reason' {
            InModuleScope Fun.Ffmpeg {
                $result = [ConvertToVvcResult]::Failed(
                    'gintoki-input.mkv',
                    'E:\Yorozuya\gintoki-input.mkv',
                    [VvcConversionReason]::EncodeFailed,
                    17,
                    '  Elizabeth encode failed  '
                )

                $result.Status.ToString() | Should -Be 'Failed'
                $result.Reason.ToString() | Should -Be 'EncodeFailed'
                $result.InputPath | Should -Be 'E:\Yorozuya\gintoki-input.mkv'
                $result.OutputPath | Should -BeNullOrEmpty
            }
        }

        It 'rejects Reason None' {
            InModuleScope Fun.Ffmpeg {
                {
                    [ConvertToVvcResult]::Failed(
                        'gintoki-input.mkv',
                        'E:\Yorozuya\gintoki-input.mkv',
                        [VvcConversionReason]::None,
                        $null,
                        '  Elizabeth encode failed  '
                    )
                } | Should -Throw -ExceptionType ([VvcConversionInvariantException])
            }
        }

        It 'allows null native exit code for pre-native failures' {
            InModuleScope Fun.Ffmpeg {
                $result = [ConvertToVvcResult]::Failed(
                    'gintoki-input.mkv',
                    'E:\Yorozuya\gintoki-input.mkv',
                    [VvcConversionReason]::ProbeFailed,
                    $null,
                    '  Katsura probe failed  '
                )

                $result.ExitCode | Should -BeNullOrEmpty
            }
        }

        It 'allows native exit code when a native tool was invoked' {
            InModuleScope Fun.Ffmpeg {
                $result = [ConvertToVvcResult]::Failed(
                    'gintoki-input.mkv',
                    'E:\Yorozuya\gintoki-input.mkv',
                    [VvcConversionReason]::EncodeFailed,
                    17,
                    '  Elizabeth encode failed  '
                )

                $result.ExitCode | Should -Be 17
            }
        }

        It 'normalizes diagnostics' {
            InModuleScope Fun.Ffmpeg {
                $result = [ConvertToVvcResult]::Failed(
                    'gintoki-input.mkv',
                    'E:\Yorozuya\gintoki-input.mkv',
                    [VvcConversionReason]::ProbeFailed,
                    $null,
                    '  Katsura probe failed  '
                )

                $result.Diagnostic | Should -Be 'Katsura probe failed'
            }
        }

        It 'sets Ok false and Skipped false as derived compatibility fields' {
            InModuleScope Fun.Ffmpeg {
                $result = [ConvertToVvcResult]::Failed(
                    'gintoki-input.mkv',
                    'E:\Yorozuya\gintoki-input.mkv',
                    [VvcConversionReason]::EncodeFailed,
                    17,
                    '  Elizabeth encode failed  '
                )

                $result.Ok | Should -BeFalse
                $result.Skipped | Should -BeFalse
            }
        }
    }
}