#Requires -Version 7.0
Set-StrictMode -Version Latest
Import-Module Pester -ErrorAction Stop

BeforeAll {
    . "$PSScriptRoot/../../path/to/your/code/under/test.ps1"
    $sandboxRoot = Join-Path ([IO.Path]::GetTempPath()) ('pwsh-fun_' + [guid]::NewGuid())
    . "$PSScriptRoot/../_helpers/New-TestSandbox.ps1" -Root $sandboxRoot | Set-Variable SB -Scope Script
}

AfterAll {
    if (Test-Path -LiteralPath $SB.Root) { Remove-Item -LiteralPath $SB.Root -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Get-FunModuleFiles' {
    It 'returns FunModuleRef objects' {
        $refs = Get-FunModuleFiles -BasePath $SB.Root
        $refs | Should -Not -BeNullOrEmpty
        $refs | ForEach-Object { $_ | Should -BeOfType FunModuleRef }
    }

    It 'prefers .psd1 over .psm1 when both exist' {
        # Alpha has psd1; Beta has only psm1
        $refs = Get-FunModuleFiles -BasePath $SB.Root | Sort-Object Name
        ($refs | Where-Object Name -EQ 'Alpha').Kind | Should -Be ([ModuleKind]::Manifest)
        ($refs | Where-Object Name -EQ 'Beta').Kind | Should -Be ([ModuleKind]::Script)
    }

    It 'skips folders with no matching files and respects Exclude' {
        $names = (Get-FunModuleFiles -BasePath $SB.Root).Name
        $names | Should -Contain 'Alpha'
        $names | Should -Contain 'Beta'
        $names | Should -Not -Contain 'Delta'      # no files
        $names | Should -Not -Contain 'Fun.OCD.Tools' # excluded by default pattern
    }

    It 'returns empty when modules folder missing' {
        $emptyRoot = Join-Path $SB.Root 'nope'
        (Get-FunModuleFiles -BasePath $emptyRoot) | Should -BeNullOrEmpty
    }

    It 'TryFromDir chooses correct kind' {
        $alphaDir = Get-Item -LiteralPath $SB.Alpha
        $betaDir = Get-Item -LiteralPath $SB.Beta
        ([FunModuleRef]::TryFromDir($alphaDir)).Kind | Should -Be ([ModuleKind]::Manifest)
        ([FunModuleRef]::TryFromDir($betaDir)).Kind | Should -Be ([ModuleKind]::Script)
    }
}
