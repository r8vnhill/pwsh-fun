[CmdletBinding()]
param(
    [string] $Settings = "$PSScriptRoot/../PSScriptAnalyzerSettings.psd1",
    [string[]] $Paths = @(
        "$PSScriptRoot/../modules",
        "$PSScriptRoot/../scripts",
        "$PSScriptRoot/../tests"
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Install-PSScriptAnalyzerIfMissing {
    # Already available?
    if (Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue) {
        return
    }

    Write-Host 'PSScriptAnalyzer not found. Installing...' 

    # Make sure TLS 1.2 is used for PSGallery over HTTPS
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    } catch {
        Write-Warning "Failed to set TLS 1.2: $_"
    }

    # Prefer PSResourceGet if available (PowerShellGet v3)
    if (Get-Command Install-PSResource -ErrorAction SilentlyContinue) {
        # Ensure PSGallery is registered
        if (-not (Get-PSResourceRepository -ErrorAction SilentlyContinue | 
                    Where-Object Name -EQ 'PSGallery')) {
            Register-PSResourceRepository -Name PSGallery `
                -Uri 'https://www.powershellgallery.com/api/v2' -Trusted
        }
        Install-PSResource PSScriptAnalyzer -Scope CurrentUser -TrustRepository -Quiet
    } else {
        # Fallback to PowerShellGet v2
        if (-not (Get-Module -ListAvailable PowerShellGet)) {
            Write-Host 'PowerShellGet not found; attempting to install/update...' 
            # Try to get PowerShellGet using the in-box bootstrap
            Install-Module PowerShellGet -Scope CurrentUser -Force -AllowClobber `
                -ErrorAction SilentlyContinue
        }
        if (-not (Get-PSRepository -ErrorAction SilentlyContinue | Where-Object Name -EQ 'PSGallery')) {
            Register-PSRepository -Name PSGallery `
                -SourceLocation 'https://www.powershellgallery.com/api/v2' `
                -InstallationPolicy Trusted
        }
        Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -AllowClobber
    }

    Import-Module PSScriptAnalyzer -Force
    if (-not (Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue)) {
        throw 'PSScriptAnalyzer installation/import failed.'
    }
}

# --- main ---
if (-not (Test-Path -LiteralPath $Settings)) {
    throw "Settings file not found: $Settings"
}

Write-Host 'Running PSScriptAnalyzer...'
Write-Host "Settings: $Settings"
Write-Host "Paths: $($Paths -join ', ')"

Install-PSScriptAnalyzerIfMissing

$allResults = @()
foreach ($p in $Paths) {
    if (-not (Test-Path -LiteralPath $p)) { continue }
    $rp = (Resolve-Path -LiteralPath $p).Path  # normalize to a single [string]
    Write-Host "Analyzing: $rp"
    $res = Invoke-ScriptAnalyzer -Path $rp -Settings $Settings -Recurse -ErrorAction Stop
    if ($res) { $allResults += $res }
}

# Pretty print + fail on errors
if ($allResults) {
    $allResults |
        Sort-Object Severity, RuleName, ScriptName, Line |
        Format-Table Severity, RuleName, ScriptName, Line, Message -Auto

    if ($allResults.Where({ $_.Severity -eq 'Error' }).Count -gt 0) { exit 1 }
    else { Write-Warning "PSScriptAnalyzer found warnings/information." }
}
else {
    Write-Host "No issues found. ✅"
}
