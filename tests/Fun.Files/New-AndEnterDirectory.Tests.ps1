Describe 'New-AndEnterDirectory' {
    BeforeAll {
        $script:preloadedModules = Get-Module -Name Fun.Files

        # Load shared test helpers (e.g., temp file generator)
        . "$PSScriptRoot\Setup.ps1"
    }

    It 'creates and enters the specified directory' {
        $testPath = Join-Path `
            -Path ([System.IO.Path]::GetTempPath()) `
            -ChildPath ("TestDir_" + [guid]::NewGuid())
        
        # Save the original location to return after test
        $originalLocation = Get-Location

        try {
            New-AndEnterDirectory -LiteralPath $testPath

            Test-Path $testPath | Should -BeTrue
            (Get-Location).Path | Should -Be $testPath
        } finally {
            Set-Location -Path $originalLocation
            Remove-Item -Path $testPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
