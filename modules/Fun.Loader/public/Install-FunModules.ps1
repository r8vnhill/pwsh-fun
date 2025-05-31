# modules\Fun.Loader\public\Install-FunModules.ps1

<#
.SYNOPSIS
Imports all modules found inside the `modules/` folder of the pwsh-fun project.

.DESCRIPTION
This function searches for subdirectories within the `modules/` folder and attempts to import a `.psm1` file whose name matches the directory name.
It is intended to dynamically load all modular PowerShell components of the pwsh-fun project during development or interactive use.

It uses `Import-Module -Scope Global` so that the exported functions become available in the current session.
Only modules with valid `.psm1` files are processed.
Missing module files are skipped with a warning.

.PARAMETER BasePath
Specifies the root path of the repository.
By default, it is calculated two levels above the current script location.
This should be the root of the `pwsh-fun` repository, containing a `modules/` folder.

.EXAMPLE
PS> Install-FunModules

Searches for modules in the default location and imports all found `.psm1` files.

.EXAMPLE
PS> Install-FunModules -BasePath "C:\Repos\pwsh-fun"

Imports modules from the specified root path.

.EXAMPLE
PS> Install-FunModules -Verbose

Displays additional progress information during module discovery and import.

.NOTES
This function uses `ShouldProcess`, so it supports `-WhatIf` and `-Confirm`.
#>
function Install-FunModules {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$BasePath = (
            Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')
        ).Path
    )

    $modulesPath = Join-Path $BasePath 'modules'

    Write-Verbose "📦 Installing modules from: $modulesPath"

    if (-not (Test-Path $modulesPath)) {
        Write-Warning "Modules folder not found: $modulesPath"
        return
    }

    Get-ChildItem -Path $modulesPath -Exclude '*Fun.OCD*' -Directory | 
        ForEach-Object {
            $moduleName = $_.Name
            $psm1Path = Join-Path $_.FullName "$moduleName.psm1"

            if (-not (Test-Path $psm1Path)) {
                Write-Warning "⚠️  Skipped: $moduleName.psm1 not found in $($_.FullName)"
                return
            }

            if ($PSCmdlet.ShouldProcess($moduleName, 'Import module')) {
                Import-Module $psm1Path -Force -Scope Global
                Write-Host "✅ Imported module: $moduleName" -ForegroundColor Green
            }
        }
}
