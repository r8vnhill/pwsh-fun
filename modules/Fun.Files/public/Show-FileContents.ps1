<#
.SYNOPSIS
Displays the contents of all files under a directory, with optional ANSI color formatting.

.DESCRIPTION
`Show-FileContents` is a utility function that recursively traverses the given path, printing the contents of each file along with its full path.

Each file is preceded by a formatted header line that includes the file’s path.
If the terminal supports ANSI escape sequences, the header is printed in cyan and the file content in dim gray.
Otherwise, plain text is shown.

Internally, the function delegates to `Invoke-FileTransform`, which performs path validation, file enumeration, and `ShouldProcess` handling.

.PARAMETER Path
The directory to scan recursively for files. Defaults to the current directory ('.').

.EXAMPLE
PS> Show-FileContents

Displays the contents of all files in the current directory and its subdirectories.

.EXAMPLE
PS> Show-FileContents -Path './logs'

Displays all files under the `logs` folder, printing each file's name and content.

Simulates what files would be displayed without actually printing the contents. Relies on `Invoke-FileTransform` for `ShouldProcess`.

.OUTPUTS
None. The function writes text output to the console using `Write-Information` and `Write-Host`.

.NOTES
- Uses ANSI escape codes to color headers cyan (`\e[36m`) and content gray (`\e[90m`) when supported.
- Delegates all recursive traversal, validation, and error handling to `Invoke-FileTransform`.
#>
function Show-FileContents {
    [Alias('sfc')]
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Directory', 'Root', 'Folder')]
        [string]$Path = '.'
    )

    $supportsColor = $Host.UI.SupportsVirtualTerminal

    Invoke-FileTransform -Path $Path -FileProcessor {
        param ($file, $header)

        $colorHeader = $supportsColor ? "`e[36m$header`e[0m" : $header

        Write-Information $colorHeader -InformationAction Continue

        $content = Get-Content $file -Raw
        if ($supportsColor) {
            # Example: gray output
            $colorContent = "`e[90m$content`e[0m"
            Write-Host $colorContent
        } else {
            Write-Host $content
        }
    }
}
