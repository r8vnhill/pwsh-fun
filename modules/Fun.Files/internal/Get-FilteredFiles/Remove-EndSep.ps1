function Remove-EndingDirectorySeparator {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string[]] $Path,

        [switch] $NormalizeSeparators
    )

    begin {
        Set-StrictMode -Version Latest

        # Determine if we can rely on Path.TrimEndingDirectorySeparator (present on PS7+ / .NET Core 2.1+)
        $hasDotNetTrim = [type]::GetType('System.IO.Path').GetMethods() |
            Where-Object { $_.Name -eq 'TrimEndingDirectorySeparator' } |
            Select-Object -First 1

        # Platform sniffing for case rules if needed later
        try {
            $isWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
                [System.Runtime.InteropServices.OSPlatform]::Windows
            )
        } catch { $isWindows = $PSVersionTable.Platform -eq 'Win32NT' }

        function Safe-TrimEndingDirectorySeparator {
            param([string] $p)

            if ($hasDotNetTrim) {
                # .NET handles root preservation correctly
                return [System.IO.Path]::TrimEndingDirectorySeparator($p)
            }

            # Fallback: preserve roots by comparing against the path root
            try {
                $full = [System.IO.Path]::GetFullPath($p)
                $root = [System.IO.Path]::GetPathRoot($full)

                # Trim for comparison only
                $trimFull = $full.TrimEnd([System.IO.Path]::DirectorySeparatorChar,
                                          [System.IO.Path]::AltDirectorySeparatorChar)
                $trimRoot = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar,
                                          [System.IO.Path]::AltDirectorySeparatorChar)

                $cmp = if ($isWindows) { [System.StringComparison]::OrdinalIgnoreCase }
                       else            { [System.StringComparison]::Ordinal }

                if ($trimFull.Equals($trimRoot, $cmp)) {
                    # It's a root; return original unchanged
                    return $p
                }

                return $p.TrimEnd([System.IO.Path]::DirectorySeparatorChar,
                                  [System.IO.Path]::AltDirectorySeparatorChar)
            } catch {
                # If normalization fails (e.g., invalid chars), fall back to trivial trim.
                return $p.TrimEnd([System.IO.Path]::DirectorySeparatorChar,
                                  [System.IO.Path]::AltDirectorySeparatorChar)
            }
        }
    }

    process {
        foreach ($p in $Path) {
            if ($null -eq $p) { continue }

            $candidate = [string]$p
            if ($NormalizeSeparators) {
                $candidate = Convert-SeparatorsIfSafe -p $candidate
            }

            Safe-TrimEndingDirectorySeparator -p $candidate
        }
    }
}
