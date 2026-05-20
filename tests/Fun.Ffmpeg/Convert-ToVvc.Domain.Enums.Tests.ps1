using module ..\..\modules\Fun.Ffmpeg\internal\ConvertToVvc.Types.psm1

#Requires -Version 7.5
#Requires -Modules Pester

Describe 'Convert-ToVvc domain enums' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1" -Force
    }

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

    Context 'VvcConversionInvariantException' {
        It 'can be thrown and matched by exact exception type' {
            {
                throw [VvcConversionInvariantException]::new('Invalid state')
            } | Should -Throw -ExceptionType ([VvcConversionInvariantException])
        }
    }
}