using module ..\..\modules\Fun.Ffmpeg\internal\ConvertToVvc.Types.psm1

#Requires -Version 7.5
#Requires -Modules Pester

Describe 'VvcNativeResult' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1" -Force
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
}