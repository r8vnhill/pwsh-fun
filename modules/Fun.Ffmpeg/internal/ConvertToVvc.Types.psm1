#Requires -Version 7.6
using namespace System
using namespace System.IO

class VvcConversionInvariantException : Exception {
    VvcConversionInvariantException([string]$Message) : base($Message) {}
}

enum VvcConversionStatus {
    Converted
    Skipped
    Failed
}

enum VvcConversionAction {
    Convert
    Skip
    Fail
}

enum VvcConversionReason {
    None
    InvalidInput
    ExistingOutputValid
    EncodeFailed
    EncodedOutputMissing
    ProbeFailed
    UnexpectedCodec
    DurationUnavailable
    DurationDrift
    DecodeFailed
    PromoteFailed
    SizeUnavailable
    UnexpectedFailure
}

class VvcConversionGuard {
    static [void] Invariant([bool]$Condition, [string]$Message) {
        if (-not $Condition) {
            throw [VvcConversionInvariantException]::new($Message)
        }
    }

    static [string] RequiredString([string]$Value, [string]$Name) {
        [VvcConversionGuard]::Invariant(
            -not [string]::IsNullOrWhiteSpace($Value),
            "$Name must not be blank."
        )
        return $Value
    }

    static [string] OptionalString([string]$Value) {
        if ([string]::IsNullOrWhiteSpace($Value)) {
            return $null
        }

        return $Value.Trim()
    }

    static [Nullable[double]] OptionalNonNegativeDouble(
        [object]$Value,
        [string]$Name
    ) {
        if ($null -eq $Value) {
            return $null
        }

        $number = [double]$Value
        [VvcConversionGuard]::Invariant($number -ge 0.0, "$Name cannot be negative.")
        return $number
    }
}

class VvcConversionRequest {
    [string]$InputPath
    [string]$OutputDir
    [string]$Suffix
    [int]$Qp
    [string]$Preset
    [bool]$Overwrite
    [string]$VerifyMode
    [double]$MaxDriftSec
    [string]$FfmpegPath
    [string]$FfprobePath
    [int]$EncoderThreads

    VvcConversionRequest(
        [string]$InputPath,
        [string]$OutputDir,
        [string]$Suffix,
        [int]$Qp,
        [string]$Preset,
        [bool]$Overwrite,
        [string]$VerifyMode,
        [double]$MaxDriftSec,
        [string]$FfmpegPath,
        [string]$FfprobePath,
        [int]$EncoderThreads
    ) {
        [VvcConversionGuard]::Invariant($Qp -ge 0 -and $Qp -le 63, 'Qp must be between 0 and 63.')
        [VvcConversionGuard]::Invariant($VerifyMode -in @('none', 'quick', 'strict'), 'VerifyMode is invalid.')
        [VvcConversionGuard]::Invariant($MaxDriftSec -ge 0.0, 'MaxDriftSec cannot be negative.')
        [VvcConversionGuard]::Invariant($EncoderThreads -ge 0, 'EncoderThreads cannot be negative.')

        $this.InputPath = [VvcConversionGuard]::RequiredString($InputPath, 'InputPath')
        $this.OutputDir = [VvcConversionGuard]::RequiredString($OutputDir, 'OutputDir')
        $this.Suffix = [VvcConversionGuard]::RequiredString($Suffix, 'Suffix')
        $this.Qp = $Qp
        $this.Preset = [VvcConversionGuard]::RequiredString($Preset, 'Preset')
        $this.Overwrite = $Overwrite
        $this.VerifyMode = $VerifyMode
        $this.MaxDriftSec = $MaxDriftSec
        $this.FfmpegPath = [VvcConversionGuard]::RequiredString($FfmpegPath, 'FfmpegPath')
        $this.FfprobePath = [VvcConversionGuard]::RequiredString($FfprobePath, 'FfprobePath')
        $this.EncoderThreads = $EncoderThreads
    }
}

class VvcConversionPathSet {
    [string]$InputPath
    [string]$OutputPath
    [string]$TempPath

    VvcConversionPathSet([string]$InputPath, [string]$OutputPath, [string]$TempPath) {
        $this.InputPath = [VvcConversionGuard]::RequiredString($InputPath, 'InputPath')
        $this.OutputPath = [VvcConversionGuard]::RequiredString($OutputPath, 'OutputPath')
        $this.TempPath = [VvcConversionGuard]::RequiredString($TempPath, 'TempPath')

        [VvcConversionGuard]::Invariant(
            $this.TempPath -ne $this.OutputPath,
            'TempPath must differ from OutputPath.'
        )
        [VvcConversionGuard]::Invariant(
            [Path]::GetDirectoryName($this.TempPath) -eq [Path]::GetDirectoryName($this.OutputPath),
            'TempPath must be in the output directory.'
        )
        [VvcConversionGuard]::Invariant(
            [Path]::GetExtension($this.TempPath) -eq [Path]::GetExtension($this.OutputPath),
            'TempPath must use the output extension.'
        )
    }
}

class VvcNativeResult {
    [string]$ToolPath
    [string[]]$Arguments
    [int]$ExitCode
    [string]$Stdout
    [string]$Stderr
    [bool]$Succeeded

    VvcNativeResult(
        [string]$ToolPath,
        [string[]]$Arguments,
        [int]$ExitCode,
        [string]$Stdout,
        [string]$Stderr
    ) {
        $this.ToolPath = [VvcConversionGuard]::RequiredString($ToolPath, 'ToolPath')
        [VvcConversionGuard]::Invariant($null -ne $Arguments, 'Arguments cannot be null.')
        $this.Arguments = @($Arguments)
        $this.ExitCode = $ExitCode
        $this.Stdout = [VvcConversionGuard]::OptionalString($Stdout)
        $this.Stderr = [VvcConversionGuard]::OptionalString($Stderr)
        $this.Succeeded = $ExitCode -eq 0
    }
}

class VvcMediaProbe {
    [bool]$Valid
    [VvcConversionReason]$Reason
    [string]$Codec
    [Nullable[double]]$DurationSec
    [string]$Diagnostic

    VvcMediaProbe(
        [bool]$Valid,
        [VvcConversionReason]$Reason,
        [string]$Codec,
        [object]$DurationSec,
        [string]$Diagnostic
    ) {
        if ($Valid) {
            [VvcConversionGuard]::Invariant($Reason -eq [VvcConversionReason]::None, 'Valid probes must use Reason = None.')
            [VvcConversionGuard]::RequiredString($Codec, 'Codec') | Out-Null
        }
        else {
            [VvcConversionGuard]::Invariant($Reason -ne [VvcConversionReason]::None, 'Invalid probes require an explicit reason.')
        }

        $this.Valid = $Valid
        $this.Reason = $Reason
        $this.Codec = [VvcConversionGuard]::OptionalString($Codec)
        $this.DurationSec = [VvcConversionGuard]::OptionalNonNegativeDouble($DurationSec, 'DurationSec')
        $this.Diagnostic = [VvcConversionGuard]::OptionalString($Diagnostic)
    }
}

class VvcOutputValidation {
    [bool]$Valid
    [VvcConversionReason]$Reason
    [Nullable[double]]$DurationDriftSec
    [string]$Diagnostic

    VvcOutputValidation(
        [bool]$Valid,
        [VvcConversionReason]$Reason,
        [object]$DurationDriftSec,
        [string]$Diagnostic
    ) {
        if ($Valid) {
            [VvcConversionGuard]::Invariant($Reason -eq [VvcConversionReason]::None, 'Valid output validation must use Reason = None.')
        }
        else {
            [VvcConversionGuard]::Invariant($Reason -ne [VvcConversionReason]::None, 'Invalid output validation requires an explicit reason.')
        }

        $this.Valid = $Valid
        $this.Reason = $Reason
        $this.DurationDriftSec = [VvcConversionGuard]::OptionalNonNegativeDouble($DurationDriftSec, 'DurationDriftSec')
        $this.Diagnostic = [VvcConversionGuard]::OptionalString($Diagnostic)
    }
}

class ConvertToVvcResult {
    [string]$File
    [string]$InputPath
    [string]$OutputPath
    [object]$Status
    [object]$Reason
    [double]$OriginalMB
    [double]$NewMB
    [Nullable[double]]$Ratio
    [Nullable[int]]$ExitCode
    [string]$Diagnostic
    [bool]$Ok
    [bool]$Skipped

    ConvertToVvcResult(
        [string]$File,
        [bool]$Ok,
        [bool]$Skipped,
        [string]$Reason,
        [double]$OriginalMB,
        [double]$NewMB,
        [double]$Ratio
    ) {
        $this.File = $File
        $this.InputPath = $File
        $this.OutputPath = $null
        $this.Status = if ($Ok -and -not $Skipped) {
            [VvcConversionStatus]::Converted
        }
        elseif ($Ok -and $Skipped) {
            [VvcConversionStatus]::Skipped
        }
        else {
            [VvcConversionStatus]::Failed
        }
        $this.Ok = $Ok
        $this.Skipped = $Skipped
        $this.Reason = if ([string]::IsNullOrWhiteSpace($Reason)) { '' } else { $Reason }
        $this.OriginalMB = [Math]::Round([Math]::Max(0.0, $OriginalMB), 2)
        $this.NewMB = [Math]::Round([Math]::Max(0.0, $NewMB), 2)
        $this.Ratio = [Math]::Round([Math]::Max(0.0, $Ratio), 1)
        $this.ExitCode = $null
        $this.Diagnostic = $null
    }

    hidden ConvertToVvcResult(
        [string]$File,
        [string]$InputPath,
        [string]$OutputPath,
        [VvcConversionStatus]$Status,
        [VvcConversionReason]$Reason,
        [double]$OriginalMB,
        [double]$NewMB,
        [object]$Ratio,
        [object]$ExitCode,
        [string]$Diagnostic
    ) {
        [ConvertToVvcResult]::ValidateState($InputPath, $OutputPath, $Status, $Reason, $NewMB, $Ratio, $Diagnostic)

        $this.File = [VvcConversionGuard]::RequiredString($File, 'File')
        $this.InputPath = $InputPath
        $this.OutputPath = $OutputPath
        $this.Status = $Status
        $this.Reason = $Reason
        $this.OriginalMB = [Math]::Round([Math]::Max(0.0, $OriginalMB), 2)
        $this.NewMB = [Math]::Round([Math]::Max(0.0, $NewMB), 2)
        $this.Ratio = [VvcConversionGuard]::OptionalNonNegativeDouble($Ratio, 'Ratio')
        $this.ExitCode = if ($null -eq $ExitCode) { $null } else { [int]$ExitCode }
        $this.Diagnostic = [VvcConversionGuard]::OptionalString($Diagnostic)
        $this.Ok = $Status -ne [VvcConversionStatus]::Failed
        $this.Skipped = $Status -eq [VvcConversionStatus]::Skipped
    }

    hidden static [void] ValidateState(
        [string]$InputPath,
        [string]$OutputPath,
        [VvcConversionStatus]$Status,
        [VvcConversionReason]$Reason,
        [double]$NewMB,
        [object]$Ratio,
        [string]$Diagnostic
    ) {
        [VvcConversionGuard]::RequiredString($InputPath, 'InputPath') | Out-Null
        [VvcConversionGuard]::OptionalNonNegativeDouble($Ratio, 'Ratio') | Out-Null

        if ($Status -eq [VvcConversionStatus]::Converted) {
            [VvcConversionGuard]::Invariant($Reason -eq [VvcConversionReason]::None, 'Converted results must use Reason = None.')
            [VvcConversionGuard]::RequiredString($OutputPath, 'OutputPath') | Out-Null
            [VvcConversionGuard]::Invariant($NewMB -gt 0.0, 'Converted results require positive NewMB.')
            return
        }

        [VvcConversionGuard]::Invariant($Reason -ne [VvcConversionReason]::None, 'Skipped and failed results require an explicit reason.')
        [VvcConversionGuard]::OptionalString($Diagnostic) | Out-Null
    }

    static [ConvertToVvcResult] Converted(
        [string]$File,
        [string]$InputPath,
        [string]$OutputPath,
        [double]$OriginalMB,
        [double]$NewMB,
        [object]$Ratio
    ) {
        return [ConvertToVvcResult]::new(
            $File,
            $InputPath,
            $OutputPath,
            [VvcConversionStatus]::Converted,
            [VvcConversionReason]::None,
            $OriginalMB,
            $NewMB,
            $Ratio,
            $null,
            $null
        )
    }

    static [ConvertToVvcResult] Skipped(
        [string]$File,
        [string]$InputPath,
        [VvcConversionReason]$Reason,
        [string]$Diagnostic
    ) {
        return [ConvertToVvcResult]::new(
            $File,
            $InputPath,
            $null,
            [VvcConversionStatus]::Skipped,
            $Reason,
            0.0,
            0.0,
            $null,
            $null,
            $Diagnostic
        )
    }

    static [ConvertToVvcResult] Failed(
        [string]$File,
        [string]$InputPath,
        [VvcConversionReason]$Reason,
        [object]$ExitCode,
        [string]$Diagnostic
    ) {
        return [ConvertToVvcResult]::new(
            $File,
            $InputPath,
            $null,
            [VvcConversionStatus]::Failed,
            $Reason,
            0.0,
            0.0,
            $null,
            $ExitCode,
            $Diagnostic
        )
    }
}

class VvcConversionDecision {
    [VvcConversionAction]$Action
    [VvcConversionReason]$Reason
    [ConvertToVvcResult]$Result
    [string]$Diagnostic

    VvcConversionDecision(
        [VvcConversionAction]$Action,
        [VvcConversionReason]$Reason,
        [ConvertToVvcResult]$Result,
        [string]$Diagnostic
    ) {
        if ($Action -eq [VvcConversionAction]::Convert) {
            [VvcConversionGuard]::Invariant($Reason -eq [VvcConversionReason]::None, 'Convert decisions must use Reason = None.')
            [VvcConversionGuard]::Invariant($null -eq $Result, 'Convert decisions must not include a result.')
        }
        else {
            [VvcConversionGuard]::Invariant($Reason -ne [VvcConversionReason]::None, 'Skip and fail decisions require an explicit reason.')
            [VvcConversionGuard]::Invariant($null -ne $Result, 'Skip and fail decisions require a result.')
        }

        $this.Action = $Action
        $this.Reason = $Reason
        $this.Result = $Result
        $this.Diagnostic = [VvcConversionGuard]::OptionalString($Diagnostic)
    }

    static [VvcConversionDecision] Convert() {
        return [VvcConversionDecision]::new(
            [VvcConversionAction]::Convert,
            [VvcConversionReason]::None,
            $null,
            $null
        )
    }

    static [VvcConversionDecision] Skip(
        [VvcConversionReason]$Reason,
        [ConvertToVvcResult]$Result
    ) {
        return [VvcConversionDecision]::new(
            [VvcConversionAction]::Skip,
            $Reason,
            $Result,
            $null
        )
    }

    static [VvcConversionDecision] Fail(
        [VvcConversionReason]$Reason,
        [ConvertToVvcResult]$Result
    ) {
        return [VvcConversionDecision]::new(
            [VvcConversionAction]::Fail,
            $Reason,
            $Result,
            $null
        )
    }
}
