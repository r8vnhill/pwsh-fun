<#
.SYNOPSIS
Asserts that all required commands are available after importing a module.

.DESCRIPTION
`Assert-ModuleCommandsPresent` verifies that a given list of commands is available in the session, typically after importing a module. 
If any expected command is missing, the function throws a `CommandNotFoundException`.

This is useful in test setups or CI pipelines to ensure the module exposes all intended public commands.

.PARAMETER Module
The name of the module that should have exported the required commands.
Used in error messages for clarity.

.PARAMETER RequiredCommands
A list of command names that must be available in the session.
If any are missing, an exception is thrown.

.PARAMETER VerboseOnSuccess
If set, the function will write a verbose message for each command found.

.EXAMPLE
PS> Assert-ModuleCommandsPresent -Module 'Fun.Files' -RequiredCommands 'Show-FileContents', 'Get-FileContents'

Verifies that the commands `Show-FileContents` and `Get-FileContents` are present in the session after importing the `Fun.Files` module.

.EXAMPLE
PS> Assert-ModuleCommandsPresent -Module 'Fun.Loader' -RequiredCommands 'Install-FunModules' -VerboseOnSuccess

Checks that `Install-FunModules` exists and logs a verbose message on success.

.NOTES
- Throws a [System.Management.Automation.CommandNotFoundException] for missing commands.
- Useful in `Initialize-TestSuite` functions and module bootstrapping checks.
#>
function Assert-ModuleCommandsPresent {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Module,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$RequiredCommands,

        [switch]$VerboseOnSuccess
    )

    foreach ($cmd in $RequiredCommands) {
        try {
            Get-Command -Name $cmd -ErrorAction Stop | Out-Null
            if ($VerboseOnSuccess) {
                Write-Verbose "✔ Command available: $cmd"
            }
        } catch {
            throw [System.Management.Automation.CommandNotFoundException]::new(
                "❌ Expected command '$cmd' not found after importing module: $Module",
                $_.Exception
            )
        }
    }
}
