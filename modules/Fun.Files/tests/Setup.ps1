# Dot-source internal test helper assertions (e.g., Assert-ThrowsWithType)
. "$PSScriptRoot\internal\Assertions.ps1"

# Import the module under test, forcibly reloading it to ensure changes are reflected
#   -Force ensures any previous version of the module is replaced
#   -ErrorAction Stop ensures the test fails immediately if the module cannot be loaded
Import-Module "$PSScriptRoot\..\Fun.Files.psm1" -Force -ErrorAction Stop
