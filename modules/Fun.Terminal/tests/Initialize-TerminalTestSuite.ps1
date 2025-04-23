# Resolve and import the module under test
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\Fun.Terminal.psd1'

if (-not (Test-Path $modulePath)) {
    throw "❌ Module path '$modulePath' not found."
}

$requiredCommands = @(
    'Test-Command'
)

foreach ($cmd in $requiredCommands) {
    try {
        Get-Command $cmd -ErrorAction Stop | Out-Null
    } catch {
        throw "❌ Expected command '$cmd' not found after importing module."
    }
}
