# modules\Fun.Loader\Fun.Loader.psd1
@{
    # Script module associated with this manifest
    RootModule           = 'Fun.Loader.psm1'

    # Semantic versioning recommended
    ModuleVersion        = '0.3.0'

    # PowerShell Core compatible (PS7+)
    CompatiblePSEditions = @('Core')

    # Unique module ID
    GUID                 = '78c3070f-a04f-4d0f-902d-f02948227cad'

    # Module author
    Author               = 'Ignacio Slater-Muñoz'

    # Optional: Displayed on gallery listings or metadata
    CompanyName          = 'Ignacio Slater-Muñoz'

    # Copyright notice
    Copyright            = '(c) Ignacio Slater-Muñoz. All rights reserved.'

    # Description shown in `Get-Module` and on the gallery
    Description          = 'Utility functions to load and unload all pwsh-fun modules at once.'

    # Minimum version of PowerShell required (recommended for PS7+)
    PowerShellVersion    = '7.0'

    # Export only public functions (explicit names preferred for performance)
    FunctionsToExport    = @('Install-FunModules', 'Remove-FunModules')

    # No cmdlets, variables, or aliases are explicitly exported
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData          = @{
        PSData = @{
            # Tags for discovery (e.g., when published on PowerShell Gallery)
            Tags         = @('powershell', 'modules', 'loader', 'fun', 'utilities')

            # Optional metadata if published online
            LicenseUri   = 'https://opensource.org/license/bsd-2-clause'
            ProjectUri   = 'https://gitlab\.com/r8vnhill/pwsh-fun'
            # IconUri      = '...'
            ReleaseNotes = 'Initial version with basic loader functions.'
        }
    }

    # Optional help info
    HelpInfoURI          = 'https://gitlab\.com/r8vnhill/pwsh-fun/blob/main/modules/Fun.Loader/README.md'

    # Optional command prefix to avoid naming collisions
    # DefaultCommandPrefix = 'Fun'
}
