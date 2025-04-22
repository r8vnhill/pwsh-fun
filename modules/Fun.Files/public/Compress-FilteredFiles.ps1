<#
.SYNOPSIS
Compresses selected files from one or more directories into a zip archive, using filtering.

.DESCRIPTION
`Compress-FilteredFiles` recursively traverses one or more input directories and creates a `.zip` archive with files that match a set of inclusion and exclusion regular expressions.
File paths are preserved relative to their input roots.

This function is suitable for archiving filtered content, exporting source code, or building custom packages in automated scripts.
It supports verbose/debug output and `-WhatIf`/`-Confirm` scenarios via `SupportsShouldProcess`.

The function supports pipeline input for `-Path`, accumulating values across invocations and emitting the resulting zip path once.

.PARAMETER Path
One or more directories to scan. Accepts pipeline input.
Paths are resolved to full filesystem paths and treated as root anchors for relative structure.

.PARAMETER DestinationZip
The path to the zip archive to create. Must end with `.zip`.
If the file already exists, it will be removed and replaced unless `-WhatIf` is specified.

.PARAMETER IncludeRegex
An array of regular expressions that determine which files to include.
Matches are evaluated against normalized relative paths.
Defaults to `'.*'` (all files).

.PARAMETER ExcludeRegex
An array of regular expressions that determine which files to exclude.
These override any matches from `IncludeRegex`.

.OUTPUTS
[string] The full path of the created zip file, or `$null` if no files matched.

.EXAMPLE
PS> Compress-FilteredFiles -Path './src' -DestinationZip 'output.zip'

Compresses all files under `./src` into `output.zip`.

.EXAMPLE
PS> Compress-FilteredFiles -Path './modules' -DestinationZip 'archive.zip' `
>>>     -IncludeRegex '.*\.ps1$', '.*\.psm1$' `
>>>     -ExcludeRegex '.*\/tests\/.*'

Compresses `.ps1` and `.psm1` files under `./modules`, excluding those in a `tests` folder.

.EXAMPLE
PS> './src', './lib' | Compress-FilteredFiles -DestinationZip 'combined.zip'

Combines files from both `./src` and `./lib` into `combined.zip`, preserving relative paths.

.EXAMPLE
PS> Compress-FilteredFiles -Path './src' -DestinationZip 'src.zip' -WhatIf

Simulates the compression operation without writing any files.

.NOTES
- Uses `Get-FilesToZip`, `Initialize-ZipTarget`, and `Add-FilesToZip` internally.
- Preserves relative paths from each root directory.
- Supports `-WhatIf`, `-Confirm`, `-Verbose`, and `-Debug`.
- Compatible with CI/CD workflows where selective archiving is needed.
#>
function Compress-FilteredFiles {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([string])]
    [Alias('cmff')]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [Alias('Directory', 'Root', 'Folder')]
        [string]$Path,

        [Parameter(Mandatory, Position = 1)]
        [ValidateScript({ $_.EndsWith('.zip') })]
        [string]$DestinationZip,

        [ValidateScript({ $null -ne ($_ | ForEach-Object { [regex]::new($_) }) })]
        [Alias('Include', 'IncludeFile', 'IncludePatterns', 'Like')]
        [string[]]$IncludeRegex = @('.*'),

        [ValidateScript({ $null -ne ($_ | ForEach-Object { [regex]::new($_) }) })]
        [Alias('Exclude', 'ExcludeFile', 'ExcludePatterns', 'NotLike')]
        [string[]]$ExcludeRegex = @()
    )

    begin {
        $allPaths = [System.Collections.Generic.List[string]]::new()
    }

    process {
        $Path | ForEach-Object { $allPaths.Add($_) }
    }

    end {
        if ($PSCmdlet.ShouldProcess($DestinationZip, 'Create archive with filtered files')) {
            $DestinationZip = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestinationZip)
            Write-Verbose "📦 Starting compression for path(s): $($allPaths -join ', ')"
            Write-Verbose "🎯 Destination: $DestinationZip"
            Write-Debug   "Include patterns: $($IncludeRegex -join ', ')"
            Write-Debug   "Exclude patterns: $($ExcludeRegex -join ', ')"

            $files = Get-FilesToZip -Path $allPaths `
                -IncludeRegex $IncludeRegex `
                -ExcludeRegex $ExcludeRegex `
                -Verbose:$VerbosePreference `
                -Debug:$DebugPreference

            if ($files.Count -eq 0) {
                Write-Warning '⚠️ No files matched the filters. Nothing to compress.'
                return $null
            }

            Write-Verbose "📁 Total files to zip: $($files.Count)"

            Initialize-ZipTarget -DestinationZip $DestinationZip
            Add-FilesToZip -Files $files `
                -DestinationZip $DestinationZip `
                -Verbose:$VerbosePreference `
                -Debug:$DebugPreference

            Write-Verbose "✅ Archive created: $DestinationZip"
        }

        # Only emit result once when invoked as a non-streaming command
        if ($allPaths.Count -gt 0 -and -not $PSCmdlet.MyInvocation.ExpectingInput) {
            return $DestinationZip
        }
    }
}

<#
.SYNOPSIS
Returns a list of files matching the specified filters along with their root paths.

.DESCRIPTION
`Get-FilesToZip` resolves each given path to its absolute file system path, then recursively enumerates files matching the specified inclusion and exclusion patterns.
Each result is returned as a `[ZipFileEntry]` instance containing the file and the root it was matched from.

This function is typically used when compressing files while maintaining their relative paths within the archive.

.PARAMETER Path
One or more root directories to scan for matching files.
Each path is resolved to its full provider path.

.PARAMETER IncludeRegex
An array of regular expressions to include files whose relative paths match any of the given patterns.
Defaults to `'.*'` (all files).

.PARAMETER ExcludeRegex
An array of regular expressions to exclude files whose relative paths match any of the given patterns.
Exclusions override inclusions.

.OUTPUTS
[System.Collections.Generic.List[ZipFileEntry]]
Each object contains:
- `File` ([System.IO.FileInfo]): The matched file.
- `Root` ([string]): The resolved root directory that the file was discovered under.

.EXAMPLE
PS> Get-FilesToZip -Path './src', './lib' -IncludeRegex '.*\.ps1$' -ExcludeRegex 'test/'

Returns all `.ps1` files under `./src` and `./lib`, excluding those matching `test/`, along with their root paths.

.NOTES
- Uses `Invoke-FileTransform` internally for traversal and filtering.
- Designed to support zip operations where relative paths are based on the original root.
#>
function Get-FilesToZip {
    [OutputType([System.Collections.Generic.List[ZipFileEntry]])]
    [CmdletBinding()]
    param (
        [string[]]$Path,
        [string[]]$IncludeRegex,
        [string[]]$ExcludeRegex
    )

    $files = [System.Collections.Generic.List[ZipFileEntry]]::new()

    foreach ($root in $Path) {
        $resolvedRoot = (Resolve-Path -LiteralPath $root).ProviderPath
        Invoke-FileTransform -Path $resolvedRoot `
            -IncludeRegex $IncludeRegex `
            -ExcludeRegex $ExcludeRegex `
            -FileProcessor {
            param ($file, $header)
            Write-Debug "✅ Queued file: $($file.FullName)"
            $files.Add([ZipFileEntry]::new($file, $resolvedRoot))
        }
    }

    return $files
}

<#
.SYNOPSIS
Prepares a ZIP file target by removing any existing archive at the destination path.

.DESCRIPTION
`Initialize-ZipTarget` ensures that the specified ZIP archive path is ready to be used for compression.
If a file already exists at the given destination, it is removed.

The function resolves the path to its absolute file system location and returns it.
This is useful for subsequent calls to compression functions that require an empty ZIP archive.

.PARAMETER DestinationZip
The path to the destination ZIP file.
Must not be null or empty.
Can be relative or absolute.

.OUTPUTS
[string] The resolved full file system path of the destination ZIP file.

.EXAMPLE
PS> $zipPath = Initialize-ZipTarget -DestinationZip './output/archive.zip' -Verbose

Ensures `archive.zip` in the `./output/` folder does not already exist, then returns its absolute path.

.NOTES
- This function loads the necessary .NET compression assemblies if not already loaded.
- This function does not create the ZIP file—it only ensures the path is clean.
#>
function Initialize-ZipTarget {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationZip
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Add-Type -AssemblyName System.IO.Compression

    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
        $DestinationZip
    )

    if (Test-Path -LiteralPath $resolved) {
        if ($PSCmdlet.ShouldProcess($resolved, 'Remove existing archive')) {
            Write-Verbose "🗑 Removing existing archive at: $resolved"
            Remove-Item -LiteralPath $resolved -Force
        }
    }

    return $resolved
}

<#
.SYNOPSIS
Adds a list of files to a ZIP archive, preserving their relative paths.

.DESCRIPTION
`Add-FilesToZip` takes a collection of [ZipFileEntry] objects—each containing a file and its root directory— and compresses them into a ZIP archive at the specified destination path.
Each file is added using a relative path derived from its root to maintain directory structure inside the archive.

If the target ZIP archive does not already exist, it is created.

.PARAMETER Files
A list of [ZipFileEntry] objects.
Each entry contains:
- `File`: A [System.IO.FileInfo] representing the file to be compressed.
- `Root`: A [string] representing the root directory from which the relative path will be computed.

.PARAMETER DestinationZip
The target path for the ZIP archive. Must end with `.zip`.
If a file already exists at this path, the function will add to it in "Update" mode; otherwise, it creates a new archive.

.OUTPUTS
[void] This function does not return output but modifies the ZIP file as a side effect.

.EXAMPLE
PS> $files = Get-FilesToZip -Path './src' -IncludeRegex '.*\.ps1$'
PS> Add-FilesToZip -Files $files -DestinationZip 'output.zip'

Compresses all `.ps1` files from `./src`, maintaining their relative paths, into `output.zip`.

.NOTES
- This function requires the `System.IO.Compression.FileSystem` and `System.IO.Compression` assemblies.
- Use in conjunction with `Get-FilesToZip` and `ZipFileEntry` for structured and reproducible file zipping.
#>
function Add-FilesToZip {
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [System.Collections.Generic.List[ZipFileEntry]]$Files,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationZip
    )

    if (-not (Test-Path $DestinationZip)) {
        [System.IO.Compression.ZipFile]::Open($DestinationZip, 'Create').Dispose()
    }

    $zip = [System.IO.Compression.ZipFile]::Open($DestinationZip, 'Update')

    foreach ($entry in $Files) {
        $file = $entry.File
        $root = $entry.Root

        $rootFolderName = Split-Path -Path $root -Leaf
        $relativePath = Join-Path $rootFolderName (
            $file.FullName.Substring($root.Length + 1)
        ) -Resolve:$false
        $relativePath = $relativePath -replace '\\', '/'

        Write-Verbose "📄 Adding file: $($file.FullName)"
        Write-Debug   "→ Archive entry path: $relativePath"

        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip,
            $file.FullName,
            $relativePath
        ) | Out-Null
    }

    $zip.Dispose()
}

<#
.SYNOPSIS
Represents a file selected for compression along with its root path.

.DESCRIPTION
The `ZipFileEntry` class is used to track individual files matched for inclusion in an archive, preserving the root directory from which each file was discovered.

This is useful when creating zip archives while maintaining the relative path structure of each file.

Each instance stores:
- The original file as a `[System.IO.FileInfo]` object
- The resolved root path as a `[string]`, used to compute relative paths for the archive

The class overrides `ToString()` to provide a human-readable representation of the entry.

.CONSTRUCTORS
ZipFileEntry([System.IO.FileInfo]$File, [string]$Root)

.EXAMPLE
PS> $entry = [ZipFileEntry]::new((Get-Item './src/module.ps1'), (Resolve-Path './src'))
PS> $entry.ToString()
C:\path\to\src\module.ps1 (from: C:\path\to\src)

.OUTPUTS
[ZipFileEntry]

.NOTES
Used internally by compression functions such as `Compress-FilteredFiles` to maintain relative path integrity in the archive.
#>
class ZipFileEntry {
    [System.IO.FileInfo]$File
    [string]$Root

    ZipFileEntry([System.IO.FileInfo]$File, [string]$Root) {
        $this.File = $File
        $this.Root = $Root
    }

    [string] ToString() {
        return "[ZipEntry] $($this.File.FullName) (from: $($this.Root))"
    }
}
