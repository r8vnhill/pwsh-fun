Describe 'Invoke-FileTransform' {

    BeforeAll {
        # Capture pre-existing modules so we can skip unloading them
        $script:preloadedModules = Get-Module -Name 'Fun.Files', 'Assertions'
        . "$PSScriptRoot\..\Setup.ps1"

        # Create a temporary directory and file structure for testing
        $paths = New-TestDirectoryWithFiles -BaseName 'InvokeFileTransformTest'
        $script:tempDir = $paths.Base
        $script:filePath1 = $paths.File1
        $script:filePath2 = $paths.File2

        # Clean any leftovers from previous runs and create test files
        Remove-Item $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -Path $script:filePath1 -ItemType File -Force | Out-Null
        New-Item -Path $script:filePath2 -ItemType File -Force | Out-Null
    }

    AfterAll {
        Remove-TestEnvironment `
            -TempDir $script:tempDir `
            -PreloadedModules $script:preloadedModules
    }

    It 'invokes the processor for each file recursively' {
        # The function should call the provided script block once per file
        $processedFiles  = Get-InvokedFilePathsForTest -Path $script:tempDir

        # Assert that both files were passed to the FileProcessor
        $processedFiles | Should -Contain $script:filePath1
        $processedFiles | Should -Contain $script:filePath2
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

    It 'respects IncludeRegex to only match specific files' {
        $processedFiles = Get-InvokedFilePathsForTest -Path $script:tempDir `
            -IncludeRegex '.*file1\.txt$' `
    
        $processedFiles.Count | Should -Be 1
        $processedFiles | Should -HaveCount 1
    }
    
    It 'respects ExcludeRegex to skip specific files' {
        $processedFiles = Get-InvokedFilePathsForTest -Path $script:tempDir `
            -ExcludeRegex '.*file2\.txt$'
    
        $processedFiles.Count | Should -Be 1
        $processedFiles | Should -BeExactly @($script:filePath1)
    }
    
    It 'applies both IncludeRegex and ExcludeRegex with exclusion taking precedence' {
        $processedFiles = Get-InvokedFilePathsForTest -Path $script:tempDir `
            -IncludeRegex '.*file2\.txt$' `
            -ExcludeRegex '.*sub.*'
    
        # The file matches the include but is excluded by the exclude pattern
        $processedFiles.Count | Should -Be 0
    }

    It 'does not invoke processor if no files match' {
        $processedFiles = Get-InvokedFilePathsForTest -Path $script:tempDir -IncludeRegex '.*\.md$'
        $processedFiles.Count | Should -Be 0
    }

    It 'does not invoke processor if directory is empty' {
        $emptyDir = Join-Path $env:TEMP 'InvokeFileTransformTestEmpty'
        New-Item -Path $emptyDir -ItemType Directory -Force | Out-Null
    
        $processedFiles = Get-InvokedFilePathsForTest -Path $emptyDir
        $processedFiles.Count | Should -Be 0
    
        Remove-Item $emptyDir -Recurse -Force -ErrorAction SilentlyContinue
    }    
}
