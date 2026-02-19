function Get-DirectoryItems {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType([System.IO.FileSystemInfo])]
    param(
        [Parameter(
            ParameterSetName = 'Path',
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [Alias('FullName')]
        [SupportsWildcards()]
        [string[]] $Path = '.',

        [Parameter(ParameterSetName = 'Literal', ValueFromPipelineByPropertyName)]
        [Alias('PSPath')]
        [string[]] $LiteralPath,

        [switch] $Recurse,
        [int] $Depth,
        [switch] $Directory,
        [switch] $File,
        [string] $Filter,
        [string[]] $Include,
        [string[]] $Exclude,
        [switch] $Force,
        [switch] $FollowSymlink
    )

    begin {
        Set-StrictMode -Version Latest
    }

    process {
        # Select which set of paths to use based on parameter set
        $targets = if ($PSCmdlet.ParameterSetName -eq 'Literal') { $LiteralPath } else { $Path }

        foreach ($t in $targets) {
            if ([string]::IsNullOrWhiteSpace($t)) { continue }

            $base = @{ Path = $t }
            $useLiteral = ($PSCmdlet.ParameterSetName -eq 'Literal')
            $splat = New-GciSplat -Base $base -UseLiteral:$useLiteral

            try {
                # Emit items; pipeline handles enumeration naturally
                Get-ChildItem @splat
            } catch {
                # Create a rich error record that includes the target path and original exception
                $err = New-Object System.Management.Automation.ErrorRecord `
                ($_.Exception), 'DirectoryEnumerationFailed', `
                    [System.Management.Automation.ErrorCategory]::OpenError, $t
                $err.ErrorDetails = [System.Management.Automation.ErrorDetails]::new("Failed to list contents of '$t'.")
                Write-Error $err
                # Continue to the next target without emitting $null
                continue
            }
        }
    }
}
