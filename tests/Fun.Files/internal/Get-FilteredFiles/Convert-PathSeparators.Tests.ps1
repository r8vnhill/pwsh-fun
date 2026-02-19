#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for the Convert-PathSeparators function.

.DESCRIPTION
    This Pester test suite verifies that Convert-PathSeparators correctly transforms
    file and directory path separators between Windows (`\`) and Unix (`/`) styles,
    with additional options for UNC handling, collapsing duplicate separators,
    skipping URI or extended prefix paths, and applying only when mixed separators
    are present.

    It uses mocking to control the output of Get-PathSeparator so that tests can
    simulate different environments (Windows vs Unix targets) without depending on
    the current platform.
#>

Describe 'Convert-PathSeparators' -Tag 'unit', 'paths' {

    BeforeAll {
        Set-StrictMode -Version Latest

        # Load shared helpers, system under test (SUT), and dependency.
        . "$PSScriptRoot\..\_internal__Setup.ps1"
        . (New-InternalScriptLoader -Parts @(
                'Get-FilteredFiles', 'Convert-PathSeparators.ps1'))
        . (New-InternalScriptLoader -Parts @(
                'Get-FilteredFiles', 'Get-PathSeparator.ps1'))

        # Sanity checks to ensure required functions exist.
        Get-Command Convert-PathSeparators -CommandType Function -ErrorAction Stop | 
            Out-Null
        Get-Command Get-PathSeparator -CommandType Function -ErrorAction Stop | 
            Out-Null

        # Helpers to fix the target separator in tests without repeatedly mocking inline.
        function Use-WindowsTarget { Mock Get-PathSeparator { '\' } @args }
        function Use-UnixTarget { Mock Get-PathSeparator { '/' } @args }
    }

    AfterEach {
        # Ensure mocks are removed between tests.
        Remove-Item Alias:\Get-PathSeparator -ErrorAction Ignore
    }

    # ─────────────────────────────────────────────────────────────────────────────
    # Parameter validation and binding contract
    # ─────────────────────────────────────────────────────────────────────────────
    Context 'Parameter contract' {
        It 'Style has ValidateSet and CustomSeparator has ValidatePattern' {
            $cmd = Get-Command Convert-PathSeparators

            # Style should allow only specific values.
            ($cmd.Parameters['Style'].Attributes |
                Where-Object { 
                    $_ -is [System.Management.Automation.ValidateSetAttribute] 
                }).ValidValues |
                    Should -Be @('Platform', 'Windows', 'Unix')

            # CustomSeparator should only allow '\' or '/'.
            ($cmd.Parameters['CustomSeparator'].Attributes |
                Where-Object { 
                    $_ -is [System.Management.Automation.ValidatePatternAttribute] 
                }).RegexPattern |
                    Should -Be '^(\\|/)$'
        }

        It 'calls Get-PathSeparator with -Style Platform by default' {
            Mock Get-PathSeparator { '\' } -ParameterFilter { $Style -eq 'Platform' }
            Convert-PathSeparators -Path 'a/b' | Should -Be 'a\b'
            Assert-MockCalled Get-PathSeparator -Times 1 -ParameterFilter { 
                $Style -eq 'Platform' 
            }
        }

        It 'throws when CustomSeparator is invalid' {
            { Convert-PathSeparators -Path 'a/b' -CustomSeparator '-' } |
                Should -Throw -ErrorId 'ParameterArgumentValidationError*'
        }

        It 'Path enforces ValidateNotNullOrEmpty (null)' {
            Use-WindowsTarget
            { Convert-PathSeparators -Path $null } |
                Should -Throw -ErrorId 'ParameterArgumentValidationError*'
        }

        It 'Path enforces ValidateNotNullOrEmpty (empty string)' {
            Use-WindowsTarget
            { Convert-PathSeparators -Path '' } |
                Should -Throw -ErrorId 'ParameterArgumentValidationError*'
        }
    }

    # ─────────────────────────────────────────────────────────────────────────────
    # Style vs CustomSeparator precedence
    # ─────────────────────────────────────────────────────────────────────────────
    Context 'Style and CustomSeparator selection' {
        It 'uses -Style Windows when CustomSeparator is not provided' {
            Mock Get-PathSeparator { '\' } -ParameterFilter { $Style -eq 'Windows' }
            Convert-PathSeparators -Path 'a/b' -Style Windows | Should -Be 'a\b'
            Assert-MockCalled Get-PathSeparator -Times 1 -ParameterFilter {
                $Style -eq 'Windows'
            }
        }

        It 'uses -CustomSeparator over -Style when both supplied' {
            Mock Get-PathSeparator { '/' } -ParameterFilter { $CustomSeparator -eq '/' }
            Convert-PathSeparators -Path 'a\b' -Style Windows -CustomSeparator '/' |
                Should -Be 'a/b'
            Assert-MockCalled Get-PathSeparator -Times 1 -ParameterFilter {
                $CustomSeparator -eq '/'
            }
        }
    }

    # ─────────────────────────────────────────────────────────────────────────────
    # Core conversion logic
    # ─────────────────────────────────────────────────────────────────────────────
    Context 'Core conversion (table-driven)' {
        $cases = @(
            @{ Target = 'Windows'; MockOut = '\'; In = 'x/y'; Out = 'x\y' },
            @{ Target = 'Unix'; MockOut = '/'; In = 'x\y'; Out = 'x/y' },
            @{ Target = 'Windows'; MockOut = '\'; In = 'p//q'; Out = 'p\\q' }, # double slashes preserved
            @{ Target = 'Unix'; MockOut = '/'; In = 'p\\q'; Out = 'p//q' }  # double backslashes preserved
        )
        It 'converts separators to <Target>' -TestCases $cases {
            param($Target, $MockOut, $In, $Out)
            Mock Get-PathSeparator { $MockOut }
            Convert-PathSeparators -Path $In | Should -Be $Out
        }

        It 'handles arrays and preserves order (Windows)' {
            Use-WindowsTarget
            Convert-PathSeparators -Path @('a/b', 'x/y/z') |
                Should -Be @('a\b', 'x\y\z')
        }

        It 'binds from pipeline via -FullName alias' {
            Use-WindowsTarget
            $items = @(
                [PSCustomObject]@{ FullName = 'one/two' },
                [PSCustomObject]@{ FullName = 'three/four' }
            )
            ($items | Convert-PathSeparators) |
                Should -Be @('one\two', 'three\four')
        }
    }

    # ─────────────────────────────────────────────────────────────────────────────
    # UNC handling and duplicate collapsing
    # ─────────────────────────────────────────────────────────────────────────────
    Context 'PreserveUncLeading & CollapseDuplicates' {
        BeforeEach { Use-WindowsTarget }

        It 'preserves up to two leading separators for UNC-like inputs' {
            Convert-PathSeparators -Path '//server/share/a/b' -PreserveUncLeading |
                Should -Be '\\server\share\a\b'
            Convert-PathSeparators -Path '////server/share' -PreserveUncLeading |
                Should -Be '\\server\share'
        }

        It 'without -PreserveUncLeading converts leading separators normally' {
            Convert-PathSeparators -Path '//server/share' |
                Should -Be '\\server\share'
        }

        It 'does not collapse preserved UNC leading separators' {
            Convert-PathSeparators -Path '//srv///share//a' -PreserveUncLeading `
                -CollapseDuplicates |
                Should -Be '\\srv\share\a'
        }

        It 'collapses duplicate target separators in the body when on' {
            Convert-PathSeparators -Path 'a//b///c' -CollapseDuplicates |
                Should -Be 'a\b\c'
        }

        It 'does not collapse when off' {
            Convert-PathSeparators -Path 'a//b///c' |
                Should -Be 'a\\b\\\c'
        }
    }

    # ─────────────────────────────────────────────────────────────────────────────
    # URI and extended prefix skip flags
    # ─────────────────────────────────────────────────────────────────────────────
    Context 'SkipExtendedPrefix and SkipUri (Windows target)' {
        BeforeEach { Use-WindowsTarget }

        It 'skips extended prefix paths when SkipExtendedPrefix is $true (default)' {
            Convert-PathSeparators -Path '\\?\C:\Foo/Bar' |
                Should -Be '\\?\C:\Foo/Bar'
        }

        It 'converts extended prefix paths when SkipExtendedPrefix is $false' {
            Convert-PathSeparators -Path '\\?\C:\Foo/Bar' -SkipExtendedPrefix:$false |
                Should -Be '\\?\C:\Foo\Bar'
        }

        It 'skips URI-like strings when SkipUri is $true (default)' {
            Convert-PathSeparators -Path 'http://example.com/a/b' |
                Should -Be 'http://example.com/a/b'
        }

        It 'converts URI-like strings when SkipUri is $false' {
            Convert-PathSeparators -Path 'http://example.com/a/b' -SkipUri:$false |
                Should -Be 'http:\\example.com\a\b'
        }
    }

    Context 'SkipExtendedPrefix and SkipUri (Unix target)' {
        BeforeEach { Use-UnixTarget }

        It 'skips extended prefix paths when SkipExtendedPrefix is $true' {
            Convert-PathSeparators -Path '\\?\C:\Foo\Bar' |
                Should -Be '\\?\C:\Foo\Bar'
        }

        It 'converts extended prefix paths when SkipExtendedPrefix is $false' {
            Convert-PathSeparators -Path '\\?\C:\Foo\Bar' -SkipExtendedPrefix:$false |
                Should -Be '//?/C:/Foo/Bar'
        }

        It 'skips URI-like strings when SkipUri is $true' {
            Convert-PathSeparators -Path 'https://x/y/z' |
                Should -Be 'https://x/y/z'
        }

        It 'converts URI-like strings when SkipUri is $false' {
            Convert-PathSeparators -Path 'https://x/y' -SkipUri:$false |
                Should -Be 'https://x/y'
        }
    }

    # ─────────────────────────────────────────────────────────────────────────────
    # OnlyIfMixed behavior
    # ─────────────────────────────────────────────────────────────────────────────
    Context 'OnlyIfMixed' {
        It 'converts only when the path contains the other separator (Windows target)' {
            Use-WindowsTarget
            Convert-PathSeparators -Path 'a/b' -OnlyIfMixed | Should -Be 'a\b'
            Convert-PathSeparators -Path 'a\b' -OnlyIfMixed | Should -Be 'a\b'
        }

        It 'works with Unix target too' {
            Use-UnixTarget
            Convert-PathSeparators -Path 'a\b' -OnlyIfMixed | Should -Be 'a/b'
            Convert-PathSeparators -Path 'a/b' -OnlyIfMixed | Should -Be 'a/b'
        }

        It 'does not change when path has only target separator (negative)' {
            Use-WindowsTarget
            Convert-PathSeparators -Path 'a\b\c' -OnlyIfMixed |
                Should -Be 'a\b\c'
        }
    }

    # ─────────────────────────────────────────────────────────────────────────────
    # Custom separator end-to-end
    # ─────────────────────────────────────────────────────────────────────────────
    Context 'Custom separator and return types' {
        It 'uses a custom slash when provided' {
            Mock Get-PathSeparator { '/' } -ParameterFilter { $CustomSeparator -eq '/' }
            Convert-PathSeparators -Path 'a\b' -CustomSeparator '/' |
                Should -Be 'a/b'
        }

        It 'emits strings only' {
            Use-WindowsTarget
            $out = Convert-PathSeparators -Path @('a/b', 'c/d')
            foreach ($o in $out) {
                $o.GetType().FullName | Should -Be 'System.String'
            }
        }
    }
}
