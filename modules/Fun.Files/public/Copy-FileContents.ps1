<#
.SYNOPSIS
Copies the formatted contents of matching files to the system clipboard.

.DESCRIPTION
`Copy-FileContents` recursively scans a directory and collects the contents of all files that match the specified include and exclude path patterns.
Each matching file is printed with a formatted header and its raw contents, separated by newlines.
The combined result is copied to the clipboard using `Set-Clipboard`.

Internally, the function delegates traversal and filtering to `Get-FileContents`, which returns structured [FileContent] objects.

.PARAMETER Path
The root directory to scan for files. Defaults to the current directory (`.`).

.PARAMETER IncludePatterns
An optional list of wildcard path patterns (`-like` style) to include.
If empty, all files are included unless explicitly excluded.

.PARAMETER ExcludePatterns
An optional list of wildcard path patterns to exclude from processing.
If a file matches any of these patterns, it will be ignored even if it matches an include pattern.

.EXAMPLE
PS> Copy-FileContents -Path './docs'

Copies the contents of all files under the `docs` folder to the clipboard.

.EXAMPLE
PS> Copy-FileContents -Path './src' -IncludePatterns '*.ps1' -ExcludePatterns '*tests*'

Copies all `.ps1` files under `src`, excluding those in any folder matching `*tests*`.

.OUTPUTS
None. The formatted result is written to the system clipboard.

.NOTES
- Uses `Get-FileContents` to apply recursive scanning and filtering.
- Each file is printed with a header like `📄 File: path`, followed by its contents.
- This function is useful for quickly copying multiple file contents into editors or issue trackers.
#>
function Copy-FileContents {
    [Alias('cfc')]
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Directory', 'Root', 'Folder')]
        [string]$Path = '.',

        [Alias('Include', 'IncludeFile', 'Like')]
        [string[]]$IncludePatterns = @(),
        [Alias('Exclude', 'ExcludeFile', 'NotLike')]
        [string[]]$ExcludePatterns = @()
    )

    Get-FileContents -Path $Path `
        -IncludePatterns $IncludePatterns `
        -ExcludePatterns $ExcludePatterns | `
            ForEach-Object { "$($_.Header)`n$($_.ContentText)`n" } | Set-Clipboard
}
