function Test-Command {
    [CmdletBinding()]
    [OutputType([CommandCheck])]
    [Alias('tc')]
    param (
        [Parameter(
            Mandatory,
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]$Command,

        [switch]$OnlyExisting
    )

    process {
        foreach ($cmdName in $Command) {
            Write-Verbose "Checking if command '$cmdName' exists..."

            $cmd = Get-Command -Name $cmdName -ErrorAction SilentlyContinue
            $result = [CommandCheck]::new(
                $cmdName,
                [bool]$cmd,
                $cmd.Source ? $cmd.Source : ($cmd.Path ? $cmd.Path : $null),
                $cmd.CommandType
            )

            if (-not $OnlyExisting -or $result.Exists) {
                $result
            }
        }
    }
}

<#
.SYNOPSIS
Represents the result of checking whether a PowerShell command exists.

.DESCRIPTION
The `CommandCheck` class encapsulates metadata about a given PowerShell command name.
It includes information such as:
- Whether the command exists in the current session.
- The type of the command (e.g., Cmdlet, Function, Alias, Application).
- The source path or module name associated with the command.

This class is typically used by tooling or scripts to analyze command availability in a structured and programmatic way.

.PROPERTIES
Name         - The name of the command being checked.
Exists       - A boolean indicating whether the command was found.
Path         - The source path or module name of the command. May be $null if unknown or not found.
CommandType  - The command type (Cmdlet, Function, Alias, Application). May be $null for unknown or missing commands.

.CONSTRUCTORS
CommandCheck([string]$Name, [bool]$Exists, [string]$Path, [CommandTypes]$CommandType)
    Creates a new instance representing a known command and its metadata.

CommandCheck([string]$Name)
    Creates a new instance representing a command that was not found.

.METHODS
ToString()
    Returns a human-readable summary.
    For found commands: "<Name>: <Type> @ <Path>".
    For missing commands: "<Name>: Not Found".

.EXAMPLE
$check = [CommandCheck]::new('Get-Item', $true, 'Microsoft.PowerShell.Management', [System.Management.Automation.CommandTypes]::Cmdlet)
$check.ToString()
# Output: Get-Item: Cmdlet @ Microsoft.PowerShell.Management

.EXAMPLE
$missing = [CommandCheck]::new('nonexistent-command')
$missing.ToString()
# Output: nonexistent-command: Not Found

.NOTES
Intended for use with utilities such as Test-Command that inspect the command table in PowerShell.
#>
class CommandCheck {
    [string] $Name
    [bool] $Exists

    [AllowNull()]
    [string] $Path

    [AllowNull()]
    [System.Nullable[System.Management.Automation.CommandTypes]] $CommandType

    CommandCheck(
        [string] $Name,
        [bool] $Exists,
        [string] $Path,
        [System.Nullable[System.Management.Automation.CommandTypes]]$CommandType
    ) {
        $this.Name = $Name
        $this.Exists = $Exists
        $this.Path = $Path
        $this.CommandType = $CommandType
    }

    CommandCheck([string] $Name) {
        $this.Name = $Name
        $this.Exists = $false
        $this.Path = $null
        $this.CommandType = $null
    }

    [string] ToString() {
        return if ($this.Exists) {
            "$($this.Name): $($this.CommandType ?? '?') @ $($this.Path ?? 'unknown path')"
        } else {
            "$($this.Name): Not Found"
        }
    }
}
