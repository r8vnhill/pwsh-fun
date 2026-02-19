function Test-StandardMediaPath {
    param (
        [string] $Path
    )

    if (Test-Path -LiteralPath $Path) {
        return $true
    }

    $unescaped = ConvertFrom-EscapedPath -Path $Path
    if ($unescaped -eq $Path) {
        return $false
    }

    return (Test-Path -LiteralPath $unescaped)
}

function Resolve-StandardMediaPath {
    [CmdletBinding()]
    param (
        [string] $Path
    )

    try {
        return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    }
    catch {
        $unescaped = ConvertFrom-EscapedPath -Path $Path
        if ($unescaped -ne $Path) {
            return (Resolve-Path -LiteralPath $unescaped -ErrorAction Stop).ProviderPath
        }

        throw
    }
}

function ConvertFrom-EscapedPath {
    param (
        [string] $Path
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or -not $Path.Contains('`')) {
        return $Path
    }

    return ($Path -replace '`', '')
}

function Format-YearRange {
    [CmdletBinding()]
    param (
        [object[]] $Year
    )

    $values = @($Year)
    if ($values.Count -eq 0) {
        return $null
    }

    $start = ConvertTo-YearText -Value $values[0]
    $end = if ($values.Count -gt 1) { ConvertTo-YearText -Value $values[1] } else { $null }

    if ([string]::IsNullOrWhiteSpace($start) -and [string]::IsNullOrWhiteSpace($end)) {
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($start)) {
        return $end
    }

    if ($values.Count -gt 1) {
        $dash = [char]0x2013
        if ([string]::IsNullOrWhiteSpace($end)) {
            return "$start$dash"
        }

        return "$start$dash$end"
    }

    return $start
}

function ConvertTo-YearText {
    param (
        [object] $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [DateTime]) {
        return $Value.Year.ToString()
    }

    if ($Value -is [DateOnly]) {
        return $Value.Year.ToString()
    }

    if ($Value -is [int] -or $Value -is [long] -or $Value -is [short]) {
        return $Value.ToString()
    }

    $text = $Value.ToString().Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    $parsed = [DateTime]::MinValue
    if ([DateTime]::TryParse($text, [ref]$parsed)) {
        return $parsed.Year.ToString()
    }

    return $text
}

function Format-FileName {
    [CmdletBinding()]
    param (
        [string] $FileName
    )

    $normalized = [Regex]::Replace($FileName, '\s{2,}', ' ').Trim()

    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars() |
        ForEach-Object { [Regex]::Escape($_) } |
        Join-String -Separator ''
    $pattern = "[$invalidChars]"

    $cleaned = [Regex]::Replace($normalized, $pattern, '_').TrimEnd('.')
    if ($cleaned) {
        return $cleaned
    }

    return '_'
}
