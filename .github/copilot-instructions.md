<!-- .github/copilot-instructions.md for pwsh-fun -->
# Guidance for AI coding agents working on pwsh-fun

This file contains concise, actionable notes to help an AI assistant be productive in this repository.

- Project type: modular PowerShell toolkit. Primary code lives under `modules/` and each module follows a small PowerShell Module layout (`.psd1`, `.psm1`, `public/`, `README.md`).
- Primary modules: `modules/Fun.Files` (file processing utilities) and `modules/Fun.Loader` (dynamic loader/unloader).

Key developer workflows (how humans run and test things):

- Load modules for development:
  - Import `Fun.Loader` then run `Install-FunModules` to load all modules into the current session (uses `Import-Module -Scope Global`). See `modules/Fun.Loader/README.md`.
  - Example: Import-Module ./modules/Fun.Loader/Fun.Loader.psd1 ; Install-FunModules

- Run common commands to exercise functionality:
  - `Show-FileContents -Path './docs'` — prints files with headers and optional color.
  - `Invoke-FileTransform -Path './notes' -IncludeRegex '.*\.md$' -FileProcessor { ... }` — apply transformations to matching files.

Project-specific conventions and patterns the agent should follow or preserve:

- Files and formatting:
  - Use PowerShell 7+ compatible syntax (repository README demands pwsh 7+).
  - Functions support standard PowerShell parameters (`-WhatIf`, `-Confirm`, `-Verbose`) when side-effects occur; preserve that pattern for new commands.

- API/objects:
  - `Get-FileContents` returns custom `[FileContent]`-like objects with `Path`, `Header`, `ContentText` fields — maintain that shape when extending outputs.

- Module layout:
  - Public entrypoints live under each module's `public/` folder and are dot-sourced into the module `.psm1`. Keep new public functions under `public/` and update module manifest `.psd1` if necessary.

Integration points and external dependencies:

- Clipboard usage: several commands call `Set-Clipboard` (`Copy-FileContents`) — be mindful of cross-platform CI where clipboard isn't available and fallback behavior exists.
- Compression: `Compress-FilteredFiles` produces ZIP archives; preserve relative paths and WhatIf support.

Places to read for patterns and examples (must-check files):

- `README.md` (repo root) — project overview and example invocations.
- `modules/Fun.Files/README.md` — canonical examples for `Invoke-FileTransform`, `Show-FileContents`, `Get-FileContents`, `Copy-FileContents`, `Compress-FilteredFiles`.
- `modules/Fun.Loader/README.md` — how modules are loaded/unloaded in development.

Quick heuristics for changes/PRs the agent might author:

- Prefer adding new commands under the appropriate module `public/` folder and wire into `.psm1`/`.psd1`.
- If modifying output objects, update README examples and maintain backward-compatible property names (`Path`, `Header`, `ContentText`).
- Add `-WhatIf`/`-Confirm` where new commands modify filesystem state.

Edge cases and CI hints for tests:

- Tests or CI runs may not have a GUI clipboard; avoid hard failures when calling `Set-Clipboard` by detecting environment or providing a `-NoClipboard` switch.
- Colorized ANSI output is disabled in non-interactive environments — ensure detection uses `$Host.UI.SupportsVirtualTerminal` or equivalent.

If you need more context, read the module READMEs and `Fun.Loader` code to understand how functions are exported and loaded. When in doubt, follow existing command signatures and patterns.

If this file should include more granular coding rules (linting, tests, commit hooks), ask the repo owner for preferred tools — none are detectable in the workspace.

— End of guidance —
