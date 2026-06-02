#Requires -Version 7.6
#Requires -Modules Pester

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Support' -AdditionalChildPath 'ConvertToVvc.InvocationSuite.ps1')
    $script:toolSupport = Initialize-ConvertToVvcInvocationSuite -TestDrivePath $TestDrive
}

AfterAll {
    Restore-ConvertToVvcInvocationSuite -ToolSupport $script:toolSupport
}

Describe 'Convert-ToVvc invocation marker support' -Tag 'integration' {
    BeforeEach {
        Reset-ConvertToVvcInvocationSuite -ToolSupport $script:toolSupport
    }

    AfterEach {
        Reset-ConvertToVvcInvocationSuite -ToolSupport $script:toolSupport
    }

    Context 'when fake-tool markers are read through support helpers' {
        It 'reads legacy raw marker text as compatibility argv tokens' {
            $markerPath = Join-Path $TestDrive 'legacy-fake-tool-marker.txt'
            Set-Content -LiteralPath $markerPath -Value '-i asakawa-source.mkv -threads 2 output.mkv' -NoNewline

            $marker = Read-FakeToolArguments -MarkerPath $markerPath

            $marker.Format | Should -Be 'LegacyRaw'
            $marker.Raw | Should -Be '-i asakawa-source.mkv -threads 2 output.mkv'
            Assert-FakeToolArgumentValue -Argv $marker.Argv -Name '-threads' -ExpectedValue '2'
        }

        It 'reads a JSON marker file as argv tokens' {
            $markerPath = Join-Path $TestDrive 'json-fake-tool-marker.txt'
            $markerJson = @{
                schemaVersion    = 1
                tool             = 'ffmpeg'
                argv             = @('-i', 'asakawa-source.mkv', '-threads', '2', 'output.mkv')
                workingDirectory = 'Nenya'
                timestampUtc     = '2026-05-26T12:34:56.7890000Z'
            } | ConvertTo-Json -Compress
            Set-Content -LiteralPath $markerPath -Value $markerJson -NoNewline

            $marker = Read-FakeToolArguments -MarkerPath $markerPath

            $marker.Format | Should -Be 'Json'
            $marker.SchemaVersion | Should -Be 1
            $marker.ToolName | Should -Be 'ffmpeg'
            $marker.WorkingDirectory | Should -Be 'Nenya'
            $marker.TimestampUtc | Should -Be '2026-05-26T12:34:56.7890000Z'
            Assert-FakeToolArgumentValue -Argv $marker.Argv -Name '-threads' -ExpectedValue '2'
        }

        It 'reads marker directory records in filename order' {
            $markerDir = Join-Path $TestDrive 'json-marker-records'
            New-Item -ItemType Directory -Path $markerDir -Force | Out-Null
            $first = @{
                schemaVersion    = 1
                tool             = 'ffmpeg'
                argv             = @('-i', 'first.mkv', '-threads', '1', 'first-out.mkv')
                workingDirectory = 'Nenya'
                timestampUtc     = '2026-05-26T12:34:56.7890000Z'
            } | ConvertTo-Json -Compress
            $second = @{
                schemaVersion    = 1
                tool             = 'ffmpeg'
                argv             = @('-i', 'second.mkv', '-threads', '2', 'second-out.mkv')
                workingDirectory = 'Nenya'
                timestampUtc     = '2026-05-26T12:35:56.7890000Z'
            } | ConvertTo-Json -Compress
            Set-Content -LiteralPath (Join-Path $markerDir '0002.json') -Value $second -NoNewline
            Set-Content -LiteralPath (Join-Path $markerDir '0001.json') -Value $first -NoNewline

            $markers = @(Read-FakeToolInvocations -MarkerPath $markerDir)

            $markers.Count | Should -Be 2
            $markers[0].Argv[1] | Should -Be 'first.mkv'
            $markers[1].Argv[1] | Should -Be 'second.mkv'
        }

        It 'reads the latest marker directory record' {
            $markerDir = Join-Path $TestDrive 'latest-json-marker-records'
            New-Item -ItemType Directory -Path $markerDir -Force | Out-Null
            $first = @{
                schemaVersion    = 1
                tool             = 'ffprobe'
                argv             = @('-show_entries', 'format=format_name', 'first.mkv')
                workingDirectory = 'Nenya'
                timestampUtc     = '2026-05-26T12:34:56.7890000Z'
            } | ConvertTo-Json -Compress
            $second = @{
                schemaVersion    = 1
                tool             = 'ffprobe'
                argv             = @('-show_entries', 'format=duration', 'second.mkv')
                workingDirectory = 'Nenya'
                timestampUtc     = '2026-05-26T12:35:56.7890000Z'
            } | ConvertTo-Json -Compress
            Set-Content -LiteralPath (Join-Path $markerDir '0001.json') -Value $first -NoNewline
            Set-Content -LiteralPath (Join-Path $markerDir '0002.json') -Value $second -NoNewline

            $marker = Read-LatestFakeToolInvocation -MarkerPath $markerDir

            $marker.ToolName | Should -Be 'ffprobe'
            $marker.Argv[-1] | Should -Be 'second.mkv'
        }

        It 'returns no records for empty or missing marker directories' {
            $emptyMarkerDir = Join-Path $TestDrive 'empty-marker-records'
            $missingMarkerDir = Join-Path $TestDrive 'missing-marker-records'
            New-Item -ItemType Directory -Path $emptyMarkerDir -Force | Out-Null

            @(Read-FakeToolInvocations -MarkerPath $emptyMarkerDir).Count | Should -Be 0
            @(Read-FakeToolInvocations -MarkerPath $missingMarkerDir).Count | Should -Be 0
        }

        It 'throws when the latest marker is requested from an empty directory' {
            $markerDir = Join-Path $TestDrive 'empty-latest-marker-records'
            New-Item -ItemType Directory -Path $markerDir -Force | Out-Null

            { Read-LatestFakeToolInvocation -MarkerPath $markerDir } |
                Should -Throw -ExpectedMessage '*Fake tool invocation marker directory was empty*'
        }

        It 'creates fresh valid scenario parameters for each example setup' {
            $first = New-ValidConvertScenarioParams -FileName 'asakawa-isolation-one.mkv'
            $second = New-ValidConvertScenarioParams -FileName 'asakawa-isolation-two.mkv'

            $first.FfprobeScenarios['asakawa-isolation-one.mkv'].CodecName = 'vp9'

            $second.FfprobeScenarios['asakawa-isolation-two.mkv'].CodecName |
                Should -Be 'h264'
            [object]::ReferenceEquals($first.FfprobeScenarios, $second.FfprobeScenarios) |
                Should -BeFalse
        }
    }
}
