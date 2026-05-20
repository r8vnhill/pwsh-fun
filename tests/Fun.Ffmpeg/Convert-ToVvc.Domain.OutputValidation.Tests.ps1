using module ..\..\modules\Fun.Ffmpeg\internal\ConvertToVvc.Types.psm1

#Requires -Version 7.5
#Requires -Modules Pester

Describe 'VvcOutputValidation' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1" -Force
    }

    Context 'VvcOutputValidation' {
        It 'accepts valid output with Reason None' {
            InModuleScope Fun.Ffmpeg {
                $valid = [VvcOutputValidation]::new(
                    $true,
                    [VvcConversionReason]::None,
                    0.4,
                    '  Yorozuya validation passed  '
                )

                $valid.Valid | Should -BeTrue
                $valid.Reason.ToString() | Should -Be 'None'
                $valid.DurationDriftSec | Should -Be 0.4
                $valid.Diagnostic | Should -Be 'Yorozuya validation passed'
            }
        }

        It 'accepts invalid output with a non-None reason and diagnostic' {
            InModuleScope Fun.Ffmpeg {
                $invalid = [VvcOutputValidation]::new(
                    $false,
                    [VvcConversionReason]::DecodeFailed,
                    $null,
                    '  Elizabeth output validation failed  '
                )

                $invalid.Valid | Should -BeFalse
                $invalid.Reason.ToString() | Should -Be 'DecodeFailed'
                $invalid.DurationDriftSec | Should -BeNullOrEmpty
                $invalid.Diagnostic | Should -Be 'Elizabeth output validation failed'
            }
        }

        It 'rejects valid output with a non-None reason' {
            InModuleScope Fun.Ffmpeg {
                { [VvcOutputValidation]::new($true, [VvcConversionReason]::DecodeFailed, 0.1, '') } |
                    Should -Throw -ExceptionType ([VvcConversionInvariantException])
            }
        }

        It 'rejects invalid output with Reason None' {
            InModuleScope Fun.Ffmpeg {
                { [VvcOutputValidation]::new($false, [VvcConversionReason]::None, 0.1, '') } |
                    Should -Throw -ExceptionType ([VvcConversionInvariantException])
            }
        }

        It 'rejects negative duration drift' {
            InModuleScope Fun.Ffmpeg {
                { [VvcOutputValidation]::new($true, [VvcConversionReason]::None, -0.1, '') } |
                    Should -Throw -ExceptionType ([VvcConversionInvariantException])
            }
        }

        It 'normalizes blank diagnostic for invalid output to null' {
            InModuleScope Fun.Ffmpeg {
                $invalid = [VvcOutputValidation]::new(
                    $false,
                    [VvcConversionReason]::DurationDrift,
                    1.25,
                    '   '
                )

                $invalid.Diagnostic | Should -BeNullOrEmpty
            }
        }

        It 'trims diagnostics' {
            InModuleScope Fun.Ffmpeg {
                $invalid = [VvcOutputValidation]::new(
                    $false,
                    [VvcConversionReason]::DurationDrift,
                    1.25,
                    '  Shinsengumi duration drift detected  '
                )

                $invalid.Diagnostic | Should -Be 'Shinsengumi duration drift detected'
            }
        }

        It 'normalizes blank diagnostic for valid output to null' {
            InModuleScope Fun.Ffmpeg {
                $valid = [VvcOutputValidation]::new(
                    $true,
                    [VvcConversionReason]::None,
                    $null,
                    '   '
                )

                $valid.Diagnostic | Should -BeNullOrEmpty
            }
        }
    }
}