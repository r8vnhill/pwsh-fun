# [DONE] Phase 1 Characterization Tests

## Objective

Before the `Convert-ToVvc` worker is refactored, capture the current user-visible behavior of the command with scenario-level characterization tests.

The goal is **not** to freeze the current implementation. The goal is to preserve observable behavior while Phase 2+ replaces internals such as the worker scriptblock, native tool invocation, request object construction, and verification flow.

Phase 1 should answer:

> “Given the current public command behavior, what outcomes must remain stable unless we intentionally change the contract?”

The current characterization suite should stay focused on observable outcomes and avoid metadata-coupled assertions such as `GetType().Name` or `OutputType` checks.

---

## Scope

### In scope

* Characterize existing `Convert-ToVvc` behavior through the public command surface.
* Use the existing fake-media integration harness.
* Assert on externally observable outcomes:

  * result count
  * emitted result shape where already public
  * output file presence or absence
  * skipped versus converted behavior
  * fake `ffmpeg` / `ffprobe` invocation markers
  * cleanup of partial output
  * behavior under `-WhatIf`
  * behavior under `-Overwrite`
  * behavior when conversion or validation fails

### Out of scope

* Refactoring production code.
* Introducing the future `Status` / normalized `Reason` contract.
* Testing private helper names directly.
* Asserting on worker scriptblock internals.
* Asserting on `GetType().Name`, `[OutputType()]`, or other metadata unless already part of a documented public contract.
* Replacing the current fake-media harness.
* Adding real `ffmpeg` / `ffprobe` dependencies.

---

## Test Design Principles

1. **Test through `Convert-ToVvc`, not through private helpers.**

   Phase 2+ is expected to rewrite private worker internals. Tests should remain valid through that refactor.

2. **Prefer scenario-level assertions over object-shape snapshots.**

   Assert only the public result fields that users or existing tests already rely on, such as:

   ```powershell
   $result.Ok
   $result.Skipped
   $result.Reason
   ```

   Avoid deep structural assertions unless the current public contract clearly exposes them.

3. **Use fake tool markers as behavioral evidence.**

   Marker files are useful because they prove whether `ffmpeg` and `ffprobe` were invoked without coupling tests to implementation details.

4. **Characterize, do not redesign.**

   The tests should record current behavior, including awkward or temporary behavior, so future refactors can intentionally preserve or deliberately change it.

5. **Keep each scenario narrow.**

   Each test should prove one behavior. Avoid large “kitchen sink” tests that make future refactors harder to diagnose.

---

## Scenario Coverage

### Required characterization buckets

| Scenario                                   | Expected characterization focus                                                             |
| ------------------------------------------ | ------------------------------------------------------------------------------------------- |
| Successful conversion                      | Result emitted, output created, expected tools invoked.                                     |
| Invalid input failure                      | No conversion, failure result or thrown error matches current behavior.                     |
| Existing valid output without `-Overwrite` | Conversion skipped, output preserved, `ffmpeg` not invoked unnecessarily.                   |
| Existing valid output with `-Overwrite`    | Existing output does not cause skip; conversion is attempted again.                         |
| `-WhatIf`                                  | No output written, no conversion side effect, current no-result behavior preserved.         |
| Extension filtering                        | Unsupported or filtered extensions produce no conversion result, matching current behavior. |
| `ffmpeg` non-zero exit                     | Failure result or error behavior preserved, partial output cleaned up.                      |
| Post-validation failure                    | Conversion attempt happens, validation fails, partial output cleanup behavior preserved.    |

### Optional characterization bucket

| Scenario                                | Include only if cheap and already externally visible                                                                               |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `-Verify` default versus `-Verify none` | Characterize only the observable difference in fake tool invocation or result behavior. Do not assert internal verification steps. |

---

## Steps

### 1. Confirm Phase 0 importability is stable

Run the import smoke check first:

```powershell
pwsh -NoProfile -Command "Import-Module './modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1' -Force"
```

Phase 1 should not proceed if the module still fails to import.

---

### 2. Preserve and reuse the existing fake-media harness

Keep the existing support files as the foundation:

```text
tests/Fun.Ffmpeg/Support/ConvertToVvc.SpecSupport.ps1
tests/Fun.Ffmpeg/Support/FakeMediaTools.ps1
```

Do not introduce a second fixture model unless the current harness blocks a required scenario.

The existing harness should remain responsible for:

* creating fake media inputs
* wiring fake `ffmpeg` / `ffprobe`
* recording invocation markers
* creating valid or invalid fake outputs
* simulating tool failures
* asserting cleanup state

---

### 3. Audit existing tests before adding new ones

Review the current coverage in:

```text
tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1
tests/Fun.Ffmpeg/Convert-ToVvc.InputValidation.Tests.ps1
```

Classify each existing test as one of:

* already good characterization coverage
* useful but too implementation-coupled
* redundant
* missing scenario coverage

Prefer renaming or tightening existing tests over adding duplicate tests.

Current implementation update:

* The invocation suite now includes an explicit overwrite characterization case so the behavior difference between skip and re-encode is visible in the test set.
* The shared assertion helpers were tightened to assert public outcome fields and side effects instead of type metadata.

---

### 4. Make the scenario buckets explicit

Organize the tests around externally meaningful contexts.

Suggested structure:

```powershell
Describe 'Convert-ToVvc characterization' {
    Context 'when conversion succeeds' {
        It 'creates the expected output and reports success' {
            # ...
        }
    }

    Context 'when the input is invalid' {
        It 'does not invoke conversion and reports the current failure behavior' {
            # ...
        }
    }

    Context 'when a valid output already exists' {
        It 'skips conversion by default' {
            # ...
        }

        It 'converts again when Overwrite is specified' {
            # ...
        }
    }

    Context 'when WhatIf is used' {
        It 'does not create output or invoke ffmpeg' {
            # ...
        }
    }

    Context 'when the input extension is filtered out' {
        It 'does not emit conversion results' {
            # ...
        }
    }

    Context 'when ffmpeg fails' {
        It 'reports failure and removes partial output' {
            # ...
        }
    }

    Context 'when post-validation fails' {
        It 'reports validation failure and cleans up partial output' {
            # ...
        }
    }
}
```

This makes the test suite read like a behavioral specification instead of a mirror of the current implementation.

---

### 5. Add the missing overwrite characterization

Add one focused test that proves the current distinction between:

* valid existing output without `-Overwrite`
* valid existing output with `-Overwrite`

The test should assert:

Without `-Overwrite`:

```powershell
$result.Skipped | Should -BeTrue
$result.Ok | Should -BeTrue
# existing output remains
# ffmpeg marker absent or unchanged
```

With `-Overwrite`:

```powershell
$result.Skipped | Should -BeFalse
# conversion attempted
# ffmpeg marker present or invocation count increased
# output rewritten according to current fake-tool behavior
```

Avoid asserting on internal branch names or private function calls.

Implementation note: this overwrite characterization is now present in the invocation suite, so future edits should preserve its external behavior rather than duplicating the same scenario in a second file.

---

### 6. Add narrow verification characterization only if worthwhile

Only add `-Verify` characterization if the current fake tools can distinguish behavior cleanly.

Useful assertions may include:

* default verification invokes `ffprobe` after conversion
* `-Verify none` avoids the post-conversion validation branch
* output/result behavior differs in a currently observable way

Avoid locking down:

* exact internal validation function names
* exact ffprobe argument ordering
* future verification strategy
* the future `Status` model

If the current fake harness cannot distinguish this cheaply, defer this to the verification-specific refactor phase.

---

### 7. Tighten assertions around observable effects

Prefer assertions like:

```powershell
$outputPath | Should -Exist
$ffmpegMarker | Should -Exist
$ffprobeMarker | Should -Exist
$partialOutputPath | Should -Not -Exist
$result | Should -HaveCount 1
$result.Ok | Should -BeTrue
$result.Skipped | Should -BeFalse
```

Avoid assertions like:

```powershell
$result.GetType().Name | Should -Be 'SomeInternalType'
$scriptBlock.Ast.ToString() | Should -Match 'Invoke-SomePrivateHelper'
```

The latter would make Phase 2 unnecessarily brittle.

Prefer the current helper style in `tests/Fun.Ffmpeg/Support/ConvertToVvc.SpecSupport.ps1`, which checks the existing public fields and tool markers but does not assert the result type name.

---

## Relevant Files

| File                                                       | Purpose                                                                                                                             |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1`      | Primary characterization suite for conversion, skip, overwrite, `-WhatIf`, extension filtering, tool failure, and cleanup behavior. |
| `tests/Fun.Ffmpeg/Convert-ToVvc.InputValidation.Tests.ps1` | Characterization coverage for invalid inputs, empty files, corrupt containers, and early rejection behavior.                        |
| `tests/Fun.Ffmpeg/Support/ConvertToVvc.SpecSupport.ps1`    | Shared scenario builder, fake environment setup, helper assertions, and fixture lifecycle.                                          |
| `tests/Fun.Ffmpeg/Support/FakeMediaTools.ps1`              | Fake `ffmpeg` / `ffprobe` behavior, failure injection, output simulation, and marker-file plumbing.                                 |
| `modules/Fun.Ffmpeg/public/Convert-ToVvc.ps1`              | Public orchestration surface under characterization.                                                                                |
| `modules/Fun.Ffmpeg/internal/ConvertToVvc.Worker.ps1`      | Current worker behavior exercised indirectly only through public command scenarios.                                                 |

---

## Verification

### 1. Run the import smoke test

```powershell
pwsh -NoProfile -Command "Import-Module './modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1' -Force"
```

### 2. Run the narrow affected test files first

```powershell
Invoke-Pester -Path @(
    './tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1',
    './tests/Fun.Ffmpeg/Convert-ToVvc.InputValidation.Tests.ps1'
) -Output Detailed
```

### 3. Run the full Fun.Ffmpeg slice

```powershell
Invoke-Pester -Path './tests/Fun.Ffmpeg' -Output Detailed
```

### 4. Confirm test intent

After the tests pass, confirm that the suite proves behavior using:

* output files
* marker files
* cleanup state
* result count
* current public result fields

and does **not** depend on:

* worker scriptblock text
* private helper names
* object type names
* metadata attributes
* exact internal call ordering unless externally significant

---

## Acceptance Criteria

Phase 1 is complete when:

1. The `Fun.Ffmpeg` module imports cleanly.
2. The fake-media characterization tests pass.
3. The suite explicitly covers:

   * successful conversion
   * invalid input
   * existing output skip
   * overwrite conversion
   * `-WhatIf`
   * extension filtering
   * `ffmpeg` failure
   * post-validation failure
4. Tests assert observable behavior, not implementation details.
5. No production behavior is changed.
6. No real media tooling is required.
7. The suite is strong enough to detect accidental behavior changes during Phase 2+.

---

## Decisions

* Reuse the existing Pester/fake-media harness.
* Keep Phase 1 as characterization only.
* Add the overwrite case because it is a clear user-visible branch.
* Add verification characterization only when the current fake tools can distinguish it reliably.
* Avoid locking in the future `Status` / `Reason` contract prematurely.
* Treat type names, `OutputType`, and private helper structure as implementation details.

---

## Suggested Commit Shape

Prefer one focused test-only commit:

```text
Characterize Convert-ToVvc public behavior before worker refactor
```

If Phase 0 and Phase 1 are committed separately, this keeps the history clean:

```text
Fix Fun.Ffmpeg import failure from misplaced OutputType attribute
Characterize Convert-ToVvc public behavior before worker refactor
```
