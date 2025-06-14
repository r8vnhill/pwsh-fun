@{
    RootModule        = '.\tests\internal\Assertions\Assertions.psm1'
    ModuleVersion = '0.3.0'
    CompatiblePSEditions = @('Core', 'Desktop')
    GUID              = '6e6ce1fd-bf3a-4021-a367-4a60990acfe2'
    Author            = 'Ignacio Slater-Muñoz'
    CompanyName       = 'Ignacio Slater-Muñoz'
    Copyright         = '(c) Ignacio Slater-Muñoz. All rights reserved.'
    Description       = 'Assertions and validation utilities for PowerShell test suites.'
    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Assert-CommandName',
        'Assert-ModuleManifestPaths',
        'Assert-PathExists',
        'Assert-ThrowsWithType'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags = @('Testing', 'Assertions', 'Validation', 'PowerShell')
        }
    }
}
