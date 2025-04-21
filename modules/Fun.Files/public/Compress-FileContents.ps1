function Compress-FileContents {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [Alias('Directory', 'Root', 'Folder')]
        [string[]]$Path,

        [Parameter(Mandatory, Position = 1)]
        [string]$DestinationZip,

        [Alias('Include', 'IncludeFile', 'IncludePatterns', 'Like')]
        [string[]]$IncludeRegex = @('.*'),

        [Alias('Exclude', 'ExcludeFile', 'ExcludePatterns', 'NotLike')]
        [string[]]$ExcludeRegex = @()
    )

    $filesToZip = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

    Invoke-FileTransform -Path $Path `
        -IncludeRegex $IncludeRegex `
        -ExcludeRegex $ExcludeRegex `
        -FileProcessor {
            param ($file, $header)
            $filesToZip.Add($file)
        }

    # Create zip archive
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipPath = Resolve-Path -LiteralPath $DestinationZip -ErrorAction SilentlyContinue
    if ($zipPath) { Remove-Item $DestinationZip -Force }

    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        (Split-Path $filesToZip[0].FullName -Parent),
        $DestinationZip,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )

    # Manually add files (filtered ones only)
    $zip = [System.IO.Compression.ZipFile]::Open($DestinationZip, 'Update')
    foreach ($file in $filesToZip) {
        $entryPath = $file.FullName.Substring((Split-Path $file.Directory.FullName -Parent).Length + 1)
        $entryPath = $entryPath -replace '\\', '/'
        $zip.CreateEntryFromFile($file.FullName, $entryPath) | Out-Null
    }
    $zip.Dispose()

    return $DestinationZip
}
