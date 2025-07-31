function New-GciSplat {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [hashtable] $Base = @{},
        [hashtable] $Bound = @{},
        [switch] $UseLiteral,
        [bool] $SupportsFollowSymlink = $false
    )

    begin {
        Set-StrictMode -Version Latest
    }

    process {
        $ht = @{ ErrorAction = 'Stop' }

        # TODO

        foreach ($k in 'Depth', 'Filter') {
            if ($Bound.ContainsKey($k)) {
                $ht[$k] = $Bound[$k]
            }
        }

        foreach ($k in 'Include', 'Exclude') {
            if ($Bound.ContainsKey($k) -and $Bound[$k]) {
                $ht[$k] = $Bound[$k]
            }
        }

        if ($SupportsFollowSymlink -and $Bound['FollowSymlink']) {
            $ht['FollowSymlink'] = $true
        }

        foreach ($k in $Base.Keys) {
            $ht[$k] = $Base[$k]
        }

        if ($UseLiteral -and $ht.ContainsKey('Path')) {
            $ht['LiteralPath'] = $ht['Path']
            $null = $ht.Remove('Path')
        }

        return $ht
    }
}
