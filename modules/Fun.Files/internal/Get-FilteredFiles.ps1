function Get-FilteredFiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]    $RootPath,
        [string[]]  $IncludeRegex = @('.*'),
        [string[]]  $ExcludeRegex = @(),
        [string[]]  $IncludeGlob = @(),
        [string[]]  $ExcludeGlob = @(),
        [switch]    $CaseSensitive
    )

    begin {
        try {
            $rootFullPath = [System.IO.Path]::GetFullPath($RootPath)
        } catch {
            throw "RootPath is not valid: $RootPath. Details: $($_.Exception.Message)"
        }

        $regexOptions = [System.Text.RegularExpressions.RegexOptions]::Compiled
        if (-not $CaseSensitive.IsPresent) {
            $regexOptions = $regexOptions -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        }

        $wcOptions = [System.Management.Automation.WildcardOptions]::CultureInvariant
        if (-not $CaseSensitive.IsPresent) {
            $wcOptions = $wcOptions -bor [System.Management.Automation.WildcardOptions]::IgnoreCase
        }
        try { $wcOptions = $wcOptions -bor [System.Management.Automation.WildcardOptions]::Compiled } catch {}

        $compiledIncludeRegex = @()
        foreach ($pat in $IncludeRegex) {
            if ([string]::IsNullOrWhiteSpace($pat)) { continue }
            $compiledIncludeRegex += [regex]::new($pat, $regexOptions)
        }

        $compiledExcludeRegex = @()
        foreach ($pat in $ExcludeRegex) {
            if ([string]::IsNullOrWhiteSpace($pat)) { continue }
            $compiledExcludeRegex += [regex]::new($pat, $regexOptions)
        }

        $compiledIncludeGlob = @()
        foreach ($pat in $IncludeGlob) {
            if ([string]::IsNullOrWhiteSpace($pat)) { continue }
            $compiledIncludeGlob += [System.Management.Automation.WildcardPattern]::new($pat, $wcOptions)
        }

        $compiledExcludeGlob = @()
        foreach ($pat in $ExcludeGlob) {
            if ([string]::IsNullOrWhiteSpace($pat)) { continue }
            $compiledExcludeGlob += [System.Management.Automation.WildcardPattern]::new($pat, $wcOptions)
        }

        function Get-RelativePathNormalized {
            param([string] $Base, [string] $Path)
            try {
                $rel = [System.IO.Path]::GetRelativePath($Base, $Path)
            } catch {
                # Fallback si no está disponible (entornos viejos)
                $baseTrim = $Base.TrimEnd('\', '/')
                $rel = $Path.Substring([Math]::Min($Path.Length, $baseTrim.Length)).TrimStart('\', '/')
            }
            return $rel.Replace('\', '/')
        }

        function Test-IncludeExclude {
            param([string] $RelativePath)

            $inByRegex = $false
            foreach ($rx in $compiledIncludeRegex) {
                if ($rx.IsMatch($RelativePath)) { $inByRegex = $true; break }
            }

            $inByGlob = $false
            foreach ($wc in $compiledIncludeGlob) {
                if ($wc.IsMatch($RelativePath)) { $inByGlob = $true; break }
            }

            $hasAnyInclude = ($compiledIncludeRegex.Count -gt 0) -or ($compiledIncludeGlob.Count -gt 0)
            $included = if ($hasAnyInclude) { $inByRegex -or $inByGlob } else { $true }

            if (-not $included) { return $false }

            foreach ($rx in $compiledExcludeRegex) {
                if ($rx.IsMatch($RelativePath)) { return $false }
            }
            foreach ($wc in $compiledExcludeGlob) {
                if ($wc.IsMatch($RelativePath)) { return $false }
            }

            return $true
        }

        function Test-ExcludeDirectory {
            param([string] $RelativeDir)

            foreach ($rx in $compiledExcludeRegex) {
                if ($rx.IsMatch($RelativeDir)) { return $true }
            }
            foreach ($wc in $compiledExcludeGlob) {
                if ($wc.IsMatch($RelativeDir)) { return $true }
            }
            return $false
        }

        function Get-FolderContent {
            param([string] $CurrentPath)

            $entries = Get-ChildItem -Path $CurrentPath -Force -ErrorAction SilentlyContinue
            foreach ($entry in $entries) {
                if ($entry.PSIsContainer) {
                    $relativeDir = Get-RelativePathNormalized -Base $rootFullPath -Path $entry.FullName
                    if (-not (Test-ExcludeDirectory -RelativeDir $relativeDir)) {
                        Get-FolderContent -CurrentPath $entry.FullName
                    }
                } elseif ($entry -is [System.IO.FileInfo]) {
                    $relativePath = Get-RelativePathNormalized -Base $rootFullPath -Path $entry.FullName
                    if (Test-IncludeExclude -RelativePath $relativePath) {
                        $entry
                    }
                }
            }
        }
    }

    process {
        Get-FolderContent -CurrentPath $rootFullPath
    }
}
