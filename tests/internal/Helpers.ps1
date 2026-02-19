<#
.SYNOPSIS
Helper function for testing Invoke-FileTransform by capturing processed file paths.

.DESCRIPTION
`Get-InvokedFilePathsForTest` invokes the [Invoke-FileTransform] function with the given directory path and optional inclusion and exclusion regular expressions.

Instead of performing any processing on the files, this stub collects the full paths of the files passed to the file processor and stores them in the `$script:invoked` variable.
This makes it useful in Pester tests for asserting which files were matched.

.PARAMETER Path
The root directory to search for files. Must be an existing directory.

.PARAMETER IncludeRegex
An array of regular expressions used to filter which files should be included.
Defaults to `'.*'`, meaning all files are included unless excluded.

.PARAMETER ExcludeRegex
An array of regular expressions used to exclude files from processing.
If a file matches any of these patterns, it will be excluded even if it also matches an include pattern.

.OUTPUTS
None. The function populates the `$script:invoked` variable with the matched file paths.

.EXAMPLE
PS> $acc = Get-InvokedFilePathsForTest -Path './src' -IncludeRegex '.*\.ps1$'

Collects all `.ps1` files in `./src`, storing their full paths in `$acc`.

.NOTES
This is an internal utility for tests and is not intended for general use.
#>
function Get-InvokedFilePathsForTest {
    param (
        [string]$Path,
        [string[]]$IncludeRegex = @('.*'),
        [string[]]$ExcludeRegex = @()
    )

    $acc = [System.Collections.Generic.List[string]]::new()

    Invoke-FileTransform -Path $Path `
        -IncludeRegex $IncludeRegex `
        -ExcludeRegex $ExcludeRegex `
        -FileProcessor {
        param ($file, $header)
        $acc.Add($file.FullName)
    }

    return $acc.ToArray()
}

<#
.SYNOPSIS
Creates a temporary test directory with a simple file structure.

.DESCRIPTION
`New-TestDirectoryWithFiles` creates a temporary directory structure under the system's `$env:TEMP` path for use in file-related tests.
It includes:
- A base directory (default: `TestFiles`)
- A subdirectory (`sub`)
- Two text files: `file1.txt` in the base and `file2.txt` in the subdirectory

If the base directory already exists, it is removed and recreated to ensure a clean test environment.

.PARAMETER BaseName
The name of the base directory to create under `$env:TEMP`.
Defaults to `'TestFiles'`.

.OUTPUTS
A hashtable containing the paths of the created directories and files:
- `Base`: Full path to the base directory
- `File1`: Full path to `file1.txt`
- `File2`: Full path to `file2.txt`

.EXAMPLE
PS> $newTestDir = New-TestDirectoryWithFiles -BaseName 'MyTest'

Creates `C:\Users\user\AppData\Local\Temp\MyTest` with two text files and returns their paths.

.NOTES
Intended for use in automated testing to provide a reliable file system sandbox.
#>
function New-TestDirectoryWithFiles {
    param (
        [string]$BaseName = 'TestFiles'
    )

    $base = Join-Path $env:TEMP $BaseName
    $sub = Join-Path $base 'sub'
    Remove-Item $base -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -Path $sub -ItemType Directory -Force | Out-Null

    $f1 = Join-Path $base 'file1.txt'
    $f2 = Join-Path $sub 'file2.txt'
    New-Item -Path $f1 -ItemType File -Force | Out-Null
    New-Item -Path $f2 -ItemType File -Force | Out-Null

    return @{
        Base  = $base
        Sub   = $sub
        File1 = $f1
        File2 = $f2
    }
}

<#
.SYNOPSIS
Cleans up a test environment by removing temporary files and unloading test modules.

.DESCRIPTION
`Remove-TestEnvironment` is intended for use in test suites.
It deletes a temporary directory and unloads modules that were loaded during testing, but only if they weren't already loaded before the test started.

Useful in `AfterAll` blocks to restore a clean state between test sessions.

.PARAMETER TempDir
The full path to the temporary directory to delete.
The directory and all its contents will be removed.

.PARAMETER PreloadedModules
A collection of modules that were already loaded before the test began.
Modules listed in `ModuleNames` that are not found in this list will be removed after the test finishes.

.PARAMETER ModuleNames
The names of modules to remove if they were not preloaded. Defaults to `'Assertions'` and `'Fun.Files'`.

.EXAMPLE
PS> Remove-TestEnvironment -TempDir $script:tempDir -PreloadedModules $script:preloadedModules

Cleans up `$script:tempDir` and removes any modules that were loaded for the test but not preloaded by the user.

.NOTES
This function is designed to be idempotent and safe to call during cleanup. It will not throw if the directory or modules do not exist.
#>
function Remove-TestEnvironment {
    param (
        [string]$TempDir,
        [PSModuleInfo[]]$PreloadedModules,
        [string[]]$ModuleNames
    )

    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue

    foreach ($modName in $ModuleNames) {
        $wasPreloaded = $PreloadedModules | Where-Object { $_.Name -eq $modName }
        if (-not $wasPreloaded) {
            Remove-Module -Name $modName -ErrorAction SilentlyContinue
        }
    }
}

<#
.SYNOPSIS
    Builds a full filesystem path from a start directory and one or more relative parts.

.DESCRIPTION
    Combines a base path (-Start) with a sequence of path segments (-Parts), normalizes
    the result to a full absolute path, and optionally verifies that the resolved path
    exists.

    - Skips empty/null parts.
    - Rejects rooted/absolute parts unless -AllowAbsoluteParts is specified.
    - Uses fast .NET APIs for combination/normalization.
    - When validating existence, uses Test-Path -LiteralPath (no wildcard expansion).

.PARAMETER Start
    Base directory (can be relative or absolute). Will be normalized to an absolute path
    before combining parts.

.PARAMETER Parts
    One or more relative path segments to append. Empty/null items are ignored.
    By default, absolute segments are rejected to avoid accidentally resetting the base.

.PARAMETER AllowAbsoluteParts
    Allow absolute segments in -Parts. If present, the first absolute segment resets the
    base for subsequent segments (like Join-Path behavior).

.PARAMETER RequireExists
    If supplied, throws when the final path does not exist.

.PARAMETER PathType
    When -RequireExists is used, the expected type of the final path. 'Any' (default),
    'Leaf' (file) or 'Container' (directory).

.OUTPUTS
    [string]

.EXAMPLE
    Resolve-RelativePath -Start $PSScriptRoot -Parts @('..','..','modules')
    # -> Full absolute path to the "modules" folder, two levels up.

.EXAMPLE
    Resolve-RelativePath -Start '.' -Parts 'data','input.json' -RequireExists `
        -PathType Leaf
    # -> Verifies the path exists and is a file.
#>
function Resolve-RelativePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Start,

        [Parameter()]
        [string[]] $Parts = @(),

        [Parameter()]
        [switch] $AllowAbsoluteParts,

        [Parameter()]
        [switch] $RequireExists,

        [Parameter()]
        [ValidateSet('Any', 'Leaf', 'Container')]
        [string] $PathType = 'Any'
    )

    begin {
        Set-StrictMode -Version Latest
        function Test-FinalPath {
            param([string] $p, [string] $type)
            $typeSwitch = switch ($type) {
                'Leaf' { @{ PathType = 'Leaf' } }
                'Container' { @{ PathType = 'Container' } }
                default { @{} }
            }
            Test-Path -LiteralPath $p @typeSwitch
        }
    }

    process {
        # Normalize base; .NET GetFullPath uses current directory if Start is relative.
        $base = [System.IO.Path]::GetFullPath($Start)

        # Combine parts in order; reject rooted segments unless allowed.
        $current = $base
        foreach ($part in $Parts) {
            if ([string]::IsNullOrWhiteSpace($part)) { continue }

            if (-not $AllowAbsoluteParts -and [System.IO.Path]::IsPathRooted($part)) {
                throw @(
                    "Resolve-RelativePath: Part '$part' is an absolute path.",
                    "Pass -AllowAbsoluteParts to permit resetting the base."
                ) -join "`n"
            }

            $current = [System.IO.Path]::Combine($current, $part)
        }

        # Normalize again to collapse "..", ".", etc.
        $final = [System.IO.Path]::GetFullPath($current)

        if ($RequireExists) {
            if (-not (Test-FinalPath -p $final -type $PathType)) {
                $msg = if ($PathType -eq 'Any') {
                    "Path does not exist: '$final'."
                } else {
                    "Expected a $PathType at: '$final', but it was not found."
                }
                throw $msg
            }
        }

        return $final
    }
}

<#
.SYNOPSIS
    Resolves the absolute path to the repository-level 'modules' folder.

.DESCRIPTION
    Convenience wrapper that resolves "..\..\modules" relative to the current module's
    root ($PSScriptRoot). Throws if the folder does not exist.

.OUTPUTS
    [string]
#>
function Resolve-ModulesPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    Resolve-RelativePath -Start $PSScriptRoot -Parts @('..', '..', 'modules') `
        -RequireExists -PathType Container
}
