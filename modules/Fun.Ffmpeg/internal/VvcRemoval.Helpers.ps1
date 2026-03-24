using module .\VvcRemoval.Types.psm1

function New-VvcRemovalResult {
    param(
        [Parameter(Mandatory)]
        $Item,

        [Parameter(Mandatory)]
        [ValidateSet('Removed', 'Skipped', 'WouldRemove', 'Failed')]
        [string]$Status,

        [string]$Reason,

        [double]$ReclaimedMB = 0.0,

        [string]$ErrorMessage
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

function ConvertTo-VvcRemovalExtensions {
    param(
        [Parameter(Mandatory)]
        [string[]]$Extensions
    )

    @(
        foreach ($extension in $Extensions) {
            if ([string]::IsNullOrWhiteSpace($extension)) {
                continue
            }

            $trimmed = $extension.Trim()
            if (-not $trimmed.StartsWith('.')) {
                $trimmed = ".$trimmed"
            }

            $trimmed
        }
    )
}

function Get-VvcRemovalAuditItems {
    param(
        [Parameter(Mandatory)]
        [string]$InputDir,

        [Parameter(Mandatory)]
        [string]$Suffix,

        [Parameter(Mandatory)]
        [string[]]$Extensions,

        [Parameter(Mandatory)]
        [string]$Verify,

        [Parameter(Mandatory)]
        [double]$MaxDrift,

        [Parameter(Mandatory)]
        [double]$MinExpectedVvcMB,

        [Parameter(Mandatory)]
        [bool]$Recurse
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
            } else {
                $_.OriginalPath
            }
        }
    }
    $sortByEpisodeKey = @{ Expression = { $_.EpisodeKey } }

    @(Get-VvcAudit @auditParams) |
        Sort-Object `
            $sortByOriginalPath, `
            $sortByEpisodeKey
}

function Get-VvcRemovalAction {
    param(
        [Parameter(Mandatory)]
        $Item
    )

    if ([string]::IsNullOrWhiteSpace($Item.OriginalPath)) {
        $resultParams = @{
            Item   = $Item
            Status = 'Skipped'
            Reason = 'MissingOriginalPath'
        }
        return New-VvcRemovalResult @resultParams
    }

    if (-not $Item.SafeToDeleteOriginal) {
        $resultParams = @{
            Item   = $Item
            Status = 'Skipped'
            Reason = 'UnsafeToDelete'
        }
        return New-VvcRemovalResult @resultParams
    }

    $null
}

function Get-VvcRemovalShouldProcessAction {
    param(
        [Parameter(Mandatory)]
        $Item
    )

    "Remove original validated duplicate (keeping '$($Item.VvcName)')"
}

function Invoke-VvcOriginalRemoval {
    param(
        [Parameter(Mandatory)]
        $Item,

        [Parameter(Mandatory)]
        [bool]$StopOnError
    )

    try {
        Remove-Item -LiteralPath $Item.OriginalPath -Force -ErrorAction Stop
        $resultParams = @{
            Item        = $Item
            Status      = 'Removed'
            ReclaimedMB = $Item.OriginalSizeMB
        }
        New-VvcRemovalResult @resultParams
    } catch {
        $resultParams = @{
            Item         = $Item
            Status       = 'Failed'
            Reason       = 'RemoveFailed'
            ErrorMessage = $_.Exception.Message
        }
        $result = New-VvcRemovalResult @resultParams
        if ($StopOnError) {
            Write-Output $result
            throw
        }

        $result
    }
}

function New-VvcRemovalSummary {
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[VvcRemovalResult]]$Results
    )

    $removedTotal = @(
        $Results |
            Where-Object Status -eq 'Removed' |
            Measure-Object -Property ReclaimedMB -Sum
    ).Sum ?? 0.0

    [VvcRemovalSummary]::new(
        $Results.Count,
        @($Results | Where-Object Status -eq 'Removed').Count,
        @($Results | Where-Object Status -eq 'Skipped').Count,
        @($Results | Where-Object Status -eq 'WouldRemove').Count,
        @($Results | Where-Object Status -eq 'Failed').Count,
        $removedTotal
    )
}

function Write-VvcRemovalResult {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[VvcRemovalResult]]$Results,

        [Parameter(Mandatory)]
        [VvcRemovalResult]
        $Result
    )

    $Results.Add($Result)
    Write-Output $Result
}
