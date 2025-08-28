@{
    # Root module file that contains the Export-ModuleMember declarations
    RootModule        = '.\Fun.Ffmpeg.psm1'

    # Semantic version of the module
    ModuleVersion     = '0.3.0'

    # Unique module identifier
    GUID              = '2bb223bb-b9c8-495f-bd7a-028b1b4c9177'

    # Author and copyright metadata
    Author            = 'Ignacio Slater-Muñoz'
    CompanyName       = 'Ignacio Slater-Muñoz'
    Copyright         = '(c) Ignacio Slater-Muñoz. All rights reserved.'

    # Explicit list of exported functions
    FunctionsToExport = @()

    # No cmdlets, variables, or aliases are exported
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # Optional metadata, useful for future gallery publishing
    PrivateData       = @{
        PSData = @{
            Tags         = @()
            LicenseUri   = 'https://opensource.org/license/bsd-2-clause'
            ProjectUri   = 'https://gitlab\.com/r8vnhill/pwsh-fun'
            IconUri      = ''
            ReleaseNotes = ''
        }
    }
}
