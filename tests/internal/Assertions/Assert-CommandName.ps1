<#
.SYNOPSIS
Validates that a command name follows PowerShell's standard naming conventions.

.DESCRIPTION
`Assert-CommandName` ensures that a command name adheres to the Verb-Noun pattern used in PowerShell and meets the following criteria:

- Follows the `Verb-Noun` format with a single dash.
- Uses proper casing: both verb and noun start with uppercase letters.
- Uses an approved PowerShell verb as defined by `Get-Verb`.

This function uses helper assertions internally and throws an error if the command name does not meet these standards.

.PARAMETER CommandName
The name of the command to validate.
Must be a non-empty string in the form `Verb-Noun`.
Accepts pipeline input.

.OUTPUTS
[bool]  
Returns `$true` if the command name passes all validation checks.

.EXAMPLE
'Get-Item' | Assert-CommandName

Validates that 'Get-Item' is correctly formatted and uses an approved verb.

.EXAMPLE
Assert-CommandName -CommandName 'make-widget'

Throws an error because 'make' is not an approved PowerShell verb and does not use the expected casing.

.NOTES
This function depends on internal assertion functions:
- `Assert-VerbNounConvention`
- `Assert-VerbCasing`
- `Assert-NounCasing`
- `Assert-ApprovedVerb`

It automatically loads them if not already available.

#>
function Assert-CommandName {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$CommandName
    )
    begin {
        if (-not $script:InternalAssertionsImported) {
            script:Import-InternalAssertions -ErrorAction Stop
            $script:InternalAssertionsImported = $true
        }
    }
    process {
        Assert-VerbNounConvention -CommandName $CommandName -ErrorAction Stop
        $command = [Command]::new($CommandName)
        # Check if the command name is in the correct format
        Assert-VerbCasing -Verb $command.Verb `
            -CommandName $command.Name `
            -ErrorAction Stop
        Assert-NounCasing -Noun $command.Noun `
            -CommandName $command.Name `
            -ErrorAction Stop
        Assert-ApprovedVerb -Verb $command.Verb `
            -CommandName $command.Name `
            -ErrorAction Stop
    }
    end {
        return $true
    }
}

<#
.SYNOPSIS
Imports internal assertion scripts required for command validation.

.DESCRIPTION
Loads a predefined set of internal assertion scripts into the current session. 
Each script is expected to exist under the 'internal' subdirectory relative to the script's root directory.
If a script is missing, a warning is issued, but the import process continues for other available scripts.

This function is typically called before validating command naming conventions to ensure all necessary assertions are available.

.NOTES
Scripts imported:
- Assert-VerbNounConvention.ps1
- Assert-VerbCasing.ps1
- Assert-NounCasing.ps1
- Assert-ApprovedVerb.ps1

Imported scripts are dot-sourced, making their functions available in the caller's scope.
#>
function script:Import-InternalAssertions {
    [CmdletBinding()]
    param ()

    $internalDir = Join-Path -Path $PSScriptRoot -ChildPath 'internal'

    $scripts = @(
        'Assert-VerbNounConvention.ps1',
        'Assert-VerbCasing.ps1',
        'Assert-NounCasing.ps1',
        'Assert-ApprovedVerb.ps1'
    )

    foreach ($script in $scripts) {
        $fullPath = Join-Path -Path $internalDir -ChildPath $script
        if (Test-Path -LiteralPath $fullPath) {
            . $fullPath
            Write-Verbose "✅ Imported: $script"
        } else {
            Write-Warning "⚠️ Could not find expected script: $script"
        }
    }
}

<#
.SYNOPSIS
Represents a PowerShell command and splits its name into Verb and Noun components.

.DESCRIPTION
The `Command` class encapsulates a PowerShell-style command name (e.g., `Get-Item`) and provides properties to access its `Verb` and `Noun` parts.

It validates that the input string follows the standard `Verb-Noun` naming convention, throwing a `[System.ArgumentException]` if the format is invalid.

This is useful for enforcing naming standards and simplifying validation logic in module or test setups.

.CONSTRUCTORS
Command([string]$name)
Creates a new instance of the class, validating and parsing the command name into its components.

.PARAMETER Name
The full name of the command (e.g., 'Get-Item'). Must include a hyphen separating verb and noun.

.PROPERTIES
Name  - The original command name string.
Verb  - The verb part of the command name.
Noun  - The noun part of the command name.

.EXAMPLE
$cmd = [Command]::new('Get-File')
$cmd.Verb  # Outputs 'Get'
$cmd.Noun  # Outputs 'File'

.EXAMPLE
# This throws an exception due to missing dash:
[Command]::new('InvalidCommand')

.NOTES
- Verb and Noun casing is not validated here. Use separate assertions if needed.
- Designed for use in test frameworks or module validation tooling.
#>
class Command {
    [string]$Name
    [string]$Verb
    [string]$Noun

    Command([string]$name) {
        $parts = $name.Split('-', 2)
        if ($parts.Count -ne 2) {
            $message = @(
                "❌ Invalid command name format: '$name'.",
                "Expected format 'Verb-Noun'."
            ) -join ' '
            throw [System.ArgumentException]::new($message)
        }
        $this.Name = $name
        $this.Verb = $parts[0]
        $this.Noun = $parts[1]
    }
}
