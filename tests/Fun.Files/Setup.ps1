# Load the shared test suite initializer from the internal directory.
# This function handles verifying the module exists, importing it, and checking for required commands.
Import-Module -Name "$PSScriptRoot\..\internal\Test.Init\Test.Init.psd1" -ErrorAction Stop

# Load additional helper functions used in tests (e.g., for creating temporary files).
. "$PSScriptRoot/../internal/Helpers.ps1"

# Initialize the test suite for the 'Fun.Files' module.
# This will:
# - Resolve and import the module from 'modules/Fun.Files/Fun.Files.psd1'
# - Verify that the specified commands are available after import
# - Force re-import if the module is already loaded (to ensure a clean state)
Initialize-TestSuite -Module 'Fun.Files' -RequiredCommands @(
    'Compress-FilteredFiles',  # Compress files matching filters into a .zip
    'Get-FileContents',        # Retrieve file contents with header and metadata
    'Show-FileContents'        # Pretty-print files with optional ANSI color
) -ForceImport
