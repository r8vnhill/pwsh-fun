. "$PSScriptRoot/../internal/Initialize-TestSuite.ps1"
. "$PSScriptRoot/../internal/Helpers.ps1"

Initialize-TestSuite -Module 'Fun.Files' -RequiredCommands @(
    'Compress-FilteredFiles',
    'Get-FileContents',
    'Show-FileContents'
) -ForceImport
