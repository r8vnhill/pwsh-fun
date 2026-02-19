# modules\_Common\Import-ModuleScripts.ps1
#Requires -Version 7.0

param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Root
)

Set-StrictMode -Version Latest

<#
.SYNOPSIS
    Dot-sources internal then public scripts **in the caller’s scope**.

.DESCRIPTION
    This is a *script*, not a function*. Dot-source it from your .psm1:
        . "$PSScriptRoot\..\_Common\Import-ModuleScripts.ps1" -Root $PSScriptRoot

    Because it is dot-sourced from the module file, all subsequent dot-sourced
    files load into the module scope (so they are visible/exportable).
#>

# Pull in the discovery helper local to this script's scope
. "$PSScriptRoot\Get-ModuleScriptFiles.ps1"

foreach ($file in Get-ModuleScriptFiles -Subfolder 'internal' -Root $Root) {
    try {
        Write-Verbose "Dot-sourcing (internal): $($file.FullName)"
        . $file.FullName
    } catch {
        throw ("Error importing internal script '{0}': {1}" -f $file.FullName, $_.Exception.Message)
    }
}

foreach ($file in Get-ModuleScriptFiles -Subfolder 'public' -Root $Root) {
    try {
        Write-Verbose "Dot-sourcing (public): $($file.FullName)"
        . $file.FullName
    } catch {
        throw ("Error importing public script '{0}': {1}" -f $file.FullName, $_.Exception.Message)
    }
}
