# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - TBD

### Added

- Function `Get-FilteredFiles` for regex-based file inclusion and exclusion.
- Internal helpers for validation and test support:
  - `Resolve-ValidDirectory`, `ShouldIncludeFile`, `Get-InvokedFilePathsForTest`
  - `New-TestDirectoryWithFiles`, `Remove-TestEnvironment`
- Centralized test utilities in `Helpers.ps1`.
- `IncludeRegex` and `ExcludeRegex` parameters added to:
  - `Invoke-FileTransform`, `Get-FileContents`, and `Copy-FileContents` for consistent, advanced filtering.
- `Invoke-FileTransform` now supports:
  - Multiple paths via array or pipeline input.
  - Enhanced docstring and parameter annotations for discoverability.
- Declared `[OutputType([FileContent])]` on `Get-FileContents`.

### Changed

- Replaced wildcard-based filters with regex-based filtering in all core functions.
- Standardized parameter names and aliases across public functions.
- Refactored `Get-FileContents` to delegate filtering to `Invoke-FileTransform`.
- Refactored test bootstrapping to import `.psd1` instead of `.psm1`, with setup validation in `Setup.ps1`.
- Improved test coverage:
  - Added checks for content accuracy and edge case handling.
- Expanded `README.md` with a table of contents, detailed examples, and modern usage patterns.
- Updated `Get-FileContents` to accept and process **multiple paths** via array or pipeline.

### Renamed

- Renamed `Assertions.psm1` to `Assertions.ps1` to reflect actual script structure and ensure module consistency.

<!-- [unreleased]: https://github.com/r8vnhill/pwsh-fun/compare/v0.0.1...HEAD -->
<!-- [0.0.2]: https://github.com/r8vnhill/pwsh-fun/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/r8vnhill/pwsh-fun/releases/tag/v0.0.1 -->
