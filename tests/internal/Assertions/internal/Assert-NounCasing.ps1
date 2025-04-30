<#
.SYNOPSIS
Validates that a command noun starts with an uppercase letter.

.DESCRIPTION
`Assert-NounCasing` checks whether the provided noun segment of a command name starts with an uppercase letter, following PowerShell naming conventions.
It optionally allows subsequent characters to be uppercase, lowercase, or digits.

If the noun does not conform to this casing rule, a `[System.ArgumentException]` is thrown.

This validation is useful for enforcing consistent and idiomatic naming in scripts, modules, and libraries.

.PARAMETER Noun
The noun part of the command to validate.
Must be a non-empty string and can be provided via parameter or pipeline input.

.PARAMETER CommandName
The full name of the command (Verb-Noun) used to construct meaningful error messages.

.OUTPUTS
[bool] Returns `$true` if the noun casing is valid.

.EXAMPLE
PS> Assert-NounCasing -Noun 'Item' -CommandName 'Get-Item'

Validates successfully because 'Item' starts with an uppercase letter.

.EXAMPLE
PS> 'FileSystem' | Assert-NounCasing -CommandName 'Get-FileSystem'

Validates successfully when piped input is provided.

.EXAMPLE
PS> Assert-NounCasing -Noun 'filesystem' -CommandName 'Get-filesystem'

Throws an error because 'filesystem' does not start with an uppercase letter.

.NOTES
- This function only validates casing. It does not validate full naming format (Verb-Noun).
- Combine with `Assert-VerbNounConvention` and `Assert-VerbCasing` for stricter validation.
#>
function Assert-NounCasing {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$Noun,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$CommandName
    )
    
    if (-not ($Noun -cmatch '^[A-Z][a-zA-Z0-9]*$')) {
        $errorMessage = @(
            "Invalid Noun casing in '$CommandName'.", 
            'Noun should start with an uppercase letter.'
        ) -join ' '
        throw [System.ArgumentException]::new(
            $errorMessage
        )
    }

    return $true
}
