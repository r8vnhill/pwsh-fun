# Import all public functions
Get-ChildItem -Path "$PSScriptRoot\public" -Filter '*.ps1' | ForEach-Object {
    . $_.FullName
}

# Export all function names based on file names
$publicFunctions = Get-ChildItem -Path "$PSScriptRoot\public" -Filter '*.ps1' |
    ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }

Export-ModuleMember -Function $publicFunctions
