<#
.SYNOPSIS
Validates the casing of the verb part of a PowerShell command name.

.DESCRIPTION
`Assert-VerbCasing` checks whether the provided verb follows standard PowerShell naming conventions:
it must start with an uppercase letter and be followed by lowercase letters or digits.

This validation helps enforce consistent and idiomatic naming across modules, scripts, and libraries.

.PARAMETER Verb
The verb part of a command name (the string before the dash `-`).
Must be a non-empty string.

.PARAMETER CommandName
The full name of the command (e.g., 'Get-Item').
Used only for clearer error reporting.

.OUTPUTS
[bool] Returns `$true` if the verb casing is valid.

.EXAMPLE
PS> Assert-VerbCasing -Verb 'Get' -CommandName 'Get-Item'

Passes successfully because the verb casing is valid.

.EXAMPLE
PS> Assert-VerbCasing -Verb 'get' -CommandName 'get-Item'

Throws an error because the verb starts with a lowercase letter instead of uppercase.

.NOTES
- This function only checks the casing of the verb, not whether the verb is approved.
- Combine it with approved verb validation for stricter enforcement.
#>
function Assert-VerbCasing {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Verb,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$CommandName
    )

    if (-not ($Verb -cmatch '^[A-Z][a-z0-9]*$')) {
        $errorMessage = @(
            "Invalid Verb casing in command '$CommandName'.",
            "Verb '$Verb' should start with an uppercase letter followed by lowercase",
            "letters or digits."
        ) -join ' '
        throw [System.ArgumentException]::new($errorMessage)
    }
}
