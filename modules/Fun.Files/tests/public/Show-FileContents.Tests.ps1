Describe 'Show-FileContents' {

    BeforeAll {
        # Prepare a temporary test directory and file
        $script:tempDir = Join-Path $env:TEMP 'ShowFileContentsTest'
        $script:filePath = Join-Path $script:tempDir 'example.txt'
        $script:sampleContent = 'Kimetsu no Yaiba'

        # Clean up any previous test directory and create the new file
        Remove-Item $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -Path $script:filePath -ItemType File -Force | Set-Content -Value $script:sampleContent
    }

    AfterAll {
        # Clean up the temporary directory after all tests run
        Remove-Item $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'displays file header and content without color' {
        # Mock Invoke-FileTransform to simulate its behavior in a controlled way
        Mock Invoke-FileTransform {
            param ($Path, $FileProcessor)

            # Invoke the processor as if it was processing a real file
            $FileProcessor.Invoke((Get-Item $script:filePath), "`n📄 File: $($script:filePath)")
        }

        # Capture all output from Show-FileContents (including Write-Host and Write-Information)
        $output = & {
            Show-FileContents -Path $script:tempDir
        } *>&1 | Out-String

        # Assert that the file header was printed
        $output | Should -Match '📄 File: .+example\.txt'

        # Assert that the file content was printed
        $output | Should -Match $script:sampleContent
    }

    It 'throws when path does not exist (delegated)' {
        # Ensure the function throws an error for a non-existent path
        { Show-FileContents -Path "$script:tempDir\NOPE" } | Should -Throw
    }
}
