function Test-MoveAndLinkAdministrator {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $principal = [System.Security.Principal.WindowsPrincipal]::new(
        [System.Security.Principal.WindowsIdentity]::GetCurrent())

    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Resolve-MoveAndLinkPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [ValidateSet('Any', 'Leaf', 'Container')]
        [string] $PathType = 'Any',

        [switch] $RequireExists
    )

    if ($RequireExists) {
        $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
        $resolvedPath = $resolved.ProviderPath

        switch ($PathType) {
            'Leaf' {
                if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
                    throw [System.IO.FileNotFoundException]::new("Expected a file path: $Path")
                }
            }
            'Container' {
                if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
                    throw [System.IO.DirectoryNotFoundException]::new("Expected a directory path: $Path")
                }
            }
        }

        return [System.IO.Path]::GetFullPath($resolvedPath)
    }

    return [System.IO.Path]::GetFullPath($Path)
}

function Get-MoveAndLinkItemKind {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath
    )

    $item = Get-Item -LiteralPath $LiteralPath -Force -ErrorAction Stop
    if ($item.PSIsContainer) {
        return 'Directory'
    }

    return 'File'
}

function Test-MoveAndLinkLockRelatedError {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [System.Exception] $Exception
    )

    $message = $Exception.Message

    return (
        $Exception -is [System.UnauthorizedAccessException] -or
        $Exception -is [System.IO.IOException] -or
        $message -match 'being used by another process' -or
        $message -match 'process cannot access the file' -or
        $message -match 'access to the path.*denied' -or
        $message -match 'sharing violation' -or
        $message -match 'used by another process'
    )
}

function Get-MoveAndLinkBlockingProcesses {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Path
    )

    $handleCommand = Get-Command -Name 'handle.exe' -ErrorAction SilentlyContinue
    if (-not $handleCommand) {
        return @()
    }

    $results = New-Object 'System.Collections.Generic.List[object]'
    foreach ($candidatePath in $Path) {
        if ([string]::IsNullOrWhiteSpace($candidatePath)) {
            continue
        }

        try {
            $rawOutput = & $handleCommand.Source -nobanner -vt $candidatePath 2>$null
            if (-not $rawOutput) {
                continue
            }

            if ($rawOutput -is [string]) {
                $rawOutput = @($rawOutput)
            }

            if ($rawOutput[0] -match 'No matching handles found') {
                continue
            }

            if ($rawOutput[0] -notmatch ',') {
                continue
            }

            $records = $rawOutput | ConvertFrom-Csv
            foreach ($record in $records) {
                $propertyNames = $record.PSObject.Properties.Name
                $pidProperty = $propertyNames | Where-Object { $_ -match '^(PID|ProcessId|Id)$' } | Select-Object -First 1
                $processProperty = $propertyNames | Where-Object { $_ -match '^(Process|Image|ProcessName)$' } | Select-Object -First 1
                $pathProperty = $propertyNames | Where-Object { $_ -match '^(Name|Path|Object)$' } | Select-Object -First 1

                if (-not $pidProperty -or -not $processProperty) {
                    continue
                }

                $pidValue = $record.$pidProperty
                $processName = $record.$processProperty
                $matchedPath = if ($pathProperty) { $record.$pathProperty } else { $candidatePath }

                if (-not $pidValue -or -not $processName) {
                    continue
                }

                $results.Add([pscustomobject]@{
                        Id          = [int] $pidValue
                        ProcessName = [string] $processName
                        Path        = [string] $matchedPath
                    })
            }
        }
        catch {
            Write-Verbose "Failed to inspect locks for '$candidatePath': $($_.Exception.Message)"
        }
    }

    return @(
        $results |
            Sort-Object -Property Id, ProcessName, Path -Unique
    )
}

function Move-MoveAndLinkItemWithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SourcePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $DestinationPath,

        [ValidateRange(1, [int]::MaxValue)]
        [int] $RetryCount = 3
    )

    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            Move-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force -ErrorAction Stop
            return
        }
        catch {
            if ($attempt -ge $RetryCount) {
                throw
            }

            $delayMs = [Math]::Min(200 * [Math]::Pow(2, $attempt - 1), 2000)
            Write-Verbose "Move failed ($attempt/$RetryCount) from '$SourcePath' to '$DestinationPath': $($_.Exception.Message). Retrying in $delayMs ms."
            Start-Sleep -Milliseconds ([int] $delayMs)
        }
    }
}

function New-MoveAndLinkReference {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LinkPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $TargetPath,

        [Parameter(Mandatory)]
        [ValidateSet('SymbolicLink', 'Junction')]
        [string] $LinkType
    )

    New-Item -ItemType $LinkType -Path $LinkPath -Target $TargetPath -Force -ErrorAction Stop | Out-Null
}

function Remove-MoveAndLinkPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath
    )

    if (Test-Path -LiteralPath $LiteralPath) {
        Remove-Item -LiteralPath $LiteralPath -Force -Recurse -ErrorAction Stop
    }
}

function New-MoveAndLinkErrorRecord {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ErrorId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Message,

        [Parameter(Mandatory)]
        [System.Exception] $InnerException,

        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorCategory] $Category,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $TargetObject,

        [Parameter(Mandatory)]
        [hashtable] $Data
    )

    $exception = [System.InvalidOperationException]::new($Message, $InnerException)
    foreach ($key in $Data.Keys) {
        $exception.Data[$key] = $Data[$key]
    }

    return [System.Management.Automation.ErrorRecord]::new(
        $exception,
        $ErrorId,
        $Category,
        $TargetObject
    )
}

function Invoke-MoveAndLinkRollback {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SourcePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $DestinationPath,

        [ValidateRange(1, [int]::MaxValue)]
        [int] $RetryCount = 1
    )

    if (Test-Path -LiteralPath $SourcePath) {
        Remove-MoveAndLinkPath -LiteralPath $SourcePath
    }

    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        return $false
    }

    Move-MoveAndLinkItemWithRetry -SourcePath $DestinationPath -DestinationPath $SourcePath -RetryCount $RetryCount
    return $true
}

function Move-AndLinkItem {
    <#
    .SYNOPSIS
    Moves an item to another root and leaves a link behind at the original path.

    .DESCRIPTION
    Use this command to relocate a file or directory while preserving the original
    path through a symbolic link or junction. For directory moves on Windows,
    `-UseJunction` avoids the administrator requirement of symbolic links.

    .PARAMETER PathToSymlink
    Existing file or directory that will be moved and replaced by a link.

    .PARAMETER PathToContent
    Existing destination directory that will receive the moved item.

    .PARAMETER UseJunction
    Creates a junction instead of a symbolic link. Junctions only work for
    directories.

    .PARAMETER RetryCount
    Number of retry attempts when the move operation temporarily fails.

    .EXAMPLE
    Move-AndLinkItem `
        -PathToSymlink 'C:\Users\usuario\AppData\Local\ms-playwright' `
        -PathToContent 'B:\Dev-Cache' `
        -UseJunction

    Moves the Playwright browser cache to `B:\Dev-Cache\ms-playwright` and leaves
    a junction at the original path.

    .EXAMPLE
    $paths = @(
        'C:\Users\usuario\AppData\Local\ms-playwright',
        'C:\Users\usuario\AppData\Local\pnpm',
        'C:\Users\usuario\AppData\Local\pnpm-cache',
        'C:\Users\usuario\AppData\Local\uv',
        'C:\Users\usuario\AppData\Local\Coursier',
        'C:\Users\usuario\AppData\Local\cabal'
    )
    $destinationRoot = 'B:\Dev-Cache'

    foreach ($path in $paths) {
        Move-AndLinkItem -PathToSymlink $path -PathToContent $destinationRoot -UseJunction
    }

    Useful for reclaiming space on `C:` by moving development caches and package
    managers to another drive while keeping tools working with the same paths.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PathToSymlink,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PathToContent,

        [switch] $UseJunction,

        [ValidateRange(1, [int]::MaxValue)]
        [int] $RetryCount = 3
    )

    process {
        $sourcePath = $null
        $destinationRoot = $null
        $destinationPath = $null
        $itemKind = $null
        $linkType = if ($UseJunction) { 'Junction' } else { 'SymbolicLink' }
        $rollbackAttempted = $false
        $rollbackSucceeded = $false

        try {
            if (-not $IsWindows) {
                throw [System.PlatformNotSupportedException]::new('Move-AndLinkItem is supported only on Windows.')
            }

            $sourcePath = Resolve-MoveAndLinkPath -Path $PathToSymlink -RequireExists
            $destinationRoot = Resolve-MoveAndLinkPath -Path $PathToContent -PathType Container -RequireExists
            $itemKind = Get-MoveAndLinkItemKind -LiteralPath $sourcePath
            $destinationPath = Join-Path -Path $destinationRoot -ChildPath (Split-Path -Path $sourcePath -Leaf)

            if (Test-Path -LiteralPath $destinationPath) {
                throw [System.IO.IOException]::new("Destination already exists: $destinationPath")
            }

            if ($UseJunction -and $itemKind -ne 'Directory') {
                throw [System.ArgumentException]::new('Junctions can only target directories.')
            }

            $moveAction = "Move item to '$destinationPath'"
            $linkAction = "Create $linkType at '$sourcePath' targeting '$destinationPath'"

            $shouldMove = $PSCmdlet.ShouldProcess($sourcePath, $moveAction)
            $shouldLink = $PSCmdlet.ShouldProcess($sourcePath, $linkAction)
            if (-not $shouldMove -or -not $shouldLink) {
                return
            }

            if (-not $UseJunction -and -not (Test-MoveAndLinkAdministrator)) {
                throw [System.UnauthorizedAccessException]::new(
                    'Administrator privileges are required to create symbolic links. Please run PowerShell as Administrator.')
            }
        }
        catch {
            $caughtException = if ($_ -is [System.Management.Automation.ErrorRecord]) {
                $_.Exception
            }
            elseif ($_ -is [System.Exception]) {
                $_
            }
            else {
                [System.Exception]::new([string]$_)
            }

            $preflightPath = if ($destinationPath) { $destinationPath } elseif ($sourcePath) { $sourcePath } else { $PathToSymlink }
            $preflightData = @{
                SourcePath        = $sourcePath
                DestinationPath   = $destinationPath
                LinkType          = $linkType
                RetryCount        = $RetryCount
                RollbackAttempted = $false
                RollbackSucceeded = $false
                BlockingProcesses = @()
            }

            $category = switch -Regex ($caughtException.GetType().FullName) {
                'PlatformNotSupportedException' { [System.Management.Automation.ErrorCategory]::NotImplemented; break }
                'UnauthorizedAccessException' { [System.Management.Automation.ErrorCategory]::PermissionDenied; break }
                'ArgumentException' { [System.Management.Automation.ErrorCategory]::InvalidArgument; break }
                default {
                    if ($caughtException.Message -match '^Destination already exists:') {
                        [System.Management.Automation.ErrorCategory]::ResourceExists
                    }
                    else {
                        [System.Management.Automation.ErrorCategory]::InvalidOperation
                    }
                }
            }

            $preflightError = New-MoveAndLinkErrorRecord `
                -ErrorId 'MoveAndLinkItem.PreflightFailed' `
                -Message $caughtException.Message `
                -InnerException $caughtException `
                -Category $category `
                -TargetObject $preflightPath `
                -Data $preflightData

            $PSCmdlet.ThrowTerminatingError($preflightError)
        }

        try {
            Write-Verbose "Moving '$sourcePath' to '$destinationPath'"
            Move-MoveAndLinkItemWithRetry -SourcePath $sourcePath -DestinationPath $destinationPath -RetryCount $RetryCount
            Write-Verbose "Creating $linkType at '$sourcePath' targeting '$destinationPath'"
            New-MoveAndLinkReference -LinkPath $sourcePath -TargetPath $destinationPath -LinkType $linkType
            Write-Verbose "Move-AndLinkItem completed successfully for '$sourcePath'"
        }
        catch {
            $caughtException = if ($_ -is [System.Management.Automation.ErrorRecord]) {
                $_.Exception
            }
            elseif ($_ -is [System.Exception]) {
                $_
            }
            else {
                [System.Exception]::new([string]$_)
            }

            $stage = if (Test-Path -LiteralPath $destinationPath) { 'Link' } else { 'Move' }
            $rollbackInnerException = $null
            $blockingProcesses = @()

            if ($stage -eq 'Link' -and (Test-Path -LiteralPath $destinationPath)) {
                $rollbackAttempted = $true
                try {
                    $rollbackSucceeded = Invoke-MoveAndLinkRollback -SourcePath $sourcePath -DestinationPath $destinationPath -RetryCount $RetryCount
                    Write-Verbose "Rollback succeeded for '$sourcePath'"
                }
                catch {
                    $rollbackSucceeded = $false
                    $rollbackInnerException = $_.Exception
                    Write-Verbose "Rollback failed for '$sourcePath': $($rollbackInnerException.Message)"
                }
            }

            if (Test-MoveAndLinkLockRelatedError -Exception $caughtException) {
                $blockingProcesses = @(Get-MoveAndLinkBlockingProcesses -Path @($sourcePath, $destinationPath))
                if ($blockingProcesses.Count -gt 0) {
                    $pidList = ($blockingProcesses | Select-Object -ExpandProperty Id -Unique) -join ', '
                    Write-Verbose "Blocking processes detected for '$sourcePath': $pidList"
                }
            }

            $errorData = @{
                SourcePath        = $sourcePath
                DestinationPath   = $destinationPath
                LinkType          = $linkType
                RetryCount        = $RetryCount
                RollbackAttempted = $rollbackAttempted
                RollbackSucceeded = $rollbackSucceeded
                BlockingProcesses = $blockingProcesses
            }

            if ($rollbackInnerException) {
                $errorData['RollbackError'] = $rollbackInnerException.Message
            }

            $message = switch ($stage) {
                'Move' { "Failed to move '$sourcePath' to '$destinationPath'. $($caughtException.Message)" }
                'Link' {
                    if ($rollbackAttempted -and $rollbackSucceeded) {
                        "Failed to create $linkType at '$sourcePath'. Rollback restored the original item. $($caughtException.Message)"
                    }
                    elseif ($rollbackAttempted) {
                        "Failed to create $linkType at '$sourcePath', and rollback failed. $($caughtException.Message)"
                    }
                    else {
                        "Failed to create $linkType at '$sourcePath'. $($caughtException.Message)"
                    }
                }
            }

            $category = if (@($blockingProcesses).Count -gt 0) {
                [System.Management.Automation.ErrorCategory]::ResourceBusy
            }
            else {
                [System.Management.Automation.ErrorCategory]::WriteError
            }

            $errorId = if ($stage -eq 'Move') { 'MoveAndLinkItem.MoveFailed' } else { 'MoveAndLinkItem.LinkFailed' }
            if ($rollbackAttempted -and -not $rollbackSucceeded) {
                $errorId = 'MoveAndLinkItem.RollbackFailed'
            }

            $outerException = if ($rollbackInnerException) {
                [System.AggregateException]::new($message, @($caughtException, $rollbackInnerException))
            }
            else {
                $caughtException
            }

            $errorRecord = New-MoveAndLinkErrorRecord `
                -ErrorId $errorId `
                -Message $message `
                -InnerException $outerException `
                -Category $category `
                -TargetObject $(if ($stage -eq 'Move') { $sourcePath } else { $destinationPath }) `
                -Data $errorData

            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }
}
