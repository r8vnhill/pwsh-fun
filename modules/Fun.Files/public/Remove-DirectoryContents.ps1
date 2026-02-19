function Remove-DirectoryContents {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [Alias('empty')]
    param (
        [Parameter(Position = 0)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string] $Path = (Get-Location).Path,

        [switch] $UseRecycleBin
    )

    $items = Get-DirectoryItems -Path $Path
    if (-not $items) {
        Write-Verbose "📂 No items found in '$Path'. Nothing to remove."
        return
    }

    foreach ($item in $items) {
        if ($PSCmdlet.ShouldProcess($item.FullName, 'Delete')) {
            Remove-ItemSafely -Item $item -UseRecycleBin:$UseRecycleBin
        }
    }
}

function Remove-ItemSafely {
    param (
        [Parameter(Mandatory)]
        [System.IO.FileSystemInfo] $Item,

        [switch] $UseRecycleBin
    )

    try {
        if ($UseRecycleBin) {
            Move-ToRecycleBin -Item $Item
        } else {
            Remove-Item -LiteralPath $Item.FullName -Recurse -Force -ErrorAction Stop
        }
        Write-Verbose "🗑️ Removed: $($Item.FullName)"
    } catch {
        Write-Warning "⚠️ Failed to remove: $($Item.FullName). $_"
    }
}
