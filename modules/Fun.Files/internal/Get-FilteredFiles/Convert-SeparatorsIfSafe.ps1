function Convert-PathSeparators {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string[]] $Path,

        [Parameter()]
        [ValidateSet('Platform', 'Windows', 'Unix')]
        [string] $Style = 'Platform',

        [Parameter()]
        [ValidatePattern('^(\\|/)$')]
        [string] $CustomSeparator,

        [Parameter()]
        [switch] $PreserveUncLeading,

        [Parameter()]
        [switch] $CollapseDuplicates,

        [Parameter()]
        [switch] $SkipExtendedPrefix = $true,

        [Parameter()]
        [switch] $SkipUri = $true,

        [Parameter()]
        [switch] $OnlyIfMixed
    )

    begin {
        Set-StrictMode -Version Latest

        # Decide the target separator using the internal helper.
        # If a custom separator was passed, it takes precedence over -Style.
        $targetSep = if ($PSBoundParameters.ContainsKey('CustomSeparator')) {
            Get-PathSeparator -CustomSeparator $CustomSeparator
        } else {
            Get-PathSeparator -Style $Style
        }

        # The “other” separator is the one we will replace in inputs.
        $otherSep = if ($targetSep -eq '\') { '/' } else { '\' }

        # Regex for extended path prefixes (Windows), e.g. \\?\C:\ or //?/UNC/...
        $rxExtended = [System.Text.RegularExpressions.Regex]::new(
            '^(\\\\\?\\|//\?/)',
            [System.Text.RegularExpressions.RegexOptions]::Compiled `
                -bor [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )

        # Regex for URIs (scheme://...)
        $rxUri = [System.Text.RegularExpressions.Regex]::new(
            '^[A-Za-z][A-Za-z0-9+\.\-]*://',
            [System.Text.RegularExpressions.RegexOptions]::Compiled `
                -bor [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )
    }

    process {
        foreach ($p in $Path) {
            if ($null -eq $p) { continue }
            $s = [string]$p
            if ([string]::IsNullOrWhiteSpace($s)) { $s; continue }

            # Skip extended prefixes or URIs if requested (safer default).
            if ($SkipExtendedPrefix -and $rxExtended.IsMatch($s)) { $s; continue }
            if ($SkipUri           -and $rxUri.IsMatch($s))       { $s; continue }

            # When OnlyIfMixed is set, only convert if the string contains the “other” separator.
            if ($OnlyIfMixed -and $s.IndexOf($otherSep) -lt 0) { $s; continue }

            # Optionally preserve a leading UNC '//' or '\\' prefix count.
            $leading = ''
            $body    = $s
            if ($PreserveUncLeading) {
                # Count leading slashes/backslashes.
                $leadingCount = 0
                foreach ($ch in $body.ToCharArray()) {
                    if ($ch -eq '\' -or $ch -eq '/') { $leadingCount++ } else { break }
                }
                if ($leadingCount -gt 0) {
                    # Preserve at most 2 for UNC; if there were more, collapsing may reduce later.
                    $body = $body.Substring($leadingCount)
                    $leading = if ($targetSep -eq '\') {
                        '\'.PadLeft([Math]::Min(2, $leadingCount), '\')
                    } else {
                        '/'.PadLeft([Math]::Min(2, $leadingCount), '/')
                    }
                }
            }

            # Replace all occurrences of the “other” separator in the path body.
            $converted = $body.Replace($otherSep, $targetSep)

            if ($CollapseDuplicates) {
                # Collapse duplicate target separators in the middle (keep any preserved UNC prefix).
                $t = [System.Text.RegularExpressions.Regex]::Escape($targetSep)
                $converted = [System.Text.RegularExpressions.Regex]::Replace($converted, "$t{2,}", $targetSep)
            }

            # Re-attach any preserved UNC prefix.
            $leading + $converted
        }
    }
}
