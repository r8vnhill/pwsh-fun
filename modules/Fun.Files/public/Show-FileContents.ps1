<#
.SYNOPSIS
Displays the contents of files in one or more directories with optional color formatting.

.DESCRIPTION
`Show-FileContents` recursively lists all files under the specified directories and displays their content and file headers. 
If the terminal supports ANSI escape sequences, headers are shown in cyan and file content in gray.

This function is ideal for inspecting large sets of files or previewing content in scripts and documentation workflows.

.PARAMETER Path
One or more directories to traverse. Defaults to the current directory ('.').
Accepts pipeline input and property binding.

.EXAMPLE
PS> Show-FileContents -Path './docs'

Displays the contents of all files under the `./docs` directory.

.EXAMPLE
PS> './src', './examples' | Show-FileContents

Displays the contents of files under multiple directories provided via pipeline.

.NOTES
- Uses `Invoke-FileTransform` internally for traversal and filtering.
- Outputs colored headers and contents if terminal supports it.
- Uses ANSI escape codes for color formatting.

#>
function Show-FileContents {
    [Alias('sfc')]
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]$Path = @('.')
    )

    $supportsColor = $Host.UI.SupportsVirtualTerminal

    Invoke-FileTransform -Path $Path -FileProcessor {
        param ($file, $header)

        $colorHeader = $supportsColor ? (Format-Cyan $header) : $header

        Write-Information $colorHeader -InformationAction $InformationPreference

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
