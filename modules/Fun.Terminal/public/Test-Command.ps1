# modules\Fun.Terminal\public\Test-Command.ps1

<#
.SYNOPSIS
Tests whether a given command is available in the current PowerShell session.

.DESCRIPTION
`Test-Command` checks if a specified command exists by name, and returns a structured object indicating whether it exists, its source path, and its command type.

This is useful for scripts that rely on optional tools or for reporting command availability across environments.
It supports pipeline input and `-Verbose` output.

.PARAMETER Command
The name of the command to test. Can be a function, alias, cmdlet, or external executable.

.EXAMPLE
PS> Test-Command git

Returns an object like:

Name Exists Path                             CommandType
---- ------ ----                             -----------
git  True   C:\Program Files\Git\cmd\git.exe Application

.EXAMPLE
PS> "git", "pwsh", "nonexistent" | Test-Command | Where-Object Exists

Filters only the commands that actually exist.

.EXAMPLE
PS> $results = "pwsh", "python", "curl" | Test-Command
PS> foreach ($r in $results) {
>>     if (-not $r.Exists) {
>>         Write-Warning "$($r.Name) not found!"
>>     }
>> }

Checks a list of required tools and warns about any that are missing.

.EXAMPLE
PS> if ((Test-Command docker).Exists) {
>>     Write-Host "✅ Docker is installed!"
>> } else {
>>     Write-Error "❌ Docker is not available."
>> }

Conditionally run code based on the availability of a command.

.OUTPUTS
[PSCustomObject] with the following properties:
- `Name`: The input command name
- `Exists`: `$true` if the command is found, otherwise `$false`
- `Path`: The source or definition path (if available)
- `CommandType`: The command type (e.g., Cmdlet, Application, Function)

#>
function Test-Command {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$Command
    )

    process {
        Write-Verbose "Checking if command '$Command' exists..."

        $cmd = Get-Command -Name $Command -ErrorAction SilentlyContinue

        [PSCustomObject]@{
            Name = $Command
            Exists = [bool]$cmd
            Path = $cmd ? $cmd.Source : $null
            CommandType = $cmd ? $cmd.CommandType : $null
        }
    }
}
