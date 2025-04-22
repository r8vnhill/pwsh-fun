<#
.SYNOPSIS
Displays the contents of files in one or more directories, with optional ANSI color formatting.

.DESCRIPTION
`Show-FileContents` recursively scans one or more directories, displaying each matching file with a clear header and its full content.
It supports optional include/exclude patterns for filtering files by normalized relative path.

If the terminal supports ANSI escape sequences, the function highlights headers in cyan and file contents in gray for better readability.

This is particularly useful for inspecting file sets in documentation, debugging, or scripting contexts, where seeing headers and content together improves context and visibility.

.PARAMETER Path
One or more directories to scan recursively for files.
Accepts relative or absolute paths. Defaults to the current directory (`.`).
Can also be provided via pipeline or bound by property name.

.PARAMETER IncludeRegex
An array of regular expressions used to include files based on their relative path.
Defaults to `'.*'`, which includes all files.

.PARAMETER ExcludeRegex
An array of regular expressions used to exclude files from matching.
Exclusion patterns override any include matches.

.EXAMPLE
Show-FileContents -Path './docs'

Displays all files under the `./docs` directory with formatted headers and content.

.EXAMPLE
'./src', './examples' | Show-FileContents

Displays files from multiple directories provided via the pipeline.

.EXAMPLE
Show-FileContents -Path './lib' -IncludeRegex '.*\.ps1$' -ExcludeRegex 'tests/'

Shows only `.ps1` files in `./lib`, excluding those inside `tests/` folders.

.NOTES
- Uses `Invoke-FileTransform` internally for directory traversal and filtering.
- If the host supports ANSI escape sequences, headers are colored cyan and content gray.
- Uses `Format-Cyan` and `Format-Gray` internally for color formatting.
#>
function Show-FileContents {
    [Alias('sfc')]
    [OutputType([void])]
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]$Path = @('.'),

        [Alias('Include', 'IncludeFile', 'IncludePatterns', 'Like')]
        [string[]]$IncludeRegex = @('.*'),

        [Alias('Exclude', 'ExcludeFile', 'ExcludePatterns')]
        [string[]]$ExcludeRegex = @()
    )

    $supportsColor = $Host.UI.SupportsVirtualTerminal

    Invoke-FileTransform -Path $Path `
        -IncludeRegex $IncludeRegex `
        -ExcludeRegex $ExcludeRegex `
        -FileProcessor {
        param ($file, $header)

        $colorHeader = $supportsColor ? (Format-Cyan $header) : $header

        Write-Host $colorHeader

        $content = Get-Content $file -Raw
        if ($supportsColor) {
            $colorContent = Format-Gray $content
            Write-Host $colorContent
        } else {
            Write-Host $content
        }
    }
}

<#
.SYNOPSIS
Formats a string using cyan ANSI color.

.DESCRIPTION
Returns the input text wrapped in ANSI escape sequences for cyan color.
Used for headers or emphasis in terminal output.

.PARAMETER Text
The input string to colorize.

.OUTPUTS
[string] The ANSI-wrapped string with cyan color applied.

.EXAMPLE
PS> Format-Cyan "Header Text"

Returns a cyan-colored version of "Header Text" for display in a terminal that supports ANSI codes.
#>
function Format-Cyan([string]$Text) {
    return "`e[36m$Text`e[0m"
}

<#
.SYNOPSIS
Formats a string using gray ANSI color.

.DESCRIPTION
Returns the input text wrapped in ANSI escape sequences for gray (dim) color.
Ideal for displaying secondary or less prominent output.

.PARAMETER Text
The input string to colorize.

.OUTPUTS
[string] The ANSI-wrapped string with gray color applied.

.EXAMPLE
PS> Format-Gray "Dimmed content"

Returns a gray-colored version of "Dimmed content" for terminal display.
#>
function Format-Gray([string]$Text) {
    return "`e[90m$Text`e[0m"
}
