. "$PSScriptRoot\Assert-ModuleCommandsPresent.ps1"

function Initialize-TestSuite {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Module,

        [Parameter(Mandatory)]
        [ValidateScript({ $_ | Assert-CommandName -ErrorAction Stop })]
        [string[]]$RequiredCommands,

        [ValidateScript({ $_ | Assert-ModuleManifestPath -ErrorAction Stop })]
        [string[]]$AdditionalImports = @(),

        [ValidateScript({ Assert-PathExists -Path $_ -ErrorAction Stop })]
        [ValidateNotNullOrEmpty()]
        [string]$Root = (Join-Path -Path $PSScriptRoot -ChildPath '..\..\..' -Resolve),

        [switch]$ForceImport,

        [switch]$VerboseOnSuccess
    )

    $modulePath = Join-Path -Path $Root -ChildPath "modules\$Module\$Module.psd1"
    
    $AdditionalImports | Import-Module -Force:$ForceImport

    Import-Module -Name $modulePath -Force:$ForceImport -ErrorAction Stop -Global

    Assert-ModuleCommandsPresent -Module $Module `
        -RequiredCommands $RequiredCommands `
        -VerboseOnSuccess:$VerboseOnSuccess
}
