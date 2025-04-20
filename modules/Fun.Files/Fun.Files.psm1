. "$PSScriptRoot\public\Invoke-FileTransform.ps1"
. "$PSScriptRoot\public\Show-FileContents.ps1"
. "$PSScriptRoot\public\Get-FileContents.ps1"
. "$PSScriptRoot\public\Copy-FileContents.ps1"

Export-ModuleMember `
    -Function Show-FileContents, Get-FileContents, Invoke-FileTransform, Copy-FileContents
