#Requires -Version 7.0
<#
.SYNOPSIS
    Fun.Files module bootstrap: loads internal scripts (not exported) and public scripts,
    then exports public functions/aliases.

.DESCRIPTION
    - Dot-sources every .ps1 script under ./internal (recursively). These are private
      helpers and are NOT exported.
    - Dot-sources every .ps1 script under ./public (recursively), discovers function names
      using the AST, and exports only those functions (and any aliases that map to them).
    - Uses deterministic load order and strict mode for predictability and
      maintainability.

.NOTES
    This file intentionally avoids writing to the pipeline to keep module import clean.
    Use -Verbose with Import-Module to see the loading details.
#>

Set-StrictMode -Version Latest

Write-Verbose "Initializing Fun.Files module from: $PSScriptRoot"

<#
.SYNOPSIS
    Dot-sources a script and suppresses accidental output.
.DESCRIPTION
    Executes a .ps1 file in the current scope, discarding any output the script may emit,
    and throws a descriptive error on failure.
.PARAMETER Path
    Full path to the .ps1 script to dot-source.
#>
function Invoke-DotSourceSafe {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )
    try {
        Write-Verbose "Dot-sourcing: $Path"
        $null = . $Path
    } catch {
        throw "Error importing script: '$Path'. Details: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Extracts function names defined in a .ps1 file without executing it.
.DESCRIPTION
    Uses the PowerShell parser (AST) to find FunctionDefinitionAst nodes and returns their
    names.
.PARAMETER Path
    Full path to the .ps1 file to analyze.
#>
function Get-FunctionNamesFromFile {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )
    try {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $Path, [ref]$tokens, [ref]$errors
        )

        if ($errors -and $errors.Count -gt 0) {
            Write-Verbose "Warning: The parser detected errors in '$Path'."
        }

        $funcAsts = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
            }, $true)

        foreach ($func in $funcAsts) {
            # Return function names as declared
            $func.Name
        }
    } catch {
        throw (
            "Could not parse '{0}' with the PowerShell parser. Details: {1}" `
                -f $Path, $_.Exception.Message
        )
    }
}

# --- Load internal scripts (private helpers; NOT exported) ---
$internalRoot = Join-Path $PSScriptRoot 'internal'
if (Test-Path -Path $internalRoot) {
    Get-ChildItem -Path $internalRoot -Filter '*.ps1' -File -Recurse |
        Sort-Object FullName | # deterministic load order
        ForEach-Object {
            Invoke-DotSourceSafe -Path $_.FullName
        }
} else {
    Write-Verbose "No internal folder found at $internalRoot (skipping)."
}

# --- Load public scripts and collect functions/aliases to export ---
$publicRoot = Join-Path $PSScriptRoot 'public'
$publicFunctions = @()
$publicAliases = @()

if (Test-Path -Path $publicRoot) {
    $publicScripts = Get-ChildItem -Path $publicRoot -Filter '*.ps1' -File -Recurse | `
            Sort-Object Name

    foreach ($script in $publicScripts) {
        # Discover function names BEFORE execution (avoids relying on conventions)
        $fnNames = Get-FunctionNamesFromFile -Path $script.FullName

        # Load the script (functions become available in the module scope)
        Invoke-DotSourceSafe -Path $script.FullName

        # Verify that discovered functions are now defined and collect them
        foreach ($name in $fnNames) {
            if (Get-Command `
                    -Name $name `
                    -CommandType Function `
                    -ErrorAction SilentlyContinue
            ) {
                $publicFunctions += $name
            } else {
                Write-Verbose "Function '{0}' was not found after dot-sourcing '{1}'." `
                    -f $name, $script.FullName
            }
        }

        # Export aliases that point to these functions
        foreach ($fn in $fnNames) {
            $aliasesForFn = Get-Alias -ErrorAction SilentlyContinue | Where-Object {
                $_.Definition -eq $fn
            }
            if ($aliasesForFn) {
                $publicAliases += $aliasesForFn.Name
            }
        }
    }
} else {
    Write-Verbose "No public folder found at $publicRoot (skipping)."
}

# De-duplicate and export public members
$publicFunctions = $publicFunctions | Sort-Object -Unique
$publicAliases = $publicAliases | Sort-Object -Unique

if ($publicFunctions.Count -gt 0 -or $publicAliases.Count -gt 0) {
    Export-ModuleMember -Function $publicFunctions -Alias $publicAliases
} else {
    Write-Verbose 'No public functions or aliases found to export.'
}
