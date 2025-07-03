function Rename-StandardMedia {
    [Alias('doctor')]
    [CmdletBinding(DefaultParameterSetName = 'Document', SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Document', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter(Mandatory, ParameterSetName = 'Anime', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter(Mandatory, ParameterSetName = 'Comic', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({ Test-Path $_ })]
        [string]    $Item,
        
        [Parameter(ParameterSetName = 'Anime')]
        [switch]    $Anime,

        [Parameter(ParameterSetName = 'Comic')]
        [switch]    $Comic,

        [Parameter(Mandatory, ParameterSetName = 'Document')]
        [Parameter(Mandatory, ParameterSetName = 'Anime')]
        [Parameter(Mandatory, ParameterSetName = 'Comic')]
        [Alias('t')]
        [string]    $Title,

        [Parameter(ParameterSetName = 'Document')]
        [Alias('by')]
        [string[]]  $Authors,

        [Parameter(ParameterSetName = 'Comic')]
        [string[]]  $Creators,

        [Parameter(ParameterSetName = 'Document')]
        [Parameter(ParameterSetName = 'Anime')]
        [Parameter(ParameterSetName = 'Comic')]
        [Alias('y')]
        [string]    $Year,

        [Parameter(ParameterSetName = 'Document')]
        [Parameter(ParameterSetName = 'Comic')]
        [Alias('ed')]
        [string]    $Publisher,

        [Parameter(ParameterSetName = 'Document')]
        [Alias('e')]
        [string]    $Edition,

        [Parameter(ParameterSetName = 'Anime')]
        [Alias('s')]
        [string[]]  $Studios,

        [Parameter(ParameterSetName = 'Anime')]
        [string]    $Season,

        [Parameter(ParameterSetName = 'Anime')]
        [Parameter(ParameterSetName = 'Comic')]
        [string]    $Arc,

        [Parameter(ParameterSetName = 'Comic')]
        [string]    $Volume,

        [Parameter(ParameterSetName = 'Comic')]
        [string]    $VolumeName,

        [Parameter(ParameterSetName = 'Comic')]
        [string]    $IssueNumber,

        [Parameter(ParameterSetName = 'Comic')]
        [string]    $IssueName,

        [Parameter(ParameterSetName = 'Anime')]
        [Alias('n')]
        [int]       $EpisodeNumber,

        [Parameter(ParameterSetName = 'Anime')]
        [Alias('ep')]
        [string]    $EpisodeName
    )

    process {
        $extension = [System.IO.Path]::GetExtension($Item)

        $baseName = switch ($PSCmdlet.ParameterSetName) {
            'Anime' {
                Get-BaseNameForAnime `
                    -Title $Title `
                    -Year $Year `
                    -Season $Season `
                    -Arc $Arc `
                    -Studios $Studios `
                    -EpisodeNumber $EpisodeNumber `
                    -EpisodeName $EpisodeName
            }
            'Comic' {
                Get-BaseNameForComic `
                    -Title $Title `
                    -Year $Year `
                    -Arc $Arc `
                    -Volume $Volume `
                    -VolumeName $VolumeName `
                    -IssueNumber $IssueNumber `
                    -IssueName $IssueName `
                    -Creators $Creators `
                    -Publisher $Publisher
            }
            default {
                Get-BaseNameForDocument `
                    -Title $Title `
                    -Year $Year `
                    -Edition $Edition `
                    -Publisher $Publisher `
                    -Authors $Authors
            }
        }

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
        [string]    $Title,
        [string]    $Year,
        [string]    $Season,
        [string]    $Arc,
        [string[]]  $Studios,
        [int]       $EpisodeNumber,
        [string]    $EpisodeName
    )

    $yearPart     = if ($Year) { "($Year)" } else { $null }
    $seasonArc    = Get-SeasonArcPart -Season $Season -Arc $Arc
    $studioPart   = Get-StudioPart -Studios $Studios

    $episodePart = if ($EpisodeNumber) {
        $ep = 'E' + ('{0:D3}' -f $EpisodeNumber)
        if ($EpisodeName) {
            "$ep - $EpisodeName"
        } else {
            $ep
        }
    } elseif ($EpisodeName) {
        $EpisodeName
    } else {
        $null
    }

    $parts = @(
        $Title
        $yearPart
        $seasonArc
        $episodePart
    ) | Where-Object { $_ }

    $name = ($parts -join ' ')
    if ($studioPart) {
        $name += " $studioPart"
    }

    return $name
}

function Get-BaseNameForComic {
    [CmdletBinding()]
    param (
        [string]   $Title,
        [string]   $Year,
        [string]   $Arc,
        [string[]] $Creators,
        [string]   $Publisher,
        [string]   $Volume,
        [string]   $VolumeName,
        [string]   $IssueNumber,
        [string]   $IssueName
    )

    $yearPart = if ($Year) { "($Year)" } else { $null }

    $volumePart = if ($Volume) {
        "Vol.$Volume"
    } else { $null }

    $volumeNamePart = if ($VolumeName) {
        ": $VolumeName"
    } else { $null }

    $arcPart = if ($Arc) {
        "[$Arc]"
    } else { $null }

    $issuePart = if ($IssueNumber) {
        $num = if ($IssueNumber -match '^\d+$') {
            '#{0:D3}' -f [int]$IssueNumber
        } else {
            "#$IssueNumber"
        }

        if ($IssueName) {
            "$num - $IssueName"
        } else {
            $num
        }
    } elseif ($IssueName) {
        $IssueName
    } else {
        $null
    }

    $mainParts = @(
        $Title
        $yearPart
        $volumePart
        $volumeNamePart
        $arcPart
        $issuePart
    ) | Where-Object { $_ }

    $baseName = $mainParts -join ' '

    $metaParts = @()

    if ($Creators) {
        $metaParts += "by " + ($Creators -join ', ')
    }

    if ($metaParts.Count -gt 0) {
        $baseName += " (" + ($metaParts -join ', ') + ")"
    }

    if ($Publisher) {
        $baseName += " [$Publisher]"
    }

    return $baseName
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
