#Requires -Version 7.4
#Requires -Modules Pester

BeforeAll {
    . "$PSScriptRoot\..\..\modules\Fun.OCD\public\Move-AndLinkItem.ps1"

    function New-MoveAndLinkTestRoot {
        $root = Join-Path $TestDrive ([guid]::NewGuid().Guid)
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        return $root
    }
}

Describe 'Move-AndLinkItem' {
    BeforeEach {
        Mock -CommandName Test-MoveAndLinkAdministrator -MockWith { $true }
    }

    It 'moves a file and recreates the source path when link creation succeeds' {
        $testRoot = New-MoveAndLinkTestRoot
        $sourceDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'source') -Force
        $contentDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'content') -Force
        $sourcePath = Join-Path $sourceDir.FullName 'sample.txt'
        $destinationPath = Join-Path $contentDir.FullName 'sample.txt'

        Set-Content -LiteralPath $sourcePath -Value 'payload'

        Mock -CommandName New-MoveAndLinkReference -MockWith {
            param(
                [string] $LinkPath,
                [string] $TargetPath,
                [string] $LinkType
            )

            Set-Content -LiteralPath $LinkPath -Value "$LinkType -> $TargetPath"
        }

        Move-AndLinkItem -PathToSymlink $sourcePath -PathToContent $contentDir.FullName -Confirm:$false

        Test-Path -LiteralPath $destinationPath -PathType Leaf | Should -BeTrue
        Get-Content -LiteralPath $destinationPath | Should -Be 'payload'
        Test-Path -LiteralPath $sourcePath -PathType Leaf | Should -BeTrue
        Get-Content -LiteralPath $sourcePath | Should -Be "SymbolicLink -> $destinationPath"
        Assert-MockCalled New-MoveAndLinkReference -Times 1 -Exactly -ParameterFilter {
            $LinkPath -eq $sourcePath -and
            $TargetPath -eq $destinationPath -and
            $LinkType -eq 'SymbolicLink'
        }
    }

    It 'moves a directory and recreates the source path when junction creation succeeds' {
        $testRoot = New-MoveAndLinkTestRoot
        $sourceDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'library') -Force
        $contentDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'archive') -Force
        $movedDirName = 'album'
        $sourcePath = Join-Path $sourceDir.FullName $movedDirName
        $destinationPath = Join-Path $contentDir.FullName $movedDirName

        $null = New-Item -ItemType Directory -Path $sourcePath -Force
        Set-Content -LiteralPath (Join-Path $sourcePath 'track.txt') -Value 'song'

        Mock -CommandName New-MoveAndLinkReference -MockWith {
            param(
                [string] $LinkPath,
                [string] $TargetPath,
                [string] $LinkType
            )

            New-Item -ItemType Directory -Path $LinkPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $LinkPath 'junction.txt') -Value "$LinkType -> $TargetPath"
        }

        Move-AndLinkItem -PathToSymlink $sourcePath -PathToContent $contentDir.FullName -UseJunction -Confirm:$false

        Test-Path -LiteralPath $destinationPath -PathType Container | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $destinationPath 'track.txt') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $sourcePath -PathType Container | Should -BeTrue
        Get-Content -LiteralPath (Join-Path $sourcePath 'junction.txt') | Should -Be "Junction -> $destinationPath"
        Assert-MockCalled New-MoveAndLinkReference -Times 1 -Exactly -ParameterFilter {
            $LinkPath -eq $sourcePath -and
            $TargetPath -eq $destinationPath -and
            $LinkType -eq 'Junction'
        }
    }

    It 'fails in preflight when the destination already exists and leaves the source untouched' {
        $testRoot = New-MoveAndLinkTestRoot
        $sourceDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'source') -Force
        $contentDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'content') -Force
        $sourcePath = Join-Path $sourceDir.FullName 'sample.txt'
        $destinationPath = Join-Path $contentDir.FullName 'sample.txt'

        Set-Content -LiteralPath $sourcePath -Value 'payload'
        Set-Content -LiteralPath $destinationPath -Value 'occupied'

        try {
            Move-AndLinkItem -PathToSymlink $sourcePath -PathToContent $contentDir.FullName -Confirm:$false
            throw 'Expected Move-AndLinkItem to fail.'
        }
        catch {
            $_.FullyQualifiedErrorId | Should -BeLike 'MoveAndLinkItem.PreflightFailed*'
            $_.Exception.Data['DestinationPath'] | Should -Be $destinationPath
            $_.Exception.Data['RollbackAttempted'] | Should -BeFalse
        }

        Get-Content -LiteralPath $sourcePath | Should -Be 'payload'
        Get-Content -LiteralPath $destinationPath | Should -Be 'occupied'
    }

    It 'fails in preflight when the destination directory does not exist' {
        $testRoot = New-MoveAndLinkTestRoot
        $sourceDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'source') -Force
        $sourcePath = Join-Path $sourceDir.FullName 'sample.txt'
        $missingDir = Join-Path $testRoot 'missing'

        Set-Content -LiteralPath $sourcePath -Value 'payload'

        try {
            Move-AndLinkItem -PathToSymlink $sourcePath -PathToContent $missingDir -Confirm:$false
            throw 'Expected Move-AndLinkItem to fail.'
        }
        catch {
            $_.FullyQualifiedErrorId | Should -BeLike 'MoveAndLinkItem.PreflightFailed*'
            $_.Exception.Data['DestinationPath'] | Should -Be $null
        }

        Test-Path -LiteralPath $sourcePath -PathType Leaf | Should -BeTrue
    }

    It 'fails in preflight when UseJunction targets a file' {
        $testRoot = New-MoveAndLinkTestRoot
        $sourceDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'source') -Force
        $contentDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'content') -Force
        $sourcePath = Join-Path $sourceDir.FullName 'sample.txt'

        Set-Content -LiteralPath $sourcePath -Value 'payload'

        try {
            Move-AndLinkItem -PathToSymlink $sourcePath -PathToContent $contentDir.FullName -UseJunction -Confirm:$false
            throw 'Expected Move-AndLinkItem to fail.'
        }
        catch {
            $_.FullyQualifiedErrorId | Should -BeLike 'MoveAndLinkItem.PreflightFailed*'
            $_.CategoryInfo.Category | Should -Be 'InvalidArgument'
        }

        Test-Path -LiteralPath $sourcePath -PathType Leaf | Should -BeTrue
    }

    It 'allows junction creation without administrator privileges' {
        $testRoot = New-MoveAndLinkTestRoot
        $sourceDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'source') -Force
        $contentDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'content') -Force
        $sourcePath = Join-Path $sourceDir.FullName 'folder'
        $destinationPath = Join-Path $contentDir.FullName 'folder'

        $null = New-Item -ItemType Directory -Path $sourcePath -Force
        Set-Content -LiteralPath (Join-Path $sourcePath 'payload.txt') -Value 'payload'

        Mock -CommandName Test-MoveAndLinkAdministrator -MockWith { $false }
        Mock -CommandName New-MoveAndLinkReference -MockWith {
            param(
                [string] $LinkPath,
                [string] $TargetPath,
                [string] $LinkType
            )

            New-Item -ItemType Directory -Path $LinkPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $LinkPath 'junction.txt') -Value "$LinkType -> $TargetPath"
        }

        Move-AndLinkItem -PathToSymlink $sourcePath -PathToContent $contentDir.FullName -UseJunction -Confirm:$false

        Test-Path -LiteralPath $destinationPath -PathType Container | Should -BeTrue
        Get-Content -LiteralPath (Join-Path $sourcePath 'junction.txt') | Should -Be "Junction -> $destinationPath"
        Assert-MockCalled Test-MoveAndLinkAdministrator -Times 0 -Exactly
    }

    It 'still requires administrator privileges for symbolic links' {
        $testRoot = New-MoveAndLinkTestRoot
        $sourceDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'source') -Force
        $contentDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'content') -Force
        $sourcePath = Join-Path $sourceDir.FullName 'sample.txt'

        Set-Content -LiteralPath $sourcePath -Value 'payload'
        Mock -CommandName Test-MoveAndLinkAdministrator -MockWith { $false }

        try {
            Move-AndLinkItem -PathToSymlink $sourcePath -PathToContent $contentDir.FullName -Confirm:$false
            throw 'Expected Move-AndLinkItem to fail.'
        }
        catch {
            $_.FullyQualifiedErrorId | Should -BeLike 'MoveAndLinkItem.PreflightFailed*'
            $_.CategoryInfo.Category | Should -Be 'PermissionDenied'
            $_.Exception.Message | Should -Match 'Administrator privileges are required to create symbolic links'
        }

        Test-Path -LiteralPath $sourcePath -PathType Leaf | Should -BeTrue
    }

    It 'rolls back when link creation fails after the move' {
        $testRoot = New-MoveAndLinkTestRoot
        $sourceDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'source') -Force
        $contentDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'content') -Force
        $sourcePath = Join-Path $sourceDir.FullName 'sample.txt'
        $destinationPath = Join-Path $contentDir.FullName 'sample.txt'

        Set-Content -LiteralPath $sourcePath -Value 'payload'

        Mock -CommandName New-MoveAndLinkReference -MockWith {
            param([string] $LinkPath)
            Set-Content -LiteralPath $LinkPath -Value 'partial-link'
            throw [System.IO.IOException]::new('The process cannot access the file because it is being used by another process.')
        }

        Mock -CommandName Get-MoveAndLinkBlockingProcesses -MockWith {
            @([pscustomobject]@{
                    Id          = 4242
                    ProcessName = 'lock-holder'
                    Path        = $destinationPath
                })
        }

        try {
            Move-AndLinkItem -PathToSymlink $sourcePath -PathToContent $contentDir.FullName -Confirm:$false
            throw 'Expected Move-AndLinkItem to fail.'
        }
        catch {
            $_.FullyQualifiedErrorId | Should -BeLike 'MoveAndLinkItem.LinkFailed*'
            $_.Exception.Data['RollbackAttempted'] | Should -BeTrue
            $_.Exception.Data['RollbackSucceeded'] | Should -BeTrue
            $_.Exception.Data['BlockingProcesses'].Count | Should -Be 1
            $_.Exception.Data['BlockingProcesses'][0].Id | Should -Be 4242
        }

        Test-Path -LiteralPath $sourcePath -PathType Leaf | Should -BeTrue
        Get-Content -LiteralPath $sourcePath | Should -Be 'payload'
        Test-Path -LiteralPath $destinationPath | Should -BeFalse
    }

    It 'reports rollback failure and leaves partial state visible' {
        $testRoot = New-MoveAndLinkTestRoot
        $sourceDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'source') -Force
        $contentDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'content') -Force
        $sourcePath = Join-Path $sourceDir.FullName 'sample.txt'
        $destinationPath = Join-Path $contentDir.FullName 'sample.txt'

        Set-Content -LiteralPath $sourcePath -Value 'payload'

        Mock -CommandName New-MoveAndLinkReference -MockWith {
            throw [System.IO.IOException]::new('sharing violation')
        }

        Mock -CommandName Invoke-MoveAndLinkRollback -MockWith {
            throw [System.IO.IOException]::new('rollback blocked')
        }

        Mock -CommandName Get-MoveAndLinkBlockingProcesses -MockWith { @() }

        try {
            Move-AndLinkItem -PathToSymlink $sourcePath -PathToContent $contentDir.FullName -Confirm:$false
            throw 'Expected Move-AndLinkItem to fail.'
        }
        catch {
            $_.FullyQualifiedErrorId | Should -BeLike 'MoveAndLinkItem.RollbackFailed*'
            $_.Exception.Data['RollbackAttempted'] | Should -BeTrue
            $_.Exception.Data['RollbackSucceeded'] | Should -BeFalse
            $_.Exception.Data['RollbackError'] | Should -Be 'rollback blocked'
        }

        Test-Path -LiteralPath $sourcePath | Should -BeFalse
        Test-Path -LiteralPath $destinationPath -PathType Leaf | Should -BeTrue
    }

    It 'does not fabricate blocking processes when handle.exe is unavailable' {
        Mock -CommandName Get-Command -ParameterFilter { $Name -eq 'handle.exe' } -MockWith { $null }

        $blocking = Get-MoveAndLinkBlockingProcesses -Path 'C:\temp\missing.txt'

        @($blocking).Count | Should -Be 0
    }

    It 'enriches move errors with blocking process ids when available' {
        $testRoot = New-MoveAndLinkTestRoot
        $sourceDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'source') -Force
        $contentDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'content') -Force
        $sourcePath = Join-Path $sourceDir.FullName 'sample.txt'

        Set-Content -LiteralPath $sourcePath -Value 'payload'

        Mock -CommandName Move-MoveAndLinkItemWithRetry -MockWith {
            throw [System.IO.IOException]::new('being used by another process')
        }

        Mock -CommandName Get-MoveAndLinkBlockingProcesses -MockWith {
            @(
                [pscustomobject]@{ Id = 11; ProcessName = 'alpha'; Path = $sourcePath },
                [pscustomobject]@{ Id = 22; ProcessName = 'beta'; Path = $sourcePath }
            )
        }

        try {
            Move-AndLinkItem -PathToSymlink $sourcePath -PathToContent $contentDir.FullName -Confirm:$false
            throw 'Expected Move-AndLinkItem to fail.'
        }
        catch {
            $_.FullyQualifiedErrorId | Should -BeLike 'MoveAndLinkItem.MoveFailed*'
            $_.CategoryInfo.Category | Should -Be 'ResourceBusy'
            ($_.Exception.Data['BlockingProcesses'] | Select-Object -ExpandProperty Id) | Should -Be @(11, 22)
        }
    }

    It 'handles a single blocking process object without failing on Count' {
        $testRoot = New-MoveAndLinkTestRoot
        $sourceDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'source') -Force
        $contentDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'content') -Force
        $sourcePath = Join-Path $sourceDir.FullName 'sample.txt'

        Set-Content -LiteralPath $sourcePath -Value 'payload'

        Mock -CommandName Move-MoveAndLinkItemWithRetry -MockWith {
            throw [System.IO.IOException]::new('being used by another process')
        }

        Mock -CommandName Get-MoveAndLinkBlockingProcesses -MockWith {
            [pscustomobject]@{ Id = 99; ProcessName = 'single-locker'; Path = $sourcePath }
        }

        try {
            Move-AndLinkItem -PathToSymlink $sourcePath -PathToContent $contentDir.FullName -Confirm:$false
            throw 'Expected Move-AndLinkItem to fail.'
        }
        catch {
            $_.FullyQualifiedErrorId | Should -BeLike 'MoveAndLinkItem.MoveFailed*'
            $_.CategoryInfo.Category | Should -Be 'ResourceBusy'
            @($_.Exception.Data['BlockingProcesses']).Count | Should -Be 1
            @($_.Exception.Data['BlockingProcesses'])[0].Id | Should -Be 99
        }
    }

    It 'honors WhatIf without moving or linking anything' {
        $testRoot = New-MoveAndLinkTestRoot
        $sourceDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'source') -Force
        $contentDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'content') -Force
        $sourcePath = Join-Path $sourceDir.FullName 'sample.txt'
        $destinationPath = Join-Path $contentDir.FullName 'sample.txt'

        Set-Content -LiteralPath $sourcePath -Value 'payload'

        Mock -CommandName Move-MoveAndLinkItemWithRetry
        Mock -CommandName New-MoveAndLinkReference

        Move-AndLinkItem -PathToSymlink $sourcePath -PathToContent $contentDir.FullName -WhatIf -Confirm:$false

        Assert-MockCalled Move-MoveAndLinkItemWithRetry -Times 0 -Exactly
        Assert-MockCalled New-MoveAndLinkReference -Times 0 -Exactly
        Test-Path -LiteralPath $sourcePath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $destinationPath | Should -BeFalse
    }
}
