Describe 'Invoke-FileTransform' {

    BeforeAll {
        # Capture pre-existing modules so we can skip unloading them
        $script:preloadedModules = Get-Module -Name 'Fun.Files', 'Assertions'

        # Import helper and test modules
        Import-Module (
            Join-Path -Path $PSScriptRoot -ChildPath '..\internal\Assertions.psm1'
        ) -Force -ErrorAction Stop
        Import-Module (
            Join-Path -Path $PSScriptRoot -ChildPath '..\..\Fun.Files.psm1'
        ) -Force -ErrorAction Stop

        function Invoke-AndCollect {
            param (
                [string]$Path,
                [string[]]$IncludeRegex = @('.*'),
                [string[]]$ExcludeRegex = @()
            )
        
            Invoke-FileTransform -Path $Path `
                -IncludeRegex $IncludeRegex `
                -ExcludeRegex $ExcludeRegex `
                -FileProcessor {
                param ($file, $header)
                $script:invoked += $file.FullName
            }
        }        

        # Create a temporary directory and file structure for testing
        $script:tempDir = Join-Path $env:TEMP 'InvokeFileTransformTest'
        $script:filePath1 = Join-Path $tempDir 'file1.txt'
        $script:filePath2 = Join-Path $tempDir 'sub\file2.txt'
        $script:invoked = @()  # Will store file paths seen by the processor

        # Clean any leftovers from previous runs and create test files
        Remove-Item $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -Path $script:filePath1 -ItemType File -Force | Out-Null
        New-Item -Path $script:filePath2 -ItemType File -Force | Out-Null
    }

    AfterAll {
        Remove-Item $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    
        foreach ($modName in 'Assertions', 'Fun.Files') {
            $wasPreloaded = $script:preloadedModules | Where-Object { $_.Name -eq $modName }
            if (-not $wasPreloaded) {
                Remove-Module -Name $modName -ErrorAction SilentlyContinue
            }
        }
    }

    BeforeEach {
        $script:invoked = @()
    }    

    It 'invokes the processor for each file recursively' {
        # The function should call the provided script block once per file
        Invoke-AndCollect -Path $script:tempDir

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

    It 'respects IncludeRegex to only match specific files' {
        Invoke-AndCollect -Path $script:tempDir `
            -IncludeRegex '.*file1\.txt$' `
    
        $script:invoked.Count | Should -Be 1
        $script:invoked[0] | Should -BeExactly $script:filePath1
    }
    
    It 'respects ExcludeRegex to skip specific files' {
        Invoke-AndCollect -Path $script:tempDir `
            -ExcludeRegex '.*file2\.txt$'
    
        $script:invoked.Count | Should -Be 1
        $script:invoked[0] | Should -BeExactly $script:filePath1
    }
    
    It 'applies both IncludeRegex and ExcludeRegex with exclusion taking precedence' {
        Invoke-AndCollect -Path $script:tempDir `
            -IncludeRegex '.*file2\.txt$' `
            -ExcludeRegex '.*sub.*'
    
        # The file matches the include but is excluded by the exclude pattern
        $script:invoked.Count | Should -Be 0
    }

    It 'does not invoke processor if no files match' {
        Invoke-AndCollect -Path $script:tempDir -IncludeRegex '.*\.md$'
        $script:invoked.Count | Should -Be 0
    }

    It 'does not invoke processor if directory is empty' {
        $emptyDir = Join-Path $env:TEMP 'InvokeFileTransformTestEmpty'
        New-Item -Path $emptyDir -ItemType Directory -Force | Out-Null
    
        Invoke-AndCollect -Path $emptyDir
        $script:invoked.Count | Should -Be 0
    
        Remove-Item $emptyDir -Recurse -Force -ErrorAction SilentlyContinue
    }    
}
