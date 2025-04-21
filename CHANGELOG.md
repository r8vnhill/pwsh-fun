# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- New function `Get-FilteredFiles` for regex-based file inclusion and exclusion.
- New helper functions `Resolve-ValidDirectory` and `ShouldIncludeFile` to support robust validation and filtering.
- `IncludeRegex` and `ExcludeRegex` parameters to `Invoke-FileTransform` for advanced filtering capabilities.
- Comprehensive tests for `Invoke-FileTransform` covering inclusion/exclusion behavior and edge cases.

### Changed

- Enhanced `Invoke-FileTransform` to support customizable file filtering via regex patterns.
- Refactored `Invoke-FileTransform` to use modular internal helpers for readability and testability.
- Improved documentation and inline examples in `README.md` for all public functions.
- Simplified and modernized examples for `Show-FileContents`, `Get-FileContents`, and `Copy-FileContents`.
- Improved consistency and clarity of function descriptions and parameter explanations.

### Renamed

- Renamed `Assertions.ps1` to `Assertions.psm1` to align with module naming conventions.

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
