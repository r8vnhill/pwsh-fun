using module ..\internal\VvcAudit.Models.psm1

function Get-VvcAudit {
    <#
    .SYNOPSIS
    Audits source videos and `_vvc` outputs before conversion or cleanup.

    .DESCRIPTION
    Scans a directory for supported video files, pairs originals with their `_vvc`
    counterparts by episode key, validates both sides with the internal VVC audit
    helpers, and returns one `VvcAuditResult` per pair or orphaned file set.

    The command is the public audit entrypoint for the VVC workflow. Downstream
    commands such as `Remove-ValidatedVvcOriginal` consume these results by property
    name, so the emitted property contract is stable even though the implementation now
    uses named classes instead of ad hoc `pscustomobject` output.

    `SafeToDeleteOriginal` is conservative: it is only true when both files exist, both
    validate successfully, the `_vvc` file is not suspicious, and the measured duration
    drift stays within `MaxDrift`. `CanConvert` only marks valid originals that do not
    yet have a `_vvc` companion.

    The command emits `VvcAuditResult` objects with size, codec, duration, validity,
    suspicion, and cleanup guidance fields for each grouped episode.

    Internal helper outputs are typed as `VvcToolPaths` and `VvcMediaInspection`, but
    those remain internal implementation details of the module.

    .PARAMETER InputDir
    Root directory to scan for source and `_vvc` files.

    .PARAMETER Suffix
    Suffix used to identify VVC outputs paired with originals.

    .PARAMETER Extensions
    File extensions to include in the scan. Values are normalized case-insensitively,
    and both `mkv` and `.mkv` match the same files.

    .PARAMETER Verify
    Validation mode for media inspection. `quick` uses container probing only, while
    `strict` also runs a short decode test through `ffmpeg`.

    .PARAMETER MaxDrift
    Maximum allowed duration drift, in seconds, before a `_vvc` output is treated as
    suspicious for cleanup purposes.

    .PARAMETER MinExpectedVvcMB
    Minimum expected `_vvc` size, in megabytes, before the output is flagged as
    suspicious.

    .PARAMETER Recurse
    Includes subdirectories when collecting candidate files.

    .OUTPUTS
    VvcAuditResult

    .EXAMPLE
    Get-VvcAudit -InputDir .\Season01 -Verify quick

    Audits the current season directory and returns one `VvcAuditResult` per detected
    episode group.

    .EXAMPLE
    Get-VvcAudit -InputDir .\Season01 -Verify strict -MinExpectedVvcMB 64 -Recurse

    Performs a stricter recursive audit, including decode testing and a larger minimum
    expected size for `_vvc` outputs.
    #>
    [CmdletBinding()]
    [OutputType([VvcAuditResult])]
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
            $inspectParams = @{
                Path        = $group.Original.FullName
                FfprobePath = $tools.FfprobePath
                FfmpegPath  = $tools.FfmpegPath
                Verify      = $Verify
            }
            $originalInfo = Get-VvcMediaInspection @inspectParams
        }

        if ($group.Vvc) {
            $inspectParams = @{
                Path        = $group.Vvc.FullName
                FfprobePath = $tools.FfprobePath
                FfmpegPath  = $tools.FfmpegPath
                Verify      = $Verify
            }
            $vvcInfo = Get-VvcMediaInspection @inspectParams
            if ($vvcInfo.Valid -and -not (Test-VvcCodecName -CodecName $vvcInfo.VideoCodec)) {
                $vvcInfo = [VvcMediaInspection]::new(
                    $vvcInfo.Path,
                    $vvcInfo.Exists,
                    $vvcInfo.SizeMB,
                    $vvcInfo.IsEmpty,
                    $false,
                    [VvcInspectionReason]::UnexpectedCodec,
                    $vvcInfo.VideoCodec,
                    $vvcInfo.DurationSec,
                    $vvcInfo.Decodable
                )
            }
        }

        $durationDriftSec = $null
        if (
            $originalInfo -and
            $vvcInfo -and
            $null -ne $originalInfo.DurationSec -and
            $null -ne $vvcInfo.DurationSec
        ) {
            $durationDriftSec = [math]::Abs($originalInfo.DurationSec - $vvcInfo.DurationSec)
        }

        $suspiciousVvc = $false
        $suspiciousReasons = [System.Collections.Generic.List[string]]::new()
        if ($group.Vvc) {
            if (-not $vvcInfo.Valid) {
                $suspiciousVvc = $true
                $suspiciousReasons.Add($vvcInfo.Reason.ToString())
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

        [VvcAuditStatus]$status =
        if ($group.Original -and -not $group.Vvc) {
            if ($originalInfo.Valid) {
                [VvcAuditStatus]::OriginalValidNoVvc
            } else {
                [VvcAuditStatus]::OriginalCorruptNoVvc
            }
        } elseif ($group.Original -and $group.Vvc) {
            if ($suspiciousVvc) {
                [VvcAuditStatus]::VvcSuspiciousOrCorrupt
            } elseif ($originalInfo.Valid -and $vvcInfo.Valid) {
                [VvcAuditStatus]::OriginalValidAndVvcValid
            } elseif (-not $originalInfo.Valid -and $vvcInfo.Valid) {
                [VvcAuditStatus]::OriginalCorruptAndVvcValid
            } else {
                [VvcAuditStatus]::VvcSuspiciousOrCorrupt
            }
        } elseif ($group.Vvc) {
            if ($suspiciousVvc) {
                [VvcAuditStatus]::VvcSuspiciousOrCorrupt
            } else {
                [VvcAuditStatus]::VvcValidOriginalMissing
            }
        } else {
            [VvcAuditStatus]::Unclassified
        }

        [VvcAuditResult]::new(
            $group.EpisodeKey,
            $group.Directory,
            $status,
            $originalInfo,
            $vvcInfo,
            $durationDriftSec,
            $suspiciousVvc,
            @($suspiciousReasons),
            $safeToDeleteOriginal,
            ($status -eq [VvcAuditStatus]::OriginalValidNoVvc)
        )
    }
}
