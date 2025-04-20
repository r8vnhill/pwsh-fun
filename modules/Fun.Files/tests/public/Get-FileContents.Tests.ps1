# Load shared test setup (e.g., Assert helpers, module imports)
. "$PSScriptRoot\..\Setup.ps1"

# Ensure the function to test is available; fail early if missing
Get-Command Get-FileContents -ErrorAction Stop | Out-Null

Describe 'Get-FileContents' {

    BeforeAll {
        # Define test file paths and contents (reused across all test cases)
        $Script:tempDir   = Join-Path $env:TEMP 'GetFileContentsTest'
        $Script:subDir    = Join-Path $Script:tempDir 'sub'
        $Script:filePath1 = Join-Path $Script:tempDir 'file1.txt'
        $Script:filePath2 = Join-Path $Script:subDir 'file2.txt'
        $Script:content1  = "Hello, World!"
        $Script:content2  = "Another file here."
    }

    BeforeEach {
        # Clean up any previous state and set up a consistent test environment
        Remove-Item $Script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -Path $Script:subDir -ItemType Directory -Force | Out-Null

        # Write known content to test files
        Set-Content -Path $Script:filePath1 -Value $Script:content1
        Set-Content -Path $Script:filePath2 -Value $Script:content2
    }

    AfterAll {
        # Clean up test artifacts after all test cases complete
        Remove-Item $Script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
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
    }

    It 'filters files by extension using IncludePatterns' {
        # Create an extra file that should be excluded by the filter
        $excludedFile = Join-Path $Script:tempDir 'ignore.md'
        Set-Content -Path $excludedFile -Value "Should be excluded"

        # Only include .txt files
        $results = Get-FileContents -Path $Script:tempDir -IncludePatterns '*.txt'

        # Only the .txt files should be returned
        $results.Count | Should -Be 2
        $paths = $results | ForEach-Object { $_.Path }
        $paths | Should -Contain $Script:filePath1
        $paths | Should -Contain $Script:filePath2
        $paths | Should -Not -Contain $excludedFile
    }

    It 'excludes files by extension using ExcludePatterns' {
        # Create an extra file with .log extension, which should be excluded
        $excludedFile = Join-Path $Script:tempDir 'skip.log'
        Set-Content -Path $excludedFile -Value "This should be excluded"

        # Exclude .log files
        $results = Get-FileContents -Path $Script:tempDir -ExcludePatterns '*.log'

        # Confirm only the two original files remain
        $results.Count | Should -Be 2
        $paths = $results | ForEach-Object { $_.Path }
        $paths | Should -Contain $Script:filePath1
        $paths | Should -Contain $Script:filePath2
        $paths | Should -Not -Contain $excludedFile
    }

    It 'throws if path does not exist (delegated)' {
        # Expect a delegated exception from Invoke-FileTransform
        { Get-FileContents -Path "$Script:tempDir\nope" } | Should -Throw
    }

    It 'throws if path is a file (delegated)' {
        # Calling Get-FileContents on a file (not a directory) should fail
        Set-Content -Path $Script:filePath1 -Value "content"
        { Get-FileContents -Path $Script:filePath1 } | Should -Throw
    }
}
