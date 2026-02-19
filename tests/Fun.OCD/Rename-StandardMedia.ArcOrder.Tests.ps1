#Requires -Version 7.4
#Requires -Modules Pester

Describe 'Rename-StandardMedia Arc Ordering' {

    BeforeAll {
        # Dot-source the main script file directly to get access to all functions
        . "$PSScriptRoot\..\..\modules\Fun.OCD\public\Rename-StandardMedia.ps1"
    }

    Describe 'Comic with Arc Order' {
        It 'formats comic with arc and arc order as "Arc Name #NNN"' {
            # Arrange
            $baseName = Get-BaseNameForComic `
                -Title 'Suicide Squad' `
                -Year 2021 `
                -Arc 'Absolute Power' `
                -ArcOrder 3

            # Assert
            $baseName | Should -Match 'Absolute Power #003'
            $baseName | Should -Match 'Suicide Squad'
        }

        It 'includes arc order in the correct position within name segments' {
            # Arrange  
            $baseName = Get-BaseNameForComic `
                -Title 'Superman' `
                -Year 2021 `
                -Arc 'Absolute Power' `
                -Volume '1' `
                -VolumeName 'New World' `
                -ArcOrder 15

            # Assert - Arc should come first for proper sorting
            $baseName | Should -Match '^Absolute Power #015.*Superman.*Vol.1'
        }

        It 'handles zero-padded arc order with 3 digits' {
            # Arrange
            $baseName1 = Get-BaseNameForComic -Title 'Test' -Arc 'Arc' -ArcOrder 1
            $baseName2 = Get-BaseNameForComic -Title 'Test' -Arc 'Arc' -ArcOrder 42
            $baseName3 = Get-BaseNameForComic -Title 'Test' -Arc 'Arc' -ArcOrder 123

            # Assert
            $baseName1 | Should -Match '#001'
            $baseName2 | Should -Match '#042'
            $baseName3 | Should -Match '#123'
        }

        It 'omits arc order when not provided' {
            # Arrange
            $baseName = Get-BaseNameForComic `
                -Title 'Batman' `
                -Arc 'Dark Nights' `
                -Year 2022

            # Assert
            $baseName | Should -Match 'Dark Nights'
            $baseName | Should -Not -Match '#\d{3}'
        }

        It 'omits arc section entirely when arc is null and arc order is null' {
            # Arrange
            $baseName = Get-BaseNameForComic `
                -Title 'Standalone Comic' `
                -Year 2023

            # Assert
            $baseName | Should -Not -Match '#\d{3}'
        }
    }

    Describe 'Anime with Arc Order' {
        It 'formats anime with arc and arc order as "Arc Name #NNN"' {
            # Arrange
            $baseName = Get-BaseNameForAnime `
                -Title 'Jujutsu Kaisen' `
                -Year 2020 `
                -Season 'S02' `
                -EpisodeNumber 5 `
                -Arc 'Shibuya Incident' `
                -ArcOrder 7

            # Assert - Arc comes first for sorting
            $baseName | Should -Match '^Shibuya Incident #007.*Jujutsu Kaisen'
        }

        It 'handles arc order without season/episode info' {
            # Arrange
            $baseName = Get-BaseNameForAnime `
                -Title 'Attack on Titan' `
                -Arc 'Marley War' `
                -ArcOrder 42

            # Assert
            $baseName | Should -Match 'Marley War #042'
        }
    }

    Describe 'Series with Arc Order' {
        It 'formats series with arc and arc order as "Arc Name #NNN"' {
            # Arrange
            $baseName = Get-BaseNameForSeries `
                -Title 'The Boys' `
                -Year 2019 `
                -Season '1' `
                -EpisodeNumber 3 `
                -Arc 'Corporate Corruption' `
                -ArcOrder 8

            # Assert
            $baseName | Should -Match 'Corporate Corruption #008'
        }
    }

    Describe 'Arc Order Integration' {
        It 'correctly formats arc order for each file in same arc' {
            # Arrange
            $file1 = Get-BaseNameForComic -Title 'Suicide Squad - Dream Team' -Arc 'Absolute Power' -ArcOrder 3
            $file2 = Get-BaseNameForComic -Title 'Superman' -Arc 'Absolute Power' -ArcOrder 15
            $file3 = Get-BaseNameForComic -Title 'Wonder Woman' -Arc 'Absolute Power' -ArcOrder 7

            # Assert - Verify each has correct arc order format
            $file1 | Should -Match 'Absolute Power #003'
            $file2 | Should -Match 'Absolute Power #015'
            $file3 | Should -Match 'Absolute Power #007'
        }
    }

    Describe 'Backward Compatibility' {
        It 'works without arc order parameter (existing behavior)' {
            # Arrange
            $baseName = Get-BaseNameForComic `
                -Title 'Old Comic' `
                -Year 2020 `
                -Volume '5'

            # Assert
            $baseName | Should -Match 'Old Comic'
            $baseName | Should -Match 'Vol.5'
            $baseName | Should -Not -Match '#\d{3}'
        }
    }
}
