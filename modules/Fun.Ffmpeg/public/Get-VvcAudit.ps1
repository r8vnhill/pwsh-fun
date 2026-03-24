function Get-VvcAudit {
    <#
    .SYNOPSIS
    Audit a folder of source videos and `_vvc` outputs before cleanup.

    .DESCRIPTION
    Scans a directory for video files, pairs originals with their `_vvc` counterparts,
    validates both sides with `ffprobe`, and returns one object per episode with
    status, size, codec, duration, drift, and safe-delete guidance.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$InputDir = '.',

        [Parameter()]
        [string]$Suffix = '_vvc',

        [Parameter()]
        [string[]]$Extensions = @('.mkv', '.mp4', '.mov', '.avi', '.ts', '.m2ts', '.webm'),

        [Parameter()]
        [ValidateSet('quick', 'strict')]
        [string]$Verify = 'quick',

        [Parameter()]
        [ValidateRange(0.0, 3600.0)]
        [double]$MaxDrift = 1.5,

        [Parameter()]
        [ValidateRange(0.0, 10240.0)]
        [double]$MinExpectedVvcMB = 32.0,

        [Parameter()]
        [switch]$Recurse
    )

    $tools = Get-VvcToolPaths

    $extSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $Extensions | ForEach-Object {
        if (-not [string]::IsNullOrWhiteSpace($_)) {
            $normalized = $_.Trim()
            if (-not $normalized.StartsWith('.')) {
                $normalized = ".$normalized"
            }
            $null = $extSet.Add($normalized)
        }
    }

    $gciParams = @{ LiteralPath = $InputDir; File = $true; ErrorAction = 'Stop' }
    if ($Recurse) {
        $gciParams.Recurse = $true
    }

    $files = @(Get-ChildItem @gciParams | Where-Object { $extSet.Contains($_.Extension) })
    $groups = [ordered]@{}

    foreach ($file in $files) {
        $episodeKey = Get-VvcEpisodeKey -File $file -Suffix $Suffix
        $groupKey = '{0}|{1}' -f $file.DirectoryName, $episodeKey
        if (-not $groups.Contains($groupKey)) {
            $groups[$groupKey] = [ordered]@{
                EpisodeKey = $episodeKey
                Directory  = $file.DirectoryName
                Original   = $null
                Vvc        = $null
            }
        }

        $baseName = [IO.Path]::GetFileNameWithoutExtension($file.Name)
        if ($baseName.EndsWith($Suffix, [System.StringComparison]::OrdinalIgnoreCase)) {
            $groups[$groupKey].Vvc = $file
        } else {
            $groups[$groupKey].Original = $file
        }
    }

    foreach ($group in $groups.Values) {
        $originalInfo = $null
        $vvcInfo = $null

        if ($group.Original) {
            $originalInfo = Get-VvcMediaInspection -Path $group.Original.FullName -FfprobePath $tools.FfprobePath -FfmpegPath $tools.FfmpegPath -Verify $Verify
        }

        if ($group.Vvc) {
            $vvcInfo = Get-VvcMediaInspection -Path $group.Vvc.FullName -FfprobePath $tools.FfprobePath -FfmpegPath $tools.FfmpegPath -Verify $Verify
            if ($vvcInfo.Valid -and -not (Test-VvcCodecName -CodecName $vvcInfo.VideoCodec)) {
                $vvcInfo.Valid = $false
                $vvcInfo.Reason = "unexpected codec: '$($vvcInfo.VideoCodec)'"
            }
        }

        $durationDriftSec = $null
        if ($originalInfo -and $vvcInfo -and $originalInfo.DurationSec -gt 0 -and $vvcInfo.DurationSec -gt 0) {
            $durationDriftSec = [math]::Abs($originalInfo.DurationSec - $vvcInfo.DurationSec)
        }

        $suspiciousVvc = $false
        $suspiciousReasons = [System.Collections.Generic.List[string]]::new()
        if ($group.Vvc) {
            if (-not $vvcInfo.Valid) {
                $suspiciousVvc = $true
                $suspiciousReasons.Add($vvcInfo.Reason)
            }
            if ($vvcInfo.SizeMB -gt 0 -and $vvcInfo.SizeMB -lt $MinExpectedVvcMB) {
                $suspiciousVvc = $true
                $suspiciousReasons.Add("small output (${MinExpectedVvcMB}MB threshold)")
            }
            if ($durationDriftSec -ne $null -and $durationDriftSec -gt $MaxDrift) {
                $suspiciousVvc = $true
                $suspiciousReasons.Add(('duration drift {0:N2}s' -f $durationDriftSec))
            }
        }

        $safeToDeleteOriginal = $false
        if ($group.Original -and $group.Vvc -and $originalInfo.Valid -and $vvcInfo.Valid -and -not $suspiciousVvc) {
            if ($durationDriftSec -eq $null -or $durationDriftSec -le $MaxDrift) {
                $safeToDeleteOriginal = $true
            }
        }

        $status =
        if ($group.Original -and -not $group.Vvc) {
            if ($originalInfo.Valid) { 'original valid, no _vvc' } else { 'original corrupt, no _vvc' }
        } elseif ($group.Original -and $group.Vvc) {
            if ($suspiciousVvc) {
                '_vvc suspicious/corrupt'
            } elseif ($originalInfo.Valid -and $vvcInfo.Valid) {
                'original valid + _vvc valid'
            } elseif (-not $originalInfo.Valid -and $vvcInfo.Valid) {
                'original corrupt + _vvc valid'
            } else {
                '_vvc suspicious/corrupt'
            }
        } elseif ($group.Vvc) {
            if ($suspiciousVvc) { '_vvc suspicious/corrupt' } else { 'vvc valid, original missing' }
        } else {
            'unclassified'
        }

        [pscustomobject]@{
            EpisodeKey             = $group.EpisodeKey
            Directory              = $group.Directory
            Status                 = $status
            OriginalPath           = if ($group.Original) { $group.Original.FullName } else { $null }
            OriginalName           = if ($group.Original) { $group.Original.Name } else { $null }
            OriginalValid          = if ($originalInfo) { $originalInfo.Valid } else { $false }
            OriginalReason         = if ($originalInfo) { $originalInfo.Reason } else { 'missing original' }
            OriginalCodec          = if ($originalInfo) { $originalInfo.VideoCodec } else { '' }
            OriginalDurationSec    = if ($originalInfo) { $originalInfo.DurationSec } else { -1.0 }
            OriginalSizeMB         = if ($originalInfo) { $originalInfo.SizeMB } else { 0.0 }
            VvcPath                = if ($group.Vvc) { $group.Vvc.FullName } else { $null }
            VvcName                = if ($group.Vvc) { $group.Vvc.Name } else { $null }
            VvcValid               = if ($vvcInfo) { $vvcInfo.Valid } else { $false }
            VvcReason              = if ($vvcInfo) { $vvcInfo.Reason } else { 'missing _vvc' }
            VvcCodec               = if ($vvcInfo) { $vvcInfo.VideoCodec } else { '' }
            VvcDurationSec         = if ($vvcInfo) { $vvcInfo.DurationSec } else { -1.0 }
            VvcSizeMB              = if ($vvcInfo) { $vvcInfo.SizeMB } else { 0.0 }
            DurationDriftSec       = $durationDriftSec
            SuspiciousVvc          = $suspiciousVvc
            SuspiciousReasons      = @($suspiciousReasons)
            SafeToDeleteOriginal   = $safeToDeleteOriginal
            CanConvert             = ($status -eq 'original valid, no _vvc')
        }
    }
}
