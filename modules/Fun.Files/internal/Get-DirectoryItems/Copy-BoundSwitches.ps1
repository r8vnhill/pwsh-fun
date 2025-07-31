function Copy-BoundSwitches {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Bound,

        [hashtable] $Target = @{},

        [string[]] $SwitchKeys = @('Force', 'Recurse', 'Directory', 'File'),

        [hashtable] $KeyMap,

        [switch] $Overwrite
    )

    begin { Set-StrictMode -Version Latest }

    process {
        $effectiveMap = @{}
        foreach ($k in $SwitchKeys) {
            if (-not [string]::IsNullOrWhiteSpace($k)) {
                $effectiveMap[$k] = $k
            }
        }

        if ($KeyMap) {
            foreach ($src in $KeyMap.Keys) {
                if ([string]::IsNullOrWhiteSpace($src)) { continue }
                $dst = $KeyMap[$src]
                if ([string]::IsNullOrWhiteSpace([string]$dst)) { continue }
                $effectiveMap[$src] = $dst
            }
        }

        return (Copy-BoundMappedSwitches `
                -KeyMap $effectiveMap `
                -Bound  $Bound `
                -Target $Target `
                -Mode   Presence `
                -Overwrite:$Overwrite `
                -Value  $true)
    }
}
