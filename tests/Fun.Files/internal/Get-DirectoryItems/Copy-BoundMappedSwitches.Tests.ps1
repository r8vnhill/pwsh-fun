#Requires -Version 7.0
#Requires -Modules Pester
<#
.SYNOPSIS
    Pester v5 tests for Copy-BoundMappedSwitches.

.DESCRIPTION
    Validates the behavior and contract of Copy-BoundMappedSwitches, including:
      - Parameter validation and metadata shape (ValidateNotNull, ValidateSet, types)
      - Presence vs True mode semantics
      - Mapping (source -> destination) and ignoring bad map entries
      - Overwrite behavior with and without -Overwrite
      - Value parameter behavior
      - No-op scenarios and reference preservation (returns the same hashtable instance)

.NOTES
    - Tests dot-source the internal function directly by design (the function is not
      exported).
    - Run with `Invoke-Pester -Output Detailed` (or `-Verbose`) to see more context if
      needed.
#>

Describe 'Copy-BoundMappedSwitches' -Tag 'unit' {

    BeforeAll {
        # Bring in shared helpers and dot-source the function under test into THIS scope.
        # We intentionally load the .ps1 directly here (not inside a helper) so
        # definitions persist in the current scope for the rest of the file.
        . "$PSScriptRoot\..\_internal__Setup.ps1"
        . (New-InternalScriptLoader -Parts @(
                'Get-DirectoryItems',
                'Copy-BoundMappedSwitches.ps1'))

        # Contract sanity: the function must exist now. If this fails, the suite should
        # stop early.
        Get-Command -Name Copy-BoundMappedSwitches `
            -CommandType Function `
            -ErrorAction Stop | Out-Null
    }

    Context 'Parameter contract & validation' {
        It 'throws when -KeyMap is $null (ValidateNotNull)' {
            { Copy-BoundMappedSwitches -KeyMap $null } | Should -Throw
        }

        It 'accepts defaulted -Bound and -Target (both default to empty hashtables)' {
            # Only -KeyMap: returns empty hashtable.
            $result = Copy-BoundMappedSwitches -KeyMap @{ A = 'A' }
            $result | Should -BeOfType 'System.Collections.Hashtable'
            $result.Count | Should -Be 0
        }

        It 'Mode only accepts Presence or True (ValidateSet)' {
            { Copy-BoundMappedSwitches -KeyMap @{ A = 'A' } -Mode 'Whatever' } | 
                Should -Throw
        }

        It 'Overwrite is a switch and Value is boolean' {
            # Verify parameter types to catch regressions in the public contract.
            $cmd = Get-Command Copy-BoundMappedSwitches
            $cmd.Parameters['Overwrite'].ParameterType.FullName | 
                Should -Be 'System.Management.Automation.SwitchParameter'
            $cmd.Parameters['Value'].ParameterType.FullName | 
                Should -Be 'System.Boolean'
        }
    }

    Context 'Basic presence mode behavior (default)' {
        It 'copies when source key is present in -Bound even if its value is $false' {
            # Presence mode checks for key existence, not truthiness.
            $map = @{ Force = 'Force' }
            $bound = @{ Force = $false }
            $tgt = @{}
            $res = Copy-BoundMappedSwitches -KeyMap $map -Bound $bound -Target $tgt
            $res['Force'] | Should -Be $true      # default -Value is $true
        }

        It 'does not copy when source key is absent' {
            $map = @{ Recurse = 'Recurse' }
            $bound = @{}      # Recurse missing
            $tgt = @{}
            $res = Copy-BoundMappedSwitches -KeyMap $map -Bound $bound -Target $tgt
            $res.ContainsKey('Recurse') | Should -BeFalse
        }

        It 'returns the same hashtable instance as -Target' {
            # This documents the "mutate and return Target" contract (useful for callers).
            $map = @{ A = 'A' }
            $bound = @{ A = $true }
            $tgt = @{}
            $res = Copy-BoundMappedSwitches -KeyMap $map -Bound $bound -Target $tgt
            [object]::ReferenceEquals($res, $tgt) | Should -BeTrue
        }
    }

    Context 'True mode behavior' {
        It 'copies when source key exists AND is $true' {
            $map = @{ FollowSymlink = 'FollowSymlink' }
            $bound = @{ FollowSymlink = $true }
            $tgt = @{}
            $res = Copy-BoundMappedSwitches -KeyMap $map `
                -Bound $bound `
                -Target $tgt `
                -Mode True
            $res['FollowSymlink'] | Should -Be $true
        }

        It 'does not copy when source key exists but is $false' {
            $map = @{ Directory = 'Directory' }
            $bound = @{ Directory = $false }
            $tgt = @{}
            $res = Copy-BoundMappedSwitches -KeyMap $map `
                -Bound $bound `
                -Target $tgt `
                -Mode True
            $res.ContainsKey('Directory') | Should -BeFalse
        }
    }

    Context 'Mapping semantics' {
        It 'renames keys according to -KeyMap (source -> destination)' {
            # Typical use: copy a different parameter name into the outgoing splat.
            $map = @{ SourceKey = 'DestKey' }
            $bound = @{ SourceKey = $true }
            $tgt = @{}
            $res = Copy-BoundMappedSwitches -KeyMap $map -Bound $bound -Target $tgt
            $res.ContainsKey('DestKey') | Should -BeTrue
            $res.ContainsKey('SourceKey') | Should -BeFalse
        }

        It 'ignores null/empty source or destination entries in -KeyMap' {
            # The function explicitly skips empty/whitespace src or dst names.
            $map = [hashtable]::new()
            $map[''] = 'X'   # empty source
            $map['  '] = 'Y'   # whitespace source
            $map['Real'] = ''    # empty destination
            $map['Also'] = '  '  # whitespace destination

            $bound = @{ Real = $true; Also = $true }
            $tgt = @{}

            $res = Copy-BoundMappedSwitches -KeyMap $map -Bound $bound -Target $tgt
            $res.Keys | Should -BeNullOrEmpty
        }
    }

    Context 'Overwrite behavior' {
        It 'does NOT overwrite existing target value unless -Overwrite is specified' {
            $map = @{ Force = 'Force' }
            $bound = @{ Force = $true }
            $tgt = @{ Force = $false }   # pre-existing value
            $res = Copy-BoundMappedSwitches -KeyMap $map -Bound $bound -Target $tgt
            $res['Force'] | Should -Be $false   # unchanged
        }

        It 'overwrites existing target value when -Overwrite is specified' {
            $map = @{ Force = 'Force' }
            $bound = @{ Force = $true }
            $tgt = @{ Force = $false }
            $res = Copy-BoundMappedSwitches -KeyMap $map `
                -Bound $bound `
                -Target $tgt `
                -Overwrite
            $res['Force'] | Should -Be $true
        }

        It 'multiple sources to same destination: first wins, -Overwrite allows last' {
            # NOTE: Regular Hashtable enumeration order is not guaranteed in .NET.
            # Use [ordered] to make the key order deterministic for this test.
            $map = [ordered]@{ A = 'X'; B = 'X' }   # both map to 'X'

            # Without -Overwrite: first key (A) sets X; B is skipped
            $tgt1 = @{}
            $res1 = Copy-BoundMappedSwitches -KeyMap $map `
                -Bound @{ A = $true; B = $true } `
                -Target $tgt1 `
                -Mode Presence
            $res1['X'] | Should -Be $true

            # With -Overwrite: last processed key wins (B in this ordered map)
            $tgt2 = @{}
            $res2 = Copy-BoundMappedSwitches -KeyMap $map `
                -Bound @{ A = $false; B = $true } `
                -Target $tgt2 `
                -Mode Presence `
                -Overwrite
            $res2['X'] | Should -Be $true
        }
    }

    Context 'Value parameter' {
        It 'writes the specified boolean Value into the target' {
            $map = @{ Directory = 'Directory' }
            $bound = @{ Directory = $true }
            $tgt = @{}
            $res = Copy-BoundMappedSwitches -KeyMap $map `
                -Bound $bound `
                -Target $tgt `
                -Value:$false
            $res['Directory'] | Should -Be $false
        }
    }

    Context 'No-op scenarios' {
        It 'returns target unchanged when -Bound has no mapped keys' {
            $map = @{ A = 'X'; B = 'Y' }
            $bound = @{ }            # no A/B present
            $tgt = @{ Existing = 1 }
            $res = Copy-BoundMappedSwitches -KeyMap $map -Bound $bound -Target $tgt

            $res.Count | Should -Be 1
            $res['Existing'] | Should -Be 1
            # The function returns the same instance it mutates (documented contract)
            [object]::ReferenceEquals($res, $tgt) | Should -BeTrue
        }
    }
}
