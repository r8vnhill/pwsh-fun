<#
.SYNOPSIS
    Copies selected parameters from a caller's $PSBoundParameters into a target hashtable
    using a name map.

.DESCRIPTION
    Given:
      - `-KeyMap`: a hashtable mapping source names -> destination names, and
      - `-Bound`: typically a snapshot of the caller's $PSBoundParameters,
      - `-Target`: a hashtable to populate (and return),
    this helper copies entries into -Target according to the map.

    Two copy modes:
      - Presence (default): copy when the source key is PRESENT in -Bound (value can be
        $true or $false).
      - True: copy when the source key is PRESENT AND its value evaluates to $true.

    Overwrite behavior:
      - By default, existing keys in -Target are preserved.
      - With -Overwrite, existing keys are replaced.
      - If multiple sources map to the same destination, the first writer wins (no
        -Overwrite) or the last processed source wins (with -Overwrite). Note that
        Hashtable key enumeration order is not guaranteed; use [ordered]@{...} in tests
        when order matters.

    The function MUTATES and RETURNS the SAME -Target hashtable instance for convenient
    splatting.

.PARAMETER KeyMap
    Hashtable mapping source keys (from -Bound) to destination keys (written to -Target).
    Example: @{ Force='Force'; Recurse='Recurse'; FollowSymlink='FollowSymlink' }.
    Null/empty/whitespace source or destination names are ignored.

.PARAMETER Bound
    Hashtable of candidate inputs to copy (commonly $PSBoundParameters). Defaults to {}.

.PARAMETER Target
    Hashtable to populate. Defaults to {}. This instance is mutated and also returned.

.PARAMETER Mode
    Copy condition:
      - 'Presence' (default): copy when the key exists in -Bound.
      - 'True': copy when the key exists AND its value is $true.

.PARAMETER Overwrite
    If present, allows overwriting existing keys in -Target.

.PARAMETER Value
    Value to assign for each copied destination key. Defaults to $true (typical for
    switches).

.OUTPUTS
    System.Collections.Hashtable
    The same -Target instance, mutated with any copied entries.

.EXAMPLE
    # Presence mode: copy Force/Recurse if present (even if $false)
    $splat = Copy-BoundMappedSwitches -KeyMap @{ Force='Force'; Recurse='Recurse' } `
             -Bound $PSBoundParameters -Target @{}

.EXAMPLE
    # True mode: copy only when FollowSymlink is explicitly $true
    $splat = Copy-BoundMappedSwitches -KeyMap @{ FollowSymlink='FollowSymlink' } `
             -Bound $PSBoundParameters -Target @{} -Mode True

.EXAMPLE
    # Overwrite existing target values and use a custom value
    $tgt = @{ Force = $false }
    $splat = Copy-BoundMappedSwitches -KeyMap @{ Force='Force' } `
             -Bound @{ Force = $true } -Target $tgt -Overwrite -Value:$true
#>
function Copy-BoundMappedSwitches {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [hashtable] $KeyMap,
        [ValidateNotNull()]
        [hashtable] $Bound = @{},
        [ValidateNotNull()]
        [hashtable] $Target = @{},
        [ValidateSet('Presence','True')]
        [string] $Mode = 'Presence',
        [switch] $Overwrite,
        [bool] $Value = $true
    )

    begin {
        Set-StrictMode -Version Latest
    }

    process {
        # Copy mapped switches from Bound to Target.
        foreach ($src in $KeyMap.Keys) {
            # Skip null/empty/whitespace source names.
            if ([string]::IsNullOrWhiteSpace($src)) { continue }

            # Resolve destination name and skip null/empty/whitespace.
            $dst = $KeyMap[$src]
            if ([string]::IsNullOrWhiteSpace([string]$dst)) { continue }

            # Only proceed if the source key is present in -Bound (Presence semantics).
            $hasKey = $Bound.ContainsKey($src)
            if (-not $hasKey) { continue }

            # Decide whether to copy based on Mode:
            # - Presence: copy because key exists (value doesn't matter).
            # - True: copy only if the value is truthy.
            $shouldCopy = if ($Mode -eq 'True') { $Bound[$src] } else { $true }

            if ($shouldCopy) {
                # Honor overwrite policy.
                if ($Overwrite -or -not $Target.ContainsKey($dst)) {
                    $Target[$dst] = $Value
                }
            }
        }

        # Return the same instance that was passed in as -Target (documented contract).
        return $Target
    }
}
