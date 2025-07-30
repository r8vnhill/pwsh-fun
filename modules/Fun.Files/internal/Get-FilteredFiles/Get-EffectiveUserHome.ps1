function Get-EffectiveUserHome {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string] $UserHome,

        [Parameter()]
        [switch] $NoTilde,

        [Parameter()]
        [switch] $NormalizeSeparators,

        [Parameter()]
        [switch] $RequireExisting
    )

    begin {
        Set-StrictMode -Version Latest

        function Normalize-SeparatorsIfSafe {
            param([string] $PathValue)
            if ([string]::IsNullOrWhiteSpace($PathValue)) { return $PathValue }
            # Avoid changing extended prefixes (\\?\ or //?/)
            if ($PathValue -match '^(\\\\\?\\|//\?/)' ) { return $PathValue }

            $ds = [System.IO.Path]::DirectorySeparatorChar
            if ($ds -eq '\') {
                return ($PathValue -replace '/', '\')
            } else {
                return ($PathValue -replace '\\', '/')
            }
        }

        function Trim-TrailingSeparatorsSafely {
            param([string] $PathValue)
            if ([string]::IsNullOrWhiteSpace($PathValue)) { return $PathValue }
            if (Test-IsRootPath -PathValue $PathValue) {
                # Never trim a root (e.g., 'C:\' or '\\server\share\')
                return $PathValue
            }
            return $PathValue.TrimEnd([System.IO.Path]::DirectorySeparatorChar,
                                      [System.IO.Path]::AltDirectorySeparatorChar)
        }
    }

    process {
        try {
            $effective = $UserHome

            if (-not $NoTilde) {
                # Compute fallback only when no user value supplied
                if ([string]::IsNullOrWhiteSpace($effective)) {
                    $effective = $HOME
                    if ([string]::IsNullOrWhiteSpace($effective)) {
                        $effective = [System.Environment]::GetFolderPath(
                            [System.Environment+SpecialFolder]::UserProfile
                        )
                    }
                }
            }

            # If still empty (e.g., NoTilde + empty UserHome), just return as-is
            if ([string]::IsNullOrWhiteSpace($effective)) { return $effective }

            # Absolute normalization (works even if path doesn't exist)
            $effective = [System.IO.Path]::GetFullPath($effective)

            # Safe trimming of trailing separators
            $effective = Trim-TrailingSeparatorsSafely -PathValue $effective

            # Optional separator normalization
            if ($NormalizeSeparators) {
                $effective = Normalize-SeparatorsIfSafe -PathValue $effective
            }

            if ($RequireExisting -and -not (Test-Path -LiteralPath $effective -PathType Container)) {
                $ex = New-Object System.IO.DirectoryNotFoundException "Effective home directory does not exist: $effective"
                $err = New-Object System.Management.Automation.ErrorRecord `
                    ($ex), 'EffectiveHomeNotFound', `
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound, $effective
                throw $err
            }

            $effective
        }
        catch {
            $err = New-Object System.Management.Automation.ErrorRecord `
                ($_.Exception), 'GetEffectiveUserHomeFailed', `
                [System.Management.Automation.ErrorCategory]::InvalidOperation, $UserHome
            throw $err
        }
    }
}
