# Load internal test helper assertions
. "$PSScriptRoot\internal\Assertions.ps1"
. "$PSScriptRoot\internal\Helpers.ps1"

# Resolve and import the module under test
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\Fun.Files.psd1'

if (-not (Test-Path $modulePath)) {
    throw "❌ Module path '$modulePath' not found."
}

Import-Module $modulePath -Force -ErrorAction Stop

# Verify required commands are available
$requiredCommands = @(
    'Invoke-FileTransform',
    'Get-FileContents',
    'Show-FileContents'
)

foreach ($cmd in $requiredCommands) {
    try {
        Get-Command $cmd -ErrorAction Stop | Out-Null
    } catch {
        throw "❌ Expected command '$cmd' not found after importing module."
    }
}
