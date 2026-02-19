function Get-BaseNameForAnime {
    [CmdletBinding()]
    param (
        [string]    $Title,
        [object[]]  $Year,
        [string]    $Encoding,
        [string]    $Season,
        [string]    $Arc,
        [Nullable[int]] $ArcOrder,
        [string[]]  $Studios,
        [Nullable[int]] $EpisodeNumber,
        [string]    $EpisodeName
    )

    $yearPart = Format-YearRange -Year $Year
    $detailPart = Get-DetailPart -Parts @($yearPart, $Encoding)
    $titlePart = "$Title$detailPart"

    $seasonEpisodePart = Get-SeasonEpisodePart -Season $Season -EpisodeNumber $EpisodeNumber
    $arcPart = Get-ArcPart -Arc $Arc -ArcOrder $ArcOrder
    $episodeNamePart = if (-not [string]::IsNullOrWhiteSpace($EpisodeName)) { $EpisodeName } else { $null }
    $studioPart = Get-NamedListPart -Label 'studios' -Values $Studios

    return Join-NameSegments -Segments @(
        $arcPart
        $titlePart
        $seasonEpisodePart
        $episodeNamePart
        $studioPart
    )
}

function Get-BaseNameForSeries {
    [CmdletBinding()]
    param (
        [string]   $Title,
        [object[]] $Year,
        [string]   $Encoding,
        [string]   $Season,
        [string]   $SeasonName,
        [Nullable[int]] $EpisodeNumber,
        [string]   $EpisodeName,
        [string]   $Arc,
        [Nullable[int]] $ArcOrder,
        [string[]] $Creators
    )

    $yearPart = Format-YearRange -Year $Year
    $detailPart = Get-DetailPart -Parts @($yearPart, $Encoding)
    $titlePart = "$Title$detailPart"

    $seasonEpisodePart = Get-SeasonEpisodePart -Season $Season -EpisodeNumber $EpisodeNumber
    $seasonNamePart  = if (-not [string]::IsNullOrWhiteSpace($SeasonName)) { $SeasonName } else { $null }
    $episodeNamePart = if (-not [string]::IsNullOrWhiteSpace($EpisodeName)) { $EpisodeName } else { $null }
    $arcPart = Get-ArcPart -Arc $Arc -ArcOrder $ArcOrder
    $creatorPart = Get-NamedListPart -Label 'by' -Values $Creators

    return Join-NameSegments -Segments @(
        $arcPart
        $titlePart
        $seasonEpisodePart
        $seasonNamePart
        $episodeNamePart
        $creatorPart
    )
}

function Get-BaseNameForComic {
    [CmdletBinding()]
    param (
        [string]   $Title,
        [object[]] $Year,
        [string]   $Edition,
        [string]   $Arc,
        [Nullable[int]] $ArcOrder,
        [string[]] $Creators,
        [string]   $Publisher,
        [string]   $Volume,
        [string]   $VolumeName,
        [string]   $IssueNumber,
        [string]   $IssueName
    )

    $yearPart = Format-YearRange -Year $Year
    $detailPart = Get-DetailPart -Parts @($yearPart, $Edition)
    $titlePart = "$Title$detailPart"

    $volumeSegment = $null
    if (-not [string]::IsNullOrWhiteSpace($Volume)) {
        $volumeSegment = "Vol.$Volume"
        if (-not [string]::IsNullOrWhiteSpace($VolumeName)) {
            $volumeSegment += " $VolumeName"
        }
    }
    elseif (-not [string]::IsNullOrWhiteSpace($VolumeName)) {
        $volumeSegment = $VolumeName
    }

    $arcPart = Get-ArcPart -Arc $Arc -ArcOrder $ArcOrder

    $hasIssueNumber = $PSBoundParameters.ContainsKey('IssueNumber') -and -not [string]::IsNullOrWhiteSpace($IssueNumber)
    $hasIssueName = $PSBoundParameters.ContainsKey('IssueName') -and -not [string]::IsNullOrWhiteSpace($IssueName)

    $issueTag = if ($hasIssueNumber) {
        if ($IssueNumber -match '^\d+$') {
            '#{0:D3}' -f [int]$IssueNumber
        }
        else {
            "#$IssueNumber"
        }
    }
    else {
        $null
    }

    $issuePart = if ($hasIssueName -and $issueTag) {
        "$issueTag $IssueName"
    }
    elseif ($hasIssueName) {
        $IssueName
    }
    else {
        $issueTag
    }

    $creatorPart = Get-NamedListPart -Label 'by' -Values $Creators
    $publisherPart = Get-NamedListPart -Label 'publisher' -Values @($Publisher)

    return Join-NameSegments -Segments @(
        $arcPart
        $titlePart
        $volumeSegment
        $issuePart
        $creatorPart
        $publisherPart
    )
}

function Get-BaseNameForDocument {
    param (
        [string] $Title,
        [object[]] $Year,
        [string] $Edition,
        [string] $Publisher,
        [string[]] $Authors
    )
    $yearPart = Format-YearRange -Year $Year
    $detailsPart = Get-DetailPart -Parts @($yearPart, $Edition, $Publisher)
    $titlePart = "$Title$detailsPart"
    $authorPart = Get-NamedListPart -Label 'by' -Values $Authors

    return Join-NameSegments -Segments @(
        $titlePart
        $authorPart
    )
}

function Get-BaseNameForMovie {
    [CmdletBinding()]
    param (
        [string]   $Title,
        [object[]] $Year,
        [string]   $Encoding,
        [string[]] $Directors
    )

    $yearPart = Format-YearRange -Year $Year
    $detailPart = Get-DetailPart -Parts @($yearPart, $Encoding)
    $titlePart = "$Title$detailPart"
    $directorPart = Get-NamedListPart -Label 'dir' -Values $Directors

    return Join-NameSegments -Segments @(
        $titlePart
        $directorPart
    )
}

function Get-BaseNameForGame {
    [CmdletBinding()]
    param (
        [string]   $Title,
        [object[]] $Year,
        [string[]] $Developers,
        [string]   $Platform
    )

    $yearPart = Format-YearRange -Year $Year
    $detailPart = Get-DetailPart -Parts @($yearPart, $Platform)
    $titlePart = "$Title$detailPart"
    $developerPart = Get-NamedListPart -Label 'dev' -Values $Developers

    return Join-NameSegments -Segments @(
        $titlePart
        $developerPart
    )
}
