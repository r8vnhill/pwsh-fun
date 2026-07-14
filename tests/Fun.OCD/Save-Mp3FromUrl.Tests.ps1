#Requires -Version 7.4
#Requires -Modules Pester

BeforeAll {
    . "$PSScriptRoot\..\..\modules\Fun.OCD\public\Save-Mp3FromUrl.ps1"

    Mock -CommandName 'yt-dlp.exe' -MockWith { $global:LASTEXITCODE = 0 }
}

Describe 'Save-Mp3FromUrl' {
    It 'invokes yt-dlp with -t mp3 and the requested URL' {
        Save-Mp3FromUrl -Url 'https://youtu.be/dQw4w9WgXcQ' -OutputPath $TestDrive -Confirm:$false

        Assert-MockCalled 'yt-dlp.exe' -Times 1 -Exactly -ParameterFilter {
            $args -contains '-t' -and
            $args -contains 'mp3' -and
            $args -contains 'https://youtu.be/dQw4w9WgXcQ'
        }
    }

    It 'accepts multiple URLs via the pipeline' {
        @('https://youtu.be/aaa', 'https://youtu.be/bbb') |
            Save-Mp3FromUrl -OutputPath $TestDrive -Confirm:$false

        Assert-MockCalled 'yt-dlp.exe' -Times 2 -Exactly
    }

    It 'passes through extra yt-dlp arguments' {
        Save-Mp3FromUrl -Url 'https://youtu.be/ccc' -OutputPath $TestDrive -YtDlpArguments @('--no-playlist') -Confirm:$false

        Assert-MockCalled 'yt-dlp.exe' -Times 1 -Exactly -ParameterFilter {
            $args -contains '--no-playlist'
        }
    }

    It 'throws when the output path does not exist' {
        $missingPath = Join-Path $TestDrive 'does-not-exist'

        { Save-Mp3FromUrl -Url 'https://youtu.be/ddd' -OutputPath $missingPath -Confirm:$false } | Should -Throw

        Assert-MockCalled 'yt-dlp.exe' -Times 0 -Exactly
    }

    It 'honors WhatIf without invoking yt-dlp' {
        Save-Mp3FromUrl -Url 'https://youtu.be/eee' -OutputPath $TestDrive -WhatIf

        Assert-MockCalled 'yt-dlp.exe' -Times 0 -Exactly
    }
}
