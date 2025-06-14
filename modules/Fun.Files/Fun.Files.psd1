@{
    # Root module file that contains the Export-ModuleMember declarations
    RootModule        = '.\modules\Fun.Files\Fun.Files.psm1'

    # Semantic version of the module
    ModuleVersion = '0.3.0'

    # Unique module identifier
    GUID              = '06a00c57-8a2e-46ef-88f9-4cc0d9feba96'

    # Author and copyright metadata
    Author            = 'Ignacio Slater-Muñoz'
    CompanyName       = 'Ignacio Slater-Muñoz'
    Copyright         = '(c) Ignacio Slater-Muñoz. All rights reserved.'

    # Explicit list of exported functions
    FunctionsToExport = @(
        'Show-FileContents',
        'Get-FileContents',
        'Copy-FileContents',
        'Invoke-FileTransform',
        'Compress-FilteredFiles',
        'New-AndEnterDirectory'
    )

    # No cmdlets, variables, or aliases are exported
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @(
        'mdcd'  # Alias for New-AndEnterDirectory
    )

    # Optional metadata, useful for future gallery publishing
    PrivateData       = @{
        PSData = @{
            Tags         = @('files', 'content', 'clipboard', 'transform', 'utilities')
            LicenseUri   = 'https://opensource.org/license/bsd-2-clause'
            ProjectUri   = 'https://github.com/r8vnhill/pwsh-fun'
            IconUri      = ''
            ReleaseNotes = 'Initial development version with content viewing, transformation, and clipboard integration.'
        }
    }
}
