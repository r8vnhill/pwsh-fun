@{
    RootModule           = 'Fun.OCD.psm1'
    ModuleVersion        = '0.3.0'
    CompatiblePSEditions = @('Core', 'Desktop')
    GUID                 = 'b4b98180-9095-448d-aeba-73233ba84e60'
    Author               = 'Ignacio Slater-Muñoz'
    CompanyName          = 'None'
    Copyright            = '(c) Ignacio Slater-Muñoz. All rights reserved.'
    Description          = 'Tools to please my OCD.'

    FunctionsToExport    = @(
        'Rename-StandardMedia',
        'Convert-AudioToMp3',
        'Install-SSHKey',
        'Remove-DirectoryContents',
        'Move-AndLinkItem'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @('doctor', 'empty')

    PrivateData          = @{
        PSData = @{
            Tags       = @(
                'powershell',
                'media',
                'rename',
                'audio',
                'video',
                'cleanup',
                'ffmpeg',
                'ssh',
                'symlink',
                'link',
                'directory',
                'contents',
                'recyclebin'
            )
            LicenseUri = 'https://opensource.org/license/bsd-2-clause'
            ProjectUri = 'https://github.com/r8vnhill/pwsh-fun'
        }
    }
}
