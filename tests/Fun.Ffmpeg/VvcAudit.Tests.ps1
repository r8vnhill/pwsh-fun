#Requires -Version 7.5
#Requires -Modules Pester

BeforeAll {
    $script:originalPath = $env:PATH
    $script:mockDir = Join-Path $TestDrive 'ffmpeg-audit-mocks'
    New-Item -ItemType Directory -Path $script:mockDir -Force | Out-Null

    Set-Content -LiteralPath (Join-Path $script:mockDir 'ffprobe.ps1') -Value @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)

$target = $Args[-1]
$name = [System.IO.Path]::GetFileName($target)

switch ($name) {
    'episode01.mkv' { 'h264'; '1440.0'; exit 0 }
    'episode01_vvc.mkv' { 'vvc'; '1439.6'; exit 0 }
    'episode02.mkv' { 'EBML header parsing failed'; exit 1 }
    'episode02_vvc.mkv' { 'vvc'; '1440.0'; exit 0 }
    'episode03.mkv' { 'h264'; '1440.0'; exit 0 }
    'episode03_vvc.mkv' { 'vvc'; '1440.0'; exit 0 }
    'episode04.mkv' { 'h264'; '1440.0'; exit 0 }
    'episode04_vvc.mkv' { 'vvc'; '1440.0'; exit 0 }
    'episode05.mkv' { 'h264'; '1440.0'; exit 0 }
    default { 'unexpected ffprobe input'; exit 1 }
}
'@

    Set-Content -LiteralPath (Join-Path $script:mockDir 'ffmpeg.ps1') -Value @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)

if ($Args -contains '-encoders') {
    ' V..... libvvenc            H.266 / VVC'
    exit 0
}

exit 0
'@

    $env:PATH = "$script:mockDir$([IO.Path]::PathSeparator)$env:PATH"
    Import-Module -Name (Join-Path $PSScriptRoot '..\..\modules\Fun.Ffmpeg\Fun.Ffmpeg.psd1') -Force -ErrorAction Stop

    function New-VvcAuditTestRoot {
        $root = Join-Path $TestDrive ([guid]::NewGuid().Guid)
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        return $root
    }
}

AfterAll {
    $env:PATH = $script:originalPath
}

Describe 'VvcAudit types' {
    It 'uses enum-backed inspection reasons and nullable durations' {
        InModuleScope Fun.Ffmpeg {
            $inspection = [VvcMediaInspection]::new(
                'C:\videos\episode01.mkv',
                $true,
                12.345,
                $false,
                $true,
                [VvcInspectionReason]::None,
                'h264',
                1440.0,
                $null
            )

            $inspection.Reason.GetType().Name | Should -Be 'VvcInspectionReason'
            $inspection.DurationSec.GetType().Name | Should -Be 'Double'
            $inspection.SizeMB | Should -Be 12.34
        }
    }

    It 'rejects impossible inspection states' {
        InModuleScope Fun.Ffmpeg {
            {
                [VvcMediaInspection]::new(
                    'C:\videos\missing.mkv',
                    $false,
                    1.0,
                    $false,
                    $true,
                    [VvcInspectionReason]::None,
                    '',
                    $null,
                    $null
                )
            } | Should -Throw

            {
                [VvcMediaInspection]::new(
                    'C:\videos\negative.mkv',
                    $true,
                    1.0,
                    $false,
                    $false,
                    [VvcInspectionReason]::ProbeFailed,
                    '',
                    -1.0,
                    $null
                )
            } | Should -Throw
        }
    }

    It 'stores composed inspections and preserves flattened compatibility accessors' {
        InModuleScope Fun.Ffmpeg {
            $original = [VvcMediaInspection]::new(
                'C:\videos\episode01.mkv',
                $true,
                100.0,
                $false,
                $true,
                [VvcInspectionReason]::None,
                'h264',
                1440.0,
                $null
            )
            $vvc = [VvcMediaInspection]::new(
                'C:\videos\episode01_vvc.mkv',
                $true,
                40.0,
                $false,
                $true,
                [VvcInspectionReason]::None,
                'vvc',
                1439.6,
                $null
            )

            $audit = [VvcAuditResult]::new(
                'episode01',
                'C:\videos',
                [VvcAuditStatus]::OriginalValidAndVvcValid,
                $original,
                $vvc,
                0.4,
                $false,
                @(),
                $true,
                $false
            )

            $audit.Status.GetType().Name | Should -Be 'VvcAuditStatus'
            $audit.Original.GetType().Name | Should -Be 'VvcMediaInspection'
            $audit.Vvc.GetType().Name | Should -Be 'VvcMediaInspection'
            $audit.OriginalPath | Should -Be 'C:\videos\episode01.mkv'
            $audit.VvcValid | Should -BeTrue
            $audit.OriginalReason.ToString() | Should -Be 'None'
        }
    }

    It 'rejects impossible audit combinations' {
        InModuleScope Fun.Ffmpeg {
            $original = [VvcMediaInspection]::new(
                'C:\videos\episode01.mkv',
                $true,
                100.0,
                $false,
                $true,
                [VvcInspectionReason]::None,
                'h264',
                1440.0,
                $null
            )
            $invalidVvc = [VvcMediaInspection]::new(
                'C:\videos\episode01_vvc.mkv',
                $true,
                40.0,
                $false,
                $false,
                [VvcInspectionReason]::DecodeFailed,
                'vvc',
                1439.6,
                $false
            )

            {
                [VvcAuditResult]::new(
                    'episode01',
                    'C:\videos',
                    [VvcAuditStatus]::OriginalValidAndVvcValid,
                    $original,
                    $invalidVvc,
                    0.4,
                    $false,
                    @(),
                    $true,
                    $false
                )
            } | Should -Throw
        }
    }
}

Describe 'Get-VvcAudit' {
    It 'classifies validated pairs as safe-to-delete originals' {
        $root = New-VvcAuditTestRoot
        $originalPath = Join-Path $root 'episode01.mkv'
        $vvcPath = Join-Path $root 'episode01_vvc.mkv'
        Set-Content -LiteralPath $originalPath -Value ('a' * 1024)
        Set-Content -LiteralPath $vvcPath -Value ('b' * 1024)

        $result = @(Get-VvcAudit -InputDir $root -MinExpectedVvcMB 0)

        $result.Count | Should -Be 1
        $result[0].GetType().Name | Should -Be 'VvcAuditResult'
        $result[0].Status.ToString() | Should -Be 'OriginalValidAndVvcValid'
        $result[0].Original.GetType().Name | Should -Be 'VvcMediaInspection'
        $result[0].Vvc.GetType().Name | Should -Be 'VvcMediaInspection'
        $result[0].SafeToDeleteOriginal | Should -BeTrue
        $result[0].CanConvert | Should -BeFalse
        $result[0].DurationDriftSec | Should -BeLessThan 1.5
    }

    It 'classifies corrupt originals with valid vvc outputs' {
        $root = New-VvcAuditTestRoot
        $originalPath = Join-Path $root 'episode02.mkv'
        $vvcPath = Join-Path $root 'episode02_vvc.mkv'
        Set-Content -LiteralPath $originalPath -Value ('a' * 1024)
        Set-Content -LiteralPath $vvcPath -Value ('b' * 1024)

        $result = @(Get-VvcAudit -InputDir $root -MinExpectedVvcMB 0)

        $result.Count | Should -Be 1
        $result[0].GetType().Name | Should -Be 'VvcAuditResult'
        $result[0].Status.ToString() | Should -Be 'OriginalCorruptAndVvcValid'
        $result[0].OriginalValid | Should -BeFalse
        $result[0].VvcValid | Should -BeTrue
        $result[0].SafeToDeleteOriginal | Should -BeFalse
    }

    It 'flags tiny or invalid vvc outputs as suspicious' {
        $root = New-VvcAuditTestRoot
        $originalPath = Join-Path $root 'episode03.mkv'
        $vvcPath = Join-Path $root 'episode03_vvc.mkv'
        Set-Content -LiteralPath $originalPath -Value ('a' * 1024)
        New-Item -ItemType File -Path $vvcPath -Force | Out-Null

        $result = @(Get-VvcAudit -InputDir $root -MinExpectedVvcMB 1)

        $result.Count | Should -Be 1
        $result[0].GetType().Name | Should -Be 'VvcAuditResult'
        $result[0].Status.ToString() | Should -Be 'VvcSuspiciousOrCorrupt'
        $result[0].SuspiciousVvc | Should -BeTrue
        $result[0].SafeToDeleteOriginal | Should -BeFalse
    }
}

Describe 'Remove-ValidatedVvcOriginal' {
    It 'emits structured results for all audited items and removes only safe originals' {
        $root = New-VvcAuditTestRoot
        $safeOriginalPath = Join-Path $root 'episode04.mkv'
        $safeVvcPath = Join-Path $root 'episode04_vvc.mkv'
        $unsafeOriginalPath = Join-Path $root 'episode05.mkv'

        Set-Content -LiteralPath $safeOriginalPath -Value ('a' * 1024)
        Set-Content -LiteralPath $safeVvcPath -Value ('b' * 1024)
        Set-Content -LiteralPath $unsafeOriginalPath -Value ('c' * 1024)

        $result = @(Remove-ValidatedVvcOriginal -InputDir $root -MinExpectedVvcMB 0 -Confirm:$false)

        $result.Count | Should -Be 2
        @($result | Where-Object Status -eq 'Removed').Count | Should -Be 1
        @($result | Where-Object Status -eq 'Skipped').Count | Should -Be 1
        $result[0].GetType().Name | Should -Be 'VvcRemovalResult'
        $result[1].GetType().Name | Should -Be 'VvcRemovalResult'
        $result[0].OriginalPath | Should -Be $safeOriginalPath
        $result[0].Status.ToString() | Should -Be 'Removed'
        $result[0].Reason.ToString() | Should -Be 'None'
        $result[0].ReclaimedMB | Should -Be $result[0].OriginalSizeMB
        $result[1].OriginalPath | Should -Be $unsafeOriginalPath
        $result[1].Status.ToString() | Should -Be 'Skipped'
        $result[1].Reason.ToString() | Should -Be 'UnsafeToDelete'
        (Test-Path -LiteralPath $safeOriginalPath) | Should -BeFalse
        (Test-Path -LiteralPath $safeVvcPath) | Should -BeTrue
        (Test-Path -LiteralPath $unsafeOriginalPath) | Should -BeTrue
    }

    It 'returns would-remove results under WhatIf without deleting files' {
        $root = New-VvcAuditTestRoot
        $safeOriginalPath = Join-Path $root 'episode04.mkv'
        $safeVvcPath = Join-Path $root 'episode04_vvc.mkv'

        Set-Content -LiteralPath $safeOriginalPath -Value ('a' * 1024)
        Set-Content -LiteralPath $safeVvcPath -Value ('b' * 1024)

        $result = @(Remove-ValidatedVvcOriginal -InputDir $root -MinExpectedVvcMB 0 -WhatIf)

        $result.Count | Should -Be 1
        $result[0].GetType().Name | Should -Be 'VvcRemovalResult'
        $result[0].Status.ToString() | Should -Be 'WouldRemove'
        $result[0].Reason.ToString() | Should -Be 'WhatIf'
        (Test-Path -LiteralPath $safeOriginalPath) | Should -BeTrue
    }

    It 'emits a summary object when IncludeSummary is specified' {
        $root = New-VvcAuditTestRoot
        $safeOriginalPath = Join-Path $root 'episode04.mkv'
        $safeVvcPath = Join-Path $root 'episode04_vvc.mkv'
        $unsafeOriginalPath = Join-Path $root 'episode05.mkv'

        Set-Content -LiteralPath $safeOriginalPath -Value ('a' * 1024)
        Set-Content -LiteralPath $safeVvcPath -Value ('b' * 1024)
        Set-Content -LiteralPath $unsafeOriginalPath -Value ('c' * 1024)

        $result = @(Remove-ValidatedVvcOriginal -InputDir $root -MinExpectedVvcMB 0 -IncludeSummary -Confirm:$false)

        $result.Count | Should -Be 3
        $summary = $result[-1]
        $summary.GetType().Name | Should -Be 'VvcRemovalSummary'
        $summary.AuditedCount | Should -Be 2
        $summary.RemovedCount | Should -Be 1
        $summary.SkippedCount | Should -Be 1
        $summary.WouldRemoveCount | Should -Be 0
        $summary.FailedCount | Should -Be 0
        $summary.TotalReclaimedMB | Should -Be ($result | Where-Object Status -eq 'Removed' | Select-Object -ExpandProperty ReclaimedMB)
    }

    Context 'with mocks' {
        BeforeEach {
            Mock Get-VvcAudit {
                @(
                    [pscustomobject]@{
                        EpisodeKey           = 'safe'
                        OriginalPath         = 'C:\videos\safe.mkv'
                        VvcPath              = 'C:\videos\safe_vvc.mkv'
                        VvcName              = 'safe_vvc.mkv'
                        OriginalSizeMB       = 100.5
                        VvcSizeMB            = 40.25
                        DurationDriftSec     = 0.4
                        SafeToDeleteOriginal = $true
                    },
                    [pscustomobject]@{
                        EpisodeKey           = 'unsafe'
                        OriginalPath         = 'C:\videos\unsafe.mkv'
                        VvcPath              = 'C:\videos\unsafe_vvc.mkv'
                        VvcName              = 'unsafe_vvc.mkv'
                        OriginalSizeMB       = 90.0
                        VvcSizeMB            = 38.0
                        DurationDriftSec     = 3.0
                        SafeToDeleteOriginal = $false
                    },
                    [pscustomobject]@{
                        EpisodeKey           = 'missing'
                        OriginalPath         = ''
                        VvcPath              = 'C:\videos\missing_vvc.mkv'
                        VvcName              = 'missing_vvc.mkv'
                        OriginalSizeMB       = 50.0
                        VvcSizeMB            = 25.0
                        DurationDriftSec     = $null
                        SafeToDeleteOriginal = $true
                    }
                )
            } -ModuleName Fun.Ffmpeg
        }

        It 'continues on remove failures and reports failed results' {
            Mock Remove-Item {
                if ($LiteralPath -eq 'C:\videos\safe.mkv') {
                    throw 'simulated delete failure'
                }
            } -ModuleName Fun.Ffmpeg

            $result = @(Remove-ValidatedVvcOriginal -InputDir 'C:\videos' -Confirm:$false)

            $result.Count | Should -Be 3
            ($result | Where-Object { $_.Reason.ToString() -eq 'MissingOriginalPath' }).Count | Should -Be 1
            ($result | Where-Object { $_.Reason.ToString() -eq 'MissingOriginalPath' }).Status.ToString() | Should -Be 'Skipped'
            $failed = $result | Where-Object { $_.Status.ToString() -eq 'Failed' }
            $failed.Count | Should -Be 1
            $failed[0].GetType().Name | Should -Be 'VvcRemovalResult'
            $failed[0].Reason.ToString() | Should -Be 'RemoveFailed'
            $failed[0].ErrorMessage | Should -Match 'simulated delete failure'
            Assert-MockCalled Remove-Item -Times 1 -ModuleName Fun.Ffmpeg -Exactly
        }

        It 'stops after reporting a failed result when StopOnError is set' {
            Mock Remove-Item {
                throw 'simulated delete failure'
            } -ModuleName Fun.Ffmpeg

            { Remove-ValidatedVvcOriginal -InputDir 'C:\videos' -Confirm:$false -StopOnError } | Should -Throw
            Assert-MockCalled Remove-Item -Times 1 -ModuleName Fun.Ffmpeg -Exactly
        }

        It 'forwards recurse verify suffix and normalized extensions to Get-VvcAudit' {
            Mock Remove-Item {} -ModuleName Fun.Ffmpeg

            $null = Remove-ValidatedVvcOriginal -InputDir 'C:\videos' -Suffix '__encoded' -Extensions 'mkv', '.mp4' -Verify strict -Recurse -Confirm:$false

            Assert-MockCalled Get-VvcAudit -Times 1 -ModuleName Fun.Ffmpeg -Exactly -ParameterFilter {
                $InputDir -eq 'C:\videos' -and
                $Suffix -eq '__encoded' -and
                $Verify -eq 'strict' -and
                $Recurse -and
                $Extensions.Count -eq 2 -and
                $Extensions[0] -eq '.mkv' -and
                $Extensions[1] -eq '.mp4'
            }
        }

        It 'supports pipeline input for InputDir' {
            Mock Remove-Item {} -ModuleName Fun.Ffmpeg

            $null = 'C:\videos' | Remove-ValidatedVvcOriginal -Confirm:$false

            Assert-MockCalled Get-VvcAudit -Times 1 -ModuleName Fun.Ffmpeg -Exactly -ParameterFilter {
                $InputDir -eq 'C:\videos'
            }
        }

        It 'normalizes extensions to lowercase unique dotted values' {
            Mock Remove-Item {} -ModuleName Fun.Ffmpeg

            $null = Remove-ValidatedVvcOriginal -InputDir 'C:\videos' -Extensions 'mkv', '.MKV', ' Mp4 ', '.mp4' -Confirm:$false

            Assert-MockCalled Get-VvcAudit -Times 1 -ModuleName Fun.Ffmpeg -Exactly -ParameterFilter {
                $Extensions.Count -eq 2 -and
                $Extensions[0] -eq '.mkv' -and
                $Extensions[1] -eq '.mp4'
            }
        }

        It 'fails when extension normalization yields an empty set' {
            InModuleScope Fun.Ffmpeg {
                try {
                    throw [VvcRemovalConfigurationException]::new(
                        'At least one non-empty extension is required after normalization.'
                    )
                } catch {
                    $_.Exception.GetType().Name | Should -Be 'VvcRemovalConfigurationException'
                }
            }
        }

        It 'maintains key safety properties across randomized audit items' {
            $items = for ($i = 0; $i -lt 25; $i++) {
                $originalPath = if ($i % 5 -eq 0) { '' } else { "C:\videos\ep$i.mkv" }
                $safe = ($i % 2 -eq 0)
                [pscustomobject]@{
                    EpisodeKey           = "ep$i"
                    OriginalPath         = $originalPath
                    VvcPath              = "C:\videos\ep${i}_vvc.mkv"
                    VvcName              = "ep${i}_vvc.mkv"
                    OriginalSizeMB       = [double](50 + $i)
                    VvcSizeMB            = [double](20 + $i)
                    DurationDriftSec     = [double]($i / 10)
                    SafeToDeleteOriginal = $safe
                }
            }

            Mock Get-VvcAudit { $items } -ModuleName Fun.Ffmpeg
            Mock Remove-Item {} -ModuleName Fun.Ffmpeg

            $result = @('C:\videos' | Remove-ValidatedVvcOriginal -Confirm:$false)
            $removed = @($result | Where-Object { $_.Status.ToString() -eq 'Removed' })

            foreach ($entry in ($result | Where-Object { $_.Status.ToString() -eq 'Removed' })) {
                $source = $items | Where-Object EpisodeKey -eq $entry.EpisodeKey
                $source.SafeToDeleteOriginal | Should -BeTrue
                [string]::IsNullOrWhiteSpace($source.OriginalPath) | Should -BeFalse
                $entry.ReclaimedMB | Should -Be $entry.OriginalSizeMB
            }

            foreach ($entry in ($result | Where-Object OriginalPath -eq '')) {
                $entry.Status.ToString() | Should -Be 'Skipped'
                $entry.Reason.ToString() | Should -Be 'MissingOriginalPath'
            }

            foreach ($entry in ($result | Where-Object { $_.Status.ToString() -eq 'Skipped' })) {
                if ($entry.Reason.ToString() -eq 'UnsafeToDelete') {
                    ($items | Where-Object EpisodeKey -eq $entry.EpisodeKey).SafeToDeleteOriginal | Should -BeFalse
                }
            }

            Assert-MockCalled Remove-Item -Times $removed.Count -ModuleName Fun.Ffmpeg -Exactly
        }

        It 'produces idempotent non-empty normalized extensions' {
            InModuleScope Fun.Ffmpeg {
                $once = ConvertTo-VvcRemovalExtensions -Extensions 'MKV', 'mkv', '.Mp4', '  avi '
                $twice = ConvertTo-VvcRemovalExtensions -Extensions $once

                foreach ($extension in $once) {
                    $extension.StartsWith('.') | Should -BeTrue
                    $extension | Should -Be $extension.ToLowerInvariant()
                    [string]::IsNullOrWhiteSpace($extension) | Should -BeFalse
                }

                $once | Should -Be $twice
            }
        }

        It 'uses domain invariant exceptions for invalid result construction' {
            InModuleScope Fun.Ffmpeg {
                {
                    [VvcRemovalResult]::new(
                        'ep01',
                        'C:\videos\ep01.mkv',
                        'C:\videos\ep01_vvc.mkv',
                        [VvcRemovalStatus]::Removed,
                        [VvcRemovalReason]::UnsafeToDelete,
                        100.0,
                        40.0,
                        100.0,
                        [Nullable[double]]0.0,
                        $null
                    )
                } | Should -Throw -ExceptionType ([VvcRemovalInvariantException])
            }
        }

        It 'uses domain execution exceptions for strict-mode stop behavior' {
            Mock Remove-Item {
                throw 'simulated delete failure'
            } -ModuleName Fun.Ffmpeg

            try {
                Remove-ValidatedVvcOriginal -InputDir 'C:\videos' -Confirm:$false -StopOnError
                throw 'Expected Remove-ValidatedVvcOriginal to fail.'
            } catch {
                $_.Exception.GetType().Name | Should -Be 'VvcRemovalExecutionException'
            }
        }
    }
}
