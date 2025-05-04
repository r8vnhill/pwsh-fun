BeforeAll {
    # Load shared test setup logic (e.g., class definitions, custom functions, or module imports)
    . (Join-Path $PSScriptRoot 'Setup.ps1')
}

Describe 'Test-Command' {
    Context 'When checking for existing commands' {

        # Tests that the function itself is found and properly reported as a Function
        It 'returns a CommandCheck object for each command' {
            $commandCheck = Test-Command -Command 'Test-Command'
            
            # Should correctly identify the command type as a Function
            $commandCheck.CommandType | Should -Be 'Function'
            
            # Should return the exact name
            $commandCheck.Name | Should -Be 'Test-Command'

            # Should mark the command as existing
            $commandCheck.Exists | Should -Be $true

            # Should return the module name for user-defined functions
            $commandCheck.Path | Should -Be 'Fun.Terminal'
        }

        # Tests built-in PowerShell cmdlet detection
        It 'detects a built-in cmdlet' {
            $result = Test-Command -Command 'Get-Item'

            # Should exist and be identified as a Cmdlet
            $result.Exists | Should -Be $true
            $result.CommandType | Should -Be 'Cmdlet'
        }

        # Tests that aliases like "tc" (Test-Command) are resolved correctly
        It 'detects an alias and resolves it' {
            $result = Test-Command -Command 'tc'

            # Should exist and be reported as an Alias
            $result.Exists | Should -Be $true
            $result.CommandType | Should -Be 'Alias'

            # Should resolve to 'Fun.Terminal'
            $result.Path | Should -Be 'Fun.Terminal'
        }

        # Tests that external executables on PATH (like git) are detected
        It 'detects an external executable' {
            $result = Test-Command -Command 'git'

            # Should exist and be classified as an Application
            $result.Exists | Should -Be $true
            $result.CommandType | Should -Be 'Application'

            # Path should resolve to a file ending in git or git.exe
            $result.Path | Should -Match '\bgit(\.exe)?$'
        }

        # Tests that non-existent commands return proper "not found" metadata
        It 'returns Exists = $false for non-existent command' {
            $result = Test-Command -Command 'DefinitelyNotARealCommand'

            # Should not exist
            $result.Exists | Should -Be $false

            # Name should match the input exactly
            $result.Name | Should -Be 'DefinitelyNotARealCommand'

            # No path or command type should be returned
            $result.Path | Should -BeNullOrEmpty
            $result.CommandType | Should -BeNullOrEmpty
        }

        # PowerShell is case-insensitive — this ensures consistent behavior
        It 'treats command names as case-insensitive' {
            $lower = Test-Command -Command 'get-item'
            $upper = Test-Command -Command 'GET-ITEM'

            # Both should resolve to the same command with the same metadata
            $lower.Name | Should -Be $upper.Name
            $lower.Path | Should -Be $upper.Path
        }

        # Tests batch command checks via pipeline input
        It 'handles multiple commands via pipeline' {
            $results = @('Get-Item', 'git', 'invalid') | Test-Command

            # Should return 3 results, one for each input
            $results.Count | Should -Be 3

            # Check each result's status
            $results[0].Exists | Should -Be $true    # Get-Item exists
            $results[1].Exists | Should -Be $true    # git exists
            $results[2].Exists | Should -Be $false   # invalid command
        }

        # Tests that invalid input (empty or null strings) throws an error
        It 'throws on null or empty command name' {
            { Test-Command -Command '' } | Should -Throw
            { Test-Command -Command $null } | Should -Throw
        }
    }
}
