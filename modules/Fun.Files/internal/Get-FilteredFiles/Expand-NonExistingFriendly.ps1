# function Expand-NonExistingFriendly {
#     [CmdletBinding()]
#     [OutputType([string])]
#     param(
#         [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
#         [Alias('FullName')]
#         [string[]] $Path,

#         [Parameter()]
#         [string] $UserHome,

#         [Parameter()]
#         [switch] $NoEnv,

#         [Parameter()]
#         [switch] $NoTilde,

#         [Parameter()]
#         [switch] $NormalizeSeparators
#     )

#     begin {
#         $UserHome = Get-EffectiveUserHome -UserHome $UserHome -NoTilde:$NoTilde

#         # Pre-create regex for leading '~' to ensure culture-invariant & compiled behavior
#         $tildeRegex = [System.Text.RegularExpressions.Regex]::new(
#             pattern = '^(~)(?=([\\/]|$))',
#             options = [System.Text.RegularExpressions.RegexOptions]::CultureInvariant -bor `
#                 [System.Text.RegularExpressions.RegexOptions]::Compiled
#         )
#     }

#     process {
#         foreach ($p in $Path) {
#             if ($null -eq $p) {
#                 continue
#             }
#             try {
#                 $expanded = [string]$p

#                 # 1) Environment expansion (if enabled)
#                 if (-not $NoEnv) {
#                     # Only call when useful to avoid overhead
#                     if ($expanded -like '*%*') {
#                         $expanded = [System.Environment]::ExpandEnvironmentVariables($expanded)
#                     }
#                     # Note: $env:VAR is expanded by PowerShell in double-quoted strings,
#                     # but not necessarily for single-quoted or programmatic inputs. The above covers %VAR%.
#                 }

#                 # 2) Leading '~' expansion (if enabled and home is available)
#                 if (-not $NoTilde -and -not [string]::IsNullOrWhiteSpace($UserHome)) {
#                     if ($tildeRegex.IsMatch($expanded)) {
#                         # Use Regex.Replace so we can inject the literal Home safely
#                         $expanded = $tildeRegex.Replace($expanded,
#                             [System.Text.RegularExpressions.Regex]::Escape($UserHome))
#                     }
#                 }

#                 # 3) Optional separator normalization (be conservative by default)
#                 if ($NormalizeSeparators) {
#                     $ds = [System.IO.Path]::DirectorySeparatorChar
#                     $ads = [System.IO.Path]::AltDirectorySeparatorChar

#                     # Avoid breaking extended path prefixes (\\?\ or //?/).
#                     # Simple heuristic: if it starts with \\?\ or //?/, skip normalization.
#                     if ($expanded -notmatch '^(\\\\\?\\|//\?/)' ) {
#                         # Replace only the "other" separator with the platform default
#                         if ($ds -eq '\') {
#                             # Windows: turn forward slashes into backslashes
#                             $expanded = $expanded -replace '/', '\'
#                         } else {
#                             # Unix-like: turn backslashes into slashes
#                             $expanded = $expanded -replace '\\', '/'
#                         }
#                     }
#                 }

#                 $expanded
#             } catch {
#                 $err = New-Object System.Management.Automation.ErrorRecord `
#                 ($_.Exception), 'ExpandNonExistingFriendlyFailed', `
#                     [System.Management.Automation.ErrorCategory]::InvalidOperation, $p
#                 throw $err
#             }
#         }
#     }
# }
