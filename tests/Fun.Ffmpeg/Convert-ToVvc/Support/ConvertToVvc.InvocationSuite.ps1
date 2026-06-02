#Requires -Version 7.6

. (Join-Path -Path $PSScriptRoot -ChildPath 'FakeMediaTools.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'FakeToolArgumentSupport.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'ConvertToVvc.SpecSupport.ps1')

function Initialize-ConvertToVvcInvocationSuite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TestDrivePath
    )

    $toolSupportParams = @{
        TestDrivePath = $TestDrivePath
        MockDirName   = 'ffmpeg-convert-invocation-mocks'
    }
    $toolSupport = Initialize-FakeMediaToolSupport @toolSupportParams

    Enable-FakeMediaToolSupport -Context $toolSupport

    Import-Module -Name (
        Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath @(
            '..', '..', '..', 'modules', 'Fun.Ffmpeg', 'Fun.Ffmpeg.psd1')
    ) -Force -ErrorAction Stop

    $toolSupport
}

function Reset-ConvertToVvcInvocationSuite {
    [CmdletBinding()]
    param(
        $ToolSupport
    )

    Reset-FakeMediaToolEnvironment -Context $ToolSupport
}

function Restore-ConvertToVvcInvocationSuite {
    [CmdletBinding()]
    param(
        $ToolSupport
    )

    if ($ToolSupport) {
        try {
            Restore-FakeMediaToolSupport -Context $ToolSupport
        }
        catch {
            Write-Warning "Fake media tool cleanup failed: $($_.Exception.Message)"
        }
    }
}
