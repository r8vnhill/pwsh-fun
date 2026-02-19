# Load the shared test suite initializer from the internal directory.
# This function handles verifying the module exists, importing it, and checking for required commands.
Import-Module -Name "$PSScriptRoot\..\internal\Test.Init\Test.Init.psd1" -ErrorAction Stop

# Load additional helper functions used in tests (e.g., for creating temporary files).
. "$PSScriptRoot/../internal/Helpers.ps1"

$script:module = 'Fun.Loader'

<#
.SYNOPSIS
    Resolves the absolute path to the 'Fun.Loader' module folder.
.DESCRIPTION
    Combines the repository modules root (Resolve-ModulesPath) with 'Fun.Loader',
    normalizes it, and verifies that it exists and is a directory.
.OUTPUTS
    [string]
#>
function Resolve-FunLoaderPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    Resolve-RelativePath `
        -Start (Resolve-ModulesPath) `
        -Parts $script:module `
        -RequireExists `
        -PathType Container
}

# Initialize the test suite for the 'Fun.Loader' module.
# This will:
# - Resolve and import the module from 'modules/Fun.Loader/Fun.Loader.psd1'
# - Verify that the specified commands are available after import
# - Force re-import if the module is already loaded (to ensure a clean state)
Initialize-TestSuite -Module $script:module -RequiredCommands @(
    'Install-FunModules',   # Install the specified fun modules
    'Remove-FunModules'     # Remove the specified fun modules
) -ForceImport
