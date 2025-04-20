# modules\Fun.Loader\Fun.Loader.psm1

. "$PSScriptRoot\public\Install-FunModules.ps1"

. "$PSScriptRoot\public\Remove-FunModules.ps1"

Export-ModuleMember -Function Install-FunModules, Remove-FunModules
