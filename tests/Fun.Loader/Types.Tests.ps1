#Requires -Version 7.0
Set-StrictMode -Version Latest
Import-Module Pester -ErrorAction Stop

<#
.SYNOPSIS
    Unit tests for core types used by the loader (ModuleKind, FunModuleRef, FunModuleImportResult).

.DESCRIPTION
    - Verifies the enum and classes load and behave as expected.
    - Keeps tests fast and hermetic (no real module imports here).
    - Uses Pester v5 idioms: BeforeAll for one-time setup; Describe/Context/It for structure.

.NOTES
    These tests assume the code-under-test (types + functions) is made available by `Setup.ps1`
    and that the path resolver (`Resolve-FunLoaderPath`) points at the module that contains
    `Install-FunModules.ps1` (so dependent files are dot-sourced in a realistic way).
#>

BeforeAll {
    # Load test harness helpers (e.g., Resolve-FunLoaderPath) and any environment setup.
    . "$PSScriptRoot\Setup.ps1"

    # Dot-source just the script that defines Install-FunModules.
    # Using dot-sourcing keeps definitions in the test session scope, making types visible to assertions.
    . "$(Resolve-FunLoaderPath)\public\Install-FunModules.ps1"
}

Describe 'Types' {
    # --- Enum existence check -------------------------------------------------
    It 'ModuleKind enum exists' {
        # The editor may parse files independently, but at runtime the enum must be loaded.
        # Casting the name to [type] returns $null if not found.
        ('ModuleKind' -as [type]) | Should -Not -BeNullOrEmpty
    }

    # --- FunModuleRef ---------------------------------------------------------
    Context 'FunModuleRef' {
        It 'throws on empty name' {
            # Constructor guard should reject empty/whitespace names with a clear message.
            { [FunModuleRef]::new('', 'C:\a.psd1', [ModuleKind]::Manifest) } |
                Should -Throw '*Name is required*'
        }

        It 'throws on empty path' {
            # Constructor guard should reject empty/whitespace paths with a clear message.
            { [FunModuleRef]::new('Alpha', '', [ModuleKind]::Manifest) } |
                Should -Throw '*Path is required*'
        }

        It 'ToString contains name, kind, and path' {
            # ToString() is used for logs/debugging; ensure it includes key fields.
            $ref = [FunModuleRef]::new('Alpha', 'C:\Mods\Alpha\Alpha.psd1', [ModuleKind]::Manifest)
            $ref.ToString() | Should -Match 'Alpha'
            $ref.ToString() | Should -Match 'Manifest'
            $ref.ToString() | Should -Match 'Alpha.psd1'
        }

        It 'MatchesAny respects wildcards' {
            # Hidden helper used to filter names by wildcard patterns.
            [FunModuleRef]::MatchesAny('Fun.OCD.Tools', @('*Fun.OCD*')) | Should -BeTrue
            [FunModuleRef]::MatchesAny('Beta', @('*Fun.OCD*')) | Should -BeFalse
        }
    }

    # --- FunModuleImportResult -----------------------------------------------
    Context 'FunModuleImportResult' {
        It 'formats ToString reasonably' {
            # ToString should surface Name and Status at minimum; Version may be blank in failures.
            $r = [FunModuleImportResult]::new(
                'Alpha',
                [version]'1.2.3',
                [ModuleKind]::Manifest,
                'C:\x',
                'Imported',
                'OK'
            )
            $r.ToString() | Should -Match 'Alpha'
            $r.ToString() | Should -Match 'Imported'
        }
    }
}
