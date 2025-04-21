<#
.SYNOPSIS
Represents the contents of a file, including its path, a formatted header, and raw content.

.DESCRIPTION
The `FileContent` class is a lightweight container that holds metadata and contents for a single file.
It is used in file-processing operations such as `Get-FileContents` and `Invoke-FileTransform`.

It defines three properties:
- `Path`: The full file system path of the file.
- `Header`: A display-ready label, typically including an emoji and the full path.
- `ContentText`: The complete raw content of the file.

The `ToString()` method returns a string with the header followed by the content, suitable for display or output.

.EXAMPLE
PS> [FileContent]::new("C:\logs\output.log", "📄 File: C:\logs\output.log", "Log contents...")

Creates a new FileContent object.

.EXAMPLE
PS> $file = [FileContent]::new("file.txt", "📄 File: file.txt", "Hello")
>>> Write-Output $file.ToString()

Prints:
📄 File: file.txt
Hello

.OUTPUTS
[FileContent]

.NOTES
- Used in modules like `Fun.Files` for representing structured file data.
- Especially useful for formatting output or copying files to the clipboard.
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
Returns the contents of all files in one or more directories as typed [FileContent] objects.

.DESCRIPTION
`Get-FileContents` recursively scans all files under one or more directory roots (`Path`).
It returns a [FileContent] object for each file, which includes the file’s full path, a formatted header, and its full content as a string.

You can use regular expressions to include or exclude files based on their relative paths.

Filtering is applied to normalized paths (converted to forward slashes). Exclusions override inclusions.

.PARAMETER Path
One or more directories to scan.
Accepts pipeline input and property binding. All paths must exist and be directories.

.PARAMETER IncludeRegex
Regular expressions to select which files to include. Defaults to `'.*'` (all files).

.PARAMETER ExcludeRegex
Regular expressions to exclude certain files. Exclusions override inclusions.

.EXAMPLE
PS> Get-FileContents -Path './src'

Recursively loads all files from the `./src` directory.

.EXAMPLE
PS> Get-FileContents -Path './logs' -IncludeRegex '.*\.log$'

Returns only `.log` files from the `./logs` directory.

.EXAMPLE
PS> Get-FileContents -Path './code' -IncludeRegex '.*\.ps1$' -ExcludeRegex '.*tests.*'

Returns `.ps1` files but skips any that include `tests` in their path.

.EXAMPLE
PS> './docs', './examples' | Get-FileContents

Reads and returns files from both `./docs` and `./examples` via the pipeline.

.EXAMPLE
PS> $files = Get-FileContents -Path './data' -IncludeRegex '^important.*\.csv$'
>>> $files | ForEach-Object { $_.ContentText.Length }

Prints the length of content for each `important*.csv` file.

.OUTPUTS
[FileContent[]] Each object includes:
- `Path`: the file’s absolute path.
- `Header`: a printable label.
- `ContentText`: the raw string contents of the file.

.NOTES
- Relies internally on `Invoke-FileTransform` to apply filters and processing.
- File contents are read with `Get-Content -Raw`.
- Paths are normalized for consistent pattern matching across platforms.
#>
function Get-FileContents {
    [Alias('gfc')]
    [OutputType([FileContent])]
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Directory', 'Root', 'Folder')]
        [string[]]$Path = @('.'),

        [Alias('Include', 'IncludeFile', 'IncludePatterns', 'Like')]
        [string[]]$IncludeRegex = @('.*'),

        [Alias('Exclude', 'ExcludeFile', 'ExcludePatterns', 'NotLike')]
        [string[]]$ExcludeRegex = @()
    )

    process {
        Invoke-FileTransform `
            -Path $Path `
            -IncludeRegex $IncludeRegex `
            -ExcludeRegex $ExcludeRegex `
            -FileProcessor {
                param (
                    [System.IO.FileInfo]$file,
                    [string]$header
                )

                [FileContent]::new(
                    $file.FullName,
                    $header,
                    (Get-Content -LiteralPath $file.FullName -Raw)
                )
            }
    }
}
