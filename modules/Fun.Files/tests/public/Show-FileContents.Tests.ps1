Describe 'Show-FileContents' {

    BeforeAll {
        # Capture pre-existing modules so we can skip unloading them
        $script:preloadedModules = Get-Module -Name Fun.Files, Assertions
        . "$PSScriptRoot\..\Setup.ps1"

        # Crea estructura de archivos de prueba
        $files = New-TestDirectoryWithFiles -BaseName 'GetFileContentsTest'
        # Prepare a temporary test directory and file
        $script:tempDir = $files.Base
        $script:filePath = $files.File1
        $script:sampleContent = 'Kimetsu no Yaiba'
    }

    BeforeEach {
        # Clean up any previous state and set up a consistent test environment
        Remove-Item $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -Path $script:tempDir -ItemType Directory -Force | Out-Null
    
        # Recreate the test file path if needed
        Set-Content -Path $script:filePath -Value $script:sampleContent -NoNewline
    }    

    AfterAll {
        # Clean up the temporary directory after all tests run
        Remove-Item $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'prints file headers and contents to the host' {
        $outputPath = Join-Path $env:TEMP ('sfc-output-{0}.txt' -f ([guid]::NewGuid()))
        
        try {
            Start-Transcript -Path $outputPath -Force | Out-Null
            Show-FileContents -Path $script:tempDir
        } finally {
            Stop-Transcript | Out-Null
        }
    
        $transcript = Get-Content $outputPath -Raw
    
        $escapedPath = [Regex]::Escape($script:filePath)
        $transcript | Should -Match $escapedPath
    
        $escapedContent = [Regex]::Escape($script:sampleContent)
        $transcript | Should -Match $escapedContent
    
        Remove-Item $outputPath -Force -ErrorAction SilentlyContinue
    }     
}
