Describe 'Show-FileContents' {

    BeforeAll {
        $script:preloadedModules = Get-Module -Name Fun.Files, Assertions
        . "$PSScriptRoot\..\Initialize-FilesTestSuite.ps1"

        $files = New-TestDirectoryWithFiles -BaseName 'GetFileContentsTest'
        $script:tempDir = $files.Base
        $script:filePath = $files.File1
        $script:sampleContent = 'Kimetsu no Yaiba'
    }

    BeforeEach {
        Remove-Item $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -Path $script:tempDir -ItemType Directory -Force | Out-Null
        Set-Content -Path $script:filePath -Value $script:sampleContent -NoNewline
    }

    AfterAll {
        Remove-Item $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'prints file headers and contents to the host' {
        # Capture the output
        $output = & {
            Show-FileContents -Path $script:tempDir
        } *>&1 | Out-String

        # Match header and content
        $escapedHeader = [Regex]::Escape("File: $($script:filePath)")
        $escapedContent = [Regex]::Escape($script:sampleContent)

        $output | Should -Match $escapedHeader
        $output | Should -Match $escapedContent
    }
}
