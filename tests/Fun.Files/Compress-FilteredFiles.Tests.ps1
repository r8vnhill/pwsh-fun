Describe 'Compress-FilteredFiles' {

    # Run once before all tests
    BeforeAll {
        $script:preloadedModules = Get-Module -Name Fun.Files, Assertions

        # Load shared test helpers (e.g., temp file generator)
        . "$PSScriptRoot\Setup.ps1"
    }

    # Run before each individual test
    BeforeEach {
        # Create two temp directories with test files
        $script:temp = New-TestDirectoryWithFiles -BaseName 'CompressTest'
        $script:temp2 = New-TestDirectoryWithFiles -BaseName 'SecondRoot'

        # Define a unique zip archive path in the temp folder
        $script:zipPath = Join-Path $env:TEMP "test-archive-$([guid]::NewGuid()).zip"

        # Add an extra file that should be excluded from the archive
        Set-Content -Path (Join-Path $script:temp.Base 'ignore.md') `
            -Value 'should be excluded'
    }

    # Clean up after each test
    AfterEach {
        Remove-Item $script:zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $script:temp.Base -Recurse -Force -ErrorAction SilentlyContinue
    }

    AfterAll {
        foreach ($modName in @('Fun.Files', 'Assertions')) {
            $wasPreloaded = $script:preloadedModules | Where-Object { 
                $_.Name -eq $modName 
            }
            if (-not $wasPreloaded) {
                Remove-Module -Name $modName -ErrorAction SilentlyContinue
            }
        }
    }

    It 'creates a zip archive with only included files' {
        # Define file filters
        $include = '.*\.txt$'
        $exclude = '.*\.md$'

        # Create zip archive from files matching the filters
        Compress-FilteredFiles `
            -Path $script:temp.Base `
            -DestinationZip $script:zipPath `
            -IncludeRegex $include `
            -ExcludeRegex $exclude | Out-Null

        # Assert zip file was created
        Test-Path $script:zipPath | Should -BeTrue

        # Extract and inspect zip contents
        $zip = $null
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [System.IO.Compression.ZipFile]::OpenRead($script:zipPath)
            $entries = $zip.Entries | ForEach-Object { $_.FullName }
        } finally {
            if ($zip) { $zip.Dispose() }
        }

        # Validate correct files were included/excluded
        $entries | Should -Contain 'CompressTest/file1.txt'
        $entries | Should -Contain 'CompressTest/sub/file2.txt'
        $entries | Should -Not -Contain 'CompressTest/ignore.md'
        $entries.Count | Should -Be 2
    }

    It 'returns null if no files match the filters' {
        # Filter designed to match no files
        $result = Compress-FilteredFiles `
            -Path $script:temp.Base `
            -DestinationZip $script:zipPath `
            -IncludeRegex '.*\.doesnotexist$' *> $null

        # Assert no result and no zip file
        $result | Should -BeNullOrEmpty
        Test-Path $script:zipPath | Should -BeFalse
    }

    It 'overwrites an existing zip file' {
        # Pre-create dummy archive to test overwriting
        Set-Content -Path $script:zipPath -Value 'placeholder'

        Compress-FilteredFiles `
            -Path $script:temp.Base `
            -DestinationZip $script:zipPath `
            -IncludeRegex @('.*\.txt$') `
            -ExcludeRegex @() | Out-Null

        # Check the archive is no longer empty
        $zipInfo = Get-Item $script:zipPath
        $zipInfo.Length | Should -BeGreaterThan 0
    }

    It 'handles multiple input paths and preserves relative structure' {
        # Archive files from multiple roots via piped input
        $script:temp.Base, $script:temp2.Base |
            Compress-FilteredFiles -DestinationZip $script:zipPath -IncludeRegex '.*\.txt$' | Out-Null

        # Inspect contents of the resulting archive
        $zip = [System.IO.Compression.ZipFile]::OpenRead($script:zipPath)
        $entries = $zip.Entries | ForEach-Object { $_.FullName }
        $zip.Dispose()

        $entries | Should -Contain 'CompressTest/file1.txt'
        $entries | Should -Contain 'CompressTest/sub/file2.txt'
        $entries | Where-Object { $_ -like '*SecondRoot*' } | Should -Not -BeNullOrEmpty
    }

    It 'supports pipeline input for paths' {
        # Pass a single path via pipeline
        $result = @($script:temp.Base) |
            Compress-FilteredFiles -DestinationZip $script:zipPath

        # Should return the zip path exactly once
        $result | Should -BeExactly @($script:zipPath)
    }

    It 'rejects non-.zip destinations' {
        # Attempting to create a non-zip archive should throw
        { Compress-FilteredFiles -Path $script:temp.Base -DestinationZip 'output.txt' } |
            Should -Throw
    }
}
