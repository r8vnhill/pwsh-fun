function Test-IsRootPath {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string[]] $Path,

        [Parameter()]
        [switch] $Strict
    )

    begin {
        Set-StrictMode -Version Latest

        # Determine comparison semantics per platform
        try {
            $isWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
                [System.Runtime.InteropServices.OSPlatform]::Windows
            )
        } catch {
            # Fallback for older platforms
            $isWindows = $PSVersionTable.Platform -eq 'Win32NT'
        }
        $cmp = if ($isWindows) {
            [System.StringComparison]::OrdinalIgnoreCase
        } else {
            [System.StringComparison]::Ordinal
        }
    }

    process {
        foreach ($p in $Path) {
            if ([string]::IsNullOrWhiteSpace($p)) {
                if ($Strict) {
                    $ex = [System.ArgumentException]::new('Path cannot be null or whitespace.')
                    $err = New-Object System.Management.Automation.ErrorRecord `
                        ($ex), 'NullOrWhiteSpacePath', `
                        [System.Management.Automation.ErrorCategory]::InvalidArgument, $p
                    throw $err
                }
                $false
                continue
            }

            try {
                # Normalize the path to its absolute canonical form
                $normalized = [System.IO.Path]::GetFullPath($p)

                # Get its root as understood by the current platform
                $root = [System.IO.Path]::GetPathRoot($normalized)

                if ([string]::IsNullOrEmpty($root)) {
                    # Relative paths have no root
                    $false
                    continue
                }

                # Compare normalized path to its root, ignoring trailing separators
                $isRoot = (Remove-EndingDirectorySeparator $normalized).Equals((Remove-EndingDirectorySeparator $root), $cmp)
                $isRoot
            }
            catch {
                if ($Strict) {
                    $err = New-Object System.Management.Automation.ErrorRecord `
                        ($_.Exception), 'PathNormalizationFailed', `
                        [System.Management.Automation.ErrorCategory]::InvalidArgument, $p
                    throw $err
                }
                $false
            }
        }
    }
}
