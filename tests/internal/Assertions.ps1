<#
.SYNOPSIS
Asserts that a script block throws an exception of a specific type.

.DESCRIPTION
`Assert-ThrowsWithType` executes the given script block and asserts that it throws an exception of the expected .NET type.
If no exception is thrown, the function fails the test.
If an exception is thrown, the function compares its type (via `.Exception.GetType().FullName`) to the expected type string.

This helper is designed to be used in Pester tests to verify that the correct exception is thrown in error scenarios.

.PARAMETER Script
The script block expected to throw an exception.

.PARAMETER ExpectedType
The full name of the expected .NET exception type (e.g., 'System.IO.DirectoryNotFoundException').

.EXAMPLE
PS> Assert-ThrowsWithType {
>>>     Invoke-MyCommand -Path 'nonexistent'
>>> } 'System.IO.DirectoryNotFoundException'

Verifies that the command throws a DirectoryNotFoundException when run with an invalid path.

.OUTPUTS
None. This function is intended to be used within a Pester test context.

.NOTES
Fails the test if no exception is thrown, or if the type of the thrown exception does not match the expected type.
#>
function Assert-ThrowsWithType {
    param (
        [ScriptBlock]$Script,
        [string]$ExpectedType
    )

    try {
        & $Script
        throw "Expected exception but none was thrown"
    } catch {
        $_.Exception.GetType().FullName | Should -BeExactly $ExpectedType
    }
}
