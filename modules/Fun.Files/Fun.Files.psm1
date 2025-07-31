#Requires -Version 7.0
<#
.SYNOPSIS
    Fun.Files module bootstrapper (DRY version).

.DESCRIPTION
    Enumerates *.ps1 under ./internal and ./public in deterministic order and dot‑sources
    them in the MODULE (script) scope. The dot operator stays in the module body to ensure
    any declared functions remain in the module session state.

    - internal scripts load first (private helpers).
    - public scripts load after; what becomes public is governed by the .psd1 manifest.

    Notes:
      * Provider-side filtering (-Filter, -File) for performance.
      * Deterministic load order (Sort-Object FullName).
      * Quiet by default (Write-Verbose for diagnostics).
      * try/catch around each file for clear failures.
#>

Set-StrictMode -Version Latest
Write-Verbose "Initializing Fun.Files from: $PSScriptRoot"

# Small helper that ONLY returns files to load. It does NOT dot‑source.
function Get-ModuleScriptFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('internal', 'public')]
        [string] $Subfolder
    )

    $root = Join-Path $PSScriptRoot $Subfolder
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        Write-Verbose "No '$Subfolder' folder at $root (skipping)."
        return @()  # keep callers simple
    }

    Get-ChildItem -Path $root -Recurse -File -Filter '*.ps1' |
        Sort-Object FullName
}

# Load both trees with the same logic; keep dot‑sourcing in MODULE scope.
foreach ($file in (Get-ModuleScriptFiles -Subfolder 'internal')) {
    try {
        Write-Verbose "Dot-sourcing (internal): $($file.FullName)"
        $null = . $file.FullName
    } catch {
        throw "Error importing internal script '{0}': {1}" `
            -f $($file.FullName), $($_.Exception.Message)
    }
}

foreach ($file in (Get-ModuleScriptFiles -Subfolder 'public')) {
    try {
        Write-Verbose "Dot-sourcing (public): $($file.FullName)"
        $null = . $file.FullName
    } catch {
        throw "Error importing public script '$($file.FullName)': $($_.Exception.Message)"
    }
}
