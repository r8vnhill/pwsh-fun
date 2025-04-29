<#
.SYNOPSIS
Validates that a provided path points to a valid PowerShell module manifest (.psd1).

.DESCRIPTION
`Assert-ModuleManifestPath` ensures that the given path refers to a `.psd1` file, which is the standard extension for PowerShell module manifests.
It throws an `[ArgumentException]` if the file does not have the correct extension.

This function is useful for validating module import paths in automated tests, initialization scripts, or module management workflows.

.PARAMETER Import
The path to validate.
Must be a non-empty string.
Accepts input from the pipeline for easier chaining.

.EXAMPLE
PS> Assert-ModuleManifestPath -Import './modules/Fun.Files/Fun.Files.psd1'

Validates that the given path is a module manifest (`.psd1`).

.EXAMPLE
PS> './modules/Fun.Loader/Fun.Loader.psd1', './modules/Fun.Files/Fun.Files.psd1' | Assert-ModuleManifestPath

Validates multiple paths in a pipeline.

.NOTES
- Throws [System.ArgumentException] if the extension is not `.psd1`.
- Returns `$true` if validation succeeds.
- Designed for use in testing, initialization, or deployment scripts.
#>
function Assert-ModuleManifestPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$Import
    )

    process {
        $ext = [System.IO.Path]::GetExtension($import)
        if ($ext -ne '.psd1') {
            throw [System.ArgumentException]::new(
                "Invalid module extension '$ext'. Only '.psd1' is allowed: '$import'"
            )
        }
    }

    end {
        return $true
    }
}
