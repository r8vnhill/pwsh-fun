function Move-ToRecycleBin {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.IO.FileSystemInfo] $Item
    )

    try {
        if (-not $Item.Exists) {
            throw "❌ Item does not exist: '$($Item.FullName)'"
        }

        $shell = New-Object -ComObject Shell.Application
        $parentPath = Split-Path -Path $Item.FullName -Parent
        $folder = $shell.Namespace($parentPath)

        if (-not $folder) {
            throw "❌ Failed to access folder: '$parentPath'"
        }

        $file = $folder.ParseName($Item.Name)

        if (-not $file) {
            throw "❌ Could not parse item: '$($Item.Name)' in folder: '$parentPath'"
        }

        $file.InvokeVerb("delete")
        Write-Verbose "🗑️ Moved '$($Item.FullName)' to Recycle Bin."
    } catch {
        throw "❌ Could not move '$($Item.FullName)' to Recycle Bin: $_"
    }
}
