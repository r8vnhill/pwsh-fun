function Join-NameSegments {
    param (
        [string[]] $Segments
    )

    return ($Segments | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ' - '
}

function Get-SeasonTag {
    param (
        [string] $Season
    )

    if ([string]::IsNullOrWhiteSpace($Season)) {
        return $null
    }

    if ($Season -match '^\d+$') {
        return 'S' + ('{0:D2}' -f [int]$Season)
    }

    return $Season.Trim()
}

function Get-EpisodeTag {
    param (
        [Nullable[int]] $EpisodeNumber
    )

    if ($null -ne $EpisodeNumber -and $EpisodeNumber -gt 0) {
        return 'E' + ('{0:D3}' -f $EpisodeNumber)
    }

    return $null
}

function Get-SeasonEpisodePart {
    param (
        [string] $Season,
        [Nullable[int]] $EpisodeNumber
    )

    $seasonTag = Get-SeasonTag -Season $Season
    $episodeTag = Get-EpisodeTag -EpisodeNumber $EpisodeNumber

    if ($seasonTag -and $episodeTag) {
        if ($seasonTag -match '^S\d{2}$') {
            return "$seasonTag$episodeTag"
        }

        return "$seasonTag $episodeTag"
    }

    if ($seasonTag) {
        return $seasonTag
    }

    return $episodeTag
}

function Get-ArcPart {
    [CmdletBinding()]
    param (
        [string] $Arc,
        [Nullable[int]] $ArcOrder
    )

    if ([string]::IsNullOrWhiteSpace($Arc) -and $null -eq $ArcOrder) {
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($Arc)) {
        return $null
    }

    if ($null -eq $ArcOrder) {
        return $Arc
    }

    return "$Arc #{0:D3}" -f $ArcOrder
}

function Get-NamedListPart {
    param (
        [string]   $Label,
        [string[]] $Values
    )

    $items = @($Values | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($items.Count -eq 0) {
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($Label)) {
        return ($items -join ', ')
    }

    return "$Label $($items -join ', ')"
}

function Get-DetailPart {
    param (
        [string[]] $Parts
    )
    $filtered = @($Parts | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    return ($filtered.Count -gt 0) ? ' (' + ($filtered -join ', ') + ')' : ''
}
