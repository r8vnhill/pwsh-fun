<#
.SYNOPSIS
Asserts that a specified path exists.

.DESCRIPTION
`Assert-PathExists` verifies that a given path points to an existing item in the filesystem. 
If the path does not exist, it throws a `[System.IO.FileNotFoundException]`.

This function is typically used in validation scripts, test setups, or defensive scripting to ensure that necessary files or directories are present before proceeding.

.PARAMETER ModulePath
The path to validate.
Accepts pipeline input. 
Must not be null or empty.
If the path does not exist, the function throws an exception.

.INPUTS
[string]

.OUTPUTS
[bool]
Returns `$true` if the path exists.

.EXAMPLE
PS> Assert-PathExists -ModulePath './modules/Fun.Files/Fun.Files.psd1'

Asserts that the specified module manifest path exists.

.EXAMPLE
PS> './src', './docs' | Assert-PathExists

Validates multiple paths piped into the function.

.NOTES
- Throws a `[System.IO.FileNotFoundException]` if the path is missing.
- Designed to be silent on success and throw on failure, following assertion conventions.
#>
function Assert-PathExists {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$ModulePath
    )
    process {
        if (-not (Test-Path -LiteralPath $ModulePath)) {
            throw [System.IO.FileNotFoundException]::new(
                "Path '$ModulePath' does not exist."
            )
        }
    }
    end {
        return $true
    }
}
