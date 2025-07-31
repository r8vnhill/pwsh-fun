#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Pester v5 tests for the internal function Get-PathSeparator.

.DESCRIPTION
    These tests intentionally dot-source an *internal* function (not exported by any
    module).
    The suite:
      - Establishes platform-aware constants and exposes them via $script: scope for
        analyzer-friendliness.
      - Validates behavior across parameter sets (Style vs Custom).
      - Asserts cross-platform semantics and return types.
      - Guards the public contract via reflection tests
        (ValidateSet/ValidatePattern/DefaultParameterSet).
      - Avoids output noise and brittle pathing by resolving a robust path to the internal
        script.

.NOTES
    - Predeclaring $script:-scoped variables avoids strict-mode errors ("variable has not
      been set").
    - Using $script: scope makes usage visible outside of individual It blocks to
      PSScriptAnalyzer.
    - We keep path handling cross-platform and avoid backticks for line continuation.
#>

# --- Predeclare $script: constants so strict mode never throws on first read ---
# Defaults, overwritten in BeforeAll after runspace init.
$script:WindowsSep = '\'
$script:UnixSep = '/'
$script:PlatformSepString = [string][System.IO.Path]::DirectorySeparatorChar

Describe 'Get-PathSeparator' -Tag 'unit', 'cross-platform' {

    BeforeAll {
        . "$PSScriptRoot\..\_internal__Setup.ps1"

        . (New-InternalScriptLoader -Parts @(
                'Get-FilteredFiles',
                'Get-PathSeparator.ps1'))
        Get-Command Get-PathSeparator -CommandType Function -ErrorAction Stop | Out-Null

        $script:PlatformSepString = [string][IO.Path]::DirectorySeparatorChar
        $script:WindowsSep = '\'
        $script:UnixSep = '/'
        $script:StyleCases = @(
            @{ Style = 'Platform'; Expect = $script:PlatformSepString },
            @{ Style = 'Windows' ; Expect = $script:WindowsSep },
            @{ Style = 'Unix'    ; Expect = $script:UnixSep }
        )
    }

    Context 'Parameter set: Style (default)' {
        <#
         These tests cover the default parameter set (Style), verifying:
           - Returned value matches expected separator per style.
           - Return type and length are correct (string of length 1).
           - -AsChar returns a [char] with the same visual value.
        #>

        It 'returns <Expect> when -Style <Style> [string]' -TestCases $script:StyleCases {
            param($Style, $Expect)

            # For Platform we rely on the default; for others we pass -Style explicitly
            $result = if ($Style -eq 'Platform') {
                Get-PathSeparator
            } else {
                Get-PathSeparator -Style $Style
            }

            $result | Should -BeOfType 'System.String'
            $result.Length | Should -Be 1
            $result | Should -Be $Expect
        }

        It 'returns a [char] for -AsChar with styles' -TestCases $script:StyleCases {
            param($Style, $Expect)

            $result = if ($Style -eq 'Platform') {
                Get-PathSeparator -AsChar
            } else {
                Get-PathSeparator -Style $Style -AsChar
            }

            $result | Should -BeOfType 'System.Char'
            [string]$result | Should -Be $Expect
        }
    }

    Context 'Parameter set: Custom' {
        <#
         These tests cover the "Custom" parameter set, ensuring:
           - The custom separator is returned verbatim (string).
           - -AsChar returns a [char] with the same value.
           - This also indirectly tests ValidatePattern correctness for accepted values.
        #>

        It 'returns "\" when -CustomSeparator "\" [string]' {
            Get-PathSeparator -CustomSeparator $script:WindowsSep | `
                    Should -Be $script:WindowsSep
        }

        It 'returns "/" when -CustomSeparator "/" [string]' {
            Get-PathSeparator -CustomSeparator $script:UnixSep | `
                    Should -Be $script:UnixSep
        }

        It 'returns [char] when -CustomSeparator with -AsChar' {
            $r = Get-PathSeparator -CustomSeparator $script:WindowsSep -AsChar
            $r | Should -BeOfType 'System.Char'
            [string]$r | Should -Be $script:WindowsSep
        }
    }

    Context 'Validation & errors' {
        <#
         These tests intentionally trigger parameter binding/validation errors to verify:
           - ValidatePattern on -CustomSeparator rejects invalid inputs.
           - ValidateSet on -Style rejects invalid values.
           - Parameter set binding rejects mixing "Custom" and "Style".
        #>

        It 'throws when -CustomSeparator has more than one char' {
            { Get-PathSeparator -CustomSeparator '//' } | Should -Throw
        }

        It 'throws when -CustomSeparator is not "\" or "/"' {
            { Get-PathSeparator -CustomSeparator '-' } | Should -Throw
        }

        It 'throws when -Style is invalid' {
            { Get-PathSeparator -Style 'MacClassic' } | Should -Throw
        }

        It 'throws when both -CustomSeparator and -Style are passed' {
            { Get-PathSeparator -CustomSeparator $script:WindowsSep -Style Platform } | `
                    Should -Throw
        }
    }

    Context 'Cross-platform sanity' {
        <#
         These tests assert OS-agnostic behavior:
           - Platform style equals the engine's DirectorySeparatorChar.
           - Forced Windows/Unix styles return the expected value regardless of host OS.
        #>

        It 'default (no params) matches platform DirectorySeparatorChar' {
            Get-PathSeparator | Should -Be $script:PlatformSepString
        }

        It 'Platform style reflects current OS' {
            $expected = if ($IsWindows) { $script:WindowsSep } else { $script:UnixSep }
            Get-PathSeparator -Style Platform | Should -Be $expected
        }

        It 'Windows style is "\" regardless of platform' {
            Get-PathSeparator -Style Windows | Should -Be $script:WindowsSep
        }

        It 'Unix style is "/" regardless of platform' {
            Get-PathSeparator -Style Unix | Should -Be $script:UnixSep
        }
    }

    Context 'Types & lengths' {
        <#
         These tests enforce output type and length invariants:
           - Without -AsChar: a one-character [string].
           - With -AsChar: a [char] value.
        #>

        It 'returns one-character strings without -AsChar' {
            foreach (
                $r in @(
                    (Get-PathSeparator),
                    (Get-PathSeparator -Style Windows),
                    (Get-PathSeparator -Style Unix)
                )
            ) {
                $r | Should -BeOfType 'System.String'
                $r.Length | Should -Be 1
            }
        }

        It 'returns chars with -AsChar' {
            foreach (
                $r in @(
                    (Get-PathSeparator -AsChar),
                    (Get-PathSeparator -Style Windows -AsChar),
                    (Get-PathSeparator -Style Unix -AsChar)
                )
            ) {
                $r | Should -BeOfType 'System.Char'
            }
        }
    }

    Context 'Signature & metadata (contract tests)' {
        <#
         Contract tests: if the function signature changes, these will fail early.
           - Default parameter set name.
           - ValidateSet/ValidatePattern attributes presence and content.
           - AsChar is a switch parameter.
        #>

        It 'has default parameter set "Style"' {
            (Get-Command Get-PathSeparator).DefaultParameterSet | Should -Be 'Style'
        }

        It 'Style parameter has ValidateSet Platform/Windows/Unix' {
            $cmd = Get-Command Get-PathSeparator
            $attr = $cmd.Parameters['Style'].Attributes |
                Where-Object { 
                    $_ -is [System.Management.Automation.ValidateSetAttribute] 
                }
            $attr | Should -Not -BeNullOrEmpty
            $attr.ValidValues | Should -Be @('Platform', 'Windows', 'Unix')
        }

        It 'CustomSeparator parameter has ValidatePattern for "\" or "/"' {
            $cmd = Get-Command Get-PathSeparator
            $attr = $cmd.Parameters['CustomSeparator'].Attributes |
                Where-Object {
                    $_ -is [System.Management.Automation.ValidatePatternAttribute] 
                }
            $attr | Should -Not -BeNullOrEmpty
            $attr.RegexPattern | Should -Be '^(\\|/)$'
        }

        It 'AsChar is a switch' {
            (Get-Command Get-PathSeparator).Parameters['AsChar'].ParameterType.FullName |
                Should -Be 'System.Management.Automation.SwitchParameter'
        }
    }
}
