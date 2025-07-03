# Discover and import all public .ps1 scripts and collect function names
$publicFunctions = foreach (
    $script in Get-ChildItem -Path "$PSScriptRoot\public" -Filter '*.ps1'
) {
    . $script.FullName
    [System.IO.Path]::GetFileNameWithoutExtension($script.Name)
}

# Export all discovered functions
Export-ModuleMember -Function $publicFunctions
