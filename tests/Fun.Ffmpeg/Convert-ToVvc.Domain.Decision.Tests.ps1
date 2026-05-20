using module ..\..\modules\Fun.Ffmpeg\internal\ConvertToVvc.Types.psm1

#Requires -Version 7.5
#Requires -Modules Pester

Describe 'VvcConversionDecision' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1" -Force
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