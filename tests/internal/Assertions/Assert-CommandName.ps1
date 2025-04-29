. "$PSScriptRoot\internal\Assert-VerbNounConvention.ps1"

function Assert-CommandName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$CommandName
    )

    process {
        Assert-VerbNounConvention -CommandName $CommandName -ErrorAction Stop

        $verb, $noun = $CommandName.Split('-', 2)

        # Validate casing for Verb
        if (-not ($verb -cmatch '^[A-Z][a-z0-9]*$')) {
            throw [System.ArgumentException]::new(
                "Invalid Verb casing in '$CommandName'. Verb should start with an uppercase letter."
            )
        }

        # Validate casing for Noun
        if (-not ($noun -cmatch '^[A-Z][a-z0-9]*$')) {
            throw [System.ArgumentException]::new(
                "Invalid Noun casing in '$CommandName'. Noun should start with an uppercase letter."
            )
        }

        # Validate that Verb is from approved verbs
        $approvedVerbs = (Get-Verb).Verb

        if ($approvedVerbs -notcontains $verb) {
            throw [System.ArgumentException]::new(
                "Verb '$verb' in '$CommandName' is not an approved PowerShell verb. Use standard verbs (e.g., 'Get', 'Set', 'New')."
            )
        }
    }

    end {
        return $true
    }
}
