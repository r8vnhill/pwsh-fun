function Remove-DirectoryContents {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [Alias('empty')]
    param (
        [Parameter(Position = 0)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string] $Path = (Get-Location).Path,

        [switch] $UseRecycleBin
    )

    $items = Get-ChildItem -Path $Path -Force

    foreach ($item in $items) {
        if ($PSCmdlet.ShouldProcess($item.FullName, 'Delete')) {
            try {
                if ($UseRecycleBin) {
                    # Use Shell COM object to move to Recycle Bin
                    $shell = New-Object -ComObject Shell.Application
                    $folder = $shell.Namespace((Split-Path $item.FullName -Parent))
                    $file = $folder.ParseName($item.Name)
                    $file.InvokeVerb("delete")
                } else {
                    Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                }
                Write-Verbose "Removed: $($item.FullName)"
            }
            catch {
                Write-Warning "Failed to remove: $($item.FullName). $_"
            }
        }
    }
}
