function Convert-OpusToMp3 {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string] $Path,

        [switch] $Recurse,

        [ValidateNotNullOrEmpty()]
        [string] $OutputBitrate = '192k'
    )

    $searchOption = if ($Recurse) { '-Recurse' } else { '' }
    $opusFiles = Get-ChildItem -Path $Path -Filter '*.opus' @searchOption -File

    if (-not $opusFiles) {
        Write-Host "No .opus files found in '$Path'."
        return
    }

    $total = $opusFiles.Count
    $index = 0

    foreach ($file in $opusFiles) {
        $index++
        $outputFile = [System.IO.Path]::ChangeExtension($file.FullName, '.mp3')

        Write-Progress -Activity "Converting .opus to .mp3" -Status "$($file.Name)" -PercentComplete (($index / $total) * 100)

        try {
            & ffmpeg -y -i $file.FullName -b:a $OutputBitrate $outputFile 2>$null
            Write-Verbose "Converted: $($file.FullName) -> $outputFile"
        }
        catch {
            Write-Warning "Failed to convert: $($file.FullName) - $($_.Exception.Message)"
        }
    }

    Write-Host "Conversion complete. Processed $total files."
}
