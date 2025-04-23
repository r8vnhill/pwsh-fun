Describe 'Test-Command' {
    
    BeforeAll {
        $script:preloadedModules = Get-Module -Name 'Fun.Terminal'
        . "$PSScriptRoot\..\Initialize-TerminalTestSuite.ps1"
    }


}
