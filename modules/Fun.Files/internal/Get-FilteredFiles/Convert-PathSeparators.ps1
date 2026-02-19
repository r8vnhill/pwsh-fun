#Requires -Version 7.0

<#
.SYNOPSIS
    Converts path separators for one or more input paths.

.DESCRIPTION
    Transforms separators in paths to a target style (Windows "\" or Unix "/"), or to an
    explicitly provided custom separator. The function can:
    - Preserve a leading Universal Naming Convention (UNC) prefix (e.g., 
      //server → \\server)
    - Collapse duplicate target separators inside the path body
    - Skip converting extended Windows prefixes (\\?\ or //?/) and/or URI-like inputs
    - Convert only when the path actually contains the “other” separator (OnlyIfMixed)

    This cmdlet is pipeline-friendly and accepts input via -Path or by property name
    alias “FullName” (useful when piping from Get-ChildItem).

.PARAMETER Path
    One or more paths to convert. Accepts from pipeline or by property name (FullName).
    Cannot be null or empty; each element is normalized individually.

.PARAMETER Style
    Target style when no custom separator is specified. One of:
    - Platform  : [System.IO.Path]::DirectorySeparatorChar
    - Windows   : '\'
    - Unix      : '/'

.PARAMETER CustomSeparator
    Explicit target separator. Must be '\' or '/' (takes precedence over -Style).

.PARAMETER PreserveUncLeading
    When set, preserves up to two leading separators for UNC-like inputs (// or \\), so
    that UNC roots remain UNC after conversion.

.PARAMETER CollapseDuplicates
    When set, collapses repeated occurrences of the target separator in the converted
    path body (leading UNC, if preserved, is not collapsed).

.PARAMETER SkipExtendedPrefix
    When $true (default), paths with the extended Windows prefix (\\?\… or //?/…) are
    returned unchanged.

.PARAMETER SkipUri
    When $true (default), strings that look like URIs (scheme://) are returned unchanged.

.PARAMETER OnlyIfMixed
    When set, conversion happens only if the input contains the “other” separator (i.e.,
    the one we’re replacing). If the input already uses only the target separator, it is
    returned as-is.

.OUTPUTS
    System.String

.EXAMPLE
    PS> 'a/b/c','x/y' | Convert-PathSeparators -Style Windows
    a\b\c
    x\y

.EXAMPLE
    PS> Convert-PathSeparators -Path '//server/share/a/b' -Style Windows -PreserveUncLeading
    \\server\share\a\b

.EXAMPLE
    PS> Convert-PathSeparators -Path 'p//q///r' -Style Windows -CollapseDuplicates
    p\q\r
#>
function Convert-PathSeparators {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [ValidateNotNullOrEmpty()]
        [string[]]  $Path,
        [Parameter()]
        [ValidateSet('Platform', 'Windows', 'Unix')]
        [string]    $Style = 'Platform',
        [Parameter()]
        [ValidatePattern('^(\\|/)$')]
        [string]    $CustomSeparator,
        [switch]    $PreserveUncLeading,
        [switch]    $CollapseDuplicates,
        [bool]      $SkipExtendedPrefix = $true,
        [bool]      $SkipUri = $true,
        [switch]    $OnlyIfMixed
    )

    begin {
        Set-StrictMode -Version Latest

        # Decide target separator (CustomSeparator takes precedence over Style).
        $targetSep = if ($PSBoundParameters.ContainsKey('CustomSeparator')) {
            Get-PathSeparator -CustomSeparator $CustomSeparator
        } else {
            Get-PathSeparator -Style $Style
        }

        # Identify the “other” separator we intend to replace.
        $otherSep = if ($targetSep -eq '\') { '/' } else { '\' }

        # Precompile regex matchers (simple and fast). CultureInvariant avoids surprises.
        $rxExtended = [regex]'^(\\\\\?\\|//\?/)'
        $rxUri = [regex]'^[a-zA-Z][a-zA-Z0-9+\-.]*://'
    }

    process {
        foreach ($p in $Path) {
            Script:_ConvertSinglePathSeparator -Path $p `
                -TargetSep $targetSep `
                -OtherSep $otherSep `
                -PreserveUncLeading:$PreserveUncLeading `
                -CollapseDuplicates:$CollapseDuplicates `
                -SkipExtendedPrefix:$SkipExtendedPrefix `
                -SkipUri:$SkipUri `
                -OnlyIfMixed:$OnlyIfMixed `
                -RxExtended $rxExtended `
                -RxUri $rxUri
        }
    }
}

<#
.SYNOPSIS
    Converts a single path string according to separator rules.

.DESCRIPTION
    Internal helper that implements the actual conversion for one string. It is split
    out for readability, testability, and to keep the public function’s process block
    small.

.PARAMETER Path
    The single path input to convert. Null/empty/whitespace returns as-is.

.PARAMETER TargetSep
    The desired separator (either '\' or '/').

.PARAMETER OtherSep
The separator to replace (the counterpart of TargetSep).

.PARAMETER PreserveUncLeading
    Preserve up to two leading separators for UNC-like inputs.

.PARAMETER CollapseDuplicates
    Collapse repeated target separators in the body of the path.

.PARAMETER SkipExtendedPrefix
    Return unchanged if Path starts with an extended Windows prefix.

.PARAMETER SkipUri
    Return unchanged if Path looks like a URI (scheme://…).

.PARAMETER OnlyIfMixed
    Return unchanged if Path does not contain OtherSep.

.PARAMETER RxExtended
    Precompiled regex that matches extended prefixes.

.PARAMETER RxUri
    Precompiled regex that matches URI-like strings.

.OUTPUTS
    System.String
#>
function Script:_ConvertSinglePathSeparator {
    param(
        [string]    $Path,
        [string]    $TargetSep,
        [string]    $OtherSep,
        [bool]      $PreserveUncLeading,
        [bool]      $CollapseDuplicates,
        [bool]      $SkipExtendedPrefix,
        [bool]      $SkipUri,
        [bool]      $OnlyIfMixed,
        [regex]     $RxExtended,
        [regex]     $RxUri
    )

    # Short-circuit: null/empty/whitespace → unchanged.
    if ($null -eq $Path -or [string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    # Honor “skip” guards early for performance and clarity.
    if ($SkipExtendedPrefix -and $RxExtended.IsMatch($Path)) { return $Path }
    if ($SkipUri -and $RxUri.IsMatch($Path)) { return $Path }
    if ($OnlyIfMixed -and $Path.IndexOf($OtherSep) -lt 0) { return $Path }

    # Optionally preserve up to two leading separators (UNC roots).
    $leading = ''
    $body = $Path
    if ($PreserveUncLeading) {
        $leadingCount = 0
        foreach ($ch in $body.ToCharArray()) {
            if ($ch -eq '\' -or $ch -eq '/') { $leadingCount++ } else { break }
        }
        if ($leadingCount -gt 0) {
            # Strip the run of leading slashes from the body and synthesize up to two.
            $body = $body.Substring($leadingCount)
            $leading = $TargetSep * [Math]::Min(2, $leadingCount)
        }
    }

    # Replace the “other” separator with the target separator.
    $converted = $body.Replace($OtherSep, $TargetSep)

    # Optionally collapse duplicate target separators inside the body. The preserved
    # UNC prefix (if any) is kept untouched by design.
    if ($CollapseDuplicates) {
        $escaped = [Regex]::Escape($TargetSep)
        $converted = [Regex]::Replace($converted, "$escaped{2,}", $TargetSep)
    }

    return $leading + $converted
}
