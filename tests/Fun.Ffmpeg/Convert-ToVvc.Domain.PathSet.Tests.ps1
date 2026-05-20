using module ..\..\modules\Fun.Ffmpeg\internal\ConvertToVvc.Types.psm1

#Requires -Version 7.5
#Requires -Modules Pester

Describe 'VvcConversionPathSet' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1" -Force
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
}