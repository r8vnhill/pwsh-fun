# Install-FunModules.ps1
#Requires -Version 7.0
Set-StrictMode -Version Latest

#region Types
enum ModuleKind { Manifest; Script }

class FunModuleRef {
    [string]     $Name
    [string]     $Path
    [ModuleKind] $Kind

    FunModuleRef([string] $name, [string] $path, [ModuleKind] $kind) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw [ArgumentException]::new('Name is required')
        }
        if ([string]::IsNullOrWhiteSpace($path)) {
            throw [ArgumentException]::new('Path is required')
        }
        $this.Name = $name
        $this.Path = $path
        $this.Kind = $kind
    }

    [string] ToString() {
        return '{0} ({1}) -> {2}' -f $this.Name, $this.Kind, $this.Path
    }

    hidden static [bool] MatchesAny([string] $value, [string[]] $patterns) {
        foreach ($p in $patterns) { 
            if ($value -like $p) { return $true } 
        }
        return $false
    }

    static [FunModuleRef] TryFromDir([System.IO.DirectoryInfo] $dir) {
        if (-not $dir) { return $null }
        $n = $dir.Name
        $psd = Join-Path $dir.FullName "$n.psd1"
        $psm = Join-Path $dir.FullName "$n.psm1"
        if (Test-Path -LiteralPath $psd -PathType Leaf) {
            return [FunModuleRef]::new($n, $psd, [ModuleKind]::Manifest) 
        }
        if (Test-Path -LiteralPath $psm -PathType Leaf) {
            return [FunModuleRef]::new($n, $psm, [ModuleKind]::Script)
        }
        return $null
    }
}

class FunModuleImportResult {
    [string]     $Name
    [Version]    $Version
    [ModuleKind] $Kind
    [string]     $Path
    [string]     $Status
    [string]     $Message

    FunModuleImportResult(
        [string]$name, 
        [Version]$ver, 
        [ModuleKind]$kind, 
        [string]$path, 
        [string]$status, 
        [string]$msg) {
        $this.Name = $name
        $this.Version = $ver
        $this.Kind = $kind
        $this.Path = $path
        $this.Status = $status
        $this.Message = $msg
    }

    [string] ToString() { 
        return '{0} {1} [{2}] - {3}' `
            -f $this.Name, ($this.Version ?? ''), $this.Status, $this.Path 
    }
}
#endregion Types

#region Discovery
function script:Get-FunModuleFiles {
    [CmdletBinding()]
    [OutputType([FunModuleRef])]
    param(
        [string]   $BasePath,
        [string[]] $Exclude = @('*Fun.OCD*', '.git', '_*')
    )

    # Compute default at runtime to avoid Resolve-Path throwing at parse time
    if (-not $PSBoundParameters.ContainsKey('BasePath')) {
        $BasePath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
    }

    if (-not (
            Test-Path -LiteralPath (Join-Path $BasePath 'modules') -PathType Container)) {
        Write-Verbose "Modules folder not found under: $BasePath"
        return
    }

    $modulesPath = Join-Path $BasePath 'modules'
    Get-ChildItem -LiteralPath $modulesPath -Directory -ErrorAction Stop |
        Where-Object { -not [FunModuleRef]::MatchesAny($_.Name, $Exclude) } |
        ForEach-Object {
            $ref = [FunModuleRef]::TryFromDir($_)
            if ($ref) { $ref } 
            else { Write-Verbose "Skipping '$($_.Name)' (no matching .psd1/.psm1)." }
        }
}
#endregion Discovery

#region Install
function Install-FunModules {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        # You can either pipe in refs or let the function discover them:
        [Parameter(ValueFromPipeline)]
        [FunModuleRef[]] $Module,

        [string]   $BasePath,
        [string[]] $Exclude = @('*Fun.OCD*'),
        [ValidateSet('Global', 'Local')]
        [string]   $Scope = 'Global'
    )
    begin {
        $refs = New-Object System.Collections.Generic.List[FunModuleRef]
        # If BasePath was supplied (or default), we’ll add discovery results in end{}
        $hadInput = $false
    }
    process {
        if ($Module) {
            $hadInput = $true
            foreach ($m in $Module) { [void]$refs.Add($m) }
        }
    }
    end {
        if (-not $hadInput) {
            foreach ($m in (Get-FunModuleFiles -BasePath:$BasePath -Exclude:$Exclude)) {
                [void]$refs.Add($m)
            }
        }

        foreach ($m in $refs) {
            $target = "$($m.Name) ($($m.Kind))"
            if (-not $PSCmdlet.ShouldProcess($target, 'Import-Module')) { continue }
            try {
                Write-Verbose "Importing $($m.Name) from $($m.Path) [Scope=$Scope]"
                $mod = Import-Module -LiteralPath $m.Path -Force -Scope $Scope -PassThru `
                    -ErrorAction Stop
                [FunModuleImportResult]::new(
                    $m.Name, $mod.Version, $m.Kind, $m.Path, 'Imported', 'OK')
            } catch {
                Write-Warning "Failed to import '$($m.Name)': $($_.Exception.Message)"
                [FunModuleImportResult]::new(
                    $m.Name, $null, $m.Kind, $m.Path, 'Failed', $_.Exception.Message)
            }
        }
    }
}
#endregion Install
