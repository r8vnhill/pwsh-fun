<#
.SYNOPSIS
Copies the contents of matching files to the system clipboard with formatted headers.

.DESCRIPTION
`Copy-FileContents` recursively searches one or more directories, filters files based on regular expressions, reads their content, and copies the formatted result to the clipboard.

Each file is represented with a header line and its full text content.
This is useful for preparing snippets, debugging, or pasting into documentation or issue trackers.

This function supports both direct and piped directory input.
Clipboard writing occurs only once after all paths are processed.

.PARAMETER Path
One or more root directories to scan.
Each must exist and be a valid directory.
Accepts pipeline input and property binding.

.PARAMETER IncludeRegex
An array of regular expressions used to select which files to include.
Defaults to `'.*'` (all files).

.PARAMETER ExcludeRegex
An array of regular expressions to exclude files. Exclusion overrides inclusion.

.OUTPUTS
[string[]] The list of formatted file contents that was copied to the clipboard.

.EXAMPLE
PS> Copy-FileContents -Path './src', './lib' -IncludeRegex '.*\.ps1$'

Copies all `.ps1` files from the `src` and `lib` directories to the clipboard with headers.

.EXAMPLE
PS> './docs', './samples' | Copy-FileContents

Scans both directories from the pipeline and copies their contents.

.EXAMPLE
PS> Copy-FileContents -Path './notes' -ExcludeRegex '^archive/'

Copies files from `./notes` but skips any under `archive/`.

.NOTES
- Internally uses `Get-FileContents` for traversal and formatting.
- Uses ANSI escape sequences if supported by terminal (for related functions like `Show-FileContents`).
- Works in multi-pass scenarios by accumulating all input in `begin`/`process`/`end`.
#>
function Copy-FileContents {
    [Alias('cfc')]
    [OutputType([string[]])]
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Directory', 'Root', 'Folder')]
        [string[]]$Path = @('.'),

        [Alias('Include', 'IncludeFile', 'IncludePatterns', 'Like')]
        [string[]]$IncludeRegex = @('.*'),

        [Alias('Exclude', 'ExcludeFile', 'ExcludePatterns', 'NotLike')]
        [string[]]$ExcludeRegex = @()
    )

    begin {
        $allPaths = [System.Collections.Generic.List[string]]::new()
    }

    process {
        $Path | ForEach-Object {
            $allPaths.Add($_)
        }
    }

    end {
        $rendered = Get-FileContents -Path $allPaths `
            -IncludeRegex $IncludeRegex `
            -ExcludeRegex $ExcludeRegex |
            ForEach-Object { "$($_.Header)`n$($_.ContentText)`n" }

        $rendered | Set-Clipboard
        return $rendered
    }
}
