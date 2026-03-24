using namespace System

class VvcToolPaths {
    [string]$FfmpegPath
    [string]$FfprobePath

    VvcToolPaths([string]$FfmpegPath, [string]$FfprobePath) {
        $this.FfmpegPath = $FfmpegPath
        $this.FfprobePath = $FfprobePath
    }
}

class VvcMediaInspection {
    [string]$Path
    [bool]$Exists
    [double]$SizeMB
    [bool]$IsEmpty
    [bool]$Valid
    [string]$Reason
    [string]$VideoCodec
    [double]$DurationSec
    [Nullable[bool]]$Decodable

    VvcMediaInspection(
        [string]$Path,
        [bool]$Exists,
        [double]$SizeMB,
        [bool]$IsEmpty,
        [bool]$Valid,
        [string]$Reason,
        [string]$VideoCodec,
        [double]$DurationSec,
        [Nullable[bool]]$Decodable
    ) {
        $this.Path = $Path
        $this.Exists = $Exists
        $this.SizeMB = [Math]::Max(0.0, [Math]::Round($SizeMB, 2))
        $this.IsEmpty = $IsEmpty
        $this.Valid = $Valid
        $this.Reason = if ([string]::IsNullOrWhiteSpace($Reason)) { '' } else { $Reason }
        $this.VideoCodec = if ([string]::IsNullOrWhiteSpace($VideoCodec)) { '' } else { $VideoCodec }
        $this.DurationSec = $DurationSec
        $this.Decodable = $Decodable
    }
}

class VvcAuditResult {
    [string]$EpisodeKey
    [string]$Directory
    [string]$Status
    [string]$OriginalPath
    [string]$OriginalName
    [bool]$OriginalValid
    [string]$OriginalReason
    [string]$OriginalCodec
    [double]$OriginalDurationSec
    [double]$OriginalSizeMB
    [string]$VvcPath
    [string]$VvcName
    [bool]$VvcValid
    [string]$VvcReason
    [string]$VvcCodec
    [double]$VvcDurationSec
    [double]$VvcSizeMB
    [Nullable[double]]$DurationDriftSec
    [bool]$SuspiciousVvc
    [string[]]$SuspiciousReasons
    [bool]$SafeToDeleteOriginal
    [bool]$CanConvert

    VvcAuditResult(
        [string]$EpisodeKey,
        [string]$Directory,
        [string]$Status,
        [string]$OriginalPath,
        [string]$OriginalName,
        [bool]$OriginalValid,
        [string]$OriginalReason,
        [string]$OriginalCodec,
        [double]$OriginalDurationSec,
        [double]$OriginalSizeMB,
        [string]$VvcPath,
        [string]$VvcName,
        [bool]$VvcValid,
        [string]$VvcReason,
        [string]$VvcCodec,
        [double]$VvcDurationSec,
        [double]$VvcSizeMB,
        [Nullable[double]]$DurationDriftSec,
        [bool]$SuspiciousVvc,
        [string[]]$SuspiciousReasons,
        [bool]$SafeToDeleteOriginal,
        [bool]$CanConvert
    ) {
        $this.EpisodeKey = $EpisodeKey
        $this.Directory = $Directory
        $this.Status = $Status
        $this.OriginalPath = $OriginalPath
        $this.OriginalName = $OriginalName
        $this.OriginalValid = $OriginalValid
        $this.OriginalReason = $OriginalReason
        $this.OriginalCodec = $OriginalCodec
        $this.OriginalDurationSec = $OriginalDurationSec
        $this.OriginalSizeMB = [Math]::Max(0.0, [Math]::Round($OriginalSizeMB, 2))
        $this.VvcPath = $VvcPath
        $this.VvcName = $VvcName
        $this.VvcValid = $VvcValid
        $this.VvcReason = $VvcReason
        $this.VvcCodec = $VvcCodec
        $this.VvcDurationSec = $VvcDurationSec
        $this.VvcSizeMB = [Math]::Max(0.0, [Math]::Round($VvcSizeMB, 2))
        $this.DurationDriftSec = $DurationDriftSec
        $this.SuspiciousVvc = $SuspiciousVvc
        $this.SuspiciousReasons = @($SuspiciousReasons)
        $this.SafeToDeleteOriginal = $SafeToDeleteOriginal
        $this.CanConvert = $CanConvert
    }
}
