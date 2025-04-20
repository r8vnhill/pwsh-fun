# Load shared test setup, including helper functions (e.g. Assert-ThrowsWithType)
. "$PSScriptRoot\..\Setup.ps1"

# Ensure the command under test is available and will cause the test to fail fast if it's
# missing
Get-Command Invoke-FileTransform -ErrorAction Stop | Out-Null

Describe 'Invoke-FileTransform' {

    BeforeAll {
        # Create a temporary directory and file structure for testing
        $script:tempDir     = Join-Path $env:TEMP 'InvokeFileTransformTest'
        $script:filePath1   = Join-Path $tempDir 'file1.txt'
        $script:filePath2   = Join-Path $tempDir 'sub\file2.txt'
        $script:invoked     = @()  # Will store file paths seen by the processor

        # Clean any leftovers from previous runs and create test files
        Remove-Item $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -Path $script:filePath1 -ItemType File -Force | Out-Null
        New-Item -Path $script:filePath2 -ItemType File -Force | Out-Null
    }

    AfterAll {
        # Clean up the temporary directory after all tests have completed
        Remove-Item $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'invokes the processor for each file recursively' {
        # The function should call the provided script block once per file
        Invoke-FileTransform -Path $script:tempDir -FileProcessor {
            param ($file, $header)
            $script:invoked += $file.FullName  # Track each file seen by the processor
        }

        # Assert that both files were passed to the FileProcessor
        $script:invoked | Should -Contain $script:filePath1
        $script:invoked | Should -Contain $script:filePath2
    }

    It 'throws DirectoryNotFoundException if path does not exist' {
        # Ensure the function throws the correct .NET exception type when the path is 
        # missing
        Assert-ThrowsWithType {
            Invoke-FileTransform -Path "$script:tempDir\NOPE" -FileProcessor { }
        } 'System.IO.DirectoryNotFoundException'
    }

    It 'throws if path is not a directory' {
        # Ensure the function throws the correct .NET exception when the path is a file, 
        # not a directory
        Assert-ThrowsWithType {
            Invoke-FileTransform -Path $script:filePath1 -FileProcessor { }
        } 'System.IO.InvalidDataException'
    }
}
