# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- New function `Get-FilteredFiles` for regex-based file inclusion and exclusion.
- New internal helpers: `Resolve-ValidDirectory`, `ShouldIncludeFile`, and `Get-InvokedFilePathsForTest` for validation and testability.
- `IncludeRegex` and `ExcludeRegex` parameters to `Invoke-FileTransform`, `Get-FileContents`, and `Copy-FileContents` for consistent, advanced filtering.
- Utility functions `New-TestDirectoryWithFiles` and `Remove-TestEnvironment` for improved test setup and teardown.
- New internal test script `Helpers.ps1` to centralize reusable test utilities.
- Additional tests for `Get-FileContents`, `Invoke-FileTransform`, and `Show-FileContents` covering filtering, directory validation, and error cases.

### Changed

- Refactored `Invoke-FileTransform`, `Get-FileContents`, and `Copy-FileContents` to use regular-expression-based filtering instead of wildcard patterns.
- Standardized parameter names and aliases across all public commands for consistency (`IncludeRegex`, `ExcludeRegex`).
- Simplified internal logic in `Get-FileContents` by delegating file selection to `Invoke-FileTransform`.
- Modernized test structure by importing `.psd1` instead of `.psm1`, with improved setup validation in `Setup.ps1`.
- Updated `README.md` usage examples to reflect regex-based filtering and revised descriptions for clarity and accuracy.

### Renamed

- Renamed `Assertions.psm1` back to `Assertions.ps1` to reflect actual script structure and resolve module consistency issues.

<!-- ### Added

- v1.1 Brazilian Portuguese translation.
- v1.1 German Translation
- v1.1 Spanish translation.
- v1.1 Italian translation.
- v1.1 Polish translation.
- v1.1 Ukrainian translation.

### Changed

- Use frontmatter title & description in each language version template
- Replace broken OpenGraph image with an appropriately-sized Keep a Changelog 
  image that will render properly (although in English for all languages)
- Fix OpenGraph title & description for all languages so the title and 
description when links are shared are language-appropriate

### Removed

- Trademark sign previously shown after the project description in version 
0.3.0 -->

<!-- ## [0.0.1] - 2014-05-31

### Added

- This CHANGELOG file to hopefully serve as an evolving example of a
  standardized open source project CHANGELOG.
- CNAME file to enable GitHub Pages custom domain.
- README now contains answers to common questions about CHANGELOGs.
- Good examples and basic guidelines, including proper date formatting.
- Counter-examples: "What makes unicorns cry?". -->

<!-- [unreleased]: https://github.com/r8vnhill/pwsh-fun/compare/v0.0.1...HEAD -->
<!-- [0.0.2]: https://github.com/r8vnhill/pwsh-fun/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/r8vnhill/pwsh-fun/releases/tag/v0.0.1 -->
