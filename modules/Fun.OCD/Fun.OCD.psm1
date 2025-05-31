function Import-FunOCDScripts {
    [CmdletBinding()]
    param ()

    # Locate “public” folder relative to this module
    $moduleFolder = $PSScriptRoot
    $publicFolder = Join-Path $moduleFolder 'public'

    if (-not (Test-Path $publicFolder)) {
        Write-Verbose "No 'public' folder at $publicFolder; skipping."
        return
    }

    Get-ChildItem -Path $publicFolder -Filter '*.ps1' -File |
        ForEach-Object {
            try {
                Write-Verbose "Dot-sourcing $($_.FullName)"
                . $_.FullName
            }
            catch {
                Write-Warning "Fun.OCD: failed to load '$($_.FullName)': $($_.Exception.Message)"
            }
        }
}

# When the module is imported, run the helper to load everything under “public\*.ps1”
Import-FunOCDScripts
