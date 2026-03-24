using namespace System
using namespace System.IO
using module .\VvcAudit.Enums.psm1

<#
.SYNOPSIS
    Validated ffmpeg/ffprobe tool paths for the current session.

.DESCRIPTION
    Small value object that stores the resolved paths to the ffmpeg and ffprobe
    executables used by the VVC workflow.

    The constructor guarantees that both paths are non-empty. It does not
    itself verify executability beyond whatever resolution logic produced the
    values.

.NOTES
    Use this type after command discovery/resolution has already succeeded.
#>
class VvcToolPaths {
    [string]$FfmpegPath
    [string]$FfprobePath

    VvcToolPaths([string]$FfmpegPath, [string]$FfprobePath) {
        if ([string]::IsNullOrWhiteSpace($FfmpegPath)) {
            throw [ArgumentException]::new('FfmpegPath is required.')
        }

        if ([string]::IsNullOrWhiteSpace($FfprobePath)) {
            throw [ArgumentException]::new('FfprobePath is required.')
        }

        $this.FfmpegPath = $FfmpegPath
        $this.FfprobePath = $FfprobePath
    }
}

<#
.SYNOPSIS
    Canonical inspection result for a single media file.

.DESCRIPTION
    Represents the normalized result of probing and optionally decoding one
    media file.

    This type captures file presence, size, validity, failure reason, codec,
    optional duration, and optional decodeability. Duration is nullable so
    unknown duration does not require a sentinel value such as `0`.
    Decodeability is also nullable so the model can distinguish between "not
    evaluated" and an explicit decode success/failure result.

    The constructor applies normalization and rejects inconsistent state
    combinations.

.INVARIANTS
    The constructor enforces the following rules:

    - Missing inspections cannot be valid.
    - Missing inspections cannot be marked as empty.
    - Empty inspections cannot be valid.
    - Duration cannot be negative.
    - Valid inspections must use `Reason = None`.
    - Invalid existing non-empty inspections must use an explicit non-`None`
      reason.

.NOTES
    `Name` is derived from `Path` using `[System.IO.Path]::GetFileName()`.
#>
class VvcMediaInspection {
    hidden static [double] NormalizeNonNegativeMb([double]$Value) {
        return [Math]::Max(0.0, [Math]::Round($Value, 2))
    }

    hidden static [string] NormalizeOptionalString([string]$Value) {
        if ([string]::IsNullOrWhiteSpace($Value)) {
            return ''
        }

        return $Value
    }

    hidden static [Nullable[double]] NormalizeNullableDuration([object]$Value) {
        if ($null -eq $Value) {
            return $null
        }

        return [double]$Value
    }

    hidden static [Nullable[bool]] NormalizeNullableBool([object]$Value) {
        if ($null -eq $Value) {
            return $null
        }

        return [bool]$Value
    }

    hidden static [void] ValidatePath([string]$Path) {
        if ([string]::IsNullOrWhiteSpace($Path)) {
            throw [ArgumentException]::new('Path is required.')
        }
    }

    hidden static [void] ValidateState(
        [bool]$Exists,
        [bool]$IsEmpty,
        [bool]$Valid,
        [VvcInspectionReason]$Reason,
        [Nullable[double]]$DurationSec
    ) {
        if (-not $Exists -and $Valid) {
            throw [InvalidOperationException]::new(
                'Missing inspections cannot be valid.'
            )
        }

        if (-not $Exists -and $IsEmpty) {
            throw [InvalidOperationException]::new(
                'Missing inspections cannot be marked empty.'
            )
        }

        if ($IsEmpty -and $Valid) {
            throw [InvalidOperationException]::new(
                'Empty inspections cannot be valid.'
            )
        }

        if ($null -ne $DurationSec -and [double]$DurationSec -lt 0.0) {
            throw [InvalidOperationException]::new(
                'DurationSec cannot be negative.'
            )
        }

        if ($Valid -and $Reason -ne [VvcInspectionReason]::None) {
            throw [InvalidOperationException]::new(
                'Valid inspections must use Reason = None.'
            )
        }

        if (
            -not $Valid -and
            $Exists -and
            -not $IsEmpty -and
            $Reason -eq [VvcInspectionReason]::None
        ) {
            throw [InvalidOperationException]::new(
                'Invalid existing inspections must use an explicit reason.'
            )
        }
    }

    [string]$Path
    [bool]$Exists
    [double]$SizeMB
    [bool]$IsEmpty
    [bool]$Valid
    [VvcInspectionReason]$Reason
    [string]$VideoCodec
    [Nullable[double]]$DurationSec
    [Nullable[bool]]$Decodable
    [string]$Name

    VvcMediaInspection(
        [string]$Path,
        [bool]$Exists,
        [double]$SizeMB,
        [bool]$IsEmpty,
        [bool]$Valid,
        [VvcInspectionReason]$Reason,
        [string]$VideoCodec,
        [object]$DurationSec,
        [object]$Decodable
    ) {
        $normalizedDurationSec = [VvcMediaInspection]::NormalizeNullableDuration(
            $DurationSec
        )
        $normalizedDecodable = [VvcMediaInspection]::NormalizeNullableBool(
            $Decodable
        )
        [VvcMediaInspection]::ValidatePath($Path)
        [VvcMediaInspection]::ValidateState(
            $Exists,
            $IsEmpty,
            $Valid,
            $Reason,
            $normalizedDurationSec
        )

        $this.Path = $Path
        $this.Exists = $Exists
        $this.SizeMB = [VvcMediaInspection]::NormalizeNonNegativeMb($SizeMB)
        $this.IsEmpty = $IsEmpty
        $this.Valid = $Valid
        $this.Reason = $Reason
        $this.VideoCodec = [VvcMediaInspection]::NormalizeOptionalString(
            $VideoCodec
        )
        $this.DurationSec = $normalizedDurationSec
        $this.Decodable = $normalizedDecodable
        $this.Name = [Path]::GetFileName($Path)
    }
}

<#
.SYNOPSIS
    Aggregate audit result for one grouped episode key.

.DESCRIPTION
    Represents the complete audit view for one logical media pair or group.

    This type composes the `Original` and `Vvc` inspections, records the derived
    audit status, stores optional duration drift, flags suspicious VVC output,
    and carries cleanup guidance such as `SafeToDeleteOriginal` and
    `CanConvert`.

    To preserve compatibility with older commands and tests, the class also
    exposes flattened projection properties such as `OriginalPath`,
    `OriginalValid`, `VvcPath`, and `VvcValid`. These are derived from the
    composed inspections at construction time. New code should prefer the
    `Original` and `Vvc` properties.

.INVARIANTS
    The constructor enforces the following rules:

    - `EpisodeKey` and `Directory` are required.
    - `DurationDriftSec` cannot be negative.
    - `SafeToDeleteOriginal` requires:
        - a non-null original inspection,
        - a non-null VVC inspection,
        - a valid original,
        - a valid VVC,
        - and a non-suspicious VVC.
    - `CanConvert` requires:
        - a non-null valid original,
        - and no valid VVC inspection.
    - `Status = OriginalValidAndVvcValid` requires both inspections to exist and
      be valid.

.NOTES
    Flattened compatibility properties are projections only; they are not
    separate sources of truth.
#>
class VvcAuditResult {
    hidden static [double] NormalizeNonNegativeMb([double]$Value) {
        return [Math]::Max(0.0, [Math]::Round($Value, 2))
    }

    hidden static [Nullable[double]] NormalizeNullableDuration([object]$Value) {
        if ($null -eq $Value) {
            return $null
        }

        return [double]$Value
    }

    hidden static [void] ValidateIdentity(
        [string]$EpisodeKey,
        [string]$Directory
    ) {
        if ([string]::IsNullOrWhiteSpace($EpisodeKey)) {
            throw [ArgumentException]::new('EpisodeKey is required.')
        }

        if ([string]::IsNullOrWhiteSpace($Directory)) {
            throw [ArgumentException]::new('Directory is required.')
        }
    }

    hidden static [void] ValidateDurationDrift(
        [Nullable[double]]$DurationDriftSec
    ) {
        if ($null -ne $DurationDriftSec -and [double]$DurationDriftSec -lt 0.0) {
            throw [InvalidOperationException]::new(
                'DurationDriftSec cannot be negative.'
            )
        }
    }

    hidden static [void] ValidateSafeToDelete(
        [bool]$SafeToDeleteOriginal,
        [VvcMediaInspection]$Original,
        [VvcMediaInspection]$Vvc,
        [bool]$SuspiciousVvc
    ) {
        if (-not $SafeToDeleteOriginal) {
            return
        }

        if (
            $null -eq $Original -or
            $null -eq $Vvc -or
            -not $Original.Valid -or
            -not $Vvc.Valid -or
            $SuspiciousVvc
        ) {
            throw [InvalidOperationException]::new(
                'SafeToDeleteOriginal requires valid original and VVC inspections.'
            )
        }
    }

    hidden static [void] ValidateCanConvert(
        [bool]$CanConvert,
        [VvcMediaInspection]$Original,
        [VvcMediaInspection]$Vvc
    ) {
        if (-not $CanConvert) {
            return
        }

        if (
            $null -eq $Original -or
            -not $Original.Valid -or
            ($null -ne $Vvc -and $Vvc.Valid)
        ) {
            throw [InvalidOperationException]::new(
                'CanConvert requires a valid original and no valid VVC inspection.'
            )
        }
    }

    hidden static [void] ValidateStatus(
        [VvcAuditStatus]$Status,
        [VvcMediaInspection]$Original,
        [VvcMediaInspection]$Vvc
    ) {
        if ($Status -ne [VvcAuditStatus]::OriginalValidAndVvcValid) {
            return
        }

        if (
            $null -eq $Original -or
            $null -eq $Vvc -or
            -not $Original.Valid -or
            -not $Vvc.Valid
        ) {
            throw [InvalidOperationException]::new(
                'OriginalValidAndVvcValid requires valid original and VVC inspections.'
            )
        }
    }

    hidden static [string] GetInspectionPath([VvcMediaInspection]$Inspection) {
        if ($null -ne $Inspection) {
            return $Inspection.Path
        }

        return $null
    }

    hidden static [string] GetInspectionName([VvcMediaInspection]$Inspection) {
        if ($null -ne $Inspection) {
            return $Inspection.Name
        }

        return $null
    }

    hidden static [bool] GetInspectionValid([VvcMediaInspection]$Inspection) {
        if ($null -ne $Inspection) {
            return $Inspection.Valid
        }

        return $false
    }

    hidden static [VvcInspectionReason] GetInspectionReason(
        [VvcMediaInspection]$Inspection
    ) {
        if ($null -ne $Inspection) {
            return $Inspection.Reason
        }

        return [VvcInspectionReason]::Missing
    }

    hidden static [string] GetInspectionCodec([VvcMediaInspection]$Inspection) {
        if ($null -ne $Inspection) {
            return $Inspection.VideoCodec
        }

        return ''
    }

    hidden static [Nullable[double]] GetInspectionDuration(
        [VvcMediaInspection]$Inspection
    ) {
        if ($null -ne $Inspection) {
            return $Inspection.DurationSec
        }

        return $null
    }

    hidden static [double] GetInspectionSizeMb([VvcMediaInspection]$Inspection) {
        if ($null -ne $Inspection) {
            return [VvcAuditResult]::NormalizeNonNegativeMb($Inspection.SizeMB)
        }

        return 0.0
    }

    [string]$EpisodeKey
    [string]$Directory
    [VvcAuditStatus]$Status
    [VvcMediaInspection]$Original
    [VvcMediaInspection]$Vvc
    [Nullable[double]]$DurationDriftSec
    [bool]$SuspiciousVvc
    [string[]]$SuspiciousReasons
    [bool]$SafeToDeleteOriginal
    [bool]$CanConvert

    [string]$OriginalPath
    [string]$OriginalName
    [bool]$OriginalValid
    [VvcInspectionReason]$OriginalReason
    [string]$OriginalCodec
    [Nullable[double]]$OriginalDurationSec
    [double]$OriginalSizeMB
    [string]$VvcPath
    [string]$VvcName
    [bool]$VvcValid
    [VvcInspectionReason]$VvcReason
    [string]$VvcCodec
    [Nullable[double]]$VvcDurationSec
    [double]$VvcSizeMB

    VvcAuditResult(
        [string]$EpisodeKey,
        [string]$Directory,
        [VvcAuditStatus]$Status,
        [VvcMediaInspection]$Original,
        [VvcMediaInspection]$Vvc,
        [object]$DurationDriftSec,
        [bool]$SuspiciousVvc,
        [string[]]$SuspiciousReasons,
        [bool]$SafeToDeleteOriginal,
        [bool]$CanConvert
    ) {
        $normalizedDurationDriftSec = [VvcAuditResult]::NormalizeNullableDuration(
            $DurationDriftSec
        )
        [VvcAuditResult]::ValidateIdentity($EpisodeKey, $Directory)
        [VvcAuditResult]::ValidateDurationDrift($normalizedDurationDriftSec)
        [VvcAuditResult]::ValidateSafeToDelete(
            $SafeToDeleteOriginal,
            $Original,
            $Vvc,
            $SuspiciousVvc
        )
        [VvcAuditResult]::ValidateCanConvert($CanConvert, $Original, $Vvc)
        [VvcAuditResult]::ValidateStatus($Status, $Original, $Vvc)

        $this.EpisodeKey = $EpisodeKey
        $this.Directory = $Directory
        $this.Status = $Status
        $this.Original = $Original
        $this.Vvc = $Vvc
        $this.DurationDriftSec = $normalizedDurationDriftSec
        $this.SuspiciousVvc = $SuspiciousVvc
        $this.SuspiciousReasons = @($SuspiciousReasons)
        $this.SafeToDeleteOriginal = $SafeToDeleteOriginal
        $this.CanConvert = $CanConvert

        $this.OriginalPath = [VvcAuditResult]::GetInspectionPath($Original)
        $this.OriginalName = [VvcAuditResult]::GetInspectionName($Original)
        $this.OriginalValid = [VvcAuditResult]::GetInspectionValid($Original)
        $this.OriginalReason = [VvcAuditResult]::GetInspectionReason($Original)
        $this.OriginalCodec = [VvcAuditResult]::GetInspectionCodec($Original)
        $this.OriginalDurationSec = [VvcAuditResult]::GetInspectionDuration(
            $Original
        )
        $this.OriginalSizeMB = [VvcAuditResult]::GetInspectionSizeMb($Original)

        $this.VvcPath = [VvcAuditResult]::GetInspectionPath($Vvc)
        $this.VvcName = [VvcAuditResult]::GetInspectionName($Vvc)
        $this.VvcValid = [VvcAuditResult]::GetInspectionValid($Vvc)
        $this.VvcReason = [VvcAuditResult]::GetInspectionReason($Vvc)
        $this.VvcCodec = [VvcAuditResult]::GetInspectionCodec($Vvc)
        $this.VvcDurationSec = [VvcAuditResult]::GetInspectionDuration($Vvc)
        $this.VvcSizeMB = [VvcAuditResult]::GetInspectionSizeMb($Vvc)
    }
}
