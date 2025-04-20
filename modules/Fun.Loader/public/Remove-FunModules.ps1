# modules\Fun.Loader\public\Remove-FunModules.ps1

<#
.SYNOPSIS
Removes all currently loaded pwsh-fun modules found in the `modules/` folder.

.DESCRIPTION
This function searches for subdirectories within the `modules/` folder and removes from the session any modules whose names match those directories and are currently loaded.
It is intended to unload all modular PowerShell components of the pwsh-fun project from the current session.

Only modules that are currently loaded are removed.
Any unloaded or non-existent modules are silently skipped.

.PARAMETER BasePath
Specifies the root path of the repository.
By default, it is calculated three levels above the current script location.
This should be the root of the `pwsh-fun` repository, containing a `modules/` folder.

.EXAMPLE
PS> Remove-FunModules

Removes all pwsh-fun modules currently loaded from the default repository location.

.EXAMPLE
PS> Remove-FunModules -BasePath "C:\Repos\pwsh-fun"

Removes all loaded modules found in the specified root path.

.EXAMPLE
PS> Remove-FunModules -Verbose

Displays additional progress information while checking and removing loaded modules.

.EXAMPLE
PS> Remove-FunModules -WhatIf

Shows what would happen without actually removing the modules.

.NOTES
This function uses `ShouldProcess`, so it supports `-WhatIf` and `-Confirm`.
#>
function Remove-FunModules {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$BasePath = (
            Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')
        ).Path
    )

    $modulesPath = Join-Path $BasePath 'modules'

    Write-Verbose "🧹 Removing modules from: $modulesPath"

    if (-not (Test-Path $modulesPath)) {
        Write-Warning "Modules folder not found: $modulesPath"
        return
    }

    Get-ChildItem -Path $modulesPath -Directory | ForEach-Object {
        $moduleName = $_.Name

        if (-not (Get-Module -Name $moduleName)) {
            continue
        }

        if ($PSCmdlet.ShouldProcess($moduleName, 'Remove module')) {
            Write-Host "❌ Removing: $moduleName" -ForegroundColor Red
            Remove-Module $moduleName -Force
        }
    }
}
