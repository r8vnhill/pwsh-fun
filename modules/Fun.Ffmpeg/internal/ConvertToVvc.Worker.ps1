#Requires -Version 7.0

function Get-ConvertToVvcWorkerScriptBlock {
    Get-Command Convert-ToVvc | Out-Null
    $scriptBlockText = @'
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

function New-ConvertToVvcResult {
    param(
        [string]$File,
        [bool]$Ok,
        [bool]$Skipped,
        [string]$Reason = '',
        [double]$OriginalMB = 0.0,
        [double]$NewMB = 0.0,
        [double]$Ratio = 0.0
    )

    [pscustomobject]@{
        File = $File
        Ok = $Ok
        Skipped = $Skipped
        Reason = $Reason
        OriginalMB = $OriginalMB
        NewMB = $NewMB
        Ratio = $Ratio
    }
}

function Get-VideoCodecName {
    param([string]$Path)
    try {
        $ffprobeArgs = @(
            '-v', 'error',
            '-select_streams', 'v:0',
            '-show_entries', 'stream=codec_name',
            '-of', 'default=nw=1:nk=1',
            '--', $Path
        )
        $codec = ffprobe @ffprobeArgs 2>$null
        return ($codec | Out-String).Trim()
    } catch {
        return ''
    }
}

function Get-FormatDurationSec {
    param([string]$Path)
    try {
        $ffprobeArgs = @(
            '-v', 'error',
            '-show_entries', 'format=duration',
            '-of', 'default=nk=1:nw=1',
            '--', $Path
        )
        $duration = ffprobe @ffprobeArgs 2>$null
        return [double]::Parse(
            ($duration | Out-String).Trim(),
            [Globalization.CultureInfo]::InvariantCulture
        )
    } catch {
        return -1
    }
}

function Get-InputProbeError {
    param([string]$Path)

    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        if ($item.Length -le 0) {
            return 'input file is empty.'
        }
    } catch {
        return $_.Exception.Message
    }

    try {
        $ffprobeArgs = @(
            '-v', 'error',
            '-show_entries', 'format=format_name',
            '-of', 'default=nw=1:nk=1',
            '--', $Path
        )
        $probeOutput = @(ffprobe @ffprobeArgs 2>&1)
        if ($LASTEXITCODE -eq 0) {
            return ''
        }

        $probeMessage = ($probeOutput | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($probeMessage)) {
            return 'ffprobe could not read the input container.'
        }

        return $probeMessage
    } catch {
        return $_.Exception.Message
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
                return @{
                    Ok = $false
                    Reason = ('duration drift {0:N2}s' -f $drift)
                }
            }
        }

        if (
            $Mode -eq 'strict' -and
            -not (Test-Decodable -Path $OutputPath -FfmpegPath $FfmpegPath)
        ) {
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
    Join-Path $dir ('{0}.__partial__{1}' -f $name, $ext)
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
    if ($AllowOverwrite) {
        $ffArgs += '-y'
    } else {
        $ffArgs += '-n'
    }

    $ffArgs += @(
        '-hide_banner',
        '-stats', '-loglevel', 'error',
        '-analyzeduration', '200M', '-probesize', '200M',
        '-i', $InputPath,
        '-map', '0', '-map_chapters', '0', '-map_metadata', '0',
        '-c:v', 'libvvenc', '-profile:v', 'main10',
        '-pix_fmt', 'yuv420p10le',
        '-preset', $PresetValue, '-qp', $QpValue, '-threads', '0',
        '-c:a', 'copy', '-c:s', 'copy', '-c:t', 'copy',
        $OutputPath
    )
    $ffArgs
}

$inputPath = $File.FullName
$baseName = [IO.Path]::GetFileNameWithoutExtension($File.Name)
$outputName = "${baseName}${SuffixValue}.mkv"
$outputPath = Join-Path -Path $OutputDirValue -ChildPath $outputName
$outputTempPath = New-OutputTempPath -FinalPath $outputPath
$inputProbeError = Get-InputProbeError -Path $inputPath

if ($inputProbeError) {
    $originalSize = Get-FileSizeMB -Path $inputPath
    return New-ConvertToVvcResult -File $File.Name -Ok $false -Skipped $false `
        -Reason "invalid input: $inputProbeError" -OriginalMB $originalSize
}

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
                    return New-ConvertToVvcResult -File $File.Name -Ok $false `
                        -Skipped $false `
                        -Reason "final rename failed: $($_.Exception.Message)"
                }

                $originalSize = Get-FileSizeMB -Path $inputPath
                $newSize = Get-FileSizeMB -Path $outputPath
                $ratio = if ($originalSize -gt 0) {
                    [math]::Round(($newSize / $originalSize) * 100, 1)
                } else {
                    0
                }
                return New-ConvertToVvcResult -File $File.Name -Ok $true `
                    -Skipped $false -OriginalMB $originalSize -NewMB $newSize `
                    -Ratio $ratio
            }

            if (Test-Path -LiteralPath $outputTempPath) {
                Remove-Item -LiteralPath $outputTempPath -ErrorAction SilentlyContinue
            }
            return New-ConvertToVvcResult -File $File.Name -Ok $false `
                -Skipped $false -Reason "re-encode failed: $($post.Reason)"
        }

        if (Test-Path -LiteralPath $outputTempPath) {
            Remove-Item -LiteralPath $outputTempPath -ErrorAction SilentlyContinue
        }
        return New-ConvertToVvcResult -File $File.Name -Ok $false `
            -Skipped $false -Reason "ffmpeg exit $exitCode"
    }

    if (-not $OverwriteValue) {
        return New-ConvertToVvcResult -File $File.Name -Ok $false `
            -Skipped $true -Reason 'exists (valid)'
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
            return New-ConvertToVvcResult -File $File.Name -Ok $false `
                -Skipped $false -Reason "bad convert: $($post.Reason)"
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
            return New-ConvertToVvcResult -File $File.Name -Ok $false `
                -Skipped $false `
                -Reason "final rename failed: $($_.Exception.Message)"
        }

        $originalSize = Get-FileSizeMB -Path $inputPath
        $newSize = Get-FileSizeMB -Path $outputPath
        $ratio = if ($originalSize -gt 0) {
            [math]::Round(($newSize / $originalSize) * 100, 1)
        } else {
            0
        }
        return New-ConvertToVvcResult -File $File.Name -Ok $true `
            -Skipped $false -OriginalMB $originalSize -NewMB $newSize `
            -Ratio $ratio
    }

    if (Test-Path -LiteralPath $outputTempPath) {
        Remove-Item -LiteralPath $outputTempPath -ErrorAction SilentlyContinue
    }
    $reason = if ($exitCode -ne 0) {
        "ffmpeg exit $exitCode"
    } else {
        'missing temp output'
    }
    return New-ConvertToVvcResult -File $File.Name -Ok $false -Skipped $false `
        -Reason $reason
} catch {
    if (Test-Path -LiteralPath $outputTempPath) {
        Remove-Item -LiteralPath $outputTempPath -ErrorAction SilentlyContinue
    }
    return New-ConvertToVvcResult -File $File.Name -Ok $false -Skipped $false `
        -Reason $_.Exception.Message
}
'@
    [scriptblock]::Create($scriptBlockText)
}
