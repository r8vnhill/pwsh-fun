<#
.SYNOPSIS
Applies a script block to each file in one or more directory trees, filtered by regular expressions.

.DESCRIPTION
`Invoke-FileTransform` recursively enumerates all files under the specified directories in `$Path`, filters them using regular expressions, and invokes a custom script block (`$FileProcessor`) for each matching file.

For every file found, the function passes:
1. The file as a `[System.IO.FileInfo]` object.
2. A header string with the full file path.

This function is ideal for processing, inspecting, transforming, or displaying file contents with fine-grained control over inclusion and exclusion patterns.

.PARAMETER Path
One or more root directories to search for files.
Each path must exist and be a directory.
Supports pipeline input and property binding.

.PARAMETER FileProcessor
A script block that is called for each matching file.
It receives two arguments:
1. The file as a [System.IO.FileInfo] object.
2. A string header containing the full path of the file.

.PARAMETER IncludeRegex
An array of regular expressions that determine which files to include.
Defaults to `'.*'`, which includes all files.

.PARAMETER ExcludeRegex
An array of regular expressions to exclude specific files.
Exclusion takes precedence over inclusion.

.EXAMPLE
Invoke-FileTransform -Path './src', './lib' -IncludeRegex '.*\.ps1$' -ExcludeRegex 'test/' -FileProcessor {
    param ($file, $header)
    Write-Host $header
    Get-Content $file -Raw
}

Processes all `.ps1` files under `./src` and `./lib`, excluding any paths matching `test/`, printing their paths and contents.

.EXAMPLE
'./scripts', './examples' | Invoke-FileTransform -IncludeRegex '.*\.ps1$' -ExcludeRegex 'experimental/' -FileProcessor {
    param ($file, $header)
    "$header`n$([IO.File]::ReadAllText($file.FullName))" | Set-Clipboard
}

Takes an array of paths from the pipeline and copies matching `.ps1` files (excluding those in `experimental/`) to the clipboard.

.EXAMPLE
Get-ChildItem -Path './projects' -Directory | Select-Object -ExpandProperty FullName |
    Invoke-FileTransform -IncludeRegex '.*\.md$' -FileProcessor {
        param ($file, $header)
        Write-Host "$header`n$($file.Length) bytes"
    }

Uses `Get-ChildItem` to collect directories dynamically and invokes the processor on all `.md` files, printing their size with a header.

.OUTPUTS
The output depends on the behavior of the `$FileProcessor` script block.

.NOTES
- Uses `Resolve-ValidDirectory` to validate that each path exists and is a directory.
- Uses `Get-FilteredFiles` to apply filtering rules based on include/exclude patterns.
- Pattern matching is applied to normalized relative paths (using forward slashes).
#>
function Invoke-FileTransform {
    [Alias('ift')]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Directory', 'Root', 'Folder')]
        [string[]]$Path,

        [Alias('Action', 'ProcessFile', 'Do')]
        [scriptblock]$FileProcessor = { $_ },

        [Alias('Include', 'IncludeFile', 'IncludePatterns', 'Like')]
        [string[]]$IncludeRegex = @('.*'),

        [Alias('Exclude', 'ExcludeFile', 'ExcludePatterns', 'NotLike')]
        [string[]]$ExcludeRegex = @()
    )

    process {
        foreach ($p in $Path) {
            $root = Resolve-ValidDirectory -Path $p -Cmdlet $PSCmdlet

            Get-FilteredFiles -RootPath $root `
                -IncludeRegex $IncludeRegex `
                -ExcludeRegex $ExcludeRegex |
                ForEach-Object {
                    $header = "File: $($_.FullName)"
                    & $FileProcessor $_ $header
                }
        }
    }
}

<#
.SYNOPSIS
    Recursively retrieves files under a root path, filtering them using include and exclude regular expressions.

.DESCRIPTION
    This function traverses a directory tree starting from the specified RootPath.
    It filters files based on inclusion and exclusion regex patterns applied to their relative paths.
    The traversal avoids descending into directories that are excluded by the ExcludeRegex patterns, improving performance on large file trees.

.INPUTS
    [string] Accepts the RootPath from the pipeline.

.OUTPUTS
    [System.IO.FileInfo] Objects representing the files that match the filters.

.EXAMPLE
    Get-FilteredFiles -RootPath "C:\Projects" -IncludeRegex '^src/.*\.cs$' -ExcludeRegex '^bin/'

    Returns all `.cs` files under the `src` directory, skipping any subdirectories that match `bin`.
#>
function Get-FilteredFiles {
    [CmdletBinding()]
    param (
        # The root directory path from which to begin recursive traversal.
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $RootPath,
        # An array of regular expressions used to include matching file paths.
        # Defaults to '.*' (include all files).
        [string[]] $IncludeRegex = @('.*'),
        # An array of regular expressions used to exclude matching file or folder paths.
        # Directories that match any of these patterns will not be traversed.
        [string[]] $ExcludeRegex = @()
    )

    begin {
        # Helper: Recursively traverse folders and yield matching files.
        function Get-FolderContent {
            param (
                [string] $CurrentPath
            )

            # Get all entries in the current directory
            $entries = Get-ChildItem `
                -Path $CurrentPath `
                -Force `
                -ErrorAction SilentlyContinue

            foreach ($entry in $entries) {
                if ($entry.PSIsContainer) {
                    # Compute the relative path of the directory
                    $relativeDir = $entry.FullName.Substring(
                        $RootPath.Length + 1
                    ).Replace('\', '/')

                    $isExcluded = $ExcludeRegex | Where-Object { $relativeDir -match $_ }

                    # Recurse only if not excluded
                    if (-not $isExcluded) {
                        Get-FolderContent -CurrentPath $entry.FullName
                    }
                } elseif ($entry -is [System.IO.FileInfo]) {
                    # Compute the relative path of the file
                    $relativePath = $entry.FullName.Substring(
                        $RootPath.Length + 1
                    ).Replace('\', '/')

                    # Apply inclusion/exclusion rules using an external predicate
                    if (ShouldIncludeFile `
                            -RelativePath $relativePath `
                            -IncludeRegex $IncludeRegex `
                            -ExcludeRegex $ExcludeRegex) {
                        $entry
                    }
                }
            }
        }
    }

    process {
        # Start traversal at the given root path
        Get-FolderContent -CurrentPath $RootPath
    }
}

<#
.SYNOPSIS
Validates that the specified path exists and is a directory.

.DESCRIPTION
`Resolve-ValidDirectory` checks whether the provided path exists and is a valid directory.
If the path does not exist, it throws a terminating `DirectoryNotFoundException` using the provided `$Cmdlet` context.
If the path exists but is not a directory, it throws an `InvalidDataException`.

This function is typically used to validate input for commands that expect a directory path.

.PARAMETER Path
The path to validate. Must point to an existing directory.

.PARAMETER Cmdlet
The `$PSCmdlet` context from the calling command, used to throw a terminating error if the path is invalid.

.OUTPUTS
Returns the resolved full path as a string if validation succeeds.

.EXAMPLE
PS> $resolved = Resolve-ValidDirectory -Path 'C:\Projects' -Cmdlet $PSCmdlet

Validates that `C:\Projects` exists and is a directory. Returns the resolved full path.

.NOTES
- Intended for internal use in commands that need to ensure directory input is valid before proceeding.
- Throws:
    System.IO.DirectoryNotFoundException:
    Thrown if the path does not exist.

    System.IO.InvalidDataException:
    Thrown if the path exists but is not a directory.
#>
function Resolve-ValidDirectory {
    param (
        [string]$Path,
        [System.Management.Automation.PSCmdlet]$Cmdlet
    )

    $resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        $err = [System.IO.DirectoryNotFoundException]::new("❌ Path '$Path' does not exist.")
        $record = [System.Management.Automation.ErrorRecord]::new(
            $err,
            'PathNotFound',
            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
            $Path
        )
        $Cmdlet.ThrowTerminatingError($record)
    }

    if (-not (Test-Path $resolvedPath.Path -PathType Container)) {
        throw [System.IO.InvalidDataException]::new("❌ Path '$Path' is not a directory.")
    }

    return $resolvedPath.Path
}

<#
.SYNOPSIS
Determines if a file path should be included based on include and exclude regex patterns.

.DESCRIPTION
`ShouldIncludeFile` checks whether the given relative file path matches at least one of the patterns in `IncludeRegex` and does not match any pattern in `ExcludeRegex`.

This function is intended to be used as an internal helper to support file filtering based on regex patterns within commands like `Invoke-FileTransform`.

.PARAMETER RelativePath
The relative path to the file being evaluated, normalized with forward slashes.

.PARAMETER IncludeRegex
An array of regular expressions used to determine which files should be included.
A file is included if it matches at least one pattern.

.PARAMETER ExcludeRegex
An array of regular expressions used to exclude files. If a file matches any of these patterns, it is excluded, even if it matched the include patterns.

.OUTPUTS
[bool] `True` if the file should be included, `False` otherwise.

.EXAMPLE
PS> ShouldIncludeFile -RelativePath 'src/module/file.ps1' `
>>>                          -IncludeRegex '.*\.ps1$' `
>>>                          -ExcludeRegex '^tests/'

Returns `$true` because the file matches the include pattern and does not match the exclude pattern.

.NOTES
This function uses .NET regular expressions and is scoped to the `` namespace for reuse in module internals.
#>
function ShouldIncludeFile {
    param (
        [string]$RelativePath,
        [string[]]$IncludeRegex,
        [string[]]$ExcludeRegex
    )

    $matchesInclude = $IncludeRegex | Where-Object { [Regex]::IsMatch($RelativePath, $_) }
    $matchesExclude = $ExcludeRegex | Where-Object { [Regex]::IsMatch($RelativePath, $_) }

    return $matchesInclude -and -not $matchesExclude
}
