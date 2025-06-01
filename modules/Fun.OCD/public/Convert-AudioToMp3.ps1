function Convert-AudioToMp3 {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string] $Path,

        [string[]] $Extensions = @('.opus', '.m4a'),

        [ValidateNotNullOrEmpty()]
        [string] $OutputBitrate = '320k',

        [switch] $Recurse
    )

    $extensionsSet = $Extensions | ForEach-Object { $_.ToLowerInvariant() }
    $allFiles = Get-ChildItem -Path $Path -File -Recurse:$Recurse
    $audioFiles = $allFiles | Where-Object {
        $extensionsSet -contains $_.Extension.ToLowerInvariant()
    }

    if (-not $audioFiles) {
        Write-Information `
            "No supported audio files ($($Extensions -join ', ')) found in '$Path'."
        return
    }

    $total = $audioFiles.Count
    $index = 0

    foreach ($file in $audioFiles) {
        $index++
        $outputFile = [System.IO.Path]::ChangeExtension($file.FullName, '.mp3')

        if (Test-Path $outputFile) {
            Write-Verbose "Skipping: $outputFile already exists."
            continue
        }

        Write-Progress `
            -Activity "Converting to .mp3" `
            -Status "$($file.Name)" `
            -PercentComplete (($index / $total) * 100)

        try {
            if ($PSCmdlet.ShouldProcess($file.FullName, "Convert to MP3")) {
                & ffmpeg -y -i $file.FullName -b:a $OutputBitrate $outputFile 2>$null
                Write-Verbose "Converted: $($file.FullName) -> $outputFile"
            }
        }
        catch {
            Write-Warning "Failed to convert: $($file.FullName) - $($_.Exception.Message)"
        }
    }

    Write-Information "Conversion complete. Processed $total files."
}
