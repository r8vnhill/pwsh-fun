<#
.SYNOPSIS
Represents the contents of a file, including its path, a formatted header, and raw content.

.DESCRIPTION
The `FileContent` class is a simple data structure used to store information about a file discovered during a recursive traversal.
It holds three properties:
- `Path`: The full path to the file.
- `Header`: A formatted string that can be used as a label, usually displaying the file name.
- `ContentText`: The raw contents of the file as a single string.

The class includes a `ToString()` override to display the header followed by the file content, which can be helpful for debugging or piping to output.

.EXAMPLE
PS> [FileContent]::new("C:\logs\output.log", "📄 File: C:\logs\output.log", "Log contents...")

Creates a new `FileContent` object with the specified path, header, and content text.

.EXAMPLE
PS> $file = [FileContent]::new("file.txt", "📄 File: file.txt", "Hello")
>>> Write-Output $file.ToString()

Displaying file content with header.

.OUTPUTS
[FileContent]

.NOTES
This class is used in conjunction with `Get-FileContents` and `Invoke-FileTransform` to model file data in a structured and reusable way.
#>
class FileContent {
    [string]$Path
    [string]$Header
    [string]$ContentText

    FileContent([string]$Path, [string]$Header, [string]$ContentText) {
        $this.Path = $Path
        $this.Header = $Header
        $this.ContentText = $ContentText
    }

    [string] ToString() {
        return "$($this.Header)`n$($this.ContentText)"
    }
}

<#
.SYNOPSIS
Returns the contents of all files in a directory tree as typed [FileContent] objects.

.DESCRIPTION
`Get-FileContents` recursively scans the specified directory and returns a list of files whose paths match specified inclusion/exclusion patterns.
Each file is represented as a [FileContent] object, which contains the full file path, a formatted header, and its raw content as a single string.

This function is useful for scenarios like batch processing, file auditing, code generation, or clipboard operations, and supports advanced path-based filtering through wildcard patterns.

Filtering is based on normalized full paths (forward slashes used instead of backslashes) and uses `-like` matching semantics.

.PARAMETER Path
The root directory to search for files. Defaults to the current directory (`.`).
Supports pipeline input and binding by property name.

.PARAMETER IncludePatterns
An array of wildcard patterns used to include files. These are matched against normalized full file paths.
If omitted or empty, all files are included.
Defaults to `'*'`.

.PARAMETER ExcludePatterns
An array of wildcard patterns used to exclude files. These are matched against normalized full file paths.
If a file matches any exclude pattern, it will be skipped even if it matches an include pattern.

.EXAMPLE
PS> Get-FileContents -Path './src'

Returns all files recursively under the `src/` folder.

.EXAMPLE
PS> Get-FileContents -Path './logs' -IncludePatterns '*.log'

Only includes files with `.log` extension under `logs/`.

.EXAMPLE
PS> Get-FileContents -Path './code' -IncludePatterns '*.ps1' -ExcludePatterns '*tests*'

Includes all `.ps1` scripts except those under paths containing "tests".

.EXAMPLE
PS> './docs', './examples' | Get-FileContents

Scans both directories from pipeline input and returns all files found.

.OUTPUTS
[FileContent[]] Each object includes:
- `Path`: The full file path
- `Header`: A formatted header string (e.g., for printing)
- `ContentText`: The raw contents of the file

.NOTES
- The [FileContent] class must be defined in the same module or session.
- Internally delegates traversal and error handling to `Invoke-FileTransform`.
- This function normalizes paths to use forward slashes for pattern matching consistency.
- File content is read using `Get-Content -Raw`.
#>
function Get-FileContents {
    [Alias('gfc')]
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Directory', 'Root', 'Folder')]
        [string]$Path = '.',

        [Alias('Include', 'IncludeFile', 'Like')]
        [string[]]$IncludePatterns = @("*"),

        [Alias('Exclude', 'ExcludeFile', 'NotLike')]
        [string[]]$ExcludePatterns = @()
    )

    process {
        Invoke-FileTransform -Path $Path -FileProcessor {
            param (
                [System.IO.FileInfo]$file,
                [string]$header
            )

            $normalized = $file.FullName -replace '\\', '/'

            $included = $IncludePatterns.Count -eq 0 `
                -or ($IncludePatterns | Where-Object { $normalized -like $_ })
            $excluded = $ExcludePatterns.Count -ne 0 `
                -and ($ExcludePatterns | Where-Object { $normalized -like $_ })

            if ($included -and -not $excluded) {
                [FileContent]::new(
                    $file.FullName,
                    $header,
                    (Get-Content -LiteralPath $file.FullName -Raw)
                )
            }
        }
    }
}
