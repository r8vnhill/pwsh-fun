Describe 'Compress-FilteredFiles' {

    BeforeAll {
        $script:preloadedModules = Get-Module -Name Fun.Files, Assertions
        . "$PSScriptRoot\..\Setup.ps1"
    }

    BeforeEach {
        $script:temp = New-TestDirectoryWithFiles -BaseName 'CompressTest'
        $script:temp2 = New-TestDirectoryWithFiles -BaseName 'SecondRoot'

        $script:zipPath = Join-Path $env:TEMP "test-archive-$([guid]::NewGuid()).zip"

        # Add extra file to test exclusion
        Set-Content -Path (Join-Path $script:temp.Base 'ignore.md') `
            -Value 'should be excluded'
    }

    AfterEach {
        Remove-Item $script:zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $script:temp.Base -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'creates a zip archive with only included files' {
        $include = '.*\.txt$'
        $exclude = '.*\.md$'

        Compress-FilteredFiles `
            -Path $script:temp.Base `
            -DestinationZip $script:zipPath `
            -IncludeRegex $include `
            -ExcludeRegex $exclude | Out-Null

        Test-Path $script:zipPath | Should -BeTrue

        $zip = $null
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [System.IO.Compression.ZipFile]::OpenRead($script:zipPath)
            $entries = $zip.Entries | ForEach-Object { $_.FullName }
        } finally {
            if ($zip) {
                $zip.Dispose()
            }
        }

        $entries | Should -Contain 'CompressTest/file1.txt'
        $entries | Should -Contain 'CompressTest/sub/file2.txt'
        $entries | Should -Not -Contain 'CompressTest/ignore.md'
        $entries.Count | Should -Be 2
    }

    It 'returns null if no files match the filters' {
        $result = Compress-FilteredFiles `
            -Path $script:temp.Base `
            -DestinationZip $script:zipPath `
            -IncludeRegex '.*\.doesnotexist$' *> $null
    
        $result | Should -BeNullOrEmpty
        Test-Path $script:zipPath | Should -BeFalse
    }
    
    It 'overwrites an existing zip file' {
        Set-Content -Path $script:zipPath -Value 'placeholder'
    
        Compress-FilteredFiles `
            -Path $script:temp.Base `
            -DestinationZip $script:zipPath `
            -IncludeRegex @('.*\.txt$') `
            -ExcludeRegex @() | Out-Null
    
        $zipInfo = Get-Item $script:zipPath
        $zipInfo.Length | Should -BeGreaterThan 0
    }    

    It 'handles multiple input paths and preserves relative structure' {
        $script:temp.Base, $script:temp2.Base | Compress-FilteredFiles `
            -DestinationZip $script:zipPath `
            -IncludeRegex '.*\.txt$' | Out-Null
    
        $zip = [System.IO.Compression.ZipFile]::OpenRead($script:zipPath)
        $entries = $zip.Entries | ForEach-Object { $_.FullName }
        $zip.Dispose()
    
        $entries | Should -Contain 'CompressTest/file1.txt'
        $entries | Should -Contain 'CompressTest/sub/file2.txt'
        $entries | Where-Object { $_ -like '*SecondRoot*' } | Should -Not -BeNullOrEmpty
    }

    It 'supports pipeline input for paths' {
        $result = @($script:temp.Base)
        | Compress-FilteredFiles -DestinationZip $script:zipPath
        $result | Should -BeExactly @($script:zipPath)
    }

    It 'rejects non-.zip destinations' {
        { Compress-FilteredFiles -Path $script:temp.Base -DestinationZip 'output.txt' } |
            Should -Throw
    }
}
