#Requires -Version 7.0
Set-StrictMode -Version Latest
Import-Module Pester -ErrorAction Stop

<#
.SYNOPSIS
    Discovery tests for Get-FunModuleFiles with a temp "modules" sandbox.

.DESCRIPTION
    - We dot-source the implementation so classes/functions are available at runtime.
    - IMPORTANT: Do NOT use bare type literals like [FunModuleRef] in assertions,
      because Pester parses tests before BeforeAll runs. Resolve the type at runtime
      with: ('FunModuleRef' -as [type]).
#>

BeforeAll {
    # Load test harness helpers (e.g., Resolve-FunLoaderPath) and any environment setup.
    . "$PSScriptRoot\Setup.ps1"

    # Dot-source the script under test; this defines classes and functions into the session.
    . "$(Resolve-FunLoaderPath)\public\Install-FunModules.ps1"

    # Build a temporary repo-like sandbox with modules/Alpha, modules/Beta, etc.
    $sandboxRoot = Join-Path ([IO.Path]::GetTempPath()) ('pwsh-fun_' + [guid]::NewGuid())
    . "$PSScriptRoot/../internal/New-TestSandbox.ps1" -Root $sandboxRoot |
        Set-Variable SB -Scope Script

    # ⚠️ Resolve types at runtime (post dot-sourcing).
    # Using bare [FunModuleRef] inside tests would be parsed too early and fail.
    $script:FunModuleRefType = ('FunModuleRef' -as [type])
    $script:ModuleKindType = ('ModuleKind' -as [type])

    # Sanity: make sure the types actually loaded
    if (-not $FunModuleRefType) { throw 'FunModuleRef type not loaded.' }
    if (-not $ModuleKindType) { throw 'ModuleKind enum not loaded.' }
}

AfterAll {
    if (Test-Path -LiteralPath $SB.Root) {
        Remove-Item -LiteralPath $SB.Root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Get-FunModuleFiles' {
    It 'returns FunModuleRef objects' {
        $refs = Get-FunModuleFiles -BasePath $SB.Root
        $refs | Should -Not -BeNullOrEmpty

        # Use the resolved type object instead of a parse-time literal
        $refs | ForEach-Object { $_ | Should -BeOfType $FunModuleRefType }
    }

    It 'prefers .psd1 over .psm1 when both exist' {
        # Alpha has psd1; Beta has only psm1
        $refs = Get-FunModuleFiles -BasePath $SB.Root | Sort-Object Name

        # Access the enum via its resolved type to avoid parse-time lookup.
        $Manifest = [enum]::Parse($ModuleKindType, 'Manifest')
        $Script = [enum]::Parse($ModuleKindType, 'Script')

        ($refs | Where-Object Name -EQ 'Alpha').Kind | Should -Be $Manifest
        ($refs | Where-Object Name -EQ 'Beta').Kind | Should -Be $Script
    }

    It 'skips folders with no matching files and respects Exclude' {
        $names = (Get-FunModuleFiles -BasePath $SB.Root).Name
        $names | Should -Contain 'Alpha'
        $names | Should -Contain 'Beta'
        $names | Should -Not -Contain 'Delta'         # no files
        $names | Should -Not -Contain 'Fun.OCD.Tools' # excluded by default pattern
    }

    It 'returns empty when modules folder missing' {
        $emptyRoot = Join-Path $SB.Root 'nope'
        (Get-FunModuleFiles -BasePath $emptyRoot) | Should -BeNullOrEmpty
    }

    It 'TryFromDir chooses correct kind' {
        $alphaDir = Get-Item -LiteralPath $SB.Alpha
        $betaDir = Get-Item -LiteralPath $SB.Beta

        $Manifest = [enum]::Parse($ModuleKindType, 'Manifest')
        $Script = [enum]::Parse($ModuleKindType, 'Script')

        ([FunModuleRef]::TryFromDir($alphaDir)).Kind | Should -Be $Manifest
        ([FunModuleRef]::TryFromDir($betaDir)).Kind | Should -Be $Script
    }
}
