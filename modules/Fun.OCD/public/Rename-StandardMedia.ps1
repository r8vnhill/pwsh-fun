function Rename-StandardMedia {
    [Alias('doctor')]
    [CmdletBinding(DefaultParameterSetName = 'Document', SupportsShouldProcess)]
    param (
        
        [Parameter(Mandatory, ParameterSetName = 'Document', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter(Mandatory, ParameterSetName = 'Anime', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({ Test-Path $_ })]
        [string] $Item,
        
        [Parameter(ParameterSetName = 'Anime')]
        [switch] $Anime,

        [Parameter(Mandatory, ParameterSetName = 'Document')]
        [Parameter(Mandatory, ParameterSetName = 'Anime')]
        [Alias('t')]
        [string] $Title,

        [Parameter(ParameterSetName = 'Document')]
        [Alias('by')]
        [string[]] $Authors,

        [Parameter(ParameterSetName = 'Document')]
        [Parameter(ParameterSetName = 'Anime')]
        [Alias('y')]
        [string] $Year,

        [Parameter(ParameterSetName = 'Document')]
        [Alias('ed')]
        [string] $Publisher,

        [Parameter(ParameterSetName = 'Document')]
        [Alias('e')]
        [string] $Edition,

        [Parameter(ParameterSetName = 'Anime')]
        [Alias('s')]
        [string[]] $Studios,

        [Parameter(ParameterSetName = 'Anime')]
        [string] $Season,

        [Parameter(ParameterSetName = 'Anime')]
        [string] $Arc,

        
        [Parameter(ParameterSetName = 'Anime')]
        [Alias('n')]
        [int] $EpisodeNumber,

        [Parameter(ParameterSetName = 'Anime')]
        [Alias('ep')]
        [string] $EpisodeName
    )

    process {
        $extension = [System.IO.Path]::GetExtension($Item)

        $baseName = ($PSCmdlet.ParameterSetName -eq 'Anime') ? (
            Get-BaseNameForAnime `
                -Title $Title `
                -Year $Year `
                -Season $Season `
                -Arc $Arc `
                -Studios $Studios `
                -EpisodeNumber $EpisodeNumber `
                -EpisodeName $EpisodeName
        ) : (
            Get-BaseNameForDocument -Title $Title -Year $Year -Edition $Edition -Publisher $Publisher -Authors $Authors
        )

        $safeName = Format-FileName -FileName $baseName
        $newName = "$safeName$extension"

        if ($PSCmdlet.ShouldProcess($Item, "Rename to '$newName'")) {
            Rename-Item -Path $Item -NewName $newName
        }
    }
}

function Get-BaseNameForAnime {
    [CmdletBinding()]
    param (
        [string] $Title,
        [string] $Year,
        [string] $Season,
        [string] $Arc,
        [string[]] $Studios,
        [int] $EpisodeNumber,
        [string] $EpisodeName
    )

    $yearPart = if ($Year) { " ($Year)" } else { '' }
    $seasonArcPart = Get-SeasonArcPart -Season $Season -Arc $Arc

    $episodePart = if ($EpisodeNumber) {
        $ep = 'E' + ('{0:D2}' -f $EpisodeNumber)
        if ($EpisodeName) {
            "$ep - $EpisodeName"
        } else {
            $ep
        }
    } elseif ($EpisodeName) {
        $EpisodeName
    } else {
        ''
    }

    $studioPart = Get-StudioPart -Studios $Studios

    $parts = @(
        $Title
        $yearPart
        $seasonArcPart
        $episodePart
        $studioPart
    ) | Where-Object { $_ -and $_ -ne '' }

    return ($parts -join ' - ')
}

function Get-BaseNameForDocument {
    param (
        [string] $Title,
        [string] $Year,
        [string] $Edition,
        [string] $Publisher,
        [string[]] $Authors
    )
    $detailsPart = Get-DetailPart -Parts @($Year, $Edition, $Publisher)

    $authorPart = ($Authors -and ($Authors -join '').Trim().Length -gt 0) ? (
        ' - ' + ($Authors -join ', ')
    ) : ''

    return "$Title$detailsPart$authorPart"
}

function Get-SeasonArcPart {
    param (
        [string] $Season,
        [string] $Arc
    )
    $list = @()
    if ($Season) { $list += $Season }
    if ($Arc) { $list += $Arc }

    return ($list.Count -gt 0) ? ' (' + ($list -join ', ') + ')' : ''
}

function Get-StudioPart {
    param (
        [string[]] $Studios
    )
    return ($Studios) ? ' [' + ($Studios -join ', ') + ']' : ''
}

function Get-DetailPart {
    param (
        [string[]] $Parts
    )
    $filtered = $Parts | Where-Object { $_ }
    return ($filtered.Count -gt 0) ? ' (' + ($filtered -join ', ') + ')' : ''
}

function Format-FileName {
    [CmdletBinding()]
    param (
        [string] $FileName
    )

    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars() |
        ForEach-Object { [Regex]::Escape($_) } |
        Join-String -Separator ''
    $pattern = "[$invalidChars]"

    return [Regex]::Replace($FileName, $pattern, '_')
}
