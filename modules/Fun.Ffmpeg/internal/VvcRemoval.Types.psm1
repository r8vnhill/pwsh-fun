class VvcRemovalResult {
    [string]$EpisodeKey
    [string]$OriginalPath
    [string]$VvcPath
    [string]$Status
    [string]$Reason
    [double]$OriginalSizeMB
    [double]$VvcSizeMB
    [double]$ReclaimedMB
    [Nullable[double]]$DurationDriftSec
    [string]$ErrorMessage

    VvcRemovalResult(
        [string]$EpisodeKey,
        [string]$OriginalPath,
        [string]$VvcPath,
        [string]$Status,
        [string]$Reason,
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
        $this.OriginalSizeMB = $OriginalSizeMB
        $this.VvcSizeMB = $VvcSizeMB
        $this.ReclaimedMB = [math]::Round($ReclaimedMB, 2)
        $this.DurationDriftSec = $DurationDriftSec
        $this.ErrorMessage = $ErrorMessage
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
        $this.TotalReclaimedMB = [math]::Round($TotalReclaimedMB, 2)
    }
}
