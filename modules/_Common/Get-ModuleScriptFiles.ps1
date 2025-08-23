#Requires -Version 7.0
Set-StrictMode -Version Latest

<#
.SYNOPSIS
    Returns a deterministic list of *.ps1 files under a module subfolder.
#>
function Get-ModuleScriptFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('internal', 'public')]
        [string] $Subfolder,

        [Parameter()]
        [string] $Root = $PSScriptRoot
    )

    $base = Join-Path $Root $Subfolder
    if (-not (Test-Path -LiteralPath $base -PathType Container)) {
        Write-Verbose "No '$Subfolder' at $base (skipping)."
        return @()
    }

    Get-ChildItem -LiteralPath $base -Recurse -File -Filter '*.ps1' |
        Sort-Object FullName
}
