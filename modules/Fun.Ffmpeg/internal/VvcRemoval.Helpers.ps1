#Requires -Version 7.5
using namespace System
using namespace System.Collections.Generic
using module .\VvcRemoval.Types.psm1

Set-StrictMode -Version 3.0

<#
.SYNOPSIS
    Create a typed removal result from an audit item.

.DESCRIPTION
    Wraps construction of `VvcRemovalResult` so the rest of the workflow has a single
    place to translate an audit item plus workflow state into a typed result.

    Callers provide the removal status and any optional contextual information such as the
    reason, reclaimed space, and an error message. The resulting object is suitable for
    accumulation, pipeline emission, and summary generation.

.PARAMETER Item
    Audit item that supplies the episode identity, source and VVC paths, size information,
    and optional duration drift used to build the result.

.PARAMETER Status
    Final workflow status for the audit item.

.PARAMETER Reason
    Optional reason that explains why the item was skipped, would be removed, or failed.
    Defaults to `None`.

.PARAMETER ReclaimedMB
    Amount of space reclaimed by removing the original file, in megabytes. This is
    typically set only for successful removals and dry-run "would remove" outcomes.

.PARAMETER ErrorMessage
    Optional error message captured from a failed delete attempt.

.OUTPUTS
    VvcRemovalResult
    A typed result object describing the outcome for a single audited item.

.EXAMPLE
    New-VvcRemovalResult -Item $item -Status Removed -ReclaimedMB $item.OriginalSizeMB

    Creates a successful removal result for a validated item.

.EXAMPLE
    New-VvcRemovalResult -Item $item -Status Skipped -Reason UnsafeToDelete

    Creates a skipped result when the audit has determined that the original is not safe
    to remove.
#>
function New-VvcRemovalResult {
    [OutputType([VvcRemovalResult])]
    param(
        [Parameter(Mandatory)]
        $Item,

        [Parameter(Mandatory)]
        [VvcRemovalStatus] $Status,

        [VvcRemovalReason] $Reason = [VvcRemovalReason]::None,

        [double] $ReclaimedMB = 0.0,

        [string] $ErrorMessage
    )

    [VvcRemovalResult]::new(
        $Item.EpisodeKey,
        $Item.OriginalPath,
        $Item.VvcPath,
        $Status,
        $Reason,
        [double]$Item.OriginalSizeMB,
        [double]$Item.VvcSizeMB,
        $ReclaimedMB,
        [Nullable[double]]$Item.DurationDriftSec,
        $ErrorMessage
    )
}

<#
.SYNOPSIS
    Normalize the file-extension list used for VVC auditing.

.DESCRIPTION
    Canonicalizes extension values before they are forwarded to `Get-VvcAudit`.

    Each input value is trimmed, lowercased, forced to include a leading dot, and
    deduplicated while preserving first-seen order. Blank or whitespace-only values are
    ignored. If normalization leaves no usable extensions, the helper throws an exception
    instead of allowing the caller to continue with an empty filter.

.PARAMETER Extensions
    Collection of extension strings to normalize.

.OUTPUTS
    System.String[]
    A normalized array of distinct extensions such as `.mkv` or `.mp4`.

.EXAMPLE
    ConvertTo-VvcRemovalExtensions -Extensions @('mkv', '.MP4', '  mov  ', '', '.mkv')

    Returns `.mkv`, `.mp4`, and `.mov` in that order.

.NOTES
    Deduplication uses ordinal string comparison after lowercase normalization.
#>
function ConvertTo-VvcRemovalExtensions {
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string[]] $Extensions
    )

    [string[]]$normalized = @()
    $seen = [HashSet[string]]::new([StringComparer]::Ordinal)

    foreach ($extension in $Extensions) {
        if ([string]::IsNullOrWhiteSpace($extension)) {
            continue
        }

        $trimmed = $extension.Trim().ToLowerInvariant()
        if (-not $trimmed.StartsWith('.')) {
            $trimmed = ".$trimmed"
        }

        if ($seen.Add($trimmed)) {
            $normalized += $trimmed
        }
    }

    if ($normalized.Count -eq 0) {
        throw [VvcRemovalConfigurationException]::new(
            'At least one non-empty extension is required after normalization.'
        )
    }

    $normalized
}

<#
.SYNOPSIS
    Retrieve and deterministically order audit items for removal processing.

.DESCRIPTION
    Calls `Get-VvcAudit` with the supplied parameters and sorts the resulting items into a
    stable order before the public command processes them.

    Stable ordering makes logs easier to read and tests easier to write because the result
    sequence does not depend on filesystem enumeration order. Items are sorted first by
    `OriginalPath`, with missing paths treated as empty strings, and then by `EpisodeKey`.

.PARAMETER InputDir
    Root directory passed to `Get-VvcAudit`.

.PARAMETER Suffix
    Suffix used to identify VVC outputs associated with originals.

.PARAMETER Extensions
    Normalized extension list passed to `Get-VvcAudit`.

.PARAMETER Verify
    Verification mode forwarded to `Get-VvcAudit`.

.PARAMETER MaxDrift
    Maximum allowed duration drift, in seconds, forwarded to `Get-VvcAudit`.

.PARAMETER MinExpectedVvcMB
    Minimum expected VVC file size, in megabytes, forwarded to `Get-VvcAudit`.

.PARAMETER Recurse
    When `$true`, includes subdirectories during auditing.

.OUTPUTS
    VvcAuditResult[]
    Audit items returned by `Get-VvcAudit`, sorted into deterministic order.

.EXAMPLE
    Get-VvcRemovalAuditItems -InputDir . -Suffix '_vvc' -Extensions @('.mkv') `
        -Verify 'quick' -MaxDrift 1.5 -MinExpectedVvcMB 32 -Recurse $true

    Returns audit items ready for removal processing in a stable order.
#>
function Get-VvcRemovalAuditItems {
    [OutputType([VvcAuditResult[]])]
    param(
        [Parameter(Mandatory)]
        [string] $InputDir,

        [Parameter(Mandatory)]
        [string] $Suffix,

        [Parameter(Mandatory)]
        [string[]] $Extensions,

        [Parameter(Mandatory)]
        [string] $Verify,

        [Parameter(Mandatory)]
        [double] $MaxDrift,

        [Parameter(Mandatory)]
        [double] $MinExpectedVvcMB,

        [Parameter(Mandatory)]
        [bool] $Recurse
    )

    $auditParams = @{
        InputDir         = $InputDir
        Suffix           = $Suffix
        Extensions       = $Extensions
        Verify           = $Verify
        MaxDrift         = $MaxDrift
        MinExpectedVvcMB = $MinExpectedVvcMB
        Recurse          = $Recurse
    }
    $sortByOriginalPath = @{
        Expression = {
            if ([string]::IsNullOrWhiteSpace($_.OriginalPath)) {
                [string]::Empty
            }
            else {
                $_.OriginalPath
            }
        }
    }
    $sortByEpisodeKey = @{ Expression = { $_.EpisodeKey } }

    @(Get-VvcAudit @auditParams) |
        Sort-Object $sortByOriginalPath, $sortByEpisodeKey
}

<#
.SYNOPSIS
    Build the `ShouldProcess` action text for a removable audit item.

.DESCRIPTION
    Creates the human-readable action string passed to `ShouldProcess` by the public
    command. Keeping the message construction in one helper makes confirmation and dry-run
    text consistent across the removal workflow.

.PARAMETER Item
    Audit item that is eligible to proceed to the delete stage.

.OUTPUTS
    System.String
    The action message shown by `-WhatIf` or interactive confirmation prompts.

.EXAMPLE
    Get-VvcRemovalShouldProcessAction -Item $item

    Returns an action such as:
    `Remove original validated duplicate (keeping 'Episode01_vvc.mkv')`
#>
function Get-VvcRemovalShouldProcessAction {
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        $Item
    )

    "Remove original validated duplicate (keeping '$($Item.VvcName)')"
}

<#
.SYNOPSIS
    Translate an audit item into an explicit removal decision.

.DESCRIPTION
    Evaluates whether an audited item can proceed to the delete stage.

    If the item is not removable, the helper returns a `VvcRemovalDecision` whose
    `CanProceed` value is `$false` and whose `Result` contains the precomputed
    `Skipped` outcome. If the item is removable, the helper returns a decision whose
    `CanProceed` value is `$true`, whose `Result` is `$null`, and whose action text can
    be passed to `ShouldProcess`.

    This makes the caller's orchestration explicit and avoids older sentinel-based flows
    that relied on `$null` to signal "continue."

.PARAMETER Item
    Audit item to evaluate.

.OUTPUTS
    VvcRemovalDecision
    A typed decision describing whether the item can proceed and, if not, the precomputed
    result to emit.

.EXAMPLE
    $decision = Get-VvcRemovalDecision -Item $item

    Builds an explicit removal decision for the item.

.NOTES
    Current non-proceeding reasons are:
    - `MissingOriginalPath`
    - `UnsafeToDelete`
#>
function Get-VvcRemovalDecision {
    [OutputType([VvcRemovalDecision])]
    param(
        [Parameter(Mandatory)]
        $Item
    )

    if ([string]::IsNullOrWhiteSpace($Item.OriginalPath)) {
        $resultParams = @{
            Item   = $Item
            Status = [VvcRemovalStatus]::Skipped
            Reason = [VvcRemovalReason]::MissingOriginalPath
        }
        $result = New-VvcRemovalResult @resultParams
        [VvcRemovalDecision]::new($false, $result, $null)
    }
    elseif (-not $Item.SafeToDeleteOriginal) {
        $result = New-VvcRemovalResult -Item $Item -Status Skipped -Reason UnsafeToDelete
        [VvcRemovalDecision]::new($false, $result, $null)
    }
    else {
        $action = Get-VvcRemovalShouldProcessAction -Item $Item
        [VvcRemovalDecision]::new($true, $null, $action)
    }
}

<#
.SYNOPSIS
    Attempt to remove the original file for a previously approved audit item.

.DESCRIPTION
    Deletes the original file associated with an audit item that has already passed
    eligibility checks and confirmation handling.

    This helper never writes to the pipeline and never throws workflow-specific result
    objects directly. Instead, it always returns a typed `VvcRemovalResult` that the
    caller can accumulate, emit, and interpret. Failed filesystem deletes are represented
    as `Failed` results with an attached error message.

.PARAMETER Item
    Audit item whose original file should be removed.

.OUTPUTS
    VvcRemovalResult
    A typed result with status `Removed` on success or `Failed` on error.

.EXAMPLE
    Invoke-VvcOriginalRemoval -Item $item

    Attempts to remove the original file and returns a typed result describing the
    outcome.

.NOTES
    This helper assumes that the caller has already decided the item is safe to process
    and has already handled `ShouldProcess`.
#>
function Invoke-VvcOriginalRemoval {
    [OutputType([VvcRemovalResult])]
    param(
        [Parameter(Mandatory)]
        $Item
    )

    try {
        Remove-Item -LiteralPath $Item.OriginalPath -Force -ErrorAction Stop
        New-VvcRemovalResult -Item $Item -Status Removed -ReclaimedMB $Item.OriginalSizeMB
    }
    catch {
        $resultParams = @{
            Item         = $Item
            Status       = [VvcRemovalStatus]::Failed
            Reason       = [VvcRemovalReason]::RemoveFailed
            ErrorMessage = $_.Exception.Message
        }
        New-VvcRemovalResult @resultParams
    }
}

<#
.SYNOPSIS
    Aggregate per-item results into a typed summary.

.DESCRIPTION
    Builds a `VvcRemovalSummary` from a collection of per-item `VvcRemovalResult` objects.

    The summary is computed in a single pass so all counts and reclaimed-space totals are
    derived from the same traversal. This keeps the logic predictable and avoids
    re-enumerating the results list multiple times.

.PARAMETER Results
    Typed removal results accumulated during the run.

.OUTPUTS
    VvcRemovalSummary
    A typed summary containing total audited items, counts by status, and total reclaimed
    space for successful removals.

.EXAMPLE
    New-VvcRemovalSummary -Results $results

    Creates a summary object for the current run.

.NOTES
    `TotalReclaimedMB` includes only results whose status is `Removed`.
#>
function New-VvcRemovalSummary {
    [OutputType([VvcRemovalSummary])]
    param(
        [Parameter(Mandatory)]
        [VvcRemovalResult[]]$Results
    )

    $removedCount = 0
    $skippedCount = 0
    $wouldRemoveCount = 0
    $failedCount = 0
    $removedTotal = 0.0

    foreach ($result in $Results) {
        switch ($result.Status) {
            ([VvcRemovalStatus]::Removed) {
                $removedCount++
                $removedTotal += $result.ReclaimedMB
            }
            ([VvcRemovalStatus]::Skipped) { $skippedCount++ }
            ([VvcRemovalStatus]::WouldRemove) { $wouldRemoveCount++ }
            ([VvcRemovalStatus]::Failed) { $failedCount++ }
        }
    }

    [VvcRemovalSummary]::new(
        $Results.Count,
        $removedCount,
        $skippedCount,
        $wouldRemoveCount,
        $failedCount,
        $removedTotal
    )
}
