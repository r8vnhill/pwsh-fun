# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2025-06-13

### ✨ New Features

- **`New-AndEnterDirectory` function**: Create and navigate into directories in one command.  
  Alias `mdcd` added for convenience.
- **Comic renaming support** in `Rename-StandardMedia`:  
  Includes volume, issue number, and arc metadata for structured naming.
- **Anime episode metadata**:  
  `Rename-StandardMedia` now supports episode number and title formatting.
- **Symlink utility**:  
  Added `Move-AndLinkItem` to move files and replace them with symbolic links.
- **Folder cleanup**:  
  Introduced `Remove-DirectoryContents` to safely empty folders with optional Recycle Bin support.

### 🎧 Audio Tools

- Generalized `Convert-OpusToMp3` into `Convert-AudioToMp3`:
  - Added support for `.m4a`, `.flac`, `.ogg`, `.wav`, and more.
  - Optional `--Cleanup` flag to remove original files.
  - Modularized conversion logic for extensibility.

### 🔐 SSH Tools

- **Install-SSHKey**: Automates remote SSH key setup using `scp` and appends to `authorized_keys`.

### 🧹 Refactors & Internals

- Refactored `Rename-StandardMedia`:
  - Improved parameter order and internal logic.
  - Unified conditional expressions and formatting helpers.
- Modular test infrastructure improvements:
  - Shared test initializers (`Initialize-TestSuite`)
  - Improved assertions and test organization under `tests/` folder.
- Updated module manifests and tags for better discoverability.

### 🐛 Fixes & Maintenance

- Several hotfixes to module loading, formatting, and resolution logic.
- Improved validation for command naming conventions.
- Cleaned up obsolete test files and standardized initialization.

## [0.2.0] - 2025-04-21

### Added

- New command: `Compress-FilteredFiles`
  - Recursively compresses filtered files from one or more directories into a `.zip` archive.
  - Supports `IncludeRegex` / `ExcludeRegex` filters (regex-based).
  - Accepts multiple paths via array or pipeline.
  - Preserves relative folder structure in the archive.
  - Implements `-WhatIf`, `-Confirm`, verbose/debug output, and robust error handling.
  - Returns the archive path or `$null` if no files matched.
- Comprehensive tests for `Compress-FilteredFiles`, covering:
  - Inclusion/exclusion filters
  - Path handling and pipeline input
  - Overwrite behavior and edge cases

### Changed

- Exported `Compress-FilteredFiles` in `Fun.Files.psd1` and `.psm1`.
- Improved `Show-FileContents`:
  - Replaced `Write-Information` with `Write-Host` for header output.
  - Simplified tests to capture output without `Start-Transcript`.

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

[unreleased]: https://github.com/r8vnhill/pwsh-fun/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/r8vnhill/pwsh-fun/releases/tag/v0.3.0
[0.2.0]: https://github.com/r8vnhill/pwsh-fun/releases/tag/v0.2.0
[0.1.0]: https://github.com/r8vnhill/pwsh-fun/releases/tag/v0.1.0
