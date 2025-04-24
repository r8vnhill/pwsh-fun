function Initialize-TestSuite {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Module,

        [Parameter(Mandatory)]
        [string[]]$RequiredCommands,

        [string]$Root = (Join-Path -Path $PSScriptRoot -ChildPath '..\..' -Resolve),

        [switch]$ForceImport,

        [switch]$VerboseOnSuccess
    )

    $modulePath = Join-Path -Path $Root -ChildPath "modules\$Module\$Module.psd1"

    Assert-ModulePathExists -ModulePath $modulePath

    Foo

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

<#
.SYNOPSIS
Asserts that a module path exists on disk.

.DESCRIPTION
`Assert-ModulePathExists` verifies that the specified file system path exists. 
If the path does not resolve, the function throws a `System.IO.FileNotFoundException`.

This is useful for test setups, module initialization routines, or enforcing preconditions in automation scripts where a module path must exist.

.PARAMETER ModulePath
The file path to the module to verify.
Must be a non-empty string.
Accepts pipeline input.

.OUTPUTS
None. This function emits no output when the path exists.

.NOTES
- Throws `[System.IO.FileNotFoundException]` if the path does not exist.
- Writes a verbose message if the path exists.

.EXAMPLE
PS> Assert-ModulePathExists -ModulePath './modules/MyModule/MyModule.psd1'

Checks that the specified module manifest file exists. Throws if missing.

.EXAMPLE
'./MyModule.psd1', './Other.psd1' | Assert-ModulePathExists

Validates multiple paths passed through the pipeline.

#>
function script:Assert-ModulePathExists {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$ModulePath
    )
    
    process {
        if (-not (Test-Path -LiteralPath $ModulePath)) {
            $message = "Module path not found: '$ModulePath'"
            throw [System.IO.FileNotFoundException]::new($message)
        }
    
        Write-Verbose "✅ Module path exists: $ModulePath"
    }
}

function script:Import-TestModule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ModulePath,

        [switch]$ForceImport,

        [switch]$VerboseOnSuccess
    )

    try {
        $resolvedPath = Resolve-Path -LiteralPath $ModulePath -ErrorAction Stop
        Import-Module -Name $resolvedPath -Force:$ForceImport.IsPresent -ErrorAction Stop

        if ($VerboseOnSuccess) {
            Write-Verbose "✅ Imported module from: $resolvedPath"
        }
    } catch {
        $msg = "❌ Failed to import module from path '$ModulePath'"
        throw [System.Management.Automation.ImportModuleException]::new($msg, $_.Exception)
    }
}
