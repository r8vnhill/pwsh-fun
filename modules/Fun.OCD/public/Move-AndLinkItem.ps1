function Move-AndLinkItem {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ })]
        [string] $PathToSymlink,

        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path (Split-Path $_ -Parent) })]
        [string] $PathToContent
    )

    try {
        $itemName = Split-Path -Path $PathToSymlink -Leaf
        $destination = Join-Path -Path $PathToContent -ChildPath $itemName

        if ($PSCmdlet.ShouldProcess($PathToSymlink, "Move to $destination")) {
            Move-Item -LiteralPath $PathToSymlink -Destination $destination -Force
            Write-Verbose "Moved '$PathToSymlink' to '$destination'"
        }

        if ($PSCmdlet.ShouldProcess($PathToSymlink, "Create symbolic link to $destination")) {
            New-Item -ItemType SymbolicLink -Path $PathToSymlink -Target $destination -Force
            Write-Verbose "Created symbolic link at '$PathToSymlink' pointing to '$destination'"
        }
    }
    catch {
        Write-Error "Failed to move and link: $_"
    }
}
