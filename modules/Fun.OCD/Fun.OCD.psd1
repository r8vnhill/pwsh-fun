@{
    RootModule        = 'Fun.OCD.psm1'
    ModuleVersion     = '0.0.1'
    CompatiblePSEditions = @('Core', 'Desktop')
    GUID              = 'b4b98180-9095-448d-aeba-73233ba84e60'
    Author            = 'Ignacio Slater-Muñoz'
    CompanyName       = 'None'
    Copyright         = '(c) Ignacio Slater-Muñoz. All rights reserved.'
    Description       = 'Tools to please my OCD.'

    FunctionsToExport = @('Rename-StandardMedia')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @('doctor')

    PrivateData = @{
        PSData = @{
            Tags        = @('powershell', 'media', 'rename')
            LicenseUri   = 'https://opensource.org/license/bsd-2-clause'
            ProjectUri   = 'https://github.com/r8vnhill/pwsh-fun'
        }
    }
}
