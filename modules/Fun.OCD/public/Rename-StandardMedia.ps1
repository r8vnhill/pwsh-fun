function Rename-StandardMedia {
    [Alias('doctor')]
    [CmdletBinding(DefaultParameterSetName = 'Document', SupportsShouldProcess)]
    param (
        [switch] $Anime,
        # Every invocation needs a file path and a title, regardless of set.
        [Parameter(Mandatory = $true, ParameterSetName = 'Document', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter(Mandatory = $true, ParameterSetName = 'Anime',   ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({ Test-Path $_ })]
        [string] $Item,

        [Parameter(Mandatory = $true, ParameterSetName = 'Document')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Anime')]
        [Alias('t')]
        [string] $Title,

        # ——————— Document‐only parameters (ParameterSetName = 'Document') ———————
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

        # ——————— Anime‐only parameters (ParameterSetName = 'Anime') ———————
        [Parameter(ParameterSetName = 'Anime')]
        [Alias('s')]
        [string[]] $Studios,

        [Parameter(ParameterSetName = 'Anime')]
        [string] $Season,

        [Parameter(ParameterSetName = 'Anime')]
        [string] $Arc
    )

    process {
        # Get the extension once
        $extension = [System.IO.Path]::GetExtension($Item)

        if ($PSCmdlet.ParameterSetName -eq 'Anime') {
            #
            # === Anime Mode ===
            # Format: Title [Studio1, Studio2] (Season, Arc)
            #
            # Construct "[Studio1, Studio2]" part if any studios provided.
            $studioPart = ''
            if ($Studios) {
                $studioPart = " [" + ($Studios -join ', ') + "]"
            }

            # Build a list of season/arc details
            $detailsList = @()
            if ($Season) { $detailsList += $Season }
            if ($Arc)    { $detailsList += $Arc }

            $detailsPart = ''
            if ($detailsList.Count -gt 0) {
                $detailsPart = " (" + ($detailsList -join ', ') + ")"
            }

            $baseName = "$Title$studioPart$detailsPart"
        }
        else {
            #
            # === Document Mode ===
            # Format: Title - Author1, Author2 (Year, Edition, Publisher)
            #
            # Build author part if present
            $authorPart = ''
            if ($Authors -and ($Authors -join '').Trim().Length -gt 0) {
                $authorPart = $Authors -join ', '
            }

            # Build detail list in order: Year, Edition, Publisher
            $detailsList = @()
            if ($Year)      { $detailsList += $Year }
            if ($Edition)   { $detailsList += $Edition }
            if ($Publisher) { $detailsList += $Publisher }

            $detailsPart = ''
            if ($detailsList.Count -gt 0) {
                $detailsPart = " (" + ($detailsList -join ', ') + ")"
            }

            if ($authorPart) {
                $baseName = "$Title - $authorPart$detailsPart"
            }
            else {
                $baseName = "$Title$detailsPart"
            }
        }

        # Sanitize any invalid file-name characters
        $invalidChars = [System.IO.Path]::GetInvalidFileNameChars() |
            ForEach-Object { [Regex]::Escape($_) } |
            Join-String -Separator ''
        $pattern = "[$invalidChars]"
        $safeName = [Regex]::Replace($baseName, $pattern, '')
        $newName  = "$safeName$extension"

        if ($PSCmdlet.ShouldProcess($Item, "Rename to '$newName'")) {
            Rename-Item -Path $Item -NewName $newName
        }
    }
}
