#Requires -Version 7.6

function Split-LegacyFakeToolArguments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RawArguments
    )

    if ([string]::IsNullOrWhiteSpace($RawArguments)) {
        return @()
    }

    $RawArguments -split '\s+' | Where-Object { $_ }
}

function Read-FakeToolArguments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $MarkerPath
    )

    if (-not (Test-Path -LiteralPath $MarkerPath)) {
        throw "Fake tool marker was not found: $MarkerPath"
    }

    $raw = Get-Content -LiteralPath $MarkerPath -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Fake tool marker was empty: $MarkerPath"
    }

    $trimmed = $raw.Trim()
    if ($trimmed.StartsWith('{')) {
        try {
            $record = $trimmed | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            throw "Fake tool marker could not be parsed as JSON: $MarkerPath`n$($_.Exception.Message)"
        }

        $argv = @()
        if ($null -ne $record.argv) {
            $argv = @($record.argv)
        }

        return [pscustomobject]@{
            Format           = 'Json'
            ToolName         = $record.tool
            WorkingDirectory = $record.workingDirectory
            Raw              = $raw
            Argv             = $argv
        }
    }

    [pscustomobject]@{
        Format           = 'LegacyRaw'
        ToolName         = $null
        WorkingDirectory = $null
        Raw              = $raw
        Argv             = @(Split-LegacyFakeToolArguments -RawArguments $trimmed)
    }
}

function Assert-FakeToolArgumentValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]] $Argv,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $ExpectedValue
    )

    $index = [Array]::IndexOf($Argv, $Name)

    $index | Should -BeGreaterOrEqual 0
    ($index + 1) | Should -BeLessThan $Argv.Count
    [string] $Argv[$index + 1] | Should -Be $ExpectedValue
}