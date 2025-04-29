<#
.SYNOPSIS
Initializes a test suite by importing a module and verifying its commands.

.DESCRIPTION
`Initialize-TestSuite` sets up the environment for testing a PowerShell module. It resolves and imports the module `.psd1` file, checks for the presence of expected public commands, and optionally enables verbose output.

This function is intended to be called at the start of a test script to ensure the module under test is properly loaded and functional.

.PARAMETER Module
The name of the module to load, relative to the `modules/` directory under `$Root`.
This must match the folder and `.psd1` file name.

.PARAMETER RequiredCommands
A list of command names that must be available after importing the module.
If any are missing, an exception is thrown.

.PARAMETER AdditionalImports
A list of additional module names to import alongside the main module.
These modules are expected to be in the same directory as the main module.
This is useful for loading dependencies or related modules.

.PARAMETER Root
The root path that contains the `modules/` folder.
Defaults to the project root (two levels up from the current script).

.PARAMETER ForceImport
If specified, forces re-importing the module even if it is already loaded.
This is useful for test scenarios where the module may have changed.

.PARAMETER VerboseOnSuccess
If specified, emits verbose output confirming the module and each command were successfully found and imported.
This is useful for debugging and ensuring the test environment is correctly set up.

.EXAMPLE
PS> Initialize-TestSuite -Module 'Fun.Files' -RequiredCommands 'Get-FileContents', 'Show-FileContents'

Imports the `Fun.Files` module and ensures the `Get-FileContents` and `Show-FileContents` commands are present.

.EXAMPLE
PS> Initialize-TestSuite -Module 'Fun.Loader' `
>>>     -RequiredCommands 'Install-FunModules' `
>>>     -ForceImport -VerboseOnSuccess

Imports `Fun.Loader`, reloading it even if already present, and prints verbose output for each step.

.NOTES
- Relies on the helper functions `Assert-ModulePathExists`, `Import-TestModule`, and `Assert-ModuleCommandsPresent`.
- Designed for test initialization in module test scripts.
- Throws typed exceptions on failure.
#>
function Initialize-TestSuite {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Module,

        [Parameter(Mandatory)]
        [ValidateScript({ $_ | Assert-CommandName -ErrorAction Stop })]
        [string[]]$RequiredCommands,

        [ValidateScript({
                foreach ($import in $_) {
                    $ext = [System.IO.Path]::GetExtension($import)
                    if ($ext -ne '.psd1') {
                        throw "❌ Invalid module extension '$ext'. Only '.psd1' is allowed."
                    }
                }
                return $true
            })]
        [string[]]$AdditionalImports = @(),

        [ValidateScript({
                if (-not (Test-Path -LiteralPath $_)) {
                    throw "❌ Path '$_' does not exist."
                }
                return $true
            })]
        [ValidateNotNullOrEmpty()]
        [string]$Root = (Join-Path -Path $PSScriptRoot -ChildPath '..\..' -Resolve),

        [switch]$ForceImport,

        [switch]$VerboseOnSuccess
    )

    $modulePath = Join-Path -Path $Root -ChildPath "modules\$Module\$Module.psd1"
    
    $AdditionalImports | Import-Module

    Import-TestModule -ModulePath $modulePath `
        -ForceImport:$ForceImport `
        -VerboseOnSuccess:$VerboseOnSuccess

    Assert-ModuleCommandsPresent -Module $Module `
        -RequiredCommands $RequiredCommands `
        -VerboseOnSuccess:$VerboseOnSuccess
}

<#
.SYNOPSIS
Safely imports a PowerShell module from the specified path with optional verbosity and force reload.

.DESCRIPTION
`Import-TestModule` resolves and imports a module file (usually `.psd1` or `.psm1`) from a literal path.
It validates the path, optionally forces re-importing the module, and can emit verbose output upon success.
If the import fails, it throws a typed `ImportModuleException` with the underlying error.

This function is intended for use in test setups or test suites where explicit control and feedback over module loading is required.

.PARAMETER ModulePath
The literal path to the module manifest or script module file to import.
Must be a valid, non-empty path that resolves to an existing file.

.PARAMETER ForceImport
If set, forces re-importing the module even if it’s already loaded in the session.

.PARAMETER VerboseOnSuccess
If set, emits a verbose message after successful import indicating the resolved path.

.EXAMPLE
Import-TestModule -ModulePath './MyModule/MyModule.psd1'

Imports the module from the given path, resolving the full path before import.

.EXAMPLE
Import-TestModule -ModulePath './MyModule.psd1' -ForceImport -VerboseOnSuccess

Forces re-importing the module and writes a verbose message upon success.

.NOTES
- Throws [System.Management.Automation.ImportModuleException] on failure.
- Uses `Resolve-Path` to get the canonical file system path.
- Intended for testing environments where modules are reloaded frequently.
#>
function script:Import-TestModule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                if (-not (Test-Path -LiteralPath $_)) {
                    throw "❌ Path '$_' does not exist."
                }
                $ext = [System.IO.Path]::GetExtension($_)
                if ($ext -ne '.psd1' -and $ext -ne '.psm1') {
                    throw "❌ Invalid module extension '$ext'. Only '.psd1' and '.psm1' are allowed."
                }
                return $true
            })]
        [string]$ModulePath,

        [switch]$ForceImport,

        [switch]$VerboseOnSuccess
    )

    try {
        $resolvedPath = Resolve-Path -LiteralPath $ModulePath -ErrorAction Stop

        Import-Module -Name $resolvedPath.Path `
            -Force:$ForceImport.IsPresent `
            -ErrorAction Stop

        if ($VerboseOnSuccess) {
            Write-Verbose "✅ Imported module from: $($resolvedPath.Path)"
        }
    } catch {
        $msg = "❌ Failed to import module from path '$ModulePath'"
        throw [System.Management.Automation.ImportModuleException]::new($msg, $_.Exception)
    }
}

<#
.SYNOPSIS
Asserts that all required commands are available after importing a module.

.DESCRIPTION
`Assert-ModuleCommandsPresent` verifies that a given list of commands is available in the session, typically after importing a module. 
If any expected command is missing, the function throws a `CommandNotFoundException`.

This is useful in test setups or CI pipelines to ensure the module exposes all intended public commands.

.PARAMETER Module
The name of the module that should have exported the required commands.
Used in error messages for clarity.

.PARAMETER RequiredCommands
A list of command names that must be available in the session.
If any are missing, an exception is thrown.

.PARAMETER VerboseOnSuccess
If set, the function will write a verbose message for each command found.

.EXAMPLE
PS> Assert-ModuleCommandsPresent -Module 'Fun.Files' -RequiredCommands 'Show-FileContents', 'Get-FileContents'

Verifies that the commands `Show-FileContents` and `Get-FileContents` are present in the session after importing the `Fun.Files` module.

.EXAMPLE
PS> Assert-ModuleCommandsPresent -Module 'Fun.Loader' -RequiredCommands 'Install-FunModules' -VerboseOnSuccess

Checks that `Install-FunModules` exists and logs a verbose message on success.

.NOTES
- Throws a [System.Management.Automation.CommandNotFoundException] for missing commands.
- Useful in `Initialize-TestSuite` functions and module bootstrapping checks.
#>
function script:Assert-ModuleCommandsPresent {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Module,
        
        [Parameter(Mandatory)]
        [string[]]$RequiredCommands,

        [switch]$VerboseOnSuccess
    )
    foreach ($cmd in $RequiredCommands) {
        if (-not (Get-Command -Name $cmd -ErrorAction SilentlyContinue)) {
            throw [System.Management.Automation.CommandNotFoundException]::new(
                "Expected command '$cmd' not found after importing module: $Module"
            )
        } elseif ($VerboseOnSuccess) {
            Write-Verbose "✔ Command available: $cmd"
        }
    }
}
