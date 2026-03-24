#Requires -Version 7.0
using module .\ConvertToVvc.Types.psm1
using namespace System.Collections.Generic

function New-ConvertToVvcResult {
    [OutputType([ConvertToVvcResult])]
    param(
        [Parameter(Mandatory)]
        [string]$File,

        [Parameter(Mandatory)]
        [bool]$Ok,

        [Parameter(Mandatory)]
        [bool]$Skipped,

        [string]$Reason = '',

        [double]$OriginalMB = 0.0,

        [double]$NewMB = 0.0,

        [double]$Ratio = 0.0
    )

    [ConvertToVvcResult]::new(
        $File,
        $Ok,
        $Skipped,
        $Reason,
        $OriginalMB,
        $NewMB,
        $Ratio
    )
}

function Get-ConvertToVvcToolPaths {
    $ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if (-not $ffmpeg) {
        throw 'ffmpeg was not found in PATH.'
    }

    $ffprobe = Get-Command ffprobe -ErrorAction SilentlyContinue
    if (-not $ffprobe) {
        throw 'ffprobe was not found in PATH.'
    }

    $hasVvenc = ffmpeg -hide_banner -encoders 2>$null |
        Select-String -SimpleMatch 'libvvenc'
    if (-not $hasVvenc) {
        throw "Your ffmpeg build does not include the 'libvvenc' encoder."
    }

    @{
        FfmpegPath = $ffmpeg.Path
        FfprobePath = $ffprobe.Path
    }
}

function Get-ConvertToVvcPreparation {
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$ParameterSetName,

        [string]$InputDir,

        [string[]]$LiteralPath,

        [Parameter(Mandatory)]
        [string[]]$Extensions,

        [Parameter(Mandatory)]
        [bool]$Recurse
    )

    $toolPaths = Get-ConvertToVvcToolPaths
    $extensionSet = ConvertTo-VvcExtensions -Extensions $Extensions
    $inputFileParams = @{
        ParameterSetName = $ParameterSetName
        InputDir = $InputDir
        LiteralPath = $LiteralPath
        ExtensionSet = $extensionSet
        Recurse = $Recurse
    }
    $inputFiles = @(Get-ConvertToVvcInputFiles @inputFileParams)

    @{
        ToolPaths = $toolPaths
        ExtensionSet = $extensionSet
        InputFiles = $inputFiles
    }
}

function ConvertTo-VvcExtensions {
    [OutputType([HashSet[string]])]
    param(
        [Parameter(Mandatory)]
        [string[]]$Extensions
    )

    $extSet = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($extension in $Extensions) {
        if ([string]::IsNullOrWhiteSpace($extension)) {
            continue
        }

        $normalized = $extension.Trim()
        if (-not $normalized.StartsWith('.')) {
            $normalized = ".$normalized"
        }

        $null = $extSet.Add($normalized)
    }

    $extSet
}

function Get-ConvertToVvcInputFiles {
    [OutputType([System.IO.FileInfo[]])]
    param(
        [Parameter(Mandatory)]
        [string]$ParameterSetName,

        [string]$InputDir,

        [string[]]$LiteralPath,

        [Parameter(Mandatory)]
        [HashSet[string]]$ExtensionSet,

        [Parameter(Mandatory)]
        [bool]$Recurse
    )

    if ($ParameterSetName -eq 'LiteralPath') {
        $resolvedFiles = foreach ($path in $LiteralPath) {
            if ([string]::IsNullOrWhiteSpace($path)) {
                continue
            }

            $resolvedPath = Resolve-Path -LiteralPath $path -ErrorAction Stop
            foreach ($entry in @($resolvedPath)) {
                $item = Get-Item -LiteralPath $entry.ProviderPath -ErrorAction Stop
                if ($item -is [IO.DirectoryInfo]) {
                    continue
                }

                if ($ExtensionSet.Contains($item.Extension)) {
                    $item
                }
            }
        }

        return @($resolvedFiles | Sort-Object FullName -Unique)
    }

    $gciParams = @{
        Path = $InputDir
        File = $true
        ErrorAction = 'Stop'
    }
    if ($Recurse) {
        $gciParams.Recurse = $true
    }

    @(Get-ChildItem @gciParams | Where-Object { $ExtensionSet.Contains($_.Extension) })
}

function Get-ConvertToVvcResolvedOutputDir {
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$OutputDir
    )

    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    $resolvedOutputDir = Resolve-Path -LiteralPath $OutputDir -ErrorAction Stop
    if ($resolvedOutputDir.ProviderPath) {
        return $resolvedOutputDir.ProviderPath
    }

    $resolvedOutputDir.Path
}

function Write-ConvertToVvcNoMatchingFilesVerbose {
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet]$Cmdlet,

        [Parameter(Mandatory)]
        [string]$ParameterSetName,

        [string]$InputDir,

        [Parameter(Mandatory)]
        [string[]]$Extensions
    )

    $sourceLabel = if ($ParameterSetName -eq 'LiteralPath') {
        'explicit paths'
    } else {
        "'$InputDir'"
    }

    $Cmdlet.WriteVerbose(
        "No matching videos found in $sourceLabel with extensions: " +
        ($Extensions -join ', ') + '.'
    )
}

function Get-ConvertToVvcWorkerArguments {
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Suffix,

        [Parameter(Mandatory)]
        [string]$OutputDir,

        [Parameter(Mandatory)]
        [int]$Qp,

        [Parameter(Mandatory)]
        [string]$Preset,

        [Parameter(Mandatory)]
        [bool]$Overwrite,

        [Parameter(Mandatory)]
        [string]$FfmpegPath,

        [Parameter(Mandatory)]
        [string]$Verify,

        [Parameter(Mandatory)]
        [double]$MaxDrift
    )

    @(
        $Suffix,
        $OutputDir,
        $Qp,
        $Preset,
        $Overwrite,
        $FfmpegPath,
        $Verify,
        $MaxDrift
    )
}

function Invoke-ConvertToVvcWorker {
    [OutputType([ConvertToVvcResult[]])]
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$TargetFiles,

        [Parameter(Mandatory)]
        [scriptblock]$Worker,

        [Parameter(Mandatory)]
        [object[]]$WorkerArguments,

        [Parameter(Mandatory)]
        [int]$MaxParallel,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet]$Cmdlet
    )

    if ($MaxParallel -le 1) {
        $index = 0
        $acc = @()
        foreach ($file in $TargetFiles) {
            $index++
            $Cmdlet.WriteVerbose(
                "[$index/$($TargetFiles.Count)] Processing: $($file.Name)"
            )
            $acc += (& $Worker $file @WorkerArguments)
        }
        return $acc
    }

    $throttle = [math]::Max(1, $MaxParallel)
    $invokeParams = @{
        Parallel = $Worker
        ThrottleLimit = $throttle
        ArgumentList = $WorkerArguments
    }
    $TargetFiles | ForEach-Object @invokeParams
}

function Complete-ConvertToVvc {
    [OutputType([ConvertToVvcResult[]])]
    param(
        [Parameter(Mandatory)]
        [object[]]$Results,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet]$Cmdlet
    )

    $typedResults = @(
        foreach ($result in $Results) {
            if ($result -is [ConvertToVvcResult]) {
                $result
                continue
            }

            New-ConvertToVvcResult -File $result.File -Ok $result.Ok `
                -Skipped $result.Skipped -Reason $result.Reason `
                -OriginalMB $result.OriginalMB -NewMB $result.NewMB `
                -Ratio $result.Ratio
        }
    )

    $summary = Get-ConvertToVvcSummary -Results $typedResults
    $message = 'Completed. Converted: {0} | Skipped: {1} | Errors: {2}' -f (
        $summary.Converted,
        $summary.Skipped,
        $summary.Errors
    )
    $Cmdlet.WriteVerbose($message)
    $typedResults
}

function Get-ConvertToVvcSummary {
    param(
        [Parameter(Mandatory)]
        [object[]]$Results
    )

    $resultItems = @(
        $Results | Where-Object {
            $_ -and
            $_.PSObject -and
            $_.PSObject.Properties.Match('Ok').Count -gt 0 -and
            $_.PSObject.Properties.Match('Skipped').Count -gt 0
        }
    )

    @{
        Converted = @($resultItems | Where-Object { $_.Ok }).Count
        Skipped = @($resultItems | Where-Object { $_.Skipped }).Count
        Errors = @(
            $resultItems |
                Where-Object { -not $_.Ok -and -not $_.Skipped }
        ).Count
    }
}
