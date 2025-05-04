# modules\Fun.Terminal\Fun.Terminal.psm1
Get-ChildItem -Path "$PSScriptRoot\public" -Recurse -File | 
    Where-Object { $_.Name -like '*.ps1' } | 
    ForEach-Object { . "$PSScriptRoot\public\$($_.Name)" }

Export-ModuleMember -Function Test-Command
Export-ModuleMember -Function Get-Right
