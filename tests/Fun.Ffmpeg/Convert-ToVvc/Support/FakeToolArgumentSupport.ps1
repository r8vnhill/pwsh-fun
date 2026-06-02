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
        $timestampUtc = $record.timestampUtc
        if ($timestampUtc -is [datetime]) {
            $timestampUtc = $timestampUtc.ToUniversalTime().ToString('o')
        }
        elseif ($null -ne $timestampUtc) {
            $timestampUtc = [string] $timestampUtc
        }

        return [pscustomobject]@{
            Format           = 'Json'
            SchemaVersion    = $record.schemaVersion
            ToolName         = $record.tool
            WorkingDirectory = $record.workingDirectory
            TimestampUtc     = $timestampUtc
            Raw              = $raw
            Argv             = $argv
            MarkerPath       = $MarkerPath
        }
    }

    [pscustomobject]@{
        Format           = 'LegacyRaw'
        SchemaVersion    = $null
        ToolName         = $null
        WorkingDirectory = $null
        TimestampUtc     = $null
        Raw              = $raw
        Argv             = @(Split-LegacyFakeToolArguments -RawArguments $trimmed)
        MarkerPath       = $MarkerPath
    }
}

function Read-FakeToolInvocations {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $MarkerPath
    )

    if (-not (Test-Path -LiteralPath $MarkerPath -PathType Container)) {
        return @()
    }

    $markerFiles = @(
        Get-ChildItem -LiteralPath $MarkerPath -Filter '*.json' -File |
            Sort-Object -Property Name
    )

    if ($markerFiles.Count -eq 0) {
        return @()
    }

    @(
        foreach ($markerFile in $markerFiles) {
            $marker = Read-FakeToolArguments -MarkerPath $markerFile.FullName
            if ($marker.Format -ne 'Json') {
                throw "Fake tool invocation marker was not JSON: $($markerFile.FullName)"
            }

            $marker
        }
    )
}

function Read-LatestFakeToolInvocation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $MarkerPath
    )

    $invocations = @(Read-FakeToolInvocations -MarkerPath $MarkerPath)
    if ($invocations.Count -eq 0) {
        throw "Fake tool invocation marker directory was empty: $MarkerPath"
    }

    $invocations[-1]
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
