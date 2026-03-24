using namespace System

class VvcRemovalException : Exception {
    VvcRemovalException([string]$Message) : base($Message) {}
    VvcRemovalException([string]$Message, [Exception]$InnerException) : base($Message, $InnerException) {}
}

class VvcRemovalInvariantException : VvcRemovalException {
    VvcRemovalInvariantException([string]$Message) : base($Message) {}
    VvcRemovalInvariantException([string]$Message, [Exception]$InnerException) : base($Message, $InnerException) {}
}

class VvcRemovalConfigurationException : VvcRemovalException {
    VvcRemovalConfigurationException([string]$Message) : base($Message) {}
    VvcRemovalConfigurationException([string]$Message, [Exception]$InnerException) : base($Message, $InnerException) {}
}

class VvcRemovalExecutionException : VvcRemovalException {
    VvcRemovalExecutionException([string]$Message) : base($Message) {}
    VvcRemovalExecutionException([string]$Message, [Exception]$InnerException) : base($Message, $InnerException) {}
}

enum VvcRemovalStatus {
    Removed
    Skipped
    WouldRemove
    Failed
}

enum VvcRemovalReason {
    None
    MissingOriginalPath
    UnsafeToDelete
    WhatIf
    RemoveFailed
}

class VvcRemovalResult {
    [string]$EpisodeKey
    [string]$OriginalPath
    [string]$VvcPath
    [VvcRemovalStatus]$Status
    [VvcRemovalReason]$Reason
    [double]$OriginalSizeMB
    [double]$VvcSizeMB
    [double]$ReclaimedMB
    [Nullable[double]]$DurationDriftSec
    [string]$ErrorMessage

    VvcRemovalResult(
        [string]$EpisodeKey,
        [string]$OriginalPath,
        [string]$VvcPath,
        [VvcRemovalStatus]$Status,
        [VvcRemovalReason]$Reason,
        [double]$OriginalSizeMB,
        [double]$VvcSizeMB,
        [double]$ReclaimedMB,
        [Nullable[double]]$DurationDriftSec,
        [string]$ErrorMessage
    ) {
        $this.EpisodeKey = $EpisodeKey
        $this.OriginalPath = $OriginalPath
        $this.VvcPath = $VvcPath
        $this.Status = $Status
        $this.Reason = $Reason
        $this.OriginalSizeMB = [Math]::Max(0.0, $OriginalSizeMB)
        $this.VvcSizeMB = [Math]::Max(0.0, $VvcSizeMB)
        $this.ReclaimedMB = [math]::Round([Math]::Max(0.0, $ReclaimedMB), 2)
        $this.DurationDriftSec = $DurationDriftSec
        $this.ErrorMessage = if ([string]::IsNullOrWhiteSpace($ErrorMessage)) { $null } else { $ErrorMessage }

        if ($this.Status -eq [VvcRemovalStatus]::Removed -and $this.Reason -ne [VvcRemovalReason]::None) {
            throw [VvcRemovalInvariantException]::new(
                'Removed results must use Reason = None.'
            )
        }

        if ($this.Status -ne [VvcRemovalStatus]::Removed -and $this.Reason -eq [VvcRemovalReason]::None) {
            throw [VvcRemovalInvariantException]::new(
                'Non-removed results must include an explicit reason.'
            )
        }
    }
}

class VvcRemovalDecision {
    [bool]$CanProceed
    [VvcRemovalResult]$Result
    [string]$ShouldProcessAction

    VvcRemovalDecision(
        [bool]$CanProceed,
        [VvcRemovalResult]$Result,
        [string]$ShouldProcessAction
    ) {
        $this.CanProceed = $CanProceed
        $this.Result = $Result
        $this.ShouldProcessAction = $ShouldProcessAction

        if ($CanProceed -and [string]::IsNullOrWhiteSpace($ShouldProcessAction)) {
            throw [VvcRemovalInvariantException]::new(
                'Proceeding decisions must include a ShouldProcessAction.'
            )
        }

        if ($CanProceed -and $null -ne $Result) {
            throw [VvcRemovalInvariantException]::new(
                'Proceeding decisions must not include a precomputed result.'
            )
        }

        if (-not $CanProceed -and $null -eq $Result) {
            throw [VvcRemovalInvariantException]::new(
                'Non-proceeding decisions must include a result.'
            )
        }
    }
}

class VvcRemovalSummary {
    [int]$AuditedCount
    [int]$RemovedCount
    [int]$SkippedCount
    [int]$WouldRemoveCount
    [int]$FailedCount
    [double]$TotalReclaimedMB

    VvcRemovalSummary(
        [int]$AuditedCount,
        [int]$RemovedCount,
        [int]$SkippedCount,
        [int]$WouldRemoveCount,
        [int]$FailedCount,
        [double]$TotalReclaimedMB
    ) {
        $this.AuditedCount = $AuditedCount
        $this.RemovedCount = $RemovedCount
        $this.SkippedCount = $SkippedCount
        $this.WouldRemoveCount = $WouldRemoveCount
        $this.FailedCount = $FailedCount
        $this.TotalReclaimedMB = [math]::Round([Math]::Max(0.0, $TotalReclaimedMB), 2)
    }
}
