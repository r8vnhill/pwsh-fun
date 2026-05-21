# [DONE] Phase 1 — Domain Model Foundation

## Summary

Phase 1 locks down the typed `Convert-ToVvc` domain model before any orchestration, native-process, filesystem,
parallel-runspace, or public-command rewiring begins.

The domain test inventory is now split across focused files under `tests/Fun.Ffmpeg/Convert-ToVvc.Domain*.Tests.ps1`
instead of living in one monolithic suite.

The phase should end with a complete set of invariant-checked domain types that can be tested in isolation:

- conversion enums
- invariant exception
- native-result value object
- path-set value object
- request value object
- media-probe value object
- output-validation value object
- final conversion-result factories

Cycles 1–8 are implemented or verified in the current branch. Phase 1 now ends with traceability cleanup and a final
consistency pass over the domain suite.

## Scope

### Included

- `VvcConversionStatus`
- `VvcConversionAction`
- `VvcConversionReason`
- `VvcConversionInvariantException`
- `VvcNativeResult`
- `VvcConversionPathSet`
- `VvcConversionRequest`
- `VvcMediaProbe`
- `VvcOutputValidation`
- `ConvertToVvcResult` factory methods
- Domain-only tests in `Convert-ToVvc.Domain*.Tests.ps1`
- Traceability-log updates for Phase 1 completion

### Excluded

- `ffmpeg` invocation
- `ffprobe` invocation
- process-wrapper implementation
- filesystem existence checks
- temp path generation
- output promotion
- cleanup behavior
- parallel scriptblock changes
- public command rewiring
- public result-contract migration

Those belong to later phases.

---

## Current Phase State

| Cycle | Type / Contract                                                     | State                  |
| ----: | ------------------------------------------------------------------- | ---------------------- |
|     1 | `VvcConversionStatus`, `VvcConversionAction`, `VvcConversionReason` | Complete / verify only |
|     2 | `VvcConversionInvariantException`                                   | Complete / verify only |
|     3 | `VvcNativeResult`                                                   | Complete / verify only |
|     4 | `VvcConversionPathSet`                                              | Complete / verify only |
|     5 | `VvcConversionRequest`                                              | Complete / verify only |
|     6 | `VvcMediaProbe`                                                     | Complete / verify only |
|     7 | `VvcOutputValidation`                                               | Complete               |
|     8 | `ConvertToVvcResult` factories                                      | Complete               |

This keeps Phase 1 honest: most of it is contract verification; the remaining implementation work is Cycle 8.

---

## [✔️] Step 1 — Stabilize the Domain Test Loading Model

PowerShell classes and enums need parse-time visibility when tests reference them with type literals like:

```powershell
[VvcMediaProbe]
[VvcConversionReason]
[ConvertToVvcResult]
```

Use a top-level `using module` in the domain test file where required:

```powershell
using module ../../modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1
```

Do not rely on `Import-Module` inside `BeforeAll` for class availability if the test file contains direct type
references. `Import-Module` is still useful for functions, but class and enum references need to be resolvable when the
file is parsed.

**Done when:**

- `Convert-ToVvc.Domain.Tests.ps1` parses cleanly.
- Direct type references work without fragile ordering.
- The test suite does not require importing the public `Fun.Ffmpeg.psd1` manifest just to test internal domain types.

---

## [✔️] Step 2 — Verify the Existing Baseline Domain Contracts

Keep the existing contracts stable:

- `VvcConversionStatus`

  - `Converted`
  - `Skipped`
  - `Failed`

- `VvcConversionAction`

  - `Convert`
  - `Skip`
  - `Fail`

- `VvcConversionReason`

  - `None`
  - `InvalidInput`
  - `ExistingOutputValid`
  - `EncodeFailed`
  - `EncodedOutputMissing`
  - `ProbeFailed`
  - `UnexpectedCodec`
  - `DurationUnavailable`
  - `DurationDrift`
  - `DecodeFailed`
  - `PromoteFailed`
  - `SizeUnavailable`
  - `UnexpectedFailure`

- `VvcConversionInvariantException`

Do not rename or remove enum members in Phase 1. Later phases can decide whether reason granularity needs refinement.

**Done when:**

- Enum tests assert names, not numeric values.
- The invariant exception is directly throwable and catchable.
- The exception is used only for impossible domain states, not normal conversion failures.

---

## [✔️] Step 3 — Verify Existing Value Objects

Keep these as constructor-validated, side-effect-free contracts:

- `VvcNativeResult`
- `VvcConversionPathSet`
- `VvcConversionRequest`
- `VvcMediaProbe`

For this phase, prefer verification over redesign. Only change these types if tests reveal a contradiction, naming
mismatch, or normalization inconsistency.

### `VvcMediaProbe` Decision

Keep the implemented contract:

- `Valid`
- `Reason`
- `Codec`
- `DurationSec`
- `Diagnostic`

Preserve the current normalization rule:

- optional strings are trimmed
- blank optional strings normalize to `$null`
- nullable duration remains `$null` only when absent
- negative duration is rejected

Use Gintama-themed fake diagnostics in new tests where sample text is needed, for example:

```powershell
'  Yorozuya probe ok  '
'  Shinsengumi probe failed  '
```

**Done when:**

- Existing domain tests still pass.
- No value object depends on the filesystem.
- No value object invokes native tools.
- No value object performs orchestration decisions.

---

## [✔️] Step 4 — Cycle 7: Add `VvcOutputValidation`

### Goal

Represent output-validation state independently of `ffmpeg`, `ffprobe`, files, and worker orchestration.

`VvcOutputValidation` should answer one question only:

> Is the produced output acceptable according to already-known validation facts?

It should not calculate those facts.

### Recommended Contract

Use the current domain naming style. A minimal shape would be:

```powershell
class VvcOutputValidation {
    [bool] $Valid
    [VvcConversionReason] $Reason
    [Nullable[double]] $DurationDriftSec
    [string] $Diagnostic
}
```

Keep property names aligned with current implementation if the branch already has a partial class.

### Invariants

1. Valid output requires `Reason = [VvcConversionReason]::None`.
2. Invalid output requires `Reason -ne [VvcConversionReason]::None`.
3. `DurationDriftSec`, when supplied, must be greater than or equal to zero.
4. Invalid output must have a useful diagnostic.
5. Valid output may omit diagnostics; blank diagnostics normalize to `$null`.

Step 4 / Cycle 7 resolved diagnostic handling:

- Valid output may omit diagnostics.
- Invalid output must include a nonblank diagnostic.
- Blank diagnostics are trimmed and rejected for invalid validation states.
- No filesystem, native-process, worker, or public command behavior changed.

### Required Tests

```powershell
Describe 'VvcOutputValidation' {
    It 'accepts valid output with Reason None' {}

    It 'accepts invalid output with a non-None reason' {}

    It 'rejects valid output with a non-None reason' {}

    It 'rejects invalid output with Reason None' {}

    It 'rejects negative duration drift' {}

    It 'rejects blank diagnostics for invalid output' {}

    It 'trims diagnostics' {}

    It 'normalizes blank diagnostics for valid output' {}
}
```

Use Gintama-themed diagnostics where useful:

```powershell
'  Elizabeth duration drift detected  '
'  Katsura output validation failed  '
```

### Done When

- Validation outcomes are domain-only.
- No filesystem checks are introduced.
- No probing or decoding logic is introduced.
- All impossible validation states throw `VvcConversionInvariantException`.

---

## [✔️] Step 5 — Cycle 8: Add `ConvertToVvcResult` Factories

### Goal

Centralize final result construction so converted, skipped, and failed results cannot be created with contradictory
state.

The factory methods should become the only intended construction path:

```powershell
[ConvertToVvcResult]::Converted(...)
[ConvertToVvcResult]::Skipped(...)
[ConvertToVvcResult]::Failed(...)
```

## Required Result Invariants

### Converted

A converted result should require:

- `Status = Converted`
- `Reason = None`
- nonblank input path
- nonblank output path
- positive or non-negative size fields according to the existing result contract
- `Ok = $true` if compatibility fields are still present
- `Skipped = $false` if compatibility fields are still present

### Skipped

A skipped result should require:

- `Status = Skipped`
- `Reason -ne None`
- nonblank input path
- output path when relevant
- `Ok = $true` or current compatibility behavior
- `Skipped = $true`

For this phase, preserve compatibility behavior. Do not decide the final public fate of `Ok` and `Skipped`; that belongs
to Phase 6.

### Failed

A failed result should require:

- `Status = Failed`
- `Reason -ne None`
- nonblank input path when available
- diagnostic or error message when available
- optional native exit code only when a native process was actually invoked
- `Ok = $false`
- `Skipped = $false`

## Required Tests

```powershell
Describe 'ConvertToVvcResult' {
    Context 'Converted factory' {
        It 'creates Converted / None' {}
        It 'requires an output path' {}
        It 'rejects a non-None reason' {}
        It 'sets compatibility fields consistently' {}
    }

    Context 'Skipped factory' {
        It 'creates Skipped with a non-None reason' {}
        It 'rejects Reason None' {}
        It 'sets compatibility fields consistently' {}
    }

    Context 'Failed factory' {
        It 'creates Failed with a non-None reason' {}
        It 'rejects Reason None' {}
        It 'allows native exit code when supplied' {}
        It 'sets compatibility fields consistently' {}
    }
}
```

## Constructor Strategy

Best option:

- Make constructors hidden/private if practical in PowerShell.
- Otherwise, treat constructors as implementation details and enforce factory-only construction by tests and review.

PowerShell class privacy is limited compared with C#, so do not over-invest in constructor hiding if it makes the
implementation awkward. The important outcome is that production code uses factories.

## Done When

- Tests construct final results through factories.
- Factory methods enforce status/reason compatibility.
- Existing compatibility fields are preserved but not treated as authoritative.
- No public command tests are migrated yet.

---

## Step 6 — Refactor Pass

After Cycles 7–8 pass, do a small cleanup pass only inside:

```text
modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1
tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1
```

Recommended cleanup:

- Extract small guard helpers only if constructors are getting noisy.
- Keep helpers close to the domain types.
- Avoid a broad validation framework.
- Avoid adding general-purpose utility modules.
- Keep each constructor readable and short where possible.
- Use consistent exception messages, but do not over-test exact text unless the message is part of the contract.

Good guard candidates:

```powershell
Assert-VvcNonBlankString
ConvertTo-VvcOptionalString
Assert-VvcNonNegativeNullableDouble
Assert-VvcReasonNone
Assert-VvcReasonNotNone
```

Do not add these unless they reduce duplication.

---

## Step 7 — Traceability Update

Update:

```text
traceability-log/convert_tovvc_domain_driven_refactor.md
```

Record Phase 1 as complete only after Cycles 7 and 8 are passing.

Recommended entry shape:

```text
Phase 1 — Domain Model Foundation

Status:
- Cycles 1–6 completed before this checkpoint.
- Cycle 7 added VvcOutputValidation.
- Cycle 8 centralized ConvertToVvcResult creation behind factories.

Boundary:
- No native process execution.
- No filesystem behavior.
- No worker or public command rewiring.
- Public compatibility properties were preserved for later decision.
```

---

## Verification

Run these in order:

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1
```

```powershell
Import-Module modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1 -Force
```

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg
```

Optional parser-only check for the type module:

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

## Phase 1 Completion Criteria

Phase 1 is complete when:

- Cycles 1–8 are represented in tests.
- All domain types are side-effect-free.
- All impossible states throw `VvcConversionInvariantException`.
- `VvcOutputValidation` exists and is tested.
- `ConvertToVvcResult` construction is centralized through factories.
- Compatibility fields are preserved but not finalized.
- No public command, worker, parallel, native-process, or filesystem behavior changed.
- The broader `tests/Fun.Ffmpeg` suite still passes.

## Key Improvement Over the Original Plan

The original plan was directionally good, but it treated Phase 1 as if all parts were equally active. This version
separates:

```text
Already implemented / verify only:
  Cycles 1–6

Remaining Phase 1 implementation:
  Cycle 8 — ConvertToVvcResult factories
```

That makes the next work item much clearer and prevents Phase 1 from drifting into Phase 2 decision logic or Phase 3
infrastructure.
