function Move-AndLinkItem {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ })]
        [string] $PathToSymlink,

        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path (Split-Path $_ -Parent) })]
        [string] $PathToContent,

        [switch] $UseJunction,
        [int] $RetryCount = 3
    )

    process {
        $isAdmin = ([System.Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) {
            Write-Error 'Administrator privileges are required to create symbolic links or junctions. Please run PowerShell as Administrator.' -ErrorAction Stop
            return
        }

        try {
            $itemName = Split-Path -Path $PathToSymlink -Leaf
            $destination = Join-Path -Path $PathToContent -ChildPath $itemName

            # Check if destination already exists
            if (Test-Path $destination) {
                Write-Error "Destination already exists: $destination" -ErrorAction Stop
            }

            if ($PSCmdlet.ShouldProcess($PathToSymlink, "Move to $destination")) {
                Write-Verbose "Starting move operation from '$PathToSymlink' to '$destination'"
            
                for ($i = 0; $i -lt $RetryCount; $i++) {
                    try {
                        Move-Item -LiteralPath $PathToSymlink -Destination $destination -Force -ErrorAction Stop
                        Write-Verbose "Moved '$PathToSymlink' to '$destination'"
                        break
                    }
                    catch {
                        if ($i -lt ($RetryCount - 1)) {
                            Write-Verbose "Move failed (attempt $($i+1)/$RetryCount): $_. Retrying in 1 second..."
                            Start-Sleep -Seconds 1
                        }
                        else {
                            throw
                        }
                    }
                }
            }

            if ($PSCmdlet.ShouldProcess($PathToSymlink, "Create link to $destination")) {
                Write-Verbose "Creating link at '$PathToSymlink'"
            
                if ($UseJunction) {
                    cmd /c mklink /J "$PathToSymlink" "$destination" | Out-Null
                    Write-Verbose "Created junction at '$PathToSymlink' pointing to '$destination'"
                }
                else {
                    New-Item -ItemType SymbolicLink -Path $PathToSymlink -Target $destination -Force -ErrorAction Stop | Out-Null
                    Write-Verbose "Created symbolic link at '$PathToSymlink' pointing to '$destination'"
                }
            }

            Write-Host "Successfully moved and linked: $PathToSymlink" -ForegroundColor Green
        }
        catch {
            $errorMsg = $_.Exception.Message
            if ($errorMsg -match 'denied|privilege|access') {
                Write-Error 'Permission denied. Ensure all files are unlocked and you have admin rights.' -ErrorAction Continue
            }
            elseif ($errorMsg -match 'locked|use') {
                Write-Error "Failed - files may be in use by another process. Close any applications accessing these files and try again: $errorMsg" -ErrorAction Continue
            }
            else {
                Write-Error "Failed to move and link: $errorMsg" -ErrorAction Continue
            }
        }
    }
}
