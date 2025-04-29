<#
.SYNOPSIS
Asserts that a script block throws an exception of a specific type.

.DESCRIPTION
`Assert-ThrowsWithType` executes a script block and verifies that it throws an exception of the expected .NET exception type.
If the script does not throw, or if it throws a different type of exception, an error is raised.

This function is useful for testing error handling in functions, especially when validating behavior in unit tests.

.PARAMETER Script
The script block to execute.
It must throw an exception during execution to pass the assertion.

.PARAMETER ExpectedType
The full name of the expected exception type (e.g., `System.IO.FileNotFoundException`).

.INPUTS
None.
You cannot pipe objects to this function.

.OUTPUTS
None.
This function throws if the assertion fails.

.EXAMPLE
PS> Assert-ThrowsWithType -Script { Get-Item 'Z:\doesnotexist' } -ExpectedType 'System.Management.Automation.ItemNotFoundException'

Validates that trying to retrieve a non-existent file throws an `ItemNotFoundException`.

.EXAMPLE
PS> Assert-ThrowsWithType -Script { Remove-Item 'C:\protected\file.txt' } -ExpectedType 'System.UnauthorizedAccessException' -Verbose

Validates that deleting a protected file throws an `UnauthorizedAccessException` and emits verbose output on success.

.NOTES
- If the script block does not throw an exception, the function raises an assertion error.
- If the thrown exception is not of the expected type, a detailed error message is provided.
- Useful for test automation in Pester or custom validation scripts.
#>
function Assert-ThrowsWithType {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [ScriptBlock]$Script,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ExpectedType
    )

    try {
        & $Script
        throw "❌ Expected an exception, but none was thrown."
    } catch {
        $actualType = $_.Exception.GetType().FullName

        if ($actualType -ne $ExpectedType) {
            throw "❌ Thrown exception type was '$actualType', but expected '$ExpectedType'."
        }

        Write-Verbose "✔ Caught expected exception type: $ExpectedType"
    }
}
