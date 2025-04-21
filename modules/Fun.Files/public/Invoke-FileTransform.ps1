<#
.SYNOPSIS
Applies a script block to each file in a directory tree, filtered by regular expressions.

.DESCRIPTION
`Invoke-FileTransform` recursively enumerates all files under the specified `$Path`, filters them using regular expressions, and invokes a custom script block (`$FileProcessor`) for each file.

Each file is passed along with a formatted header containing its full path.
This function is useful for performing transformations, inspections, or reporting on selected files.

.PARAMETER Path
The root directory to search for files.
The path must exist and be a directory.

.PARAMETER FileProcessor
A script block that is called for each matching file.
Receives two arguments:
1. The file as a [System.IO.FileInfo] object
2. A header string containing the full path of the file

.PARAMETER IncludeRegex
An array of regular expressions to determine which files to include.
Defaults to `'.*'`, which includes all files.

.PARAMETER ExcludeRegex
An array of regular expressions to exclude specific files.
Exclusions take precedence over inclusions.

.EXAMPLE
Invoke-FileTransform -Path './src' -IncludeRegex '.*\.ps1$' -ExcludeRegex 'test/' -FileProcessor {
    param ($file, $header)
    Write-Host $header
    Get-Content $file -Raw
}

Processes all `.ps1` files under `./src` except those in `test/`, printing their path and contents.

.OUTPUTS
Depends on the behavior of the `$FileProcessor` script block.

.NOTES
- Uses `Resolve-ValidDirectory` to validate that the path exists and is a directory.
- Uses `Get-FilteredFiles` internally to apply inclusion and exclusion filters.
- Path matching is performed on normalized relative paths (with `/` separators).
#>
function Invoke-FileTransform {
    [Alias('ift')]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('Directory', 'Root', 'Folder')]
        [string]$Path,

        [Alias('Action', 'ProcessFile', 'Do')]
        [scriptblock]$FileProcessor = { $_ },

        [string[]]$IncludeRegex = @('.*'),

        [string[]]$ExcludeRegex = @()
    )

    $root = Resolve-ValidDirectory -Path $Path -Cmdlet $PSCmdlet

    Get-FilteredFiles -RootPath $root `
        -IncludeRegex $IncludeRegex `
        -ExcludeRegex $ExcludeRegex `
    | ForEach-Object {
        $header = "`nFile: $($_.FullName)"
        & $FileProcessor $_ $header
    }
}

<#
.SYNOPSIS
Recursively returns files under a root path that match inclusion and exclusion regex patterns.

.DESCRIPTION
`Get-FilteredFiles` enumerates all files under the specified `$RootPath` and returns only those whose relative paths match at least one of the provided `$IncludeRegex` patterns and none of the `$ExcludeRegex` patterns.

It is designed to support advanced file filtering using regular expressions and is typically used as a helper for file-processing commands.

.PARAMETER RootPath
The root directory to search for files. The path must exist and be a directory.

.PARAMETER IncludeRegex
An array of regular expressions to determine which files should be included.
Relative paths are matched against these expressions.

.PARAMETER ExcludeRegex
An array of regular expressions to exclude files.
Relative paths are matched against these expressions. Exclusions take precedence over inclusions.

.OUTPUTS
A list of [System.IO.FileInfo] objects for all matching files.

.EXAMPLE
PS> Get-FilteredFiles -RootPath './src' -IncludeRegex '.*\.ps1$' -ExcludeRegex 'tests/'

Returns all `.ps1` files in `./src`, excluding those under a `tests/` subdirectory.

.NOTES
- Paths are normalized by replacing backslashes (`\`) with forward slashes (`/`) before matching.
- Intended for internal use in file transformation or inspection tools.
#>
function Get-FilteredFiles {
    param (
        [string]$RootPath,
        [string[]]$IncludeRegex,
        [string[]]$ExcludeRegex
    )

    Get-ChildItem -Path $RootPath -File -Recurse | Where-Object {
        $relativePath = $_.FullName.Substring($RootPath.Length + 1).Replace('\', '/')
        ShouldIncludeFile -RelativePath $relativePath `
            -IncludeRegex $IncludeRegex `
            -ExcludeRegex $ExcludeRegex
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
