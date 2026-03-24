Set-StrictMode -Version Latest

function Get-VvcToolPaths {
    $ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if (-not $ffmpeg) {
        throw "ffmpeg was not found in PATH."
    }

    $ffprobe = Get-Command ffprobe -ErrorAction SilentlyContinue
    if (-not $ffprobe) {
        throw "ffprobe was not found in PATH."
    }

    [pscustomobject]@{
        FfmpegPath  = $ffmpeg.Path
        FfprobePath = $ffprobe.Path
    }
}

function Get-VvcFileSizeMB {
    param([string]$Path)

    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        return [math]::Round($item.Length / 1MB, 2)
    } catch {
        return 0
    }
}

function Test-VvcCodecName {
    param([string]$CodecName)

    return ($CodecName -match '^(vvc|vvc1)$')
}

function Get-VvcMediaInspection {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$FfprobePath,

        [Parameter(Mandatory)]
        [string]$FfmpegPath,

        [ValidateSet('quick', 'strict')]
        [string]$Verify = 'quick',

        [double]$DecodeSeconds = 8.0
    )

    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    $result = [ordered]@{
        Path        = $item.FullName
        Exists      = $true
        SizeMB      = [math]::Round($item.Length / 1MB, 2)
        IsEmpty     = ($item.Length -le 0)
        Valid       = $false
        Reason      = ''
        VideoCodec  = ''
        DurationSec = -1.0
        Decodable   = $null
    }

    if ($result.IsEmpty) {
        $result.Reason = 'input file is empty.'
        return [pscustomobject]$result
    }

    $probeArgs = @(
        '-v', 'error',
        '-show_entries', 'format=duration:stream=codec_name',
        '-select_streams', 'v:0',
        '-of', 'default=nw=1:nk=1',
        '--',
        $item.FullName
    )

    $probeOutput = @(ffprobe @probeArgs 2>&1)
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        $probeMessage = ($probeOutput | Out-String).Trim()
        $result.Reason = if ([string]::IsNullOrWhiteSpace($probeMessage)) {
            'ffprobe could not read the input container.'
        } else {
            $probeMessage
        }
        return [pscustomobject]$result
    }

    $lines = @($probeOutput | ForEach-Object { ($_ | Out-String).Trim() } | Where-Object { $_ })
    if ($lines.Count -gt 0) {
        $result.VideoCodec = $lines[0]
    }

    if ($lines.Count -gt 1) {
        try {
            $result.DurationSec = [double]::Parse($lines[1], [Globalization.CultureInfo]::InvariantCulture)
        } catch {
            $result.DurationSec = -1.0
        }
    }

    if ($Verify -eq 'strict') {
        ffmpeg -v error -noautorotate -err_detect explode -t $DecodeSeconds -i $item.FullName -f null - 2>$null
        $result.Decodable = ($LASTEXITCODE -eq 0)
        if (-not $result.Decodable) {
            $result.Reason = 'decode test failed'
            return [pscustomobject]$result
        }
    }

    $result.Valid = $true
    return [pscustomobject]$result
}

function Get-VvcEpisodeKey {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory)]
        [string]$Suffix
    )

    $baseName = [IO.Path]::GetFileNameWithoutExtension($File.Name)
    if ($baseName.EndsWith($Suffix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $baseName.Substring(0, $baseName.Length - $Suffix.Length)
    }

    return $baseName
}
