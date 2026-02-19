#Requires -Version 7.0
Set-StrictMode -Version Latest
Import-Module Pester -ErrorAction Stop

<#
.SYNOPSIS
  Pester tests for Install-FunModules.

.DESCRIPTION
  - Dot-sources implementation so classes/functions exist in-session.
  - Resolves types at runtime (avoid parse-time "type not found").
  - Tests pipeline input, -WhatIf honoring, self-discovery, and error path.
  - Uses mocks; no real Import-Module IO.
#>

BeforeAll {
    . "$PSScriptRoot\Setup.ps1"
    . "$(Resolve-FunLoaderPath)\public\Install-FunModules.ps1"

    # Sample module refs for pipeline scenarios
    $alpha = [FunModuleRef]::new(
        'Alpha', 'C:\Mods\Alpha\Alpha.psd1', [ModuleKind]::Manifest)
    $beta = [FunModuleRef]::new('Beta', 'C:\Mods\Beta\Beta.psm1', [ModuleKind]::Script)
    Set-Variable -Name Alpha -Scope Script -Value $alpha
    Set-Variable -Name Beta  -Scope Script -Value $beta

    # Resolve result type at runtime so Pester doesn’t try to parse it early
    $script:FunModuleImportResultType = ('FunModuleImportResult' -as [type])
    if (-not $FunModuleImportResultType) { 
        throw 'FunModuleImportResult type not loaded.' 
    }
}

Describe 'Install-FunModules (pipeline input)' {
    BeforeEach {
        # Intercept Import-Module; simulate a module object with Version
        Mock -CommandName Import-Module -Verifiable -MockWith {
            [pscustomobject]@{ Version = [version]'1.0.0' }
        }
    }

    It 'imports each module and returns results' {
        $res = @($Alpha, $Beta) | Install-FunModules -Scope Local -Confirm:$false

        Assert-MockCalled Import-Module -Times 2 -Exactly

        # Robust per-item type assertion (no pipeline binding to Should)
        foreach ($r in $res) {
            ($r -is $FunModuleImportResultType) | Should -BeTrue
        }

        ($res | Where-Object Name -EQ 'Alpha').Status | Should -Be 'Imported'
    }

    It 'honors -WhatIf (no Import-Module calls)' {
        @($Alpha, $Beta) | Install-FunModules -WhatIf -Confirm:$false | Out-Null
        Assert-MockCalled Import-Module -Times 0 -Exactly
    }
}

Describe 'Install-FunModules (self-discovery + error path)' {
    BeforeEach {
        # Mock discovery to yield one good and one failing module
        Mock -CommandName Get-FunModuleFiles -Verifiable -MockWith {
            @(
                [FunModuleRef]::new(
                    'Good', 'C:\Mods\Good\Good.psd1', [ModuleKind]::Manifest),
                [FunModuleRef]::new('Bad', 'C:\Mods\Bad\Bad.psm1', [ModuleKind]::Script)
            )
        }

        # IMPORTANT: match the real parameter name (-Name)
        Mock -CommandName Import-Module -Verifiable -MockWith {
            param([string]$Name)
            if ($Name -like '*Bad.psm1') { throw 'boom' }
            [pscustomobject]@{ Version = [version]'2.3.4' }
        }
    }

    It 'returns Imported and Failed statuses accordingly' {
        $res = Install-FunModules -Scope Local -Confirm:$false

        Assert-MockCalled Get-FunModuleFiles -Times 1 -Exactly
        Assert-MockCalled Import-Module     -Times 2

        # Type+status assertions
        foreach ($r in $res) {
            ($r -is $FunModuleImportResultType) | Should -BeTrue
        }
        ($res | Where-Object Name -EQ 'Good').Status | Should -Be 'Imported'
        ($res | Where-Object Name -EQ 'Bad').Status | Should -Be 'Failed'
        ($res | Where-Object Name -EQ 'Good').Version | Should -Be ([version]'2.3.4')
    }
}
