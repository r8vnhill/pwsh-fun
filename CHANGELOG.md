# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - TBD

### Added

- New command: `Compress-FilteredFiles`
  - Compresses filtered files from one or more directories into a `.zip` archive.
  - Supports regex-based `IncludeRegex` and `ExcludeRegex` filters.
  - Accepts multiple paths via array or pipeline input.
  - Preserves relative folder structure in archive.
  - Includes `-WhatIf`, `-Confirm`, verbose/debug output, and proper error handling.
  - Returns the path to the created archive or `$null` if no files matched.
- Tests for `Compress-FilteredFiles`, covering matching, exclusion, path resolution, overwrite behavior, and edge cases.

### Changed

- Exported `Compress-FilteredFiles` in `Fun.Files.psd1` and `.psm1`.
- Updated `Show-FileContents`:
  - Simplified header output using `Write-Host` instead of `Write-Information`.
  - Adjusted tests to capture console output without using `Start-Transcript`.

## [0.1.0] - 2025-04-21

### Added

- Regex-based filtering via `IncludeRegex` and `ExcludeRegex` parameters in:
  - `Invoke-FileTransform`, `Get-FileContents`, and `Copy-FileContents`.
- Support for multiple paths (array and pipeline input) in:
  - `Invoke-FileTransform`, `Get-FileContents`, `Show-FileContents`, and `Copy-FileContents`.
- Return value support in `Copy-FileContents`: outputs formatted strings copied to the clipboard.
- ANSI-colored output (headers in cyan, content in gray) in `Show-FileContents` when supported.
- Internal helpers and utilities:
  - `Resolve-ValidDirectory`, `ShouldIncludeFile`, `Get-InvokedFilePathsForTest`
  - `New-TestDirectoryWithFiles`, `Remove-TestEnvironment`, `Format-Cyan`, `Format-Gray`
  - Centralized in `Helpers.ps1`
- Declared `[OutputType([FileContent])]` for `Get-FileContents`.

### Changed

- Replaced wildcard-based filtering with regex-based matching throughout.
- Standardized parameter names and aliases across all commands.
- Refactored:
  - `Get-FileContents` to delegate to `Invoke-FileTransform`
  - `Copy-FileContents` to accumulate input across pipeline stages
  - Test bootstrapping to load `.psd1` with validation
- Improved test coverage:
  - Content accuracy, edge case handling, and output capture with `Start-Transcript`.
- Enhanced documentation:
  - Added full usage examples, pipelining patterns, and a table of contents to `README.md`.
  - Clarified terminal color support and header formatting behavior.

### Renamed

- `Assertions.psm1` → `Assertions.ps1` to match file structure and module loading expectations.

[unreleased]: https://github.com/r8vnhill/pwsh-fun/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/r8vnhill/pwsh-fun/releases/tag/v0.1.0
<!-- [0.0.2]: https://github.com/r8vnhill/pwsh-fun/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/r8vnhill/pwsh-fun/releases/tag/v0.0.1 -->
