#Requires -Version 7.6
Set-StrictMode -Version 3.0

function Get-ConvertToVvcWorkerScriptBlock {
    [OutputType([scriptblock])]
    {
        param($Request)

        if ($null -eq $Request) {
            $Request = $_
        }

        if (-not (Get-Command Invoke-FunFfmpegInternalVvcWorker -ErrorAction SilentlyContinue)) {
            Import-Module -Name $Request.ModulePath -Force -ErrorAction Stop
        }
        Invoke-FunFfmpegInternalVvcWorker -Request $Request
    }
}

function Invoke-FunFfmpegInternalVvcWorker {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Request
    )

    Invoke-VvcConversionWorker -Request $Request
}

function Invoke-VvcConversionWorker {
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Request
    )

    $paths = Resolve-VvcConversionPath -Request $Request
    $inputProbeError = Test-VvcInput -Path $paths.InputPath `
        -FfprobePath $Request.FfprobePath

    if ($inputProbeError) {
        $originalSize = Get-VvcFileSizeMB -Path $paths.InputPath
        return New-VvcFailureResult -File $Request.File.Name `
            -Reason "invalid input: $inputProbeError" `
            -OriginalMB $originalSize
    }

    if (Test-Path -LiteralPath $paths.OutputPath) {
        $existing = Test-VvcOutput -OriginalPath $paths.InputPath `
            -OutputPath $paths.OutputPath `
            -Request $Request

        if (-not $existing.Ok) {
            return Invoke-VvcConversionAttempt -Request $Request `
                -Paths $paths `
                -ValidationFailurePrefix 're-encode failed'
        }

        if (-not $Request.Overwrite) {
            return New-VvcSkippedResult -File $Request.File.Name `
                -Reason 'exists (valid)'
        }
    }

    Invoke-VvcConversionAttempt -Request $Request `
        -Paths $paths `
        -ValidationFailurePrefix 'bad convert'
}

function Resolve-VvcConversionPath {
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Request
    )

    $inputPath = $Request.File.FullName
    $baseName = [IO.Path]::GetFileNameWithoutExtension($Request.File.Name)
    $outputName = '{0}{1}.mkv' -f $baseName, $Request.Suffix
    $outputPath = Join-Path -Path $Request.OutputDir -ChildPath $outputName

    [pscustomobject]@{
        InputPath  = $inputPath
        OutputPath = $outputPath
    }
}

function Invoke-NativeTool {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList
    )

    $output = @(& $FilePath @ArgumentList 2>&1)
    $exitCode = $LASTEXITCODE
    $stdout = [System.Collections.Generic.List[string]]::new()
    $stderr = [System.Collections.Generic.List[string]]::new()

    foreach ($item in $output) {
        if ($item -is [System.Management.Automation.ErrorRecord]) {
            $stderr.Add($item.ToString())
            continue
        }

        $stdout.Add([string]$item)
    }

    [pscustomobject]@{
        FilePath  = $FilePath
        Arguments = $ArgumentList
        ExitCode  = $exitCode
        StdOut    = $stdout -join [Environment]::NewLine
        StdErr    = $stderr -join [Environment]::NewLine
        Succeeded = $exitCode -eq 0
    }
}

function Get-VvcFileSizeMB {
    [OutputType([double])]
    param([string]$Path)

    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        [math]::Round($item.Length / 1MB, 2)
    }
    catch {
        0
    }
}

function New-VvcFailureResult {
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory)]
        [string]$File,

        [Parameter(Mandatory)]
        [string]$Reason,

        [double]$OriginalMB = 0.0
    )

    New-ConvertToVvcResult -File $File -Ok $false -Skipped $false `
        -Reason $Reason -OriginalMB $OriginalMB
}

function New-VvcSkippedResult {
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory)]
        [string]$File,

        [Parameter(Mandatory)]
        [string]$Reason
    )

    New-ConvertToVvcResult -File $File -Ok $false -Skipped $true `
        -Reason $Reason
}

function New-VvcSuccessResult {
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory)]
        [string]$File,

        [Parameter(Mandatory)]
        [string]$InputPath,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $originalSize = Get-VvcFileSizeMB -Path $InputPath
    $newSize = Get-VvcFileSizeMB -Path $OutputPath
    $ratio = if ($originalSize -gt 0) {
        [math]::Round(($newSize / $originalSize) * 100, 1)
    }
    else {
        0
    }

    New-ConvertToVvcResult -File $File -Ok $true -Skipped $false `
        -OriginalMB $originalSize -NewMB $newSize -Ratio $ratio
}

function Test-VvcInput {
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$FfprobePath
    )

    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        if ($item.Length -le 0) {
            return 'input file is empty.'
        }
    }
    catch {
        return $_.Exception.Message
    }

    $ffprobeArgs = @(
        '-v', 'error',
        '-show_entries', 'format=format_name',
        '-of', 'default=nw=1:nk=1',
        '--', $Path
    )
    $probe = Invoke-NativeTool -FilePath $FfprobePath -ArgumentList $ffprobeArgs
    if ($probe.Succeeded) {
        return ''
    }

    $probeMessage = Get-VvcNativeDiagnostic -NativeResult $probe
    if ([string]::IsNullOrWhiteSpace($probeMessage)) {
        return 'ffprobe could not read the input container.'
    }

    $probeMessage
}

function Get-VvcVideoCodecName {
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$FfprobePath
    )

    $ffprobeArgs = @(
        '-v', 'error',
        '-select_streams', 'v:0',
        '-show_entries', 'stream=codec_name',
        '-of', 'default=nw=1:nk=1',
        '--', $Path
    )
    $probe = Invoke-NativeTool -FilePath $FfprobePath -ArgumentList $ffprobeArgs
    if (-not $probe.Succeeded) {
        return ''
    }

    $probe.StdOut.Trim()
}

function Get-VvcFormatDurationSec {
    [OutputType([double], [System.Void])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$FfprobePath
    )

    $ffprobeArgs = @(
        '-v', 'error',
        '-show_entries', 'format=duration',
        '-of', 'default=nk=1:nw=1',
        '--', $Path
    )
    $probe = Invoke-NativeTool -FilePath $FfprobePath -ArgumentList $ffprobeArgs
    if (-not $probe.Succeeded) {
        return $null
    }

    $duration = 0.0
    $ok = [double]::TryParse(
        $probe.StdOut.Trim(),
        [Globalization.NumberStyles]::Float,
        [Globalization.CultureInfo]::InvariantCulture,
        [ref]$duration
    )
    if (-not $ok) {
        return $null
    }

    $duration
}

function Test-VvcDecodable {
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$FfmpegPath
    )

    $ffmpegArgs = @(
        '-v', 'error',
        '-noautorotate',
        '-err_detect', 'explode',
        '-t', '8',
        '-i', $Path,
        '-f', 'null',
        '-'
    )
    $decode = Invoke-NativeTool -FilePath $FfmpegPath -ArgumentList $ffmpegArgs
    $decode.Succeeded
}

function Test-VvcOutput {
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$OriginalPath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [pscustomobject]$Request
    )

    if (-not (Test-Path -LiteralPath $OutputPath)) {
        return @{ Ok = $false; Reason = 'missing output' }
    }

    $codec = Get-VvcVideoCodecName -Path $OutputPath `
        -FfprobePath $Request.FfprobePath
    if ($codec -notmatch '^(vvc|vvc1)$') {
        return @{ Ok = $false; Reason = "unexpected codec: '$codec'" }
    }

    if ($Request.VerifyMode -ne 'none') {
        $inputDuration = Get-VvcFormatDurationSec -Path $OriginalPath `
            -FfprobePath $Request.FfprobePath
        $outputDuration = Get-VvcFormatDurationSec -Path $OutputPath `
            -FfprobePath $Request.FfprobePath

        if ($null -ne $inputDuration -and $null -ne $outputDuration) {
            $drift = [math]::Abs($inputDuration - $outputDuration)
            if ($drift -gt $Request.MaxDriftSec) {
                return @{
                    Ok     = $false
                    Reason = ('duration drift {0:N2}s' -f $drift)
                }
            }
        }

        if (
            $Request.VerifyMode -eq 'strict' -and
            -not (Test-VvcDecodable -Path $OutputPath -FfmpegPath $Request.FfmpegPath)
        ) {
            return @{ Ok = $false; Reason = 'decode test failed' }
        }
    }

    @{ Ok = $true; Reason = '' }
}

function New-VvcTempPath {
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$FinalPath
    )

    $dir = [IO.Path]::GetDirectoryName($FinalPath)
    $name = [IO.Path]::GetFileNameWithoutExtension($FinalPath)
    $ext = [IO.Path]::GetExtension($FinalPath)
    $id = [guid]::NewGuid().ToString('N')

    Join-Path $dir ('{0}.{1}.partial{2}' -f $name, $id, $ext)
}

function New-FfmpegArgumentList {
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string]$InputPath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [int]$Qp,

        [Parameter(Mandatory)]
        [string]$Preset,

        [Parameter(Mandatory)]
        [int]$EncoderThreads,

        [switch]$AllowOverwrite
    )

    $ffArgs = @()
    if ($AllowOverwrite) {
        $ffArgs += '-y'
    }
    else {
        $ffArgs += '-n'
    }

    $ffArgs += @(
        '-hide_banner',
        '-stats', '-loglevel', 'error',
        '-analyzeduration', '200M', '-probesize', '200M',
        '-i', $InputPath,
        '-map', '0', '-map_chapters', '0', '-map_metadata', '0',
        '-c:v', 'libvvenc', '-profile:v', 'main10',
        '-pix_fmt', 'yuv420p10le',
        '-preset', $Preset, '-qp', $Qp, '-threads', $EncoderThreads,
        '-c:a', 'copy', '-c:s', 'copy', '-c:t', 'copy',
        $OutputPath
    )
    $ffArgs
}

function Invoke-VvcEncode {
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Request,

        [Parameter(Mandatory)]
        [string]$InputPath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [bool]$AllowOverwrite
    )

    $ffArgs = New-FfmpegArgumentList -InputPath $InputPath `
        -OutputPath $OutputPath `
        -Qp $Request.Qp `
        -Preset $Request.Preset `
        -EncoderThreads $Request.EncoderThreads `
        -AllowOverwrite:$AllowOverwrite

    Invoke-NativeTool -FilePath $Request.FfmpegPath -ArgumentList $ffArgs
}

function Invoke-VvcConversionAttempt {
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Request,

        [Parameter(Mandatory)]
        [pscustomobject]$Paths,

        [Parameter(Mandatory)]
        [string]$ValidationFailurePrefix
    )

    $tempPath = New-VvcTempPath -FinalPath $Paths.OutputPath
    $committed = $false

    try {
        $encode = Invoke-VvcEncode -Request $Request `
            -InputPath $Paths.InputPath `
            -OutputPath $tempPath `
            -AllowOverwrite $true

        if (-not $encode.Succeeded) {
            return New-VvcFailureResult -File $Request.File.Name `
                -Reason "ffmpeg exit $($encode.ExitCode)"
        }

        if (-not (Test-Path -LiteralPath $tempPath)) {
            return New-VvcFailureResult -File $Request.File.Name `
                -Reason 'missing temp output'
        }

        $post = Test-VvcOutput -OriginalPath $Paths.InputPath `
            -OutputPath $tempPath `
            -Request $Request
        if (-not $post.Ok) {
            return New-VvcFailureResult -File $Request.File.Name `
                -Reason "$($ValidationFailurePrefix): $($post.Reason)"
        }

        try {
            if (Test-Path -LiteralPath $Paths.OutputPath) {
                Remove-Item -LiteralPath $Paths.OutputPath -Force `
                    -ErrorAction SilentlyContinue
            }
            Move-Item -LiteralPath $tempPath -Destination $Paths.OutputPath `
                -Force -ErrorAction Stop
            $committed = $true
        }
        catch {
            return New-VvcFailureResult -File $Request.File.Name `
                -Reason "final rename failed: $($_.Exception.Message)"
        }

        New-VvcSuccessResult -File $Request.File.Name `
            -InputPath $Paths.InputPath `
            -OutputPath $Paths.OutputPath
    }
    catch {
        New-VvcFailureResult -File $Request.File.Name -Reason $_.Exception.Message
    }
    finally {
        if (-not $committed -and (Test-Path -LiteralPath $tempPath)) {
            Remove-Item -LiteralPath $tempPath -Force `
                -ErrorAction SilentlyContinue
        }
    }
}

function Get-VvcNativeDiagnostic {
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$NativeResult
    )

    if (-not [string]::IsNullOrWhiteSpace($NativeResult.StdErr)) {
        return $NativeResult.StdErr.Trim()
    }

    if (-not [string]::IsNullOrWhiteSpace($NativeResult.StdOut)) {
        return $NativeResult.StdOut.Trim()
    }

    ''
}
