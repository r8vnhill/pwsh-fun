
<#
.SYNOPSIS
Creates a new directory and navigates into it.

.DESCRIPTION
Creates a directory at the specified path and immediately changes the current location to that directory.
If the directory already exists, it is reused without error.
Supports `-WhatIf` and `-Confirm` for safe execution in scripts.

This function is useful for quickly creating and entering project or workspace folders in a single step.

.PARAMETER LiteralPath
The literal path of the directory to create and enter.
Must not be null or empty.

.EXAMPLE
New-AndEnterDirectory -LiteralPath 'C:\Projects\MyApp'

Creates the 'MyApp' directory inside 'C:\Projects' and sets it as the current location.

.EXAMPLE
mdcd 'Reports\2025'

Alias for the same function.
Creates and enters the '2025' folder under 'Reports'.

.NOTES
Alias: mdcd
#>
function New-AndEnterDirectory {
    [Alias('mdcd')]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$LiteralPath
    )
    try {
        if ($PSCmdlet.ShouldProcess("Directory '$LiteralPath'", 'Create and enter')) {
            $directory = New-Item `
                -Path $LiteralPath `
                -ItemType Directory `
                -Force -ErrorAction Stop
            Push-Location -LiteralPath $directory.FullName
        }
    } catch {
        Write-Error -Message "❌ Failed to create or enter directory '$LiteralPath': $_"
    }
}
