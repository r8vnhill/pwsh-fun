function Show-FilteredTree {
    param(
        [string]$Path = ".",
        [string[]]$Include = "*",
        [int]$Indent = 0
    )

    $folders = Get-ChildItem -Path $Path -Directory -Force |
        Where-Object { $Include -contains "*" -or $_.Name -in $Include }

    foreach ($folder in $folders) {
        Write-Host (" " * $Indent) + "|-- " + $folder.Name
        Show-FilteredTree -Path $folder.FullName -Include $Include -Indent ($Indent + 4)
    }
}
