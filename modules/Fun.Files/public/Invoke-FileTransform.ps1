<#
.SYNOPSIS
Applies a custom script block to the contents of all files in a directory tree.

.DESCRIPTION
`Invoke-FileTransform` is a utility function that recursively enumerates all files under a given directory and invokes a user-provided script block (`FileProcessor`) on each file.
The processor receives both the file object and a formatted header string, which includes the file's full path and optional color formatting.

This function is designed to support dynamic file inspection, transformation, or display use cases.
It throws terminating errors for invalid or non-existent paths.

.PARAMETER Path
The root directory to search for files.
The path must exist and be a directory, or a terminating error will be thrown.

.PARAMETER FileProcessor
A script block that is invoked for each file.
The script block receives two arguments:
1. The file object (`System.IO.FileInfo`)
2. A formatted header string containing the file path (ANSI-colored if supported)

Defaults to `{ $_ }`, which simply returns the file.

.EXAMPLE
PS> Invoke-FileTransform -Path './docs' -FileProcessor {
>>>     param ($file, $header)
>>>     Write-Host $header
>>>     Get-Content $file -Raw
>>> }

Prints each file path under `./docs`, then prints its raw contents.

.EXCEPTIONS
System.IO.DirectoryNotFoundException:
Thrown when the provided path does not exist.

System.IO.InvalidDataException:
Thrown when the provided path exists but is not a directory.

.OUTPUTS
The output depends on the behavior of the `FileProcessor` script block.
By default, returns the file object unchanged.

.NOTES
- This function respects ANSI terminal capabilities for color support.
- It is safe to use in pipeline contexts, but does not accept pipeline input.
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
        [scriptblock]$FileProcessor = { $_ }
    )

    $resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        $exception = [System.IO.DirectoryNotFoundException]::new(
            "❌ Path '$Path' does not exist."
        )
        $category = [System.Management.Automation.ErrorCategory]::ObjectNotFound
        $errRecord = [System.Management.Automation.ErrorRecord]::new(
            $exception,
            'PathNotFound',
            $category,
            $Path
        )
        $PSCmdlet.ThrowTerminatingError($errRecord)
    }

    if (-not (Test-Path $resolvedPath.Path -PathType Container)) {
        throw [System.IO.InvalidDataException]::new(
            "❌ Path '$Path' is not a directory."
        )
    }

    $supportsColor = $Host.UI.SupportsVirtualTerminal

    Get-ChildItem -Path $resolvedPath.Path -File -Recurse | ForEach-Object {
        $header = "`n📄 File: $($_.FullName)"
        if ($supportsColor) {
            $header = "`e[36m$header`e[0m"
        }

        $FileProcessor.Invoke($_, $header)
    }
}
