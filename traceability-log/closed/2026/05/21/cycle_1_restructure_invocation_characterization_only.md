# [IMPLEMENTED] Cycle 1 — Restructure Invocation Characterization Only

## Summary

Refactor the active `Convert-ToVvc` characterization tests into a clearer BDD-style layout without changing the tested
behavior. This cycle is limited to test organization, scenario naming, and no-op-safe cleanup guards. It must not add
new coverage, extract helpers, change fake-tool contracts, or touch production code.

Cycle 1 should leave the observable scenario outcomes unchanged: the same behaviors should still pass, fail, skip, clean
up, and suppress output exactly as before.

## Implementation result

Implemented on the active invocation and input-validation characterization suites.

- `Convert-ToVvc.Invocation.Tests.ps1` now groups the existing 13 examples under behavior-focused contexts and uses
  clearer Ringu-themed scenario filenames without adding filename edge cases.
- `Convert-ToVvc.InputValidation.Tests.ps1` now groups its existing invalid-input DDT under a matching context.
- Both suites guard `AfterAll` fake-tool restoration when setup fails before `$script:toolSupport` exists.
- No production module or shared fake-tool support files changed in this cycle.

The pre-refactor baseline was not fully green:

| Suite | Total | Passed | Failed | Skipped | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| `Convert-ToVvc.Invocation.Tests.ps1` | 13 | 12 | 1 | 0 | Failed |
| `Convert-ToVvc.InputValidation.Tests.ps1` | 2 | 2 | 0 | 0 | Passed |

The existing invocation failure is the valid-existing-output skip scenario, where `Assert-ScenarioSkipped` observes
`Skipped = $false`. Cycle 1 preserves that characterization outcome rather than changing production or test-support
behavior to repair it.

## Scope

### In scope

- Reorganize `Convert-ToVvc.Invocation.Tests.ps1` into behavior-focused `Context` blocks.
- Apply a light matching structure pass to `Convert-ToVvc.InputValidation.Tests.ps1`.
- Rename generic fake scenario filenames to Ringu-themed names where doing so does not change test semantics.
- Add null guards around `AfterAll` fake-tool cleanup.
- Run the two focused Pester suites before and after the refactor.

### Out of scope

- No production code changes.
- No support helper extraction.
- No fake `ffmpeg` / `ffprobe` marker format changes.
- No new test scenarios.
- No assertion rewrites except those mechanically required by scenario filename renames.
- No Pester dependency policy changes.
- No PSScriptAnalyzer or CI changes.

## Relevant files

- `tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1`
- `tests/Fun.Ffmpeg/Convert-ToVvc.InputValidation.Tests.ps1`
- `traceability-log/refactor_convert_tovvc_invocation_characterization.md`

No files under `modules/Fun.Ffmpeg/` should change in this cycle.

## Pre-refactor baseline

Before editing, capture the current focused-suite result:

```powershell
$invocationBaseline = Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1 -PassThru
$inputValidationBaseline = Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.InputValidation.Tests.ps1 -PassThru
```

Acceptance for the baseline:

- both suites pass
- total test counts are recorded
- failed/skipped counts are recorded
- any existing skip behavior is understood before restructuring

This makes the cycle safer because a move-only refactor should not accidentally drop examples.

## Steps

### 1. Map current examples before editing

Create a temporary checklist mapping every current example in `Convert-ToVvc.Invocation.Tests.ps1` to its destination
context.

Suggested target layout:

```powershell
Describe 'Convert-ToVvc invocation' -Tag 'integration' {
    Context 'when inputs are convertible' { }
    Context 'when encoder configuration is supplied' { }
    Context 'when paths are bound explicitly or through the pipeline' { }
    Context 'when output already exists' { }
    Context 'when execution is bypassed' { }
    Context 'when native tools fail' { }
    Context 'when native streams contain noise' { }
    Context 'when conversion runs in parallel' { }
}
```

Do not edit assertions during this mapping step.

### 2. Move examples into contexts

Move existing examples into the new contexts without changing their setup, assertions, or expectations.

Use this mapping:

| Existing behavior                       | Target context                                            |
| --------------------------------------- | --------------------------------------------------------- |
| successful conversion                   | `when inputs are convertible`                             |
| encoder thread settings                 | `when encoder configuration is supplied`                  |
| explicit `LiteralPath` / pipeline input | `when paths are bound explicitly or through the pipeline` |
| existing output skip / overwrite        | `when output already exists`                              |
| `WhatIf` / unmatched extension          | `when execution is bypassed`                              |
| ffmpeg failure / validation failure     | `when native tools fail`                                  |
| progress or native stream noise         | `when native streams contain noise`                       |
| `MaxParallel` worker path               | `when conversion runs in parallel`                        |

Keep current DDT cases intact. Do not convert standalone cases into DDT in this cycle.

### 3. Rename generic scenario filenames only

Rename generic test filenames to Ringu-themed equivalents, but do not introduce new edge cases.

Examples:

```powershell
'good.mkv'          -> 'asakawa-source.mkv'
'threads.mkv'       -> 'ryuji-threaded-encode.mkv'
'parallel.mkv'      -> 'sadako-parallel-run.mkv'
'exists.mkv'        -> 'cursed-tape-existing-output.mkv'
'bad-convert.mkv'   -> 'well-scene-bad-convert.mkv'
```

Rules:

- Keep extensions the same unless the original test is explicitly about extension behavior.
- Do not add spaces, brackets, Unicode, or uppercase extensions yet.
- Update only expected paths or result properties directly tied to the renamed filename.
- Do not change probe scenarios except for the corresponding renamed keys.

This keeps filename renaming readable without smuggling in path-edge coverage.

### 4. Lightly restructure input-validation tests

Apply the same BDD readability pass to `Convert-ToVvc.InputValidation.Tests.ps1`, but keep it smaller than the
invocation-suite refactor.

Suggested contexts:

```powershell
Describe 'Convert-ToVvc input validation' {
    Context 'when input paths are invalid' { }
    Context 'when output options are invalid' { }
    Context 'when native tool options are invalid' { }
    Context 'when concurrency options are invalid' { }
}
```

Use the actual existing examples to decide the final context names. Avoid inventing categories that do not match current
coverage.

Keep all current DDT data and failure assertions unchanged.

### 5. Harden `AfterAll` cleanup

Guard fake-tool restoration so cleanup does not create a second error when initialization fails early.

Preferred shape:

```powershell
AfterAll {
    if ($script:toolSupport) {
        Restore-FakeMediaToolSupport -Context $script:toolSupport
    }
}
```

Use the existing variable names from each suite.

This is the only intentional safety behavior change in Cycle 1. It should be a no-op when setup succeeds.

### 6. Verify focused suites

Run:

```powershell
$invocationResult = Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1 -PassThru
$inputValidationResult = Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.InputValidation.Tests.ps1 -PassThru
```

Acceptance:

- both suites pass
- total test count matches the baseline
- skipped count matches the baseline unless the difference is intentionally explained
- no production files changed
- no support helper files changed, unless the cleanup guard genuinely lives there in the current structure

Useful diff check:

```powershell
git diff --name-only
```

Expected changed files should be limited to:

```text
tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1
tests/Fun.Ffmpeg/Convert-ToVvc.InputValidation.Tests.ps1
traceability-log/refactor_convert_tovvc_invocation_characterization.md
```

## Acceptance criteria

Cycle 1 is complete when:

- the invocation suite reads as behavior-focused BDD contexts
- the input-validation suite has matching high-level readability
- all existing scenarios still execute
- all existing result expectations are preserved
- success, skip, failure, `WhatIf`, stream filtering, and cleanup behaviors remain unchanged
- generic fake filenames have been replaced with clearer Ringu-themed names without adding new filename edge cases
- `AfterAll` cleanup is null-safe
- the focused Pester suites pass
- the test count has not accidentally decreased

## Stop conditions

Stop and fix before continuing to Cycle 2 if any of these happen:

- a production module file changes
- fake-tool support behavior changes
- marker output changes
- a new scenario is added
- a helper is extracted
- a test assertion is semantically rewritten
- test count changes unexpectedly
- the refactor requires changing public behavior to pass
