function Get-AbsolutePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string[]] $Path,

        [Parameter()]
        [string] $BasePath = (Get-Location -PSProvider FileSystem).Path,

        [Parameter()]
        [switch] $RequireExisting,

        [Parameter()]
        [switch] $Literal,

        [Parameter()]
        [switch] $EnsureTrailingSeparator
    )

    begin {
        Set-StrictMode -Version Latest

        # Normalize/validate base path (prefer filesystem provider)
        try {
            if ($RequireExisting) {
                $resolvedBase = (Resolve-Path -LiteralPath $BasePath -ErrorAction Stop).Path
            } else {
                $resolvedBase = (Resolve-Path -LiteralPath $BasePath -ErrorAction SilentlyContinue).Path
                if (-not $resolvedBase) {
                    # If base doesn't exist, still normalize its string
                    $resolvedBase = [System.IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($BasePath))
                }
            }
        } catch {
            $er = New-Object System.Management.Automation.ErrorRecord `
            ($_.Exception), 'BasePathResolutionFailed', `
                [System.Management.Automation.ErrorCategory]::InvalidArgument, $BasePath
            throw $er
        }
    }

    process {
        foreach ($p in $Path) {
            try {
                $result = $null

                if ($RequireExisting) {
                    # Use Resolve-Path; respect -Literal for wildcard behavior
                    $rp = if ($Literal) {
                        Resolve-Path -LiteralPath $p -ErrorAction Stop
                    } else {
                        Resolve-Path -Path $p -ErrorAction Stop
                    }
                    # Resolve-Path may return multiple results; return all
                    foreach ($item in $rp) {
                        $candidate = $item.Path
                        if ($EnsureTrailingSeparator -and
                            -not $candidate.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
                            # Only append when the path points to a container and lacks the separator
                            if (Test-Path -LiteralPath $candidate -PathType Container) {
                                $candidate += [System.IO.Path]::DirectorySeparatorChar
                            }
                        }
                        $candidate
                    }
                    continue
                }

                # Non-existing allowed: expand env/~ and normalize with .NET
                $expanded = Expand-NonExistingFriendly -p $p
                # Use the .NET overload with base path (more predictable than process CWD)
                $absolute = [System.IO.Path]::GetFullPath($expanded, $resolvedBase)

                if ($EnsureTrailingSeparator -and
                    -not $absolute.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
                    # Heuristic: append only if it looks like a directory path (ends with separator or no extension)
                    # We avoid expensive filesystem checks here because the path might not exist.
                    if ([string]::IsNullOrEmpty([System.IO.Path]::GetExtension($absolute))) {
                        $absolute += [System.IO.Path]::DirectorySeparatorChar
                    }
                }

                $absolute
            } catch {
                $er = New-Object System.Management.Automation.ErrorRecord `
                ($_.Exception), 'PathResolutionFailed', `
                    [System.Management.Automation.ErrorCategory]::InvalidArgument, $p
                throw $er
            }
        }
    }
}
