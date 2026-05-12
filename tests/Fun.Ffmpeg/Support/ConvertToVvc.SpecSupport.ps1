using namespace System.IO

function New-VvcTestRoot {
    $root = Join-Path $TestDrive ([guid]::NewGuid().Guid)
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $root
}

function New-ValidProbeScenario {
    param(
        [Parameter(Mandatory)]
        [string] $Codec,

        [string] $Duration = '1440.0'
    )

    @{
        FormatName = 'matroska,webm'
        CodecName  = $Codec
        Duration   = $Duration
    }
}

function New-ValidVvcScenarioSet {
    param(
        [Parameter(Mandatory)]
        [string] $FileName,

        [string] $Duration = '1440.0'
    )

    $baseName = [Path]::GetFileNameWithoutExtension($FileName)
    $outputName = '{0}_vvc.mkv' -f $baseName
    $partialName = '{0}_vvc.__partial__.mkv' -f $baseName

    @{
        $FileName    = New-ValidProbeScenario -Codec 'h264' -Duration $Duration
        $outputName  = New-ValidProbeScenario -Codec 'vvc' -Duration $Duration
        $partialName = New-ValidProbeScenario -Codec 'vvc' -Duration $Duration
    }
}

function New-ScenarioLayout {
    param(
        [Parameter(Mandatory)]
        [string] $FileName,

        [switch] $CreateExistingOutput,

        [string] $ExistingOutputName
    )

    $testRoot = New-VvcTestRoot
    $inputDir = New-Item -ItemType Directory -Path (
        Join-Path $testRoot 'input'
    ) -Force
    $outputDir = Join-Path $testRoot 'out'
    $inputPath = Join-Path $inputDir.FullName $FileName
    $ffprobeMarkerPath = Join-Path $testRoot 'ffprobe-invoked.txt'
    $ffmpegMarkerPath = Join-Path $testRoot 'ffmpeg-invoked.txt'
    $outputPath = Join-Path $outputDir (
        '{0}_vvc.mkv' -f [Path]::GetFileNameWithoutExtension($FileName)
    )
    $partialOutputPath = Join-Path $outputDir (
        '{0}_vvc.__partial__.mkv' -f [Path]::GetFileNameWithoutExtension($FileName)
    )

    $preExistingOutputPath = if ($CreateExistingOutput) {
        $existingName = if ([string]::IsNullOrWhiteSpace($ExistingOutputName)) {
            [Path]::GetFileName($outputPath)
        }
        else {
            $ExistingOutputName
        }
        Join-Path $outputDir $existingName
    }
    else {
        $null
    }

    [pscustomobject]@{
        TestRoot           = $testRoot
        InputDir           = $inputDir.FullName
        OutputDir          = $outputDir
        InputPath          = $inputPath
        OutputPath         = $outputPath
        PartialOutputPath  = $partialOutputPath
        ExistingOutputPath = $preExistingOutputPath
        FfprobeMarker      = $ffprobeMarkerPath
        FfmpegMarker       = $ffmpegMarkerPath
    }
}

function Initialize-FakeToolsForScenario {
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Layout,

        [hashtable] $FfprobeScenarios = @{},

        [switch] $CreateOutput,

        [switch] $EmitFfmpegProgress,

        [int] $FfmpegExitCode = 0
    )

    $markerParams = @{
        FfprobeMarker = $Layout.FfprobeMarker
        FfmpegMarker  = $Layout.FfmpegMarker
    }
    Set-FakeMediaToolMarkers @markerParams
    Set-FakeFfprobeScenarios -Scenarios $FfprobeScenarios
    $ffmpegBehaviorParams = @{
        ExitCode     = $FfmpegExitCode
        CreateOutput = $CreateOutput
        EmitProgress = $EmitFfmpegProgress
    }
    Set-FakeFfmpegBehavior @ffmpegBehaviorParams
}

function New-ScenarioInput {
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Layout,

        [string] $InputContent,

        [switch] $CreateEmptyFile
    )

    if ($CreateEmptyFile) {
        New-Item -ItemType File -Path $Layout.InputPath -Force | Out-Null
        return
    }

    Set-Content -LiteralPath $Layout.InputPath -Value $InputContent
}

function New-ScenarioExistingOutput {
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Layout,

        [switch] $CreateOutputDir
    )

    if (-not $CreateOutputDir -and $null -eq $Layout.ExistingOutputPath) {
        return
    }

    New-Item -ItemType Directory -Path $Layout.OutputDir -Force | Out-Null

    if ($null -eq $Layout.ExistingOutputPath) {
        return
    }

    Set-Content -LiteralPath $Layout.ExistingOutputPath -Value (
        'preexisting valid vvc output' * 131072
    )
}

function Invoke-ScenarioCommand {
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Layout,

        [switch] $UseLiteralPath,

        [switch] $UsePipelinePath,

        [switch] $UseWhatIf,

        [int] $MaxParallel = 1,

        [string[]] $Extensions,

        [int] $EncoderThreads = 0,

        [switch] $Overwrite
    )

    $commandParams = @{
        OutputDir = $Layout.OutputDir
    }

    if ($null -ne $Extensions) {
        $commandParams.Extensions = $Extensions
    }

    $commandParams.EncoderThreads = $EncoderThreads

    if ($UseWhatIf) {
        $commandParams.WhatIf = $true
    }

    $commandParams.MaxParallel = $MaxParallel

    if ($Overwrite) {
        $commandParams.Overwrite = $true
    }

    if ($UseLiteralPath) {
        $commandParams.LiteralPath = $Layout.InputPath
    }
    elseif (-not $UsePipelinePath) {
        $commandParams.InputDir = $Layout.InputDir
    }

    if ($UsePipelinePath) {
        return @($Layout.InputPath | Convert-ToVvc @commandParams)
    }

    @(Convert-ToVvc @commandParams)
}

function Assert-ScenarioResultCount {
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Scenario,

        [int] $ExpectedCount = 1
    )

    $Scenario.Result.Count | Should -Be $ExpectedCount
}

function Assert-ScenarioFailed {
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Scenario,

        [string] $ReasonPattern,

        [string] $FileName,

        [string] $OriginalMb = 'ignore'
    )

    Assert-ScenarioResultCount -Scenario $Scenario

    $result = $Scenario.Result[0]
    $result.Ok | Should -BeFalse
    $result.Skipped | Should -BeFalse

    if (-not [string]::IsNullOrWhiteSpace($ReasonPattern)) {
        $result.Reason | Should -Match $ReasonPattern
    }

    if (-not [string]::IsNullOrWhiteSpace($FileName)) {
        $result.File | Should -Be $FileName
    }

    if ($OriginalMb -eq 'positive') {
        $result.OriginalMB | Should -BeGreaterThan 0
    }
    elseif ($OriginalMb -eq 'zero') {
        $result.OriginalMB | Should -Be 0
    }
}

function Assert-ScenarioSucceeded {
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Scenario,

        [string] $FileName
    )

    Assert-ScenarioResultCount -Scenario $Scenario

    $result = $Scenario.Result[0]
    $result.Ok | Should -BeTrue
    $result.Skipped | Should -BeFalse
    $result.Reason | Should -Be ''

    if (-not [string]::IsNullOrWhiteSpace($FileName)) {
        $result.File | Should -Be $FileName
    }

    $result.OriginalMB | Should -BeGreaterThan 0
    $result.NewMB | Should -BeGreaterThan 0
    $result.Ratio | Should -BeGreaterThan 0
}

function Assert-ScenarioSkipped {
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Scenario,

        [string] $Reason,

        [string] $FileName
    )

    Assert-ScenarioResultCount -Scenario $Scenario

    $result = $Scenario.Result[0]
    $result.Ok | Should -BeFalse
    $result.Skipped | Should -BeTrue

    if (-not [string]::IsNullOrWhiteSpace($Reason)) {
        $result.Reason | Should -Be $Reason
    }

    if (-not [string]::IsNullOrWhiteSpace($FileName)) {
        $result.File | Should -Be $FileName
    }
}

function Assert-ScenarioHasNoResults {
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Scenario
    )

    Assert-ScenarioResultCount -Scenario $Scenario -ExpectedCount 0
}

function Assert-ToolInvocationState {
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Scenario,

        [bool] $ExpectFfprobe,

        [bool] $ExpectFfmpeg
    )

    (Test-Path -LiteralPath $Scenario.FfprobeMarker) | Should -Be $ExpectFfprobe
    (Test-Path -LiteralPath $Scenario.FfmpegMarker) | Should -Be $ExpectFfmpeg
}

function Invoke-ConvertScenario {
    param(
        [Parameter(Mandatory)]
        [string] $FileName,

        [string] $InputContent,

        [switch] $CreateEmptyFile,

        [hashtable] $FfprobeScenarios = @{},

        [switch] $CreateOutput,

        [switch] $EmitFfmpegProgress,

        [int] $FfmpegExitCode = 0,

        [switch] $UseLiteralPath,

        [switch] $UsePipelinePath,

        [switch] $UseWhatIf,

        [int] $MaxParallel = 1,

        [switch] $CreateExistingOutput,

        [switch] $CreateOutputDir,

        [string] $ExistingOutputName,

        [string[]] $Extensions,

        [int] $EncoderThreads = 0,

        [switch] $Overwrite
    )

    $layoutParams = @{
        FileName             = $FileName
        CreateExistingOutput = $CreateExistingOutput
        ExistingOutputName   = $ExistingOutputName
    }
    $layout = New-ScenarioLayout @layoutParams

    $fakeToolParams = @{
        Layout           = $layout
        FfprobeScenarios = $FfprobeScenarios
        CreateOutput     = $CreateOutput
        EmitFfmpegProgress = $EmitFfmpegProgress
        FfmpegExitCode   = $FfmpegExitCode
    }
    Initialize-FakeToolsForScenario @fakeToolParams

    $inputParams = @{
        Layout          = $layout
        InputContent    = $InputContent
        CreateEmptyFile = $CreateEmptyFile
    }
    New-ScenarioInput @inputParams

    $existingOutParams = @{
        Layout          = $layout
        CreateOutputDir = $CreateOutputDir
    }
    New-ScenarioExistingOutput @existingOutParams

    $cmdParams = @{
        Layout          = $layout
        UseLiteralPath  = $UseLiteralPath
        UsePipelinePath = $UsePipelinePath
        UseWhatIf       = $UseWhatIf
        MaxParallel     = $MaxParallel
        Extensions      = $Extensions
        EncoderThreads  = $EncoderThreads
        Overwrite       = $Overwrite
    }
    $result = @(Invoke-ScenarioCommand @cmdParams)

    [pscustomobject]@{
        TestRoot           = $layout.TestRoot
        InputDir           = $layout.InputDir
        OutputDir          = $layout.OutputDir
        InputPath          = $layout.InputPath
        OutputPath         = $layout.OutputPath
        PartialOutputPath  = $layout.PartialOutputPath
        ExistingOutputPath = $layout.ExistingOutputPath
        FfprobeMarker      = $layout.FfprobeMarker
        FfmpegMarker       = $layout.FfmpegMarker
        Result             = $result
    }
}
