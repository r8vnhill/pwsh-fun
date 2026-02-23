#Requires -Version 7.0
Set-StrictMode -Version 3.0

function Invoke-StorageScan {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Path = 'B',

        [Parameter(Mandatory = $false)]
        [string]$OutputFile = 'drive-scan.json',

        [Parameter(Mandatory = $false)]
        [switch]$HashDuplicates,

        [Parameter(Mandatory = $false)]
        [switch]$SkipLargeFileSearch,

        [Parameter(Mandatory = $false)]
        [switch]$EnableNetworkDeepScan,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 1000)]
        [int]$TopFileCount = 50,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 500)]
        [int]$TopFolderCount = 20,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 10)]
        [int]$OldYears = 1,

        [Parameter(Mandatory = $false)]
        [ValidateSet('LastAccessTime', 'LastWriteTime')]
        [string]$OldFileTimestamp = 'LastWriteTime',

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 10240)]
        [int]$DuplicateSizeThresholdMB = 100
    )

    function Add-CheckResult {
        param(
            [System.Collections.Generic.List[object]]$Checks,
            [Parameter(Mandatory = $true)][string]$Name,
            [Parameter(Mandatory = $true)][string]$Status,
            [Parameter(Mandatory = $true)][System.Diagnostics.Stopwatch]$Stopwatch,
            [string]$Notes = $null
        )

        $Checks.Add([pscustomobject]@{
            name       = $Name
            status     = $Status
            durationMs = $Stopwatch.ElapsedMilliseconds
            notes      = $Notes
        })
    }

    function Get-TargetPath {
        param([string]$PathSpec)

        if ([string]::IsNullOrWhiteSpace($PathSpec)) {
            return $null
        }

        $candidate = $PathSpec.Trim()

        if ($candidate -match '^[A-Za-z]$') {
            $candidate = '{0}:\' -f $candidate
        } elseif ($candidate -match '^[A-Za-z]:$') {
            $candidate = '{0}\' -f $candidate
        }

        try {
            if (-not (Test-Path -LiteralPath $candidate -ErrorAction SilentlyContinue)) {
                return $null
            }

            $item = Get-Item -LiteralPath $candidate -Force -ErrorAction Stop
            return $item.FullName
        } catch {
            return $null
        }
    }

    function Safe-GetFiles {
        param([string]$TargetPath)
        try {
            Get-ChildItem -LiteralPath $TargetPath -Recurse -File -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "File enumeration failed for '$TargetPath': $($_.Exception.Message)"
            @()
        }
    }

    function Get-TopFolderSizes {
        param(
            [string]$RootPath,
            [object[]]$Files,
            [int]$Count
        )

        $folderTotals = @{}
        $normalizedRoot = [System.IO.Path]::TrimEndingDirectorySeparator($RootPath)
        $separator = [System.IO.Path]::DirectorySeparatorChar

        foreach ($file in $Files) {
            $fileDir = Split-Path -Path $file.FullName -Parent
            if ([string]::IsNullOrEmpty($fileDir)) {
                continue
            }

            $normalizedFileDir = [System.IO.Path]::TrimEndingDirectorySeparator($fileDir)
            $relative = $normalizedFileDir.Substring([Math]::Min($normalizedRoot.Length, $normalizedFileDir.Length)).TrimStart($separator)

            if ([string]::IsNullOrWhiteSpace($relative)) {
                $bucketPath = $normalizedRoot
            } else {
                $firstSegment = $relative.Split($separator)[0]
                $bucketPath = Join-Path -Path $normalizedRoot -ChildPath $firstSegment
            }

            if (-not $folderTotals.ContainsKey($bucketPath)) {
                $folderTotals[$bucketPath] = [long]0
            }
            $folderTotals[$bucketPath] += [long]$file.Length
        }

        $folderTotals.GetEnumerator() |
            ForEach-Object {
                [pscustomobject]@{
                    path      = $_.Key
                    sizeBytes = [long]$_.Value
                }
            } |
            Sort-Object -Property sizeBytes -Descending |
            Select-Object -First $Count
    }

    function Resolve-OutputPath {
        param([string]$PathSpec)
        if ([System.IO.Path]::IsPathRooted($PathSpec)) {
            return [System.IO.Path]::GetFullPath($PathSpec)
        }
        return [System.IO.Path]::GetFullPath((Join-Path -Path (Get-Location).Path -ChildPath $PathSpec))
    }

    $scanPath = Get-TargetPath -PathSpec $Path
    if ($null -eq $scanPath) {
        Write-Warning "Invalid or non-existing path spec: $Path"
        return $null
    }

    $isUncPath = $scanPath.StartsWith('\\')
    $skipOldFiles = $false
    $skipDuplicateDetection = $false

    if ($isUncPath -and -not $EnableNetworkDeepScan.IsPresent) {
        if (-not $SkipLargeFileSearch.IsPresent) {
            $SkipLargeFileSearch = $true
            Write-Warning 'UNC path detected: large extension scan disabled by default. Use -EnableNetworkDeepScan to enable.'
        }
        $skipOldFiles = $true
        $skipDuplicateDetection = $true
        Write-Warning 'UNC path detected: old-file and duplicate checks disabled by default. Use -EnableNetworkDeepScan to enable.'
    }

    Write-Verbose "Starting scan for '$scanPath'"

    $checksPerformed = [System.Collections.Generic.List[object]]::new()
    $result = [ordered]@{
        generatedAt             = (Get-Date).ToString('o')
        path                    = $scanPath
        isUncPath               = $isUncPath
        totalSpaceBytes         = $null
        freeSpaceBytes          = $null
        topFiles                = @()
        topFolders              = @()
        recycleBinSizeBytes     = $null
        tempLocations           = @()
        systemRestoreUsageBytes = $null
        shadowCopies            = @()
        windowsOldPresent       = $false
        windowsOldSizeBytes     = $null
        largeVMFiles            = @()
        isoArchives             = @()
        oldFilesCandidates      = @()
        duplicateGroups         = @()
        suggestions             = @()
        checksPerformed         = $checksPerformed
    }

    if ($scanPath -match '^[A-Za-z]:\\?$') {
        $volWatch = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $vol = Get-Volume -DriveLetter ($scanPath[0]) -ErrorAction Stop
            $result.totalSpaceBytes = $vol.Size
            $result.freeSpaceBytes = $vol.SizeRemaining
            Add-CheckResult -Checks $checksPerformed -Name 'VolumeInformation' -Status 'completed' -Stopwatch $volWatch -Notes 'Get-Volume'
        } catch {
            try {
                $psd = Get-PSDrive -Name ($scanPath[0]) -ErrorAction Stop
                $result.totalSpaceBytes = $psd.Used + $psd.Free
                $result.freeSpaceBytes = $psd.Free
                Add-CheckResult -Checks $checksPerformed -Name 'VolumeInformation' -Status 'completed' -Stopwatch $volWatch -Notes 'Get-PSDrive fallback'
            } catch {
                Add-CheckResult -Checks $checksPerformed -Name 'VolumeInformation' -Status 'failed' -Stopwatch $volWatch -Notes $_.Exception.Message
                Write-Warning "Could not determine volume size: $($_.Exception.Message)"
            }
        }
    }

    $enumWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $allFiles = @(Safe-GetFiles -TargetPath $scanPath)
    Add-CheckResult -Checks $checksPerformed -Name 'EnumerateFilesRecursive' -Status 'completed' -Stopwatch $enumWatch -Notes ("FileCount={0}" -f $allFiles.Count)

    $topFilesWatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $result.topFiles = $allFiles |
            Sort-Object -Property Length -Descending |
            Select-Object -First $TopFileCount |
            ForEach-Object {
                [pscustomobject]@{
                    path           = $_.FullName
                    sizeBytes      = $_.Length
                    extension      = $_.Extension
                    lastAccessTime = $_.LastAccessTime
                    lastWriteTime  = $_.LastWriteTime
                }
            }
        Add-CheckResult -Checks $checksPerformed -Name 'TopFiles' -Status 'completed' -Stopwatch $topFilesWatch
    } catch {
        Add-CheckResult -Checks $checksPerformed -Name 'TopFiles' -Status 'failed' -Stopwatch $topFilesWatch -Notes $_.Exception.Message
        Write-Warning "Failed to build top files list: $($_.Exception.Message)"
    }

    $topFoldersWatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $result.topFolders = @(Get-TopFolderSizes -RootPath $scanPath -Files $allFiles -Count $TopFolderCount)
        Add-CheckResult -Checks $checksPerformed -Name 'TopFolders' -Status 'completed' -Stopwatch $topFoldersWatch
    } catch {
        Add-CheckResult -Checks $checksPerformed -Name 'TopFolders' -Status 'failed' -Stopwatch $topFoldersWatch -Notes $_.Exception.Message
        Write-Warning "Failed to build top folder list: $($_.Exception.Message)"
    }

    $recycleWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $rbPath = Join-Path -Path $scanPath -ChildPath '$Recycle.Bin'
    if (-not $isUncPath -and (Test-Path -LiteralPath $rbPath -ErrorAction SilentlyContinue)) {
        try {
            $rbSum = Get-ChildItem -LiteralPath $rbPath -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
            $result.recycleBinSizeBytes = [long]$rbSum.Sum
            Add-CheckResult -Checks $checksPerformed -Name 'RecycleBin' -Status 'completed' -Stopwatch $recycleWatch
        } catch {
            Add-CheckResult -Checks $checksPerformed -Name 'RecycleBin' -Status 'failed' -Stopwatch $recycleWatch -Notes $_.Exception.Message
            Write-Warning "Recycle Bin check failed: $($_.Exception.Message)"
        }
    } else {
        Add-CheckResult -Checks $checksPerformed -Name 'RecycleBin' -Status 'skipped' -Stopwatch $recycleWatch -Notes 'Path missing or UNC path'
    }

    $tempWatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $tempPaths = @(
            (Join-Path -Path $scanPath -ChildPath 'Windows\Temp'),
            (Join-Path -Path $scanPath -ChildPath 'Users'),
            (Join-Path -Path $scanPath -ChildPath 'OneDrive'),
            (Join-Path -Path $scanPath -ChildPath 'Windows.old'),
            (Join-Path -Path $scanPath -ChildPath 'Downloads')
        )

        foreach ($tempPath in $tempPaths) {
            if (Test-Path -LiteralPath $tempPath -ErrorAction SilentlyContinue) {
                try {
                    $item = Get-Item -LiteralPath $tempPath -Force -ErrorAction Stop
                    if ($item.PSIsContainer) {
                        $sum = Get-ChildItem -LiteralPath $tempPath -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
                        $result.tempLocations += [pscustomobject]@{ path = $tempPath; sizeBytes = [long]$sum.Sum }
                    } else {
                        $result.tempLocations += [pscustomobject]@{ path = $tempPath; sizeBytes = [long]$item.Length }
                    }
                } catch {
                    $result.tempLocations += [pscustomobject]@{ path = $tempPath; sizeBytes = $null }
                }
            } else {
                $result.tempLocations += [pscustomobject]@{ path = $tempPath; sizeBytes = $null }
            }
        }
        Add-CheckResult -Checks $checksPerformed -Name 'TempLocations' -Status 'completed' -Stopwatch $tempWatch
    } catch {
        Add-CheckResult -Checks $checksPerformed -Name 'TempLocations' -Status 'failed' -Stopwatch $tempWatch -Notes $_.Exception.Message
        Write-Warning "Temp location check failed: $($_.Exception.Message)"
    }

    $largeWatch = [System.Diagnostics.Stopwatch]::StartNew()
    if (-not $SkipLargeFileSearch.IsPresent) {
        try {
            $targetExtensions = @('.vhd', '.vhdx', '.vmdk', '.qcow2', '.iso', '.zip', '.7z', '.rar')
            $largeMatches = $allFiles |
                Where-Object { $targetExtensions -contains $_.Extension.ToLowerInvariant() } |
                Sort-Object -Property Length -Descending

            foreach ($file in $largeMatches) {
                $entry = [pscustomobject]@{
                    path      = $file.FullName
                    sizeBytes = $file.Length
                    lastWrite = $file.LastWriteTime
                }
                if ($file.Extension -in @('.iso', '.zip', '.7z', '.rar')) {
                    $result.isoArchives += $entry
                } else {
                    $result.largeVMFiles += $entry
                }
            }
            Add-CheckResult -Checks $checksPerformed -Name 'LargeExtensionSearch' -Status 'completed' -Stopwatch $largeWatch
        } catch {
            Add-CheckResult -Checks $checksPerformed -Name 'LargeExtensionSearch' -Status 'failed' -Stopwatch $largeWatch -Notes $_.Exception.Message
            Write-Warning "Large extension search failed: $($_.Exception.Message)"
        }
    } else {
        Add-CheckResult -Checks $checksPerformed -Name 'LargeExtensionSearch' -Status 'skipped' -Stopwatch $largeWatch -Notes 'Disabled by parameter or UNC safe mode'
    }

    $oldWatch = [System.Diagnostics.Stopwatch]::StartNew()
    if (-not $skipOldFiles) {
        try {
            $cutoff = (Get-Date).AddYears(-$OldYears)
            $result.oldFilesCandidates = $allFiles |
                Where-Object { $_.$OldFileTimestamp -lt $cutoff } |
                Sort-Object -Property Length -Descending |
                Select-Object -First 200 |
                ForEach-Object {
                    [pscustomobject]@{
                        path           = $_.FullName
                        sizeBytes      = $_.Length
                        lastAccessTime = $_.LastAccessTime
                        lastWriteTime  = $_.LastWriteTime
                    }
                }
            Add-CheckResult -Checks $checksPerformed -Name 'OldFiles' -Status 'completed' -Stopwatch $oldWatch -Notes ("Timestamp={0}" -f $OldFileTimestamp)
        } catch {
            Add-CheckResult -Checks $checksPerformed -Name 'OldFiles' -Status 'failed' -Stopwatch $oldWatch -Notes $_.Exception.Message
            Write-Warning "Old-files check failed: $($_.Exception.Message)"
        }
    } else {
        Add-CheckResult -Checks $checksPerformed -Name 'OldFiles' -Status 'skipped' -Stopwatch $oldWatch -Notes 'UNC safe mode'
    }

    $dupWatch = [System.Diagnostics.Stopwatch]::StartNew()
    if (-not $skipDuplicateDetection) {
        try {
            $threshold = $DuplicateSizeThresholdMB * 1MB
            $sizeBuckets = @{}

            foreach ($file in $allFiles) {
                if ($file.Length -lt $threshold) {
                    continue
                }
                $sizeKey = [string]$file.Length
                if (-not $sizeBuckets.ContainsKey($sizeKey)) {
                    $sizeBuckets[$sizeKey] = [System.Collections.Generic.List[object]]::new()
                }
                $sizeBuckets[$sizeKey].Add($file)
            }

            $duplicateGroups = [System.Collections.Generic.List[object]]::new()
            foreach ($bucket in $sizeBuckets.GetEnumerator()) {
                if ($bucket.Value.Count -lt 2) {
                    continue
                }

                if ($HashDuplicates.IsPresent) {
                    $hashBuckets = @{}
                    foreach ($candidate in $bucket.Value) {
                        try {
                            $hash = (Get-FileHash -LiteralPath $candidate.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
                            if (-not $hashBuckets.ContainsKey($hash)) {
                                $hashBuckets[$hash] = [System.Collections.Generic.List[string]]::new()
                            }
                            $hashBuckets[$hash].Add($candidate.FullName)
                        } catch {
                            Write-Warning "Hash failed for '$($candidate.FullName)': $($_.Exception.Message)"
                        }
                    }
                    foreach ($hashBucket in $hashBuckets.GetEnumerator()) {
                        if ($hashBucket.Value.Count -gt 1) {
                            $duplicateGroups.Add(@($hashBucket.Value))
                        }
                    }
                } else {
                    $duplicateGroups.Add(@($bucket.Value | ForEach-Object { $_.FullName }))
                }
            }

            $result.duplicateGroups = @($duplicateGroups | Select-Object -First 20)
            Add-CheckResult -Checks $checksPerformed -Name 'DuplicateDetection' -Status 'completed' -Stopwatch $dupWatch -Notes ("Hashing={0}" -f $HashDuplicates.IsPresent)
        } catch {
            Add-CheckResult -Checks $checksPerformed -Name 'DuplicateDetection' -Status 'failed' -Stopwatch $dupWatch -Notes $_.Exception.Message
            Write-Warning "Duplicate detection failed: $($_.Exception.Message)"
        }
    } else {
        Add-CheckResult -Checks $checksPerformed -Name 'DuplicateDetection' -Status 'skipped' -Stopwatch $dupWatch -Notes 'UNC safe mode'
    }

    $vssWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        try {
            $shadows = (& vssadmin list shadows 2>&1 | Out-String).Trim()
            $shadowStorage = (& vssadmin list shadowstorage 2>&1 | Out-String).Trim()
            $result.shadowCopies = [pscustomobject]@{
                shadows       = $shadows
                shadowStorage = $shadowStorage
            }
            Add-CheckResult -Checks $checksPerformed -Name 'ShadowCopies' -Status 'completed' -Stopwatch $vssWatch
        } catch {
            Add-CheckResult -Checks $checksPerformed -Name 'ShadowCopies' -Status 'failed' -Stopwatch $vssWatch -Notes $_.Exception.Message
            Write-Warning "vssadmin query failed: $($_.Exception.Message)"
        }
    } else {
        $result.shadowCopies = $null
        Add-CheckResult -Checks $checksPerformed -Name 'ShadowCopies' -Status 'skipped' -Stopwatch $vssWatch -Notes 'Requires admin'
    }

    $windowsOldWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $windowsOldPath = Join-Path -Path $scanPath -ChildPath 'Windows.old'
    if (Test-Path -LiteralPath $windowsOldPath -ErrorAction SilentlyContinue) {
        try {
            $sum = Get-ChildItem -LiteralPath $windowsOldPath -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
            $result.windowsOldPresent = $true
            $result.windowsOldSizeBytes = [long]$sum.Sum
            Add-CheckResult -Checks $checksPerformed -Name 'WindowsOld' -Status 'completed' -Stopwatch $windowsOldWatch
        } catch {
            Add-CheckResult -Checks $checksPerformed -Name 'WindowsOld' -Status 'failed' -Stopwatch $windowsOldWatch -Notes $_.Exception.Message
            Write-Warning "Windows.old check failed: $($_.Exception.Message)"
        }
    } else {
        Add-CheckResult -Checks $checksPerformed -Name 'WindowsOld' -Status 'skipped' -Stopwatch $windowsOldWatch -Notes 'Path not found'
    }

    $result.suggestions = @(
        [pscustomobject]@{ actionShort = 'List path usage summary'; description = 'Confirm total and free space; review results'; estimatedRecoverableBytes = $null; riskLevel = 'low' },
        [pscustomobject]@{ actionShort = 'Inspect top files/folders'; description = 'Review top files and folders from results; move or archive large files'; estimatedRecoverableBytes = $null; riskLevel = 'low' },
        [pscustomobject]@{ actionShort = 'Empty Recycle Bin (careful)'; description = "After review, empty Recycle Bin for $scanPath if you are sure"; estimatedRecoverableBytes = $result.recycleBinSizeBytes; riskLevel = 'high' },
        [pscustomobject]@{ actionShort = 'Review duplicate groups'; description = 'Validate duplicate candidates before deleting'; estimatedRecoverableBytes = $null; riskLevel = 'medium' }
    )

    if ($OutputFile) {
        $writeWatch = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $resolvedOutputFile = Resolve-OutputPath -PathSpec $OutputFile
            if ($PSCmdlet.ShouldProcess($resolvedOutputFile, 'Write storage scan JSON report')) {
                $json = ([pscustomobject]$result) | ConvertTo-Json -Depth 7
                Set-Content -LiteralPath $resolvedOutputFile -Value $json -Encoding UTF8 -ErrorAction Stop
                Add-CheckResult -Checks $checksPerformed -Name 'WriteOutputFile' -Status 'completed' -Stopwatch $writeWatch -Notes $resolvedOutputFile
                Write-Verbose "Saved JSON report to '$resolvedOutputFile'"
            } else {
                Add-CheckResult -Checks $checksPerformed -Name 'WriteOutputFile' -Status 'skipped' -Stopwatch $writeWatch -Notes 'WhatIf/ShouldProcess declined'
            }
        } catch {
            Add-CheckResult -Checks $checksPerformed -Name 'WriteOutputFile' -Status 'failed' -Stopwatch $writeWatch -Notes $_.Exception.Message
            Write-Warning "Failed to write JSON report: $($_.Exception.Message)"
        }
    }

    [pscustomobject]$result
}
