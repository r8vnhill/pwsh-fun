# Load the shared test suite initializer from the internal directory.
Import-Module -Name "$PSScriptRoot\..\internal\Test.Init\Test.Init.psd1" -ErrorAction Stop

$script:module = 'Fun.Ffmpeg'

Initialize-TestSuite -Module $script:module -RequiredCommands @(
    'Convert-ToVvc',
    'Get-VvcAudit',
    'Remove-ValidatedVvcOriginal'
) -ForceImport
