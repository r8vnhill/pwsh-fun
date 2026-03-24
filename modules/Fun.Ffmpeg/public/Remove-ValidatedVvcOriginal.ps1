#Requires -Version 7.4

Set-StrictMode -Version 3.0

<#
.SYNOPSIS
    Remove original files only when a validated `_vvc` counterpart exists.

.DESCRIPTION
    Audits a directory with `Get-VvcAudit`, then removes originals only for items that the
    audit has already marked as safe to delete. The command emits one structured result
    object per audited item so batch runs, `-WhatIf`, and tests can inspect the outcome of
    every candidate rather than only successful deletions.

    `Get-VvcAudit` remains the source of truth for media validation, duration drift, and
    safety checks. This command is responsible only for extension normalization, stable
    processing order, deletion, and reporting removal outcomes.

.PARAMETER InputDir
    Root directory to audit. Accepts pipeline input by value and by property name.

.PARAMETER Suffix
    Suffix that identifies VVC outputs paired with original files.

.PARAMETER Extensions
    Video file extensions to consider. Values are normalized so `mkv` and `.mkv` are
    treated the same before the audit runs.

.PARAMETER Verify
    Verification mode forwarded to `Get-VvcAudit`.

.PARAMETER MaxDrift
    Maximum allowed duration drift, in seconds, forwarded to `Get-VvcAudit`.

.PARAMETER MinExpectedVvcMB
    Minimum expected VVC output size, in megabytes, forwarded to `Get-VvcAudit`.

.PARAMETER Recurse
    Include subdirectories when collecting audit candidates.

.PARAMETER StopOnError
    Stop on the first delete failure after emitting that item's `Failed` result.

.PARAMETER IncludeSummary
    Append a final summary object with audited, removed, skipped, would-remove, and failed
    counts plus total reclaimed space.

.OUTPUTS
    VvcRemovalResult
    Per-item results include `EpisodeKey`, `OriginalPath`, `VvcPath`, `Status`,
    `Reason`, `OriginalSizeMB`, `VvcSizeMB`, `ReclaimedMB`, `DurationDriftSec`,
    and `ErrorMessage`. When `-IncludeSummary` is used, the final object is a
    `VvcRemovalSummary` instance with aggregate count fields and `TotalReclaimedMB`.

.EXAMPLE
    Remove-ValidatedVvcOriginal -InputDir .\library -Confirm:$false

    Audits the current library folder, removes only originals that have a validated VVC
    counterpart, and returns one result object per audited item.

.EXAMPLE
    Remove-ValidatedVvcOriginal -InputDir .\library -WhatIf

    Shows what would be removed and returns `WouldRemove` results without deleting files.

.EXAMPLE
    Get-ChildItem .\library -Directory | Remove-ValidatedVvcOriginal -IncludeSummary

    Processes multiple input directories from the pipeline and appends one summary
    object at the end of the run.

.NOTES
    Result statuses are behavior-oriented: `Removed`, `Skipped`, `WouldRemove`, and
    `Failed`. Reasons are emitted only when needed to explain why an item was not removed.
#>
function Remove-ValidatedVvcOriginal {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $InputDir = '.',

        [ValidateNotNullOrEmpty()]
        [string] $Suffix = '_vvc',

        [ValidateNotNullOrEmpty()]
        [string[]] $Extensions = @(
            '.mkv', '.mp4', '.mov', '.avi', '.ts', '.m2ts', '.webm'
        ),

        [ValidateSet('quick', 'strict')]
        [string] $Verify = 'quick',

        [ValidateRange(0.0, 3600.0)]
        [double] $MaxDrift = 1.5,

        [ValidateRange(0.0, 10240.0)]
        [double] $MinExpectedVvcMB = 32.0,

        [switch] $Recurse,

        [switch] $StopOnError,

        [switch] $IncludeSummary
    )

    begin {
        $allResults = [System.Collections.Generic.List[VvcRemovalResult]]::new()
    }

    process {
        $normalizedExtensions = ConvertTo-VvcRemovalExtensions -Extensions $Extensions
        $auditParams = @{
            InputDir         = $InputDir
            Suffix           = $Suffix
            Extensions       = $normalizedExtensions
            Verify           = $Verify
            MaxDrift         = $MaxDrift
            MinExpectedVvcMB = $MinExpectedVvcMB
            Recurse          = $Recurse
        }
        $auditItems = Get-VvcRemovalAuditItems @auditParams

        foreach ($item in $auditItems) {
            $result = Get-VvcRemovalAction -Item $item
            if ($null -eq $result) {
                $action = Get-VvcRemovalShouldProcessAction -Item $item
                if (-not $PSCmdlet.ShouldProcess($item.OriginalPath, $action)) {
                    $resultParams = @{
                        Item        = $item
                        Status      = 'WouldRemove'
                        Reason      = 'WhatIf'
                        ReclaimedMB = $item.OriginalSizeMB
                    }
                    $result = New-VvcRemovalResult @resultParams
                } else {
                    $removeParams = @{
                        Item        = $item
                        StopOnError = $StopOnError
                    }
                    $result = Invoke-VvcOriginalRemoval @removeParams
                }
            }

            Write-VvcRemovalResult -Results $allResults -Result $result
        }
    }

    end {
        if ($IncludeSummary) {
            New-VvcRemovalSummary -Results $allResults
        }
    }
}
