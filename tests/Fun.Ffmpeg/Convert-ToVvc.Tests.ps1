#Requires -Version 7.5
#Requires -Modules Pester

BeforeAll {
    $script:originalPath = $env:PATH
    $script:mockDir = Join-Path $TestDrive 'ffmpeg-mocks'
    New-Item -ItemType Directory -Path $script:mockDir -Force | Out-Null

    Set-Content -LiteralPath (Join-Path $script:mockDir 'ffprobe.ps1') -Value @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)

$target = $Args[-1]
$name = [System.IO.Path]::GetFileName($target)

switch ($name) {
    'broken.mkv' {
        Write-Output '[in#0 @ 0000000000000000] EBML header parsing failed'
        exit 1
    }
    default {
        Write-Output 'unexpected ffprobe input'
        exit 1
    }
}
'@

    Set-Content -LiteralPath (Join-Path $script:mockDir 'ffmpeg.ps1') -Value @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)

if ($Args -contains '-encoders') {
    Write-Output ' V..... libvvenc            H.266 / VVC'
    exit 0
}

if ($Args -contains '-i' -and -not [string]::IsNullOrWhiteSpace($env:FFMPEG_MOCK_MARKER)) {
    Set-Content -LiteralPath $env:FFMPEG_MOCK_MARKER -Value ($Args -join ' ')
}

exit 99
'@

    $env:PATH = "$script:mockDir$([IO.Path]::PathSeparator)$env:PATH"
    Import-Module -Name (Join-Path $PSScriptRoot '..\..\modules\Fun.Ffmpeg\Fun.Ffmpeg.psd1') -Force -ErrorAction Stop

    function New-VvcTestRoot {
        $root = Join-Path $TestDrive ([guid]::NewGuid().Guid)
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        return $root
    }
}

AfterAll {
    $env:PATH = $script:originalPath
}

Describe 'Convert-ToVvc' {
    It 'reports invalid container errors before attempting conversion' {
        $testRoot = New-VvcTestRoot
        $inputDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'input') -Force
        $outputDir = Join-Path $testRoot 'out'
        $inputPath = Join-Path $inputDir.FullName 'broken.mkv'
        $markerPath = Join-Path $testRoot 'ffmpeg-invoked.txt'

        $env:FFMPEG_MOCK_MARKER = $markerPath
        Set-Content -LiteralPath $inputPath -Value ('not a real matroska file' * 2048)

        $result = Convert-ToVvc -InputDir $inputDir.FullName -OutputDir $outputDir

        @($result).Count | Should -Be 1
        $result[0].Ok | Should -BeFalse
        $result[0].Skipped | Should -BeFalse
        $result[0].Reason | Should -Match '^invalid input: '
        $result[0].Reason | Should -Match 'EBML header parsing failed'
        $result[0].OriginalMB | Should -BeGreaterThan 0
        (Test-Path -LiteralPath $markerPath) | Should -BeFalse
    }

    It 'reports empty files without invoking ffprobe' {
        $testRoot = New-VvcTestRoot
        $inputDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'input') -Force
        $outputDir = Join-Path $testRoot 'out'
        $inputPath = Join-Path $inputDir.FullName 'empty.mkv'
        $markerPath = Join-Path $testRoot 'ffmpeg-invoked.txt'

        $env:FFMPEG_MOCK_MARKER = $markerPath
        New-Item -ItemType File -Path $inputPath -Force | Out-Null

        $result = Convert-ToVvc -InputDir $inputDir.FullName -OutputDir $outputDir

        @($result).Count | Should -Be 1
        $result[0].Ok | Should -BeFalse
        $result[0].Skipped | Should -BeFalse
        $result[0].Reason | Should -Be 'invalid input: input file is empty.'
        $result[0].OriginalMB | Should -Be 0
        (Test-Path -LiteralPath $markerPath) | Should -BeFalse
    }
}
