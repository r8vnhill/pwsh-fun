using module ..\..\modules\Fun.Ffmpeg\internal\ConvertToVvc.Types.psm1

#Requires -Version 7.5
#Requires -Modules Pester

Describe 'VvcMediaProbe' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1" -Force
    }

    Context 'VvcMediaProbe' {
        It 'accepts a valid probe with interpreted media facts' {
            InModuleScope Fun.Ffmpeg {
                $valid = [VvcMediaProbe]::new(
                    $true,
                    [VvcConversionReason]::None,
                    'vvc',
                    120.5,
                    'Yorozuya probe ok'
                )

                $valid.Valid | Should -BeTrue
                $valid.Reason.GetType().Name | Should -Be 'VvcConversionReason'
                $valid.Reason.ToString() | Should -Be 'None'
                $valid.Codec | Should -Be 'vvc'
                $valid.DurationSec | Should -Be 120.5
                $valid.Diagnostic | Should -Be 'Yorozuya probe ok'
            }
        }

        It 'normalizes valid probe strings without probing media' {
            InModuleScope Fun.Ffmpeg {
                $valid = [VvcMediaProbe]::new(
                    $true,
                    [VvcConversionReason]::None,
                    '  hevc  ',
                    $null,
                    '  Yorozuya probe ok  '
                )

                $valid.Codec | Should -Be 'hevc'
                $valid.DurationSec | Should -BeNullOrEmpty
                $valid.Diagnostic | Should -Be 'Yorozuya probe ok'
            }
        }

        It 'accepts a failed probe with normalized optional details' {
            InModuleScope Fun.Ffmpeg {
                $invalid = [VvcMediaProbe]::new(
                    $false,
                    [VvcConversionReason]::ProbeFailed,
                    ' ',
                    $null,
                    '  ffprobe failed  '
                )

                $invalid.Valid | Should -BeFalse
                $invalid.Reason.GetType().Name | Should -Be 'VvcConversionReason'
                $invalid.Reason.ToString() | Should -Be 'ProbeFailed'
                $invalid.Codec | Should -BeNullOrEmpty
                $invalid.DurationSec | Should -BeNullOrEmpty
                $invalid.Diagnostic | Should -Be 'ffprobe failed'
            }
        }

        It 'rejects a valid probe with a non-None reason' {
            InModuleScope Fun.Ffmpeg {
                { [VvcMediaProbe]::new($true, [VvcConversionReason]::ProbeFailed, 'vvc', 1.0, '') } |
                    Should -Throw -ExceptionType ([VvcConversionInvariantException])
            }
        }

        It 'rejects a valid probe with blank codec' {
            InModuleScope Fun.Ffmpeg {
                { [VvcMediaProbe]::new($true, [VvcConversionReason]::None, '', 1.0, '') } |
                    Should -Throw -ExceptionType ([VvcConversionInvariantException])
            }
        }

        It 'rejects a failed probe with Reason None' {
            InModuleScope Fun.Ffmpeg {
                { [VvcMediaProbe]::new($false, [VvcConversionReason]::None, '', $null, '') } |
                    Should -Throw -ExceptionType ([VvcConversionInvariantException])
            }
        }

        It 'rejects negative duration' {
            InModuleScope Fun.Ffmpeg {
                { [VvcMediaProbe]::new($true, [VvcConversionReason]::None, 'vvc', -1.0, '') } |
                    Should -Throw -ExceptionType ([VvcConversionInvariantException])
            }
        }
    }
}