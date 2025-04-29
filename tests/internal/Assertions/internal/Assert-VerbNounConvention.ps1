<#
.SYNOPSIS
Validates that a command name follows the Verb-Noun naming convention.

.DESCRIPTION
`Assert-VerbNounConvention` checks whether a provided command name adheres to the standard PowerShell Verb-Noun format.
The name must consist of two parts separated by a dash (`-`), where each part starts with a letter and contains only letters and numbers.

If the name does not conform to this pattern, a `[System.ArgumentException]` is thrown.

This validation helps enforce naming consistency in scripts, modules, and command libraries.

.PARAMETER CommandName
The name of the command to validate.
It must be a non-empty string provided via parameter or pipeline input.

.OUTPUTS
[bool] Returns `$true` if the command name is valid.

.EXAMPLE
PS> Assert-VerbNounConvention -CommandName 'Get-Item'

Validates successfully because 'Get-Item' follows the Verb-Noun format.

.EXAMPLE
PS> 'Set-Config' | Assert-VerbNounConvention

Validates successfully when provided via pipeline input.

.EXAMPLE
PS> Assert-VerbNounConvention -CommandName 'ItemGet'

Throws an error because 'ItemGet' does not follow the Verb-Noun pattern.

.NOTES
- This validation only checks format, not whether the verb is part of the approved PowerShell verbs list.
- To enforce approved verbs, combine with additional validation logic if needed.
#>
function Assert-VerbNounConvention {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$CommandName
    )

    process {
        if ($CommandName -notmatch '^([A-Za-z][A-Za-z0-9]*)-([A-Za-z][A-Za-z0-9]*)$') {
            throw [System.ArgumentException]::new(
                "Invalid command name '$CommandName'. Expected Verb-Noun format (e.g., 'Get-Item')."
            )
        }
    }

    end {
        return $true
    }
}
