<#
.SYNOPSIS
Validates that a verb is part of the approved PowerShell verb list.

.DESCRIPTION
`Assert-ApprovedVerb` checks whether a given verb is included in the list of standard PowerShell verbs returned by `Get-Verb`.

This helps ensure that command names follow PowerShell best practices, improving discoverability and consistency across modules.

.PARAMETER Verb
The verb to validate.
Must be a non-empty string.
Accepts pipeline input.

.PARAMETER CommandName
The full command name (e.g., `Get-Item`) for contextual error messages.
Used only to enhance error output.

.OUTPUTS
[bool]  
Returns `$true` if the verb is approved.

.EXAMPLE
'Get' | Assert-ApprovedVerb -CommandName 'Get-Item'

Validates that 'Get' is an approved verb.

.EXAMPLE
Assert-ApprovedVerb -Verb 'Make' -CommandName 'Make-Widget'

Throws an error because 'Make' is not an approved PowerShell verb.

.NOTES
Approved verbs are defined by the `Get-Verb` cmdlet and maintained by PowerShell to standardize command naming.
#>
function Assert-ApprovedVerb {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Verb,

        [Parameter(Mandatory)]
        [string]$CommandName
    )
    begin {
        $approvedVerbs = (Get-Verb).Verb
    }
    process {
        if ($approvedVerbs -notcontains $Verb) {
            $errorMessage = @(
                "Verb '$Verb' in '$CommandName' is not an approved PowerShell verb.",
                "Use standard verbs (e.g., 'Get', 'Set', 'New')."
            ) -join ' '
            throw [System.ArgumentException]::new($errorMessage)
        }
    }
    end {
        return $true
    }
}
