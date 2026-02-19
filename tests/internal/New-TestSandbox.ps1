param(
    [Parameter(Mandatory)]
    [string] $Root
)

New-Item -ItemType Directory -Path $Root -Force | Out-Null
$mods = Join-Path $Root 'modules'
New-Item -ItemType Directory -Path $mods -Force | Out-Null

# module A with manifest
$A = New-Item -ItemType Directory -Path (Join-Path $mods 'Alpha') -Force
Set-Content -LiteralPath (Join-Path $A.FullName 'Alpha.psd1') -Value "@{ ModuleVersion = '0.1.0' }"

# module B with psm1 only
$B = New-Item -ItemType Directory -Path (Join-Path $mods 'Beta') -Force
Set-Content -LiteralPath (Join-Path $B.FullName 'Beta.psm1') -Value '# beta module'

# module C excluded by pattern
$C = New-Item -ItemType Directory -Path (Join-Path $mods 'Fun.OCD.Tools') -Force
Set-Content -LiteralPath (Join-Path $C.FullName 'Fun.OCD.Tools.psm1') -Value '# ocd'

# module D missing files (should be skipped)
$D = New-Item -ItemType Directory -Path (Join-Path $mods 'Delta') -Force

@{
    Root        = $Root
    ModulesPath = $mods
    Alpha       = $A.FullName
    Beta        = $B.FullName
    Ocd         = $C.FullName
    Delta       = $D.FullName
}
