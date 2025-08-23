#Requires -Version 7.0
Set-StrictMode -Version Latest
Write-Verbose "Initializing Fun.Files from: $PSScriptRoot"

# Dot-source the loader *script* with a parameter -> runs in module scope
. "$PSScriptRoot\..\_Common\Import-ModuleScripts.ps1" -Root $PSScriptRoot
