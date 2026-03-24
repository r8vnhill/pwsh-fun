#Requires -Version 7.5

function Initialize-FakeMediaToolSupport {
    param(
        [Parameter(Mandatory)]
        [string]$TestDrivePath,

        [Parameter(Mandatory)]
        [string]$MockDirName
    )

    $mockDir = Join-Path $TestDrivePath $MockDirName
    New-Item -ItemType Directory -Path $mockDir -Force | Out-Null

    $ffprobeScript = @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)

if (-not [string]::IsNullOrWhiteSpace($env:FFPROBE_MOCK_MARKER)) {
    Set-Content -LiteralPath $env:FFPROBE_MOCK_MARKER -Value ($Args -join ' ')
}

$target = $Args[-1]
$name = [System.IO.Path]::GetFileName($target)
$showEntriesIndex = [Array]::IndexOf($Args, '-show_entries')
$showEntries = if ($showEntriesIndex -ge 0) { $Args[$showEntriesIndex + 1] } else { '' }
$json = $env:FAKE_FFPROBE_SCENARIOS_JSON
$scenarios = if ([string]::IsNullOrWhiteSpace($json)) {
    @{}
} else {
    ConvertFrom-Json -InputObject $json -AsHashtable
}

if (-not $scenarios.ContainsKey($name)) {
    Write-Output 'unexpected ffprobe input'
    exit 1
}

$scenario = $scenarios[$name]
if ($scenario.ContainsKey('ProbeFailMessage')) {
    Write-Output $scenario.ProbeFailMessage
    exit 1
}

switch ($showEntries) {
    'format=format_name' {
        Write-Output $scenario.FormatName
        exit 0
    }
    'stream=codec_name' {
        Write-Output $scenario.CodecName
        exit 0
    }
    'format=duration' {
        Write-Output $scenario.Duration
        exit 0
    }
    'format=duration:stream=codec_name' {
        Write-Output $scenario.CodecName
        Write-Output $scenario.Duration
        exit 0
    }
    default {
        Write-Output 'unexpected ffprobe input'
        exit 1
    }
}
'@

    $ffmpegScript = @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)

if ($Args -contains '-encoders') {
    Write-Output ' V..... libvvenc            H.266 / VVC'
    exit 0
}

if (
    $Args -contains '-i' -and
    -not [string]::IsNullOrWhiteSpace($env:FFMPEG_MOCK_MARKER)
) {
    Set-Content -LiteralPath $env:FFMPEG_MOCK_MARKER -Value ($Args -join ' ')
}

$createOutput = $env:FAKE_FFMPEG_CREATE_OUTPUT -eq '1'
$outputPath = if ($Args.Count -gt 0) { $Args[-1] } else { '' }
if ($createOutput -and -not [string]::IsNullOrWhiteSpace($outputPath) -and $outputPath -ne '-') {
    $parent = Split-Path -Path $outputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -LiteralPath $outputPath -Value ('fake vvc output' * 131072)
}

$exitCode = if ([string]::IsNullOrWhiteSpace($env:FAKE_FFMPEG_EXIT_CODE)) {
    0
} else {
    [int]$env:FAKE_FFMPEG_EXIT_CODE
}

exit $exitCode
'@

    Set-Content -LiteralPath (Join-Path $mockDir 'ffprobe.ps1') -Value $ffprobeScript
    Set-Content -LiteralPath (Join-Path $mockDir 'ffmpeg.ps1') -Value $ffmpegScript

    [pscustomobject]@{
        MockDir                    = $mockDir
        OriginalPath               = $env:PATH
        OriginalFfmpegMockMarker   = $env:FFMPEG_MOCK_MARKER
        OriginalFfprobeMockMarker  = $env:FFPROBE_MOCK_MARKER
        OriginalFfprobeScenarios   = $env:FAKE_FFPROBE_SCENARIOS_JSON
        OriginalFfmpegExitCode     = $env:FAKE_FFMPEG_EXIT_CODE
        OriginalFfmpegCreateOutput = $env:FAKE_FFMPEG_CREATE_OUTPUT
    }
}

function Enable-FakeMediaToolSupport {
    param(
        [Parameter(Mandatory)]
        $Context
    )

    $env:PATH = "$($Context.MockDir)$([IO.Path]::PathSeparator)$($Context.OriginalPath)"
}

function Reset-FakeMediaToolEnvironment {
    param(
        [Parameter(Mandatory)]
        $Context
    )

    $env:PATH = "$($Context.MockDir)$([IO.Path]::PathSeparator)$($Context.OriginalPath)"
    $env:FFMPEG_MOCK_MARKER = $Context.OriginalFfmpegMockMarker
    $env:FFPROBE_MOCK_MARKER = $Context.OriginalFfprobeMockMarker
    $env:FAKE_FFPROBE_SCENARIOS_JSON = $Context.OriginalFfprobeScenarios
    $env:FAKE_FFMPEG_EXIT_CODE = $Context.OriginalFfmpegExitCode
    $env:FAKE_FFMPEG_CREATE_OUTPUT = $Context.OriginalFfmpegCreateOutput
}

function Restore-FakeMediaToolSupport {
    param(
        [Parameter(Mandatory)]
        $Context
    )

    $env:PATH = $Context.OriginalPath
    $env:FFMPEG_MOCK_MARKER = $Context.OriginalFfmpegMockMarker
    $env:FFPROBE_MOCK_MARKER = $Context.OriginalFfprobeMockMarker
    $env:FAKE_FFPROBE_SCENARIOS_JSON = $Context.OriginalFfprobeScenarios
    $env:FAKE_FFMPEG_EXIT_CODE = $Context.OriginalFfmpegExitCode
    $env:FAKE_FFMPEG_CREATE_OUTPUT = $Context.OriginalFfmpegCreateOutput
}

function Set-FakeMediaToolMarkers {
    param(
        [Parameter(Mandatory)]
        [string]$FfprobeMarker,

        [Parameter(Mandatory)]
        [string]$FfmpegMarker
    )

    $env:FFPROBE_MOCK_MARKER = $FfprobeMarker
    $env:FFMPEG_MOCK_MARKER = $FfmpegMarker
}

function Set-FakeFfprobeScenarios {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Scenarios
    )

    $env:FAKE_FFPROBE_SCENARIOS_JSON = ConvertTo-Json -InputObject $Scenarios -Compress
}

function Set-FakeFfmpegBehavior {
    param(
        [int]$ExitCode = 0,

        [switch]$CreateOutput
    )

    $env:FAKE_FFMPEG_EXIT_CODE = [string]$ExitCode
    $env:FAKE_FFMPEG_CREATE_OUTPUT = if ($CreateOutput) { '1' } else { '0' }
}
