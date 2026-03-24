#Requires -Version 7.5
using module ..\internal\ConvertToVvc.Types.psm1
Set-StrictMode -Version 3.0

<#
.SYNOPSIS
    Converts video files to VVC (H.266) with ffmpeg and `libvvenc`.

.DESCRIPTION
    `Convert-ToVvc` is the public orchestration command for the VVC workflow exposed
    by `Fun.Ffmpeg`.

    The command prepares the conversion run in four stages:

    1. Resolve and validate the requested inputs.
    2. Resolve the output directory and filter the final worklist through
       `ShouldProcess`.
    3. Build the self-contained worker payload used for sequential or parallel execution.
    4. Run the worker for each selected file and emit typed results.

    Before any file is converted, the preparation phase resolves `ffmpeg` and `ffprobe`,
    validates the requested extensions, and confirms that the active `ffmpeg` build
    exposes the `libvvenc` encoder required for VVC output.

    Each file is converted to a temporary output first. The temporary file is promoted to
    its final `.mkv` path only after post-conversion validation succeeds according to the
    selected verification mode.

    This function intentionally remains an orchestration layer. Shared preparation,
    discovery, and summarization logic lives in `internal/ConvertToVvc.Helpers.ps1`, while
    the per-file worker shared by sequential and parallel execution lives in
    `internal/ConvertToVvc.Worker.ps1`.

.PARAMETER InputDir
    Directory scanned for source videos when using the default `Directory` parameter set.

    This parameter is ignored when `LiteralPath` is used.

.PARAMETER LiteralPath
    Explicit file paths to convert.

    Accepts pipeline input by value and by property name so the command can be used with
    `Get-ChildItem` output or with objects exposing properties such as `Path`, `FullName`,
    `PSPath`, or `OriginalPath`.

.PARAMETER OutputDir
    Destination directory for converted files.

    The directory is resolved to an absolute path and created when it does not already
    exist.

.PARAMETER QP
    Constant quantization parameter passed to `libvvenc`.

    Lower values usually favor quality at the cost of larger output and slower encoding,
    while higher values usually reduce output size at the cost of quality.

.PARAMETER Preset
    Encoding preset passed to `libvvenc`.

    Accepted values range from `faster` to `veryslow`.

.PARAMETER Recurse
    Recursively scans `InputDir` for matching files.

    This parameter is relevant only in the `Directory` parameter set.

.PARAMETER Overwrite
    Overwrites valid existing outputs.

    Existing outputs that are invalid or suspicious are rebuilt regardless of this switch.

.PARAMETER Suffix
    Suffix appended to the output base filename before the final `.mkv` extension.

    For example, `movie.mp4` with the default suffix becomes `movie_vvc.mkv`.

.PARAMETER MaxParallel
    Maximum number of files processed concurrently.

    Use `1` for sequential execution. Values greater than `1` use
    `ForEach-Object -Parallel` together with the self-contained internal worker.

.PARAMETER Extensions
    File extensions included from the selected inputs.

    Matching is case-insensitive. Values are normalized internally, so both `mkv` and
    `.mkv` are accepted.

.PARAMETER Verify
    Post-conversion verification mode.

    Supported values are:
    - `none`   : verify only existence and codec expectations
    - `quick`  : also verify duration drift
    - `strict` : also verify duration drift and run a decode test

.PARAMETER MaxDrift
    Maximum allowed input/output duration difference, in seconds, for verification.

    This value is used only by verification modes that perform a duration check.

.EXAMPLE
    Convert-ToVvc -InputDir 'D:\Videos' -OutputDir 'D:\Videos\vvc_out' -Recurse

    Scans `D:\Videos` recursively and converts matching files into `D:\Videos\vvc_out`.

.EXAMPLE
    Convert-ToVvc -InputDir . -OutputDir .\vvc -MaxParallel 4 -Verify strict -WhatIf

    Shows which files would be converted using four workers and strict post-conversion
    validation.

.EXAMPLE
    Get-ChildItem .\incoming -File *.mkv | Convert-ToVvc -OutputDir .\vvc_out

    Converts explicitly piped files into `.\vvc_out`.

.OUTPUTS
    ConvertToVvcResult

    Emits one `ConvertToVvcResult` per attempted file. The result exposes:
    - `File`
    - `Ok`
    - `Skipped`
    - `Reason`
    - `OriginalMB`
    - `NewMB`
    - `Ratio`

    `-WhatIf` can legitimately emit no result objects when every candidate is filtered out
    by `ShouldProcess`.

    Although the public command emits typed `ConvertToVvcResult` objects, the internal
    parallel worker may still use a simpler intermediate shape for runspace-safe transport
    before the results are normalized.

.NOTES
    This command does not implement probing, encoder detection, per-file conversion, or
    final summarization directly. Those responsibilities are delegated to the internal
    helper and worker modules to keep this function focused on orchestration.
#>
function Convert-ToVvc {
    [OutputType([ConvertToVvcResult])]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ParameterSetName = 'Directory')]
        [string]$InputDir = '.',

        [Parameter(
            Mandatory,
            ParameterSetName = 'LiteralPath',
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias('FullName', 'PSPath', 'Path', 'OriginalPath')]
        [string[]]$LiteralPath,

        [string]$OutputDir = '.\vvc_out',

        [int]$QP = 32,

        [ValidateSet('faster', 'fast', 'medium', 'slow', 'slower', 'veryslow')]
        [string]$Preset = 'fast',

        [switch]$Recurse,

        [switch]$Overwrite,

        [string]$Suffix = '_vvc',

        [ValidateRange(1, 128)]
        [int]$MaxParallel = 1,

        [string[]]$Extensions = @(
            '.mkv', '.mp4', '.mov', '.avi', '.ts', '.m2ts', '.webm'
        ),

        [ValidateSet('none', 'quick', 'strict')]
        [string]$Verify = 'quick',

        [ValidateRange(0.0, 3600.0)]
        [double]$MaxDrift = 1.5
    )

    # Prepare the run by resolving inputs, tools, and normalized extension state.
    $prepParams = @{
        ParameterSetName = $PSCmdlet.ParameterSetName
        InputDir         = $InputDir
        LiteralPath      = $LiteralPath
        Extensions       = $Extensions
        Recurse          = $Recurse.IsPresent
    }
    $prep = Get-ConvertToVvcPreparation @prepParams

    $inputFiles = $prep.InputFiles
    if ($inputFiles.Count -eq 0) {
        $noMatchParams = @{
            Cmdlet           = $PSCmdlet
            ParameterSetName = $PSCmdlet.ParameterSetName
            InputDir         = $InputDir
            Extensions       = $Extensions
        }
        Write-ConvertToVvcNoMatchingFilesVerbose @noMatchParams
        return @()
    }

    # Resolve the destination directory once, then filter work through ShouldProcess.
    $outputDirAbs = Get-ConvertToVvcResolvedOutputDir -OutputDir $OutputDir
    $targetFiles = @()

    foreach ($file in $inputFiles) {
        $baseName = [IO.Path]::GetFileNameWithoutExtension($file.Name)
        $outName = "${baseName}${Suffix}.mkv"
        $outPath = Join-Path -Path $outputDirAbs -ChildPath $outName

        if ($PSCmdlet.ShouldProcess($file.FullName, "Convert to VVC -> $outPath")) {
            $targetFiles += $file
        }
    }

    if ($targetFiles.Count -eq 0) {
        return @()
    }

    # Build the worker payload used by sequential and parallel execution paths.
    $worker = Get-ConvertToVvcWorkerScriptBlock
    $workerArgParams = @{
        Suffix     = $Suffix
        OutputDir  = $outputDirAbs
        Qp         = $QP
        Preset     = $Preset
        Overwrite  = $Overwrite.IsPresent
        FfmpegPath = $prep.ToolPaths.FfmpegPath
        Verify     = $Verify
        MaxDrift   = $MaxDrift
    }
    $workerArgs = Get-ConvertToVvcWorkerArguments @workerArgParams

    # Invoke the worker and let the completion helper emit the final result stream.
    $invokeParams = @{
        TargetFiles     = $targetFiles
        Worker          = $worker
        WorkerArguments = $workerArgs
        MaxParallel     = $MaxParallel
        Cmdlet          = $PSCmdlet
    }
    $results = @(Invoke-ConvertToVvcWorker @invokeParams)

    Complete-ConvertToVvc -Results @($results) -Cmdlet $PSCmdlet
}
