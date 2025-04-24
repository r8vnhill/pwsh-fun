Describe 'Get-FileContents' {

    BeforeAll {
        # Capture pre-existing modules so we can skip unloading them
        $script:preloadedModules = Get-Module -Name Fun.Files, Assertions
        . "$PSScriptRoot\Setup.ps1"

        # Crea estructura de archivos de prueba
        $files = New-TestDirectoryWithFiles -BaseName 'GetFileContentsTest'

        # Define rutas y contenidos esperados
        $script:tempDir = $files.Base
        $script:filePath1 = $files.File1
        $script:filePath2 = $files.File2
        $script:content1 = 'Hello, World!'
        $script:content2 = 'Another file here.'
        $script:subDir = $files.Sub
    }

    BeforeEach {
        # Clean up any previous state and set up a consistent test environment
        Remove-Item $Script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -Path $Script:subDir -ItemType Directory -Force | Out-Null

        # Write known content to test files
        Set-Content -Path $Script:filePath1 -Value $Script:content1 -NoNewline
        Set-Content -Path $Script:filePath2 -Value $Script:content2 -NoNewline
    }

    AfterAll {
        Remove-TestEnvironment `
            -TempDir $script:tempDir `
            -PreloadedModules $script:preloadedModules `
            -ModuleNames @('Fun.Files', 'Assertions')
    }

    It 'returns objects with path, header, and content' {
        # Test default behavior: all files in the directory should be returned
        $results = Get-FileContents -Path $Script:tempDir

        # Expect exactly two results (no filters applied)
        $results.Count | Should -Be 2

        # Confirm expected files are included
        $paths = $results | ForEach-Object { $_.Path }
        $paths | Should -Contain $Script:filePath1
        $paths | Should -Contain $Script:filePath2
        $results | Where-Object { $_.Path -eq $Script:filePath1 } | ForEach-Object {
            $_.ContentText | Should -BeExactly $Script:content1
        }
    }

    It 'filters files by extension using IncludePatterns' {
        # Create an extra file that should be excluded by the filter
        $excludedFile = Join-Path $Script:tempDir 'ignore.md'
        Set-Content -Path $excludedFile -Value 'Should be excluded'

        # Only include .txt files
        $results = Get-FileContents -Path $Script:tempDir -IncludePatterns '.*\.txt$'

        # Only the .txt files should be returned
        $results.Count | Should -Be 2
        $paths = $results | ForEach-Object { $_.Path }
        $paths | Should -Contain $Script:filePath1
        $paths | Should -Contain $Script:filePath2
        $paths | Should -Not -Contain $excludedFile
        $results | Where-Object { $_.Path -eq $Script:filePath1 } | ForEach-Object {
            $_.ContentText | Should -BeExactly $Script:content1
        }        
    }

    It 'excludes files by extension using ExcludePatterns' {
        # Create an extra file with .log extension, which should be excluded
        $excludedFile = Join-Path $Script:tempDir 'skip.log'
        Set-Content -Path $excludedFile -Value 'This should be excluded'

        # Exclude .log files
        $results = Get-FileContents -Path $Script:tempDir -ExcludePatterns '.*.log'

        # Confirm only the two original files remain
        $results.Count | Should -Be 2
        $paths = $results | ForEach-Object { $_.Path }
        $paths | Should -Contain $Script:filePath1
        $paths | Should -Contain $Script:filePath2
        $paths | Should -Not -Contain $excludedFile
        $results | Where-Object { $_.Path -eq $Script:filePath1 } | ForEach-Object {
            $_.ContentText | Should -BeExactly $Script:content1
        }
    }

    It 'throws if path does not exist (delegated)' {
        # Expect a delegated exception from Invoke-FileTransform
        { Get-FileContents -Path "$Script:tempDir\nope" } | Should -Throw
    }

    It 'throws if path is a file (delegated)' {
        # Calling Get-FileContents on a file (not a directory) should fail
        Set-Content -Path $Script:filePath1 -Value 'content'
        { Get-FileContents -Path $Script:filePath1 } | Should -Throw
    }
}
