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
                $cmd?.Source,
                $cmd?.CommandType
            )

            if (-not $OnlyExisting -or $result.Exists) {
                $result
            }
        }
    }
}

class CommandCheck {
    [string]$Name
    [bool]$Exists
    [string]$Path
    [System.Management.Automation.CommandTypes]$CommandType

    CommandCheck(
        [string]$Name,
        [bool]$Exists,
        [string]$Path,
        [System.Management.Automation.CommandTypes]$CommandType
    ) {
        $this.Name = $Name
        $this.Exists = $Exists
        $this.Path = $Path
        $this.CommandType = $CommandType
    }

    [string] ToString() {
        if ($this.Exists) {
            return "$($this.Name): $($this.CommandType) @ $($this.Path)"
        } else {
            return "$($this.Name): Not Found"
        }
    }
}
