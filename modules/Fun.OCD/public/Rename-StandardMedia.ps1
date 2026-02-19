#Requires -Version 7.4

Set-StrictMode -Version 3.0

$privateFolder = Join-Path $PSScriptRoot '..\private'
. (Join-Path $privateFolder 'Rename-StandardMedia.NameParts.ps1')
. (Join-Path $privateFolder 'Rename-StandardMedia.PathAndFormat.ps1')
. (Join-Path $privateFolder 'Rename-StandardMedia.NameBuilders.ps1')

function Rename-StandardMedia {
    [Alias('doctor')]
    [CmdletBinding(
        DefaultParameterSetName = 'Document', 
        SupportsShouldProcess, 
        PositionalBinding = $false)]
    [OutputType([System.IO.FileInfo])]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Document', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter(Mandatory, ParameterSetName = 'Anime', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter(Mandatory, ParameterSetName = 'Comic', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter(Mandatory, ParameterSetName = 'Movie', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter(Mandatory, ParameterSetName = 'Series', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter(Mandatory, ParameterSetName = 'Game', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({ Test-StandardMediaPath -Path $_ })]
        [ValidateNotNullOrEmpty()]
        [string]    $Item,
        
        [Parameter(ParameterSetName = 'Anime')]
        [switch]    $Anime,

        [Parameter(ParameterSetName = 'Comic')]
        [switch]    $Comic,

        [Parameter(ParameterSetName = 'Movie')]
        [switch]    $Movie,

        [Parameter(ParameterSetName = 'Series')]
        [switch]    $Series,

        [Parameter(ParameterSetName = 'Game')]
        [switch]    $Game,

        [Parameter(Mandatory, ParameterSetName = 'Document')]
        [Parameter(Mandatory, ParameterSetName = 'Anime')]
        [Parameter(Mandatory, ParameterSetName = 'Comic')]
        [Parameter(Mandatory, ParameterSetName = 'Movie')]
        [Parameter(Mandatory, ParameterSetName = 'Series')]
        [Parameter(Mandatory, ParameterSetName = 'Game')]
        [Alias('t')]
        [ValidateNotNullOrEmpty()]
        [string]    $Title,

        [Parameter(ParameterSetName = 'Document')]
        [Alias('by')]
        [string[]]  $Authors,

        [Parameter(ParameterSetName = 'Comic')]
        [Parameter(ParameterSetName = 'Series')]
        [string[]]  $Creators,

        [Parameter(ParameterSetName = 'Document')]
        [Parameter(ParameterSetName = 'Anime')]
        [Parameter(ParameterSetName = 'Comic')]
        [Parameter(ParameterSetName = 'Movie')]
        [Parameter(ParameterSetName = 'Series')]
        [Parameter(ParameterSetName = 'Game')]
        [Alias('y')]
        [object[]]  $Year,

        [Parameter(ParameterSetName = 'Anime')]
        [Parameter(ParameterSetName = 'Movie')]
        [Parameter(ParameterSetName = 'Series')]
        [Alias('enc')]
        [string]    $Encoding,

        [Parameter(ParameterSetName = 'Document')]
        [Parameter(ParameterSetName = 'Comic')]
        [Alias('ed')]
        [string]    $Publisher,

        [Parameter(ParameterSetName = 'Document')]
        [Parameter(ParameterSetName = 'Comic')]
        [Alias('e')]
        [string]    $Edition,

        [Parameter(ParameterSetName = 'Anime')]
        [Alias('s')]
        [string[]]  $Studios,

        [Parameter(ParameterSetName = 'Anime')]
        [Parameter(ParameterSetName = 'Comic')]
        [Parameter(ParameterSetName = 'Series')]
        [Alias('ao')]
        [Nullable[int]] $ArcOrder,

        [Parameter(ParameterSetName = 'Anime')]
        [Parameter(ParameterSetName = 'Series')]
        [string]    $Season,

        [Parameter(ParameterSetName = 'Series')]
        [string]    $SeasonName,

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
        [Parameter(ParameterSetName = 'Series')]
        [Alias('n')]
        [Nullable[int]] $EpisodeNumber,

        [Parameter(ParameterSetName = 'Anime')]
        [Parameter(ParameterSetName = 'Series')]
        [Alias('ep')]
        [string]    $EpisodeName,

        [Parameter(ParameterSetName = 'Movie')]
        [Alias('dir')]
        [string[]]  $Directors,

        [Parameter(ParameterSetName = 'Game')]
        [Alias('dev')]
        [string[]]  $Developers,

        [Parameter(ParameterSetName = 'Game')]
        [Alias('plt')]
        [string]    $Platform,

        [switch]    $PassThru
    )

    process {
        $resolvedPath = Resolve-StandardMediaPath -Path $Item
        $extension = [System.IO.Path]::GetExtension($resolvedPath)

        $baseName = switch ($PSCmdlet.ParameterSetName) {
            'Anime' {
                Get-BaseNameForAnime `
                    -Title $Title `
                    -Year $Year `
                    -Encoding $Encoding `
                    -Season $Season `
                    -Arc $Arc `
                    -ArcOrder $ArcOrder `
                    -Studios $Studios `
                    -EpisodeNumber $EpisodeNumber `
                    -EpisodeName $EpisodeName
            }
            'Comic' {
                Get-BaseNameForComic `
                    -Title $Title `
                    -Year $Year `
                    -Arc $Arc `
                    -ArcOrder $ArcOrder `
                    -Volume $Volume `
                    -VolumeName $VolumeName `
                    -IssueNumber $IssueNumber `
                    -IssueName $IssueName `
                    -Creators $Creators `
                    -Publisher $Publisher `
                    -Edition $Edition
            }
            'Movie' {
                Get-BaseNameForMovie `
                    -Title $Title `
                    -Year $Year `
                    -Encoding $Encoding `
                    -Directors $Directors
            }
            'Series' {
                Get-BaseNameForSeries `
                    -Title $Title `
                    -Year $Year `
                    -Encoding $Encoding `
                    -Season $Season `
                    -SeasonName $SeasonName `
                    -EpisodeNumber $EpisodeNumber `
                    -EpisodeName $EpisodeName `
                    -Arc $Arc `
                    -ArcOrder $ArcOrder `
                    -Creators $Creators
            }
            'Game' {
                Get-BaseNameForGame `
                    -Title $Title `
                    -Year $Year `
                    -Platform $Platform `
                    -Developers $Developers
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

        if ($PSCmdlet.ShouldProcess($resolvedPath, "Rename to '$newName'")) {
            $result = Rename-Item -LiteralPath $resolvedPath -NewName $newName -PassThru:$PassThru
            if ($PassThru) {
                return $result
            }
        }
    }
}
