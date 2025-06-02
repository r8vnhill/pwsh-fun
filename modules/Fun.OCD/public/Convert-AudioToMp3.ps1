function Convert-AudioToMp3 {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # Path to the directory containing audio files
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string] $Path,
        # Extensions of audio files to convert
        [string[]] $Extensions = @('.opus', '.m4a', '.flac', '.ogg', '.wav', '.aiff', '.aac'),
        # Output bitrate for the mp3 files
        [ValidateNotNullOrEmpty()]
        [string] $OutputBitrate = '320k',
        # Whether to recurse into subdirectories
        [switch] $Recurse,
        # Whether to clean up original files after conversion
        [switch] $Cleanup
    )

    $audioFiles = Get-AudioFiles -Path $Path -Extensions $Extensions -Recurse:$Recurse

    if (-not $audioFiles) {
        Write-Information "No supported audio files ($($Extensions -join ', ')) found in '$Path'."
        return
    }

    $total = $audioFiles.Count
    $index = 0

    foreach ($file in $audioFiles) {
        $index++
        Write-Progress `
            -Activity 'Converting to .mp3' `
            -Status "$($file.Name)" `
            -PercentComplete (($index / $total) * 100)

        try {
            Convert-ToMp3 -File $file -Bitrate $OutputBitrate -Cleanup:$Cleanup -PSCmdlet $PSCmdlet
        } catch {
            Write-Warning "Failed to convert: $($file.FullName) - $($_.Exception.Message)"
        }
    }

    Write-Information "Conversion complete. Processed $total files."
}

function Get-AudioFiles {
    param (
        [string] $Path,
        [string[]] $Extensions,
        [switch] $Recurse
    )
    $extensionsSet = $Extensions | ForEach-Object { $_.ToLowerInvariant() }
    $allFiles = Get-ChildItem -Path $Path -File -Recurse:$Recurse
    return $allFiles | Where-Object { $extensionsSet -contains $_.Extension.ToLowerInvariant() }
}

function Convert-ToMp3 {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, Position = 0)]
        [System.IO.FileInfo] $File,

        [Parameter(Mandatory, Position = 1)]
        [string] $Bitrate,

        [switch] $Cleanup,

        [string] $OutputExtension = '.mp3'
    )

    if (-not $PSCmdlet.ShouldProcess($File.FullName, "Convert to $OutputExtension")) {
        return
    }
    
    $outputFile = [System.IO.Path]::ChangeExtension($File.FullName, $OutputExtension)

    try {
        $outputFile | Assert-FileNotExists

        Write-Verbose "Converting: '$($File.FullName)' -> '$outputFile'"

        $ffmpegArgs = Get-FfmpegArgs 

        # Run ffmpeg and stream output to console (stdout/stderr) by default
        try {
            & ffmpeg @ffmpegArgs 2>&1 | ForEach-Object {
                if ($_ -match '^\[.*error.*\]') {
                    Write-Error $_
                } else {
                    Write-Verbose $_
                }
            }

            if ($LASTEXITCODE -eq 0) {
                Write-Verbose "Successfully converted '$($File.Name)'"

                if ($Cleanup -and (Test-Path -LiteralPath $outputFile)) {
                    if ($PSCmdlet.ShouldProcess($File.FullName, 'Delete original file')) {
                        Remove-Item -LiteralPath $File.FullName -Force
                        Write-Verbose "Deleted original: '$($File.FullName)'"
                    }
                }
            } else {
                Write-Warning "Conversion failed for '$($File.FullName)' (exit code $LASTEXITCODE)"
            }
        } catch {
            Write-Error "Exception while converting '$($File.FullName)': $_"
        }
    } catch {
        return
    }
}

function Assert-FileNotExists {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [Alias('Path')]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath
    )

    process {
        if (-not (Test-Path -LiteralPath $LiteralPath)) { return }

        Write-Verbose "Skipping: '$LiteralPath' already exists."
        throw [System.IO.IOException] "File already exists: '$LiteralPath'"
    }
}

function Get-LogLevel {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        # Debug switch to determine log level 
        [switch] $DebugPreference,
        # Verbose switch to determine log level
        [switch] $VerbosePreference,
        # Default log level if neither Debug nor Verbose is set
        [ValidateSet(
            'quiet', 'panic', 'fatal', 'error', 'warning', 'info', 'verbose', 'debug',
            'trace'
        )]
        [string] $DefaultLevel = 'info'
    )

    if ($DebugPreference.IsPresent) {
        return 'debug'
    } elseif ($VerbosePreference.IsPresent) {
        return 'verbose'
    }

    return $DefaultLevel
}

function Get-FfmpegArgs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [System.IO.FileInfo] $File,

        [Parameter(Position = 1)]
        [string] $Bitrate = '320k'
    )
    throw [System.NotImplementedException] "TODO: Missing parameters; input validation; etc."
    return @(
        '-loglevel', (Get-LogLevel)
        '-y'
        '-i', $File.FullName
        '-b:a', $Bitrate
        $outputFile
    )
}
