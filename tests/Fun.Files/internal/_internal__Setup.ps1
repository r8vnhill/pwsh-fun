#Requires -Version 7.0
#Requires -Modules Pester
Set-StrictMode -Version Latest

. "$PSScriptRoot\..\Setup.ps1"

<#
.SYNOPSIS
    Resolves the absolute path to the Fun.Files\internal folder.

.DESCRIPTION
    Combines the Fun.Files module path with 'internal' and normalizes the result.
    By default, verifies that the directory exists.

.PARAMETER RequireExists
    When set (default), throws if the resolved path does not exist or is not a directory.

.OUTPUTS
    [string]

.EXAMPLE
    Resolve-FunFilesInternalPath
    # -> '…\Fun.Files\internal' (must exist)
#>
function Resolve-FunFilesInternalPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [bool] $RequireExists = $true
    )

    Resolve-RelativePath `
        -Start (Resolve-FunFilesPath) `
        -Parts 'internal' `
        -RequireExists:$RequireExists `
        -PathType Container
}

<#
.SYNOPSIS
    Resolves the absolute path to an internal script under the Fun.Files module.

.DESCRIPTION
    Combines the Fun.Files\internal folder with one or more relative segments (-Parts),
    normalizes the result to a full path, and verifies that the script file exists.
    Intended for test bootstrapping where internal (non-exported) helpers are dot-sourced.

    This function does NOT dot-source; it only returns the absolute path or throws.

.PARAMETER Parts
    Relative path segments under the Fun.Files\internal folder that locate the script.

.OUTPUTS
    System.String
    The absolute path to the target script.
#>
function Get-InternalScriptPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string[]] $Parts
    )

    # Build the absolute path under ...\Fun.Files\internal\<Parts...>
    $path = Resolve-RelativePath -Start (Resolve-FunFilesInternalPath) -Parts $Parts

    # Ensure the target is an existing file; fail fast with a clear, typed exception.
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new(
            'Cannot find script to dot-source.',
            $path
        )
    }

    # Return the absolute path; caller decides when/how to dot-source.
    $path
}

<#
.SYNOPSIS
    Creates a scriptblock that dot-sources an internal script in the caller's scope.

.DESCRIPTION
    For test convenience, this function resolves a target internal script (via
    Get-InternalScriptPath) and returns a scriptblock that, when dot-invoked, loads the
    script into the *current* scope. This preserves function definitions beyond the call
    (unlike dot-sourcing inside a helper function).

.PARAMETER Parts
    Relative path segments under the Fun.Files\internal folder that locate the script.

.OUTPUTS
    System.Management.Automation.ScriptBlock
    A scriptblock of the form: . '<absolute\path\to\script.ps1>'
#>
function New-InternalScriptLoader {
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory)]
        [string[]] $Parts
    )

    # Resolve and validate target script path first (throws if not found).
    $path = Get-InternalScriptPath -Parts $Parts

    Write-Verbose "Preparing loader for: $path"

    # Return a scriptblock that dot-sources the file in the *caller* scope when invoked.
    # Single quotes ensure literal path handling (no wildcard expansion).
    [scriptblock]::Create(". '$path'")
}
