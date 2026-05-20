# [PLAN] Split `Convert-ToVvc` Domain Tests

## Summary

Split the current monolithic `Convert-ToVvc.Domain.Tests.ps1` into smaller concern-based files without changing
production code, assertions, test data, or load semantics.

This is a **test-only mechanical refactor**. The production type module remains untouched. The goal is to reduce
test-file size and make the domain contract easier to navigate while preserving the existing Phase 1 / domain-foundation
coverage. The larger roadmap already treats these domain types as isolated, side-effect-free contracts before
orchestration and native-process work begins.

## Completion

Implemented as eight focused files under `tests/Fun.Ffmpeg`:

- `Convert-ToVvc.Domain.Enums.Tests.ps1`
- `Convert-ToVvc.Domain.NativeResult.Tests.ps1`
- `Convert-ToVvc.Domain.PathSet.Tests.ps1`
- `Convert-ToVvc.Domain.Request.Tests.ps1`
- `Convert-ToVvc.Domain.MediaProbe.Tests.ps1`
- `Convert-ToVvc.Domain.OutputValidation.Tests.ps1`
- `Convert-ToVvc.Domain.Result.Tests.ps1`
- `Convert-ToVvc.Domain.Decision.Tests.ps1`

The monolithic `Convert-ToVvc.Domain.Tests.ps1` file was removed to avoid duplicate discovery.

One test assertion was aligned with the current domain contract during the split: blank diagnostics for invalid output
validation normalize to `$null` rather than throwing.

## Scope

### Included

- Split domain tests by type or closely related concept.
- Preserve parse-time class and enum loading.
- Preserve current assertions.
- Preserve current fixture values.
- Preserve existing `Describe` / `Context` names where practical.
- Verify that every original context appears in exactly one new file.

### Excluded

- Production changes to `ConvertToVvc.Types.psm1`.
- Public command tests.
- integration tests.
- worker tests.
- native-process tests.
- assertion rewrites.
- behavior changes.
- new result-contract decisions.

---

## Recommended File Split

Prefer one file per domain concern rather than one large “request/path/native/probe/validation” file. The point of the
split is navigability.

Recommended target structure:

```text
tests/Fun.Ffmpeg/
  Convert-ToVvc.Domain.Enums.Tests.ps1
  Convert-ToVvc.Domain.NativeResult.Tests.ps1
  Convert-ToVvc.Domain.PathSet.Tests.ps1
  Convert-ToVvc.Domain.Request.Tests.ps1
  Convert-ToVvc.Domain.MediaProbe.Tests.ps1
  Convert-ToVvc.Domain.OutputValidation.Tests.ps1
  Convert-ToVvc.Domain.Result.Tests.ps1
  Convert-ToVvc.Domain.Decision.Tests.ps1
```

Suggested mapping:

| Destination file                                  | Move these concerns                                                                                    |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `Convert-ToVvc.Domain.Enums.Tests.ps1`            | `VvcConversionStatus`, `VvcConversionAction`, `VvcConversionReason`, `VvcConversionInvariantException` |
| `Convert-ToVvc.Domain.NativeResult.Tests.ps1`     | `VvcNativeResult`                                                                                      |
| `Convert-ToVvc.Domain.PathSet.Tests.ps1`          | `VvcConversionPathSet`                                                                                 |
| `Convert-ToVvc.Domain.Request.Tests.ps1`          | `VvcConversionRequest`                                                                                 |
| `Convert-ToVvc.Domain.MediaProbe.Tests.ps1`       | `VvcMediaProbe`                                                                                        |
| `Convert-ToVvc.Domain.OutputValidation.Tests.ps1` | `VvcOutputValidation`                                                                                  |
| `Convert-ToVvc.Domain.Result.Tests.ps1`           | `ConvertToVvcResult`                                                                                   |
| `Convert-ToVvc.Domain.Decision.Tests.ps1`         | `VvcConversionDecision`                                                                                |

This is clearer than grouping many value objects into `Convert-ToVvc.Request.Tests.ps1`, because request, path, native
result, probe, and validation each represent a separate contract.

---

## Step 1 — Freeze the Current Test Inventory

Before moving anything, capture the current top-level test structure.

Recommended command:

```powershell
Invoke-Pester `
    -Path tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1 `
    -PassThru
```

Also manually note every current `Describe` and `Context`.

The split should preserve the same logical inventory. Minor file names can change, but no domain concern should
disappear.

**Done when:**

- The current monolithic file passes.
- You have a list of every original `Describe` / `Context`.
- The refactor starts from a green test state.

---

## Step 2 — Preserve Parse-Time Type Loading in Every New File

Every split file that directly references classes or enums must keep a top-level `using module`.

Example:

```powershell
using module ..\..\modules\Fun.Ffmpeg\internal\ConvertToVvc.Types.psm1
```

Do not replace this with only `Import-Module` inside `BeforeAll` when the file contains type literals such as:

```powershell
[VvcConversionRequest]
[VvcMediaProbe]
[VvcOutputValidation]
[VvcConversionReason]
```

PowerShell resolves class and enum literals at parse time, so each split file needs its own `using module`.

**Done when:**

- Every new domain test file with type literals has a top-level `using module`.
- Files can be run independently with `Invoke-Pester -Path <file>`.
- No file depends on another test file being loaded first.

---

## Step 3 — Move One Concern at a Time

Perform the split incrementally.

Recommended order:

```text
1. Enums and invariant exception
2. Native result
3. Path set
4. Request
5. Media probe
6. Output validation
7. Result factories
8. Decision type
```

After each move, run the new file directly.

Example:

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.Domain.MediaProbe.Tests.ps1
```

Then run all split domain files:

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.Domain.*.Tests.ps1
```

**Done when:**

- Each concern has moved into its destination file.
- The moved file passes independently.
- The combined split domain suite passes.

---

## Step 4 — Keep Assertions Mechanically Identical

During the split, do not improve assertions, rename examples, change fake data, or rewrite object construction unless
required by the file move.

Avoid these during the first pass:

```text
renaming test cases
changing diagnostics
changing enum assertions
changing helper names
introducing new factories
rewriting repeated construction literals
reordering assertions inside examples
```

The diff should show mostly:

```text
removed blocks from old file
added same blocks to new files
added using module lines
```

Use Gintama-themed fake data only if a moved test already needs a new fixture value because of an unavoidable extraction
issue. Otherwise keep existing literals unchanged.

**Done when:**

- Reviewers can see this is a file-organization change.
- No behavior or coverage decision is mixed into the refactor.

---

## Step 5 — Avoid Shared Support on the First Split

Do not introduce a support file immediately.

Prefer temporary duplication such as:

```powershell
$inputPath = 'C:\Yorozuya\input.mkv'
$outputPath = 'C:\Yorozuya\output.mkv'
```

over a new shared helper.

Only add a support file later if repeated setup becomes genuinely noisy across multiple files.

If needed later, use something like:

```text
tests/Fun.Ffmpeg/Support/ConvertToVvc.Domain.TestSupport.ps1
```

But keep that as a second refactor, not part of the mechanical split.

**Done when:**

- The first split has no new support abstraction unless absolutely necessary.
- Each test file remains understandable on its own.

---

## Step 6 — Retire or Shrink the Original File

After every context has moved, choose one of these options:

### Preferred option: remove the original file

Delete:

```text
tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1
```

This avoids duplicate discovery and double-running the same tests.

### Alternative: keep a tiny index file

Only keep it if your project convention expects that file to exist, but do not leave duplicate tests inside it.

For example, it could contain only a comment pointing to the split files. Usually, deletion is cleaner.

**Done when:**

- No tests are duplicated.
- No old context remains in the monolithic file.
- Pester does not discover duplicate examples.

---

## Step 7 — Verify No Context Was Lost

Use a simple before/after checklist.

Original concerns that must appear exactly once:

```text
Vvc conversion enums
VvcConversionInvariantException
VvcNativeResult
VvcConversionPathSet
VvcConversionRequest
VvcMediaProbe
VvcOutputValidation
ConvertToVvcResult
VvcConversionDecision
```

Optional grep checks:

```powershell
Select-String `
    -Path tests/Fun.Ffmpeg/Convert-ToVvc.Domain*.Tests.ps1 `
    -Pattern "Describe|Context" |
    ForEach-Object Line
```

And to detect accidental duplication:

```powershell
Select-String `
    -Path tests/Fun.Ffmpeg/Convert-ToVvc.Domain*.Tests.ps1 `
    -Pattern "Describe '" |
    Group-Object Line |
    Where-Object Count -gt 1
```

**Done when:**

- Every original concern appears in one destination file.
- No concern appears in multiple files accidentally.
- No test was dropped during the move.

---

## Verification

Run each split file directly at least once:

```powershell
Get-ChildItem tests/Fun.Ffmpeg/Convert-ToVvc.Domain*.Tests.ps1 |
    ForEach-Object {
        Invoke-Pester -Path $_.FullName
    }
```

Run the split domain suite:

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.Domain*.Tests.ps1
```

Run the whole module suite:

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg
```

Optional parse check for the production type module:

```powershell
$tokens = $null
$errors = $null

[System.Management.Automation.Language.Parser]::ParseFile(
    'modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1',
    [ref] $tokens,
    [ref] $errors
) | Out-Null

$errors | ForEach-Object {
    '{0}:{1}:{2}: {3} [{4}]' -f
        $_.Extent.File,
        $_.Extent.StartLineNumber,
        $_.Extent.StartColumnNumber,
        $_.Message,
        $_.ErrorId
}
```

For a test-only refactor, this parser check should report no new issues because the production file should not change.

---

## Completion Criteria

The split is complete when:

- The monolithic domain test file is removed or reduced to a non-discovered index.
- Each domain concern has a focused test file.
- Every split file has the required top-level `using module`.
- No production files changed.
- No assertions changed.
- No fixture values changed unless unavoidable.
- No shared support file was introduced prematurely.
- Each split file passes independently.
- `Invoke-Pester -Path tests/Fun.Ffmpeg` passes.
- The original `Describe` / `Context` inventory is fully accounted for.
