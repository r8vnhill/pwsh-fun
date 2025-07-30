<#
.SYNOPSIS
    Returns the desired path separator character as '\' or '/'.

.DESCRIPTION
    Produces a single path separator based on either:
      - A custom explicit separator (via -CustomSeparator), or
      - A style selection (via -Style): Platform (default), Windows, or Unix.

    By default, the function returns a single-character [string].
    If -AsChar is specified, it returns a [char] instead (useful for .NET APIs that expect
    a char).

    Parameter sets ensure callers cannot pass both -CustomSeparator and -Style at once.

.PARAMETER CustomSeparator
    Explicit separator to return. Must be '\' or '/'.
    When this parameter is used, the "Custom" parameter set is selected and -Style is
    ignored.

.PARAMETER Style
    Target style for the separator:
      - Platform : Uses [System.IO.Path]::DirectorySeparatorChar for the current OS.
      - Windows  : Always '\'
      - Unix     : Always '/'
    This parameter belongs to the default "Style" parameter set.

.PARAMETER AsChar
    If supplied, returns the result as a [char] instead of a [string].

.OUTPUTS
    System.String
    System.Char
    By default, returns a single-character string. With -AsChar, returns a char.

.EXAMPLE
    Get-PathSeparator
    # On Windows: '\'
    # On Linux/macOS: '/'

.EXAMPLE
    Get-PathSeparator -Style Windows
    # Always returns '\', regardless of the current OS.

.EXAMPLE
    Get-PathSeparator -CustomSeparator '/' -AsChar
    # Returns [char] '/'.

.NOTES
    - This is a pure function (no side effects).
    - Prefer using -Style Platform unless you must force a specific style, to remain
      OS-agnostic.
#>
function Get-PathSeparator {
    [CmdletBinding(DefaultParameterSetName = 'Style')]
    [OutputType([string])]
    [OutputType([char])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Custom')]
        [ValidatePattern('^(\\|/)$')]
        [string] $CustomSeparator,

        [Parameter(ParameterSetName = 'Style')]
        [ValidateSet('Platform', 'Windows', 'Unix')]
        [string] $Style = 'Platform',

        [Parameter()]
        [switch] $AsChar
    )

    # Decide the separator according to the active parameter set.
    # $PSCmdlet.ParameterSetName is the reliable way to know which set bound.
    $sep = if ($PSCmdlet.ParameterSetName -eq 'Custom') {
        $CustomSeparator
    } elseif ($Style -eq 'Windows') {
        '\'
    } elseif ($Style -eq 'Unix') {
        '/'
    } else {
        [System.IO.Path]::DirectorySeparatorChar
    }

    if ($AsChar) {
        return [char]$sep
    }

    return [string]$sep
}
