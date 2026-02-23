# Install-FunModules.ps1
#Requires -Version 7.0
Set-StrictMode -Version Latest

#region Types
<#
.SYNOPSIS
  Kind of module entry found under /modules.

.DESCRIPTION
  Distinguishes how a module is represented on disk:

  - Manifest  → The module folder contains a <Name>.psd1 manifest file.
                Preferred, since manifests control metadata and exports.
  - Script    → The module folder only contains a <Name>.psm1 script module file.

  This enum is used by [FunModuleRef] and related helpers to describe which file was chosen when resolving a module folder.
#>
enum ModuleKind {
    Manifest
    Script
}

<#
.SYNOPSIS
  Typed reference to a module candidate under /modules.

.DESCRIPTION
  Represents the resolution of a module folder into its usable definition file.
  A FunModuleRef captures three key pieces of information:
  
  - Name → The folder/module name.
  - Path → The full path to the .psd1 (manifest) or .psm1 (script) file.
  - Kind → Which type of definition file was chosen (see [ModuleKind]).

  This class enforces non-empty Name and Path at construction time, ensuring that only valid references are created.
  It is consumed by Get-FunModuleFiles and Install-FunModules to manage discovery and import.

.PROPERTIES
  [string]     Name  → Folder/module name.
  [string]     Path  → Full path to .psd1 or .psm1.
  [ModuleKind] Kind  → Manifest | Script.

.METHODS
  [string] ToString()
    Returns a readable representation in the form "<Name> (<Kind>) -> <Path>".

  hidden static [bool] MatchesAny([string] value, [string[]] patterns)
    Utility to test if a string matches any wildcard pattern.
    Used to honor Exclude lists when discovering modules.

  static [FunModuleRef] TryFromDir([System.IO.DirectoryInfo] dir)
    Given a module folder, tries to resolve the best file:
      * Returns Manifest if <Name>.psd1 exists.
      * Else returns Script if <Name>.psm1 exists.
      * Returns $null if neither is found.

.EXAMPLE
  # Construct a ref explicitly
  $ref = [FunModuleRef]::new(
      'Alpha',
      'C:\Repos\pwsh-fun\modules\Alpha\Alpha.psd1',
      [ModuleKind]::Manifest
  )
  $ref.ToString()
  # => Alpha (Manifest) -> C:\Repos\pwsh-fun\modules\Alpha\Alpha.psd1

.EXAMPLE
  # Resolve a folder automatically
  $dir = Get-Item 'C:\Repos\pwsh-fun\modules\Beta'
  [FunModuleRef]::TryFromDir($dir)
  # => Beta (Script) -> C:\Repos\pwsh-fun\modules\Beta\Beta.psm1

.LINK
  Get-FunModuleFiles
  Install-FunModules
#>
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

<#
.SYNOPSIS
  Result record for an attempted module import.

.DESCRIPTION
  Represents the outcome of calling Install-FunModules on a discovered module.
  A FunModuleImportResult captures:
    - Which module was attempted (Name, Path, Kind).
    - What version (if any) was reported by Import-Module.
    - The status string (e.g. 'Imported' or 'Failed').
    - An optional message with details (e.g. 'OK' or an error message).

  This type allows Install-FunModules to return a strongly typed, testable collection of results instead of loose hashtables or PSCustomObjects.

.PROPERTIES
  [string]     Name     → Module name (folder).
  [Version]    Version  → Imported module version (null if failed).
  [ModuleKind] Kind     → Manifest | Script.
  [string]     Path     → Full path to the attempted module file.
  [string]     Status   → 'Imported' | 'Failed'.
  [string]     Message  → Additional detail (e.g., 'OK' or error text).

.METHODS
  [string] ToString()
    Formats a short string in the form:
    "<Name> <Version> [<Status>] - <Path>"

.EXAMPLE
  # Successful import result
  $r = [FunModuleImportResult]::new(
      'Alpha',
      [version]'1.0.0',
      [ModuleKind]::Manifest,
      'C:\Repos\pwsh-fun\modules\Alpha\Alpha.psd1',
      'Imported',
      'OK'
  )
  $r.ToString()
  # => Alpha 1.0.0 [Imported] - C:\Repos\pwsh-fun\modules\Alpha\Alpha.psd1

.EXAMPLE
  # Failed import result
  $r = [FunModuleImportResult]::new(
      'Beta',
      $null,
      [ModuleKind]::Script,
      'C:\Repos\pwsh-fun\modules\Beta\Beta.psm1',
      'Failed',
      'Module file not found'
  )
  $r.ToString()
  # => Beta  [Failed] - C:\Repos\pwsh-fun\modules\Beta\Beta.psm1

.LINK
  Install-FunModules
  FunModuleRef
#>
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
<#
.SYNOPSIS
  Discovers module definition files (.psd1 preferred, else .psm1) under /modules.

.DESCRIPTION
  Scans the immediate subfolders of <BasePath>\modules and emits a typed [FunModuleRef] per folder.
  A folder is considered a module when it contains:
    - <Name>.psd1  (preferred → Kind = Manifest), or
    - <Name>.psm1  (fallback  → Kind = Script)

  Folders without either file are skipped.
  Folders that match any pattern in -Exclude are also skipped.
  The function is quiet by default but uses Write-Verbose to explain why items are skipped.

  The default for -BasePath is computed at runtime (three levels up from the current file) to avoid Resolve-Path failures during parse time.

.PARAMETER BasePath
  Repository root path (the folder that contains the 'modules' directory).
  If not supplied, it is resolved at runtime as:
    (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

.PARAMETER Exclude
  One or more wildcard patterns used to exclude folder names from discovery.
  Defaults to: '*Fun.OCD*', '.git', and '_*'.

.OUTPUTS
  FunModuleRef
    One object per discovered module with Name, Path, and Kind.

.EXAMPLE
  Get-FunModuleFiles
  # Uses the default BasePath and yields FunModuleRef objects for each module.

.EXAMPLE
  Get-FunModuleFiles -BasePath 'C:\Repos\pwsh-fun' -Exclude '*Experimental*','_legacy'
  # Discovers modules under the given repo while excluding specific folders.

.EXAMPLE
  Get-FunModuleFiles | Where-Object Kind -eq ([ModuleKind]::Manifest)
  # Filters discovered modules to only those backed by a manifest.

.NOTES
  - Uses -LiteralPath for safety (no wildcard expansion).
  - Emits nothing if <BasePath>\modules does not exist.
  - Relies on FunModuleRef.MatchesAny() and FunModuleRef.TryFromDir() for consistent exclusion and file resolution logic.

.LINK
  FunModuleRef
  Install-FunModules
#>
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
            if ($ref) { 
                $ref 
            }
            else { 
                Write-Verbose "Skipping '$($_.Name)' (no matching .psd1/.psm1)." 
            }
        }
}
#endregion Discovery

#region Install
<#
.SYNOPSIS
  Imports all modules discovered under <BasePath>\modules (or those piped in).

.DESCRIPTION
  Installs modules for the current session. You can:
    - Pipe in one or more [FunModuleRef] objects, OR
    - Let the function discover modules via Get-FunModuleFiles (-BasePath / -Exclude).

  For each module reference, Import-Module is invoked with the requested -Scope.
  The function is ShouldProcess-aware, so it supports -WhatIf and -Confirm.
  Returns a stream of [FunModuleImportResult] describing success/failure.

.PARAMETER Module
  One or more [FunModuleRef] objects (ValueFromPipeline).
  When supplied, discovery is skipped and only the provided entries are imported.

.PARAMETER BasePath
  Repository root (the folder containing 'modules').
  Used only when nothing is piped and the function needs to discover modules (delegates to Get-FunModuleFiles).

.PARAMETER Exclude
  Wildcard folder names to exclude during discovery (only applies when discovering).

.PARAMETER Scope
  Import scope for Import-Module.
  Use 'Global' to expose commands in the caller’s session (default), or 'Local' to keep them scoped to the current module/script.

.OUTPUTS
  FunModuleImportResult
    One object per attempted import with Name, Version, Kind, Path, Status, Message.

.EXAMPLE
  # Discover then import (default BasePath & exclusions)
  Install-FunModules -Verbose

.EXAMPLE
  # Pipe explicit module references (skips discovery)
  Get-FunModuleFiles -BasePath 'C:\Repos\pwsh-fun' | Install-FunModules -Scope Local

.EXAMPLE
  # See what would be imported without making changes
  Install-FunModules -WhatIf

.LINK
  Get-FunModuleFiles
  FunModuleRef
  FunModuleImportResult
#>
function Install-FunModules {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        [Parameter(ValueFromPipeline)]
        [FunModuleRef[]] $Module,

        [string]   $BasePath,

        [string[]] $Exclude = @('*Fun.OCD*'),

        [ValidateSet('Global', 'Local')]
        [string]   $Scope = 'Global'
    )

    begin {
        # Collect all work items (pipeline + discovered) before importing.
        $refs = New-Object System.Collections.Generic.List[FunModuleRef]
        # Track whether we received any pipeline input.
        $hadInput = $false

        # Compute default BasePath at runtime to avoid Resolve-Path throwing at parse time
        if (-not $PSBoundParameters.ContainsKey('BasePath')) {
            $BasePath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
        }
    }

    process {
        # Pipeline path: just queue up provided refs.
        if ($Module) {
            $hadInput = $true
            foreach ($m in $Module) { [void]$refs.Add($m) }
        }
    }

    end {
        # Discovery path: only when nothing was piped in.
        if (-not $hadInput) {
            foreach ($m in (Get-FunModuleFiles -BasePath:$BasePath -Exclude:$Exclude)) {
                [void]$refs.Add($m)
            }
        }

        # Import each queued module reference.
        foreach ($m in $refs) {
            # Nice ShouldProcess target text (shows up in -WhatIf/-Confirm).
            $target = "$($m.Name) ($($m.Kind))"
            if (-not $PSCmdlet.ShouldProcess($target, 'Import-Module')) { continue }

            try {
                Write-Verbose "Importing $($m.Name) from $($m.Path) [Scope=$Scope]"

                # Use -Name even for paths (supported) to maximize compatibility.
                # -PassThru returns the module info so we can record Version.
                $mod = Import-Module -Name $m.Path -Force -Scope $Scope -PassThru -ErrorAction Stop

                # Emit a typed success record the caller/tests can assert on.
                [FunModuleImportResult]::new(
                    $m.Name, $mod.Version, $m.Kind, $m.Path, 'Imported', 'OK'
                )
            }
            catch {
                # Keep going on failure, but surface a warning and return a result.
                Write-Warning "Failed to import '$($m.Name)': $($_.Exception.Message)"
                [FunModuleImportResult]::new(
                    $m.Name, $null, $m.Kind, $m.Path, 'Failed', $_.Exception.Message
                )
            }
        }
    }
}
#endregion Install
