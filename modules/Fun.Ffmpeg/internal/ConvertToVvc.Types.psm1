#Requires -Version 7.5
using namespace System

class ConvertToVvcResult {
    [string]$File
    [bool]$Ok
    [bool]$Skipped
    [string]$Reason
    [double]$OriginalMB
    [double]$NewMB
    [double]$Ratio

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
        $this.Ok = $Ok
        $this.Skipped = $Skipped
        $this.Reason = if ([string]::IsNullOrWhiteSpace($Reason)) {
            ''
        } else {
            $Reason
        }
        $this.OriginalMB = [Math]::Round([Math]::Max(0.0, $OriginalMB), 2)
        $this.NewMB = [Math]::Round([Math]::Max(0.0, $NewMB), 2)
        $this.Ratio = [Math]::Round([Math]::Max(0.0, $Ratio), 1)
    }
}
