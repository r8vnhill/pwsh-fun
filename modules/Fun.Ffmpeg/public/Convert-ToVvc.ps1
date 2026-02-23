#Requires -Version 7.0
Set-StrictMode -Version 3.0

function Convert-ToVvc {
    <#
    .SYNOPSIS
    Converts video files to VVC (H.266) using ffmpeg/libvvenc.

    .DESCRIPTION
    Scans an input folder for video files, encodes each file to VVC, and writes
    `.mkv` outputs into the target folder. Conversion is done through temporary
    files first and only promoted to final output after verification.

    The function supports optional recursion, overwrite control, post-conversion
    validation, and parallel processing.

    .PARAMETER InputDir
    Input directory to scan for source videos.

    .PARAMETER OutputDir
    Destination directory for converted files.

    .PARAMETER QP
    Constant QP value used by `libvvenc`.

    .PARAMETER Preset
    Encoding preset passed to `libvvenc`.

    .PARAMETER Recurse
    Recursively scan `InputDir`.

    .PARAMETER Overwrite
    Overwrite valid existing outputs. Invalid existing outputs are always rebuilt.

    .PARAMETER Suffix
    Suffix appended to output base filename.

    .PARAMETER MaxParallel
    Maximum number of files processed in parallel. Use `1` for sequential mode.

    .PARAMETER Extensions
    File extensions to include from `InputDir`.

    .PARAMETER Verify
    Verification mode:
    - `none`: only existence and codec checks.
    - `quick`: includes duration drift check.
    - `strict`: includes duration drift and decode test.

    .PARAMETER MaxDrift
    Maximum allowed input/output duration difference in seconds for verification.

    .EXAMPLE
    Convert-ToVvc -InputDir 'D:\Videos' -OutputDir 'D:\Videos\vvc_out' -Recurse

    Converts supported video files under `D:\Videos` recursively.

    .EXAMPLE
    Convert-ToVvc -InputDir . -OutputDir .\vvc -MaxParallel 4 -Verify strict -WhatIf

    Shows what would be converted with strict verification using four workers.

    .OUTPUTS
    PSCustomObject
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter()]
        [string]$InputDir = '.',

        [Parameter()]
        [string]$OutputDir = '.\vvc_out',

        [Parameter()]
        [int]$QP = 32,

        [Parameter()]
        [ValidateSet('faster', 'fast', 'medium', 'slow', 'slower', 'veryslow')]
        [string]$Preset = 'fast',

        [Parameter()]
        [switch]$Recurse,

        [Parameter()]
        [switch]$Overwrite,

        [Parameter()]
        [string]$Suffix = '_vvc',

        [Parameter()]
        [ValidateRange(1, 128)]
        [int]$MaxParallel = 1,

        [Parameter()]
        [string[]]$Extensions = @('.mkv', '.mp4', '.mov', '.avi', '.ts', '.m2ts', '.webm'),

        [Parameter()]
        [ValidateSet('none', 'quick', 'strict')]
        [string]$Verify = 'quick',

        [Parameter()]
        [ValidateRange(0.0, 3600.0)]
        [double]$MaxDrift = 1.5
    )

    function Get-FileSizeMB {
        param([string]$Path)
        try {
            $fi = Get-Item -LiteralPath $Path -ErrorAction Stop
            return [math]::Round($fi.Length / 1MB, 2)
        } catch {
            return 0
        }
    }

    function Get-VideoCodecName {
        param([string]$Path)
        try {
            $codec = ffprobe -v error -select_streams v:0 -show_entries stream=codec_name `
                -of default=nw=1:nk=1 -- "$Path" 2>$null
            return ($codec | Out-String).Trim()
        } catch {
            return ''
        }
    }

    function Get-FormatDurationSec {
        param([string]$Path)
        try {
            $duration = ffprobe -v error -show_entries format=duration `
                -of default=nk=1:nw=1 -- "$Path" 2>$null
            return [double]::Parse(($duration | Out-String).Trim(), [Globalization.CultureInfo]::InvariantCulture)
        } catch {
            return -1
        }
    }

    function Test-Decodable {
        param(
            [string]$Path,
            [string]$FfmpegPath
        )

        & $FfmpegPath -v error -noautorotate -err_detect explode -t 8 -i "$Path" -f null - 2>$null
        return ($LASTEXITCODE -eq 0)
    }

    function Test-Converted {
        param(
            [string]$OriginalPath,
            [string]$OutputPath,
            [string]$Mode,
            [double]$MaxDriftSec,
            [string]$FfmpegPath
        )

        if (-not (Test-Path -LiteralPath $OutputPath)) {
            return @{ Ok = $false; Reason = 'missing output' }
        }

        $codec = Get-VideoCodecName -Path $OutputPath
        if ($codec -notmatch '^(vvc|vvc1)$') {
            return @{ Ok = $false; Reason = "unexpected codec: '$codec'" }
        }

        if ($Mode -ne 'none') {
            $dIn = Get-FormatDurationSec -Path $OriginalPath
            $dOut = Get-FormatDurationSec -Path $OutputPath
            if ($dIn -gt 0 -and $dOut -gt 0) {
                $drift = [math]::Abs($dIn - $dOut)
                if ($drift -gt $MaxDriftSec) {
                    return @{ Ok = $false; Reason = ('duration drift {0:N2}s' -f $drift) }
                }
            }

            if ($Mode -eq 'strict' -and -not (Test-Decodable -Path $OutputPath -FfmpegPath $FfmpegPath)) {
                return @{ Ok = $false; Reason = 'decode test failed' }
            }
        }

        return @{ Ok = $true; Reason = '' }
    }

    function New-OutputTempPath {
        param([string]$FinalPath)

        $dir = [IO.Path]::GetDirectoryName($FinalPath)
        $name = [IO.Path]::GetFileNameWithoutExtension($FinalPath)
        $ext = [IO.Path]::GetExtension($FinalPath)
        return (Join-Path $dir ('{0}.__partial__{1}' -f $name, $ext))
    }

    function Build-Args {
        param(
            [string]$InputPath,
            [string]$OutputPath,
            [int]$QpValue,
            [string]$PresetValue,
            [switch]$AllowOverwrite
        )

        $ffArgs = @()
        if ($AllowOverwrite) { $ffArgs += '-y' } else { $ffArgs += '-n' }
        $ffArgs += @(
            '-hide_banner',
            '-stats', '-loglevel', 'error',
            '-analyzeduration', '200M', '-probesize', '200M',
            '-i', $InputPath,
            '-map', '0', '-map_chapters', '0', '-map_metadata', '0',
            '-c:v', 'libvvenc', '-profile:v', 'main10', '-pix_fmt', 'yuv420p10le',
            '-preset', $PresetValue, '-qp', $QpValue, '-threads', '0',
            '-c:a', 'copy', '-c:s', 'copy', '-c:t', 'copy',
            $OutputPath
        )
        return $ffArgs
    }

    $ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if (-not $ffmpeg) {
        throw "ffmpeg was not found in PATH."
    }

    $ffprobe = Get-Command ffprobe -ErrorAction SilentlyContinue
    if (-not $ffprobe) {
        throw "ffprobe was not found in PATH."
    }

    $hasVvenc = ffmpeg -hide_banner -encoders 2>$null | Select-String -SimpleMatch 'libvvenc'
    if (-not $hasVvenc) {
        throw "Your ffmpeg build does not include the 'libvvenc' encoder."
    }

    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

    $extSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $Extensions | ForEach-Object { $null = $extSet.Add($_) }

    $gciParams = @{ Path = $InputDir; File = $true; ErrorAction = 'Stop' }
    if ($Recurse.IsPresent) {
        $gciParams.Recurse = $true
    }
    $files = @(Get-ChildItem @gciParams | Where-Object { $extSet.Contains($_.Extension) })

    if ($files.Count -eq 0) {
        Write-Verbose "No matching videos found in '$InputDir' with extensions: $($Extensions -join ', ')."
        return @()
    }

    $ffmpegPath = $ffmpeg.Path
    $outputDirAbs = (Resolve-Path -LiteralPath $OutputDir).Path

    $processOne = {
        param(
            $File,
            $SuffixValue,
            $OutputDirValue,
            $QpValue,
            $PresetValue,
            $OverwriteValue,
            $FfmpegPath,
            $VerifyMode,
            $MaxDriftSec
        )

        function Get-FileSizeMB {
            param([string]$Path)
            try {
                $fi = Get-Item -LiteralPath $Path -ErrorAction Stop
                return [math]::Round($fi.Length / 1MB, 2)
            } catch {
                return 0
            }
        }

        function Get-VideoCodecName {
            param([string]$Path)
            try {
                $codec = ffprobe -v error -select_streams v:0 -show_entries stream=codec_name `
                    -of default=nw=1:nk=1 -- "$Path" 2>$null
                return ($codec | Out-String).Trim()
            } catch {
                return ''
            }
        }

        function Get-FormatDurationSec {
            param([string]$Path)
            try {
                $duration = ffprobe -v error -show_entries format=duration `
                    -of default=nk=1:nw=1 -- "$Path" 2>$null
                return [double]::Parse(($duration | Out-String).Trim(), [Globalization.CultureInfo]::InvariantCulture)
            } catch {
                return -1
            }
        }

        function Test-Decodable {
            param(
                [string]$Path,
                [string]$FfmpegPath
            )

            & $FfmpegPath -v error -noautorotate -err_detect explode -t 8 -i "$Path" -f null - 2>$null
            return ($LASTEXITCODE -eq 0)
        }

        function Test-Converted {
            param(
                [string]$OriginalPath,
                [string]$OutputPath,
                [string]$Mode,
                [double]$MaxDriftSec,
                [string]$FfmpegPath
            )

            if (-not (Test-Path -LiteralPath $OutputPath)) {
                return @{ Ok = $false; Reason = 'missing output' }
            }

            $codec = Get-VideoCodecName -Path $OutputPath
            if ($codec -notmatch '^(vvc|vvc1)$') {
                return @{ Ok = $false; Reason = "unexpected codec: '$codec'" }
            }

            if ($Mode -ne 'none') {
                $dIn = Get-FormatDurationSec -Path $OriginalPath
                $dOut = Get-FormatDurationSec -Path $OutputPath
                if ($dIn -gt 0 -and $dOut -gt 0) {
                    $drift = [math]::Abs($dIn - $dOut)
                    if ($drift -gt $MaxDriftSec) {
                        return @{ Ok = $false; Reason = ('duration drift {0:N2}s' -f $drift) }
                    }
                }

                if ($Mode -eq 'strict' -and -not (Test-Decodable -Path $OutputPath -FfmpegPath $FfmpegPath)) {
                    return @{ Ok = $false; Reason = 'decode test failed' }
                }
            }

            return @{ Ok = $true; Reason = '' }
        }

        function New-OutputTempPath {
            param([string]$FinalPath)

            $dir = [IO.Path]::GetDirectoryName($FinalPath)
            $name = [IO.Path]::GetFileNameWithoutExtension($FinalPath)
            $ext = [IO.Path]::GetExtension($FinalPath)
            return (Join-Path $dir ('{0}.__partial__{1}' -f $name, $ext))
        }

        function Build-Args {
            param(
                [string]$InputPath,
                [string]$OutputPath,
                [int]$QpValue,
                [string]$PresetValue,
                [switch]$AllowOverwrite
            )

            $ffArgs = @()
            if ($AllowOverwrite) { $ffArgs += '-y' } else { $ffArgs += '-n' }
            $ffArgs += @(
                '-hide_banner',
                '-stats', '-loglevel', 'error',
                '-analyzeduration', '200M', '-probesize', '200M',
                '-i', $InputPath,
                '-map', '0', '-map_chapters', '0', '-map_metadata', '0',
                '-c:v', 'libvvenc', '-profile:v', 'main10', '-pix_fmt', 'yuv420p10le',
                '-preset', $PresetValue, '-qp', $QpValue, '-threads', '0',
                '-c:a', 'copy', '-c:s', 'copy', '-c:t', 'copy',
                $OutputPath
            )
            return $ffArgs
        }

        $inputPath = $File.FullName
        $baseName = [IO.Path]::GetFileNameWithoutExtension($File.Name)
        $outputName = "${baseName}${SuffixValue}.mkv"
        $outputPath = Join-Path -Path $OutputDirValue -ChildPath $outputName
        $outputTempPath = New-OutputTempPath -FinalPath $outputPath

        if (Test-Path -LiteralPath $outputTempPath) {
            Remove-Item -LiteralPath $outputTempPath -Force -ErrorAction SilentlyContinue
        }

        if (Test-Path -LiteralPath $outputPath) {
            $check = Test-Converted -OriginalPath $inputPath -OutputPath $outputPath -Mode $VerifyMode -MaxDriftSec $MaxDriftSec -FfmpegPath $FfmpegPath
            if (-not $check.Ok) {
                $forceOverwrite = $true
                $ffArgs = Build-Args -InputPath $inputPath -OutputPath $outputTempPath -QpValue $QpValue -PresetValue $PresetValue -AllowOverwrite:$forceOverwrite
                & $FfmpegPath @ffArgs
                $exitCode = $LASTEXITCODE
                if ($exitCode -eq 0 -and (Test-Path -LiteralPath $outputTempPath)) {
                    $post = Test-Converted -OriginalPath $inputPath -OutputPath $outputTempPath -Mode $VerifyMode -MaxDriftSec $MaxDriftSec -FfmpegPath $FfmpegPath
                    if ($post.Ok) {
                        try {
                            if (Test-Path -LiteralPath $outputPath) {
                                Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
                            }
                            Move-Item -LiteralPath $outputTempPath -Destination $outputPath -Force -ErrorAction Stop
                        } catch {
                            if (Test-Path -LiteralPath $outputTempPath) {
                                Remove-Item -LiteralPath $outputTempPath -ErrorAction SilentlyContinue
                            }
                            return [pscustomobject]@{
                                File       = $File.Name
                                Ok         = $false
                                Skipped    = $false
                                Reason     = "final rename failed: $($_.Exception.Message)"
                                OriginalMB = 0
                                NewMB      = 0
                                Ratio      = 0
                            }
                        }

                        $originalSize = Get-FileSizeMB -Path $inputPath
                        $newSize = Get-FileSizeMB -Path $outputPath
                        return [pscustomobject]@{
                            File       = $File.Name
                            Ok         = $true
                            Skipped    = $false
                            Reason     = ''
                            OriginalMB = $originalSize
                            NewMB      = $newSize
                            Ratio      = if ($originalSize -gt 0) { [math]::Round(($newSize / $originalSize) * 100, 1) } else { 0 }
                        }
                    }

                    if (Test-Path -LiteralPath $outputTempPath) {
                        Remove-Item -LiteralPath $outputTempPath -ErrorAction SilentlyContinue
                    }
                    return [pscustomobject]@{
                        File       = $File.Name
                        Ok         = $false
                        Skipped    = $false
                        Reason     = "re-encode failed: $($post.Reason)"
                        OriginalMB = 0
                        NewMB      = 0
                        Ratio      = 0
                    }
                }

                if (Test-Path -LiteralPath $outputTempPath) {
                    Remove-Item -LiteralPath $outputTempPath -ErrorAction SilentlyContinue
                }
                return [pscustomobject]@{
                    File       = $File.Name
                    Ok         = $false
                    Skipped    = $false
                    Reason     = "ffmpeg exit $exitCode"
                    OriginalMB = 0
                    NewMB      = 0
                    Ratio      = 0
                }
            }

            if (-not $OverwriteValue) {
                return [pscustomobject]@{
                    File       = $File.Name
                    Ok         = $false
                    Skipped    = $true
                    Reason     = 'exists (valid)'
                    OriginalMB = 0
                    NewMB      = 0
                    Ratio      = 0
                }
            }
        }

        try {
            $ffArgs = Build-Args -InputPath $inputPath -OutputPath $outputTempPath -QpValue $QpValue -PresetValue $PresetValue -AllowOverwrite:$OverwriteValue
            & $FfmpegPath @ffArgs
            $exitCode = $LASTEXITCODE

            if ($exitCode -eq 0 -and (Test-Path -LiteralPath $outputTempPath)) {
                $post = Test-Converted -OriginalPath $inputPath -OutputPath $outputTempPath -Mode $VerifyMode -MaxDriftSec $MaxDriftSec -FfmpegPath $FfmpegPath
                if (-not $post.Ok) {
                    if (Test-Path -LiteralPath $outputTempPath) {
                        Remove-Item -LiteralPath $outputTempPath -ErrorAction SilentlyContinue
                    }
                    return [pscustomobject]@{
                        File       = $File.Name
                        Ok         = $false
                        Skipped    = $false
                        Reason     = "bad convert: $($post.Reason)"
                        OriginalMB = 0
                        NewMB      = 0
                        Ratio      = 0
                    }
                }

                try {
                    if (Test-Path -LiteralPath $outputPath) {
                        Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
                    }
                    Move-Item -LiteralPath $outputTempPath -Destination $outputPath -Force -ErrorAction Stop
                } catch {
                    if (Test-Path -LiteralPath $outputTempPath) {
                        Remove-Item -LiteralPath $outputTempPath -ErrorAction SilentlyContinue
                    }
                    return [pscustomobject]@{
                        File       = $File.Name
                        Ok         = $false
                        Skipped    = $false
                        Reason     = "final rename failed: $($_.Exception.Message)"
                        OriginalMB = 0
                        NewMB      = 0
                        Ratio      = 0
                    }
                }

                $originalSize = Get-FileSizeMB -Path $inputPath
                $newSize = Get-FileSizeMB -Path $outputPath
                return [pscustomobject]@{
                    File       = $File.Name
                    Ok         = $true
                    Skipped    = $false
                    Reason     = ''
                    OriginalMB = $originalSize
                    NewMB      = $newSize
                    Ratio      = if ($originalSize -gt 0) { [math]::Round(($newSize / $originalSize) * 100, 1) } else { 0 }
                }
            }

            if (Test-Path -LiteralPath $outputTempPath) {
                Remove-Item -LiteralPath $outputTempPath -ErrorAction SilentlyContinue
            }
            $reason = if ($exitCode -ne 0) { "ffmpeg exit $exitCode" } else { 'missing temp output' }
            return [pscustomobject]@{
                File       = $File.Name
                Ok         = $false
                Skipped    = $false
                Reason     = $reason
                OriginalMB = 0
                NewMB      = 0
                Ratio      = 0
            }
        } catch {
            if (Test-Path -LiteralPath $outputTempPath) {
                Remove-Item -LiteralPath $outputTempPath -ErrorAction SilentlyContinue
            }
            return [pscustomobject]@{
                File       = $File.Name
                Ok         = $false
                Skipped    = $false
                Reason     = $_.Exception.Message
                OriginalMB = 0
                NewMB      = 0
                Ratio      = 0
            }
        }
    }

    $targetFiles = @()
    foreach ($file in $files) {
        $baseName = [IO.Path]::GetFileNameWithoutExtension($file.Name)
        $outName = "${baseName}${Suffix}.mkv"
        $outPath = Join-Path -Path $outputDirAbs -ChildPath $outName
        if ($PSCmdlet.ShouldProcess($file.FullName, "Convert to VVC -> $outPath")) {
            $targetFiles += $file
        }
    }

    if ($targetFiles.Count -eq 0) {
        return @()
    }

    $results =
    if ($MaxParallel -le 1) {
        $i = 0
        $acc = @()
        foreach ($f in $targetFiles) {
            $i++
            Write-Verbose "[$i/$($targetFiles.Count)] Processing: $($f.Name)"
            $acc += (& $processOne $f $Suffix $outputDirAbs $QP $Preset $Overwrite $ffmpegPath $Verify $MaxDrift)
        }
        $acc
    } else {
        $throttle = [math]::Max(1, $MaxParallel)
        $targetFiles | ForEach-Object -Parallel $processOne `
            -ThrottleLimit $throttle `
            -ArgumentList $Suffix, $outputDirAbs, $QP, $Preset, $Overwrite, $ffmpegPath, $Verify, $MaxDrift
    }

    $ok = ($results | Where-Object { $_.Ok }).Count
    $skipped = ($results | Where-Object { $_.Skipped }).Count
    $errors = ($results | Where-Object { -not $_.Ok -and -not $_.Skipped }).Count

    Write-Verbose "Completed. Converted: $ok | Skipped: $skipped | Errors: $errors"
    return $results
}

