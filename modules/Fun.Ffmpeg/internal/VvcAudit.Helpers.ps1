using module .\VvcAudit.Types.psm1

Set-StrictMode -Version Latest

function Get-VvcToolPaths {
    [OutputType([VvcToolPaths])]
    $ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if (-not $ffmpeg) {
        throw "ffmpeg was not found in PATH."
    }

    $ffprobe = Get-Command ffprobe -ErrorAction SilentlyContinue
    if (-not $ffprobe) {
        throw "ffprobe was not found in PATH."
    }

    [VvcToolPaths]::new($ffmpeg.Path, $ffprobe.Path)
}

function Get-VvcFileSizeMB {
    [OutputType([double])]
    param([string]$Path)

    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        return [math]::Round($item.Length / 1MB, 2)
    } catch {
        return 0
    }
}

function Test-VvcCodecName {
    [OutputType([bool])]
    param([string]$CodecName)

    return ($CodecName -match '^(vvc|vvc1)$')
}

function Get-VvcMediaInspection {
    [OutputType([VvcMediaInspection])]
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
    $sizeMB = [math]::Round($item.Length / 1MB, 2)
    $isEmpty = ($item.Length -le 0)
    $valid = $false
    $reason = ''
    $videoCodec = ''
    $durationSec = -1.0
    $decodable = $null

    if ($isEmpty) {
        return [VvcMediaInspection]::new(
            $item.FullName,
            $true,
            $sizeMB,
            $true,
            $false,
            'input file is empty.',
            '',
            -1.0,
            $null
        )
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
        $reason = if ([string]::IsNullOrWhiteSpace($probeMessage)) {
            'ffprobe could not read the input container.'
        } else {
            $probeMessage
        }
        return [VvcMediaInspection]::new(
            $item.FullName,
            $true,
            $sizeMB,
            $false,
            $false,
            $reason,
            '',
            -1.0,
            $null
        )
    }

    $lines = @($probeOutput | ForEach-Object { ($_ | Out-String).Trim() } | Where-Object { $_ })
    if ($lines.Count -gt 0) {
        $videoCodec = $lines[0]
    }

    if ($lines.Count -gt 1) {
        try {
            $durationSec = [double]::Parse(
                $lines[1],
                [Globalization.CultureInfo]::InvariantCulture
            )
        } catch {
            $durationSec = -1.0
        }
    }

    if ($Verify -eq 'strict') {
        ffmpeg -v error -noautorotate -err_detect explode -t $DecodeSeconds -i $item.FullName -f null - 2>$null
        $decodable = ($LASTEXITCODE -eq 0)
        if (-not $decodable) {
            return [VvcMediaInspection]::new(
                $item.FullName,
                $true,
                $sizeMB,
                $false,
                $false,
                'decode test failed',
                $videoCodec,
                $durationSec,
                $decodable
            )
        }
    }

    [VvcMediaInspection]::new(
        $item.FullName,
        $true,
        $sizeMB,
        $false,
        $true,
        '',
        $videoCodec,
        $durationSec,
        $decodable
    )
}

function Get-VvcEpisodeKey {
    [OutputType([string])]
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
