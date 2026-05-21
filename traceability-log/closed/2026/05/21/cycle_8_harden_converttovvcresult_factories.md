# [DONE] Cycle 8 — Harden `ConvertToVvcResult` Factories

## Summary

Cycle 8 finalizes `ConvertToVvcResult` as the single domain-approved way to represent terminal conversion outcomes.

The current branch already has the three intended factories:

```powershell
[ConvertToVvcResult]::Converted(...)
[ConvertToVvcResult]::Skipped(...)
[ConvertToVvcResult]::Failed(...)
```

So this cycle should focus on:

- verifying the existing factory surface
- tightening status/reason invariants
- making compatibility fields derived, not caller-controlled
- covering diagnostic and exit-code behavior
- documenting factory-only usage

This remains a **domain-only** cycle. Do not touch worker orchestration, public command wiring, native invocation,
filesystem behavior, or compatibility-property finalization.

The larger roadmap originally defines Cycle 8 as centralizing invariant-checked result construction through `Converted`,
`Skipped`, and `Failed` factories, with tests constructing results only through factories.

---

## Scope

### Included

- `ConvertToVvcResult` factory validation
- result-state invariants
- compatibility-field derivation
- nullable exit-code behavior
- diagnostic normalization
- focused domain tests in:

```text
tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Result.Tests.ps1
```

- optional traceability update after tests pass

### Excluded

- changing public command output behavior
- deciding whether to remove `Ok` / `Skipped`
- changing worker result handling
- adding decision logic
- adding filesystem checks
- adding ffmpeg / ffprobe behavior
- refactoring unrelated domain types

Compatibility-property finalization belongs to Cycle 25, not Cycle 8.

---

## Target Contract

`ConvertToVvcResult` should represent exactly one of three terminal states:

| Factory          | Status      | Reason     | Meaning                                   |
| ---------------- | ----------- | ---------- | ----------------------------------------- |
| `Converted(...)` | `Converted` | `None`     | Conversion completed successfully.        |
| `Skipped(...)`   | `Skipped`   | non-`None` | Conversion intentionally did not run.     |
| `Failed(...)`    | `Failed`    | non-`None` | Conversion attempted or preflight failed. |

The factories are the public domain construction surface. The constructor may remain technically callable if PowerShell
class limitations make hiding it awkward, but production code should treat it as internal implementation detail.

---

## Required Invariants

## `Converted(...)`

A converted result must enforce:

- `Status = [VvcConversionStatus]::Converted`
- `Reason = [VvcConversionReason]::None`
- input path is nonblank, if part of the current result contract
- output path is nonblank
- new/output size is valid according to the live contract

  - if size must be positive, reject `0` and negative values
  - if zero-size is impossible but not currently represented, keep the stricter positive rule
- diagnostic is optional and normalized
- native exit code is optional
- compatibility fields are derived:

  - `Ok = $true`
  - `Skipped = $false`

## `Skipped(...)`

A skipped result must enforce:

- `Status = [VvcConversionStatus]::Skipped`
- `Reason -ne [VvcConversionReason]::None`
- input path is nonblank, if part of the current result contract
- output path is optional or required according to the current skip scenarios
- diagnostic is optional unless the current contract requires explanation
- native exit code should normally be `$null`
- compatibility fields are derived:

  - `Ok = $true`
  - `Skipped = $true`

Do not make skipped results look like failures. A skipped result is successful command handling with no conversion
performed.

## `Failed(...)`

A failed result must enforce:

- `Status = [VvcConversionStatus]::Failed`
- `Reason -ne [VvcConversionReason]::None`
- input path is nonblank when available
- output path may be `$null` if no output was produced
- diagnostic should be trimmed and preserved when supplied
- native exit code may be `$null` when failure occurred before native invocation
- native exit code may be populated when `ffmpeg` / `ffprobe` was invoked
- compatibility fields are derived:

  - `Ok = $false`
  - `Skipped = $false`

---

## Main Design Decision

Keep `Ok` and `Skipped` as **derived compatibility fields** for now.

Do not allow callers or constructors to supply these values independently. They should be computed from `Status`:

```text
Converted -> Ok true,  Skipped false
Skipped   -> Ok true,  Skipped true
Failed    -> Ok false, Skipped false
```

This avoids contradictory states like:

```text
Status = Failed, Ok = true
Status = Converted, Skipped = true
```

The final decision to keep or remove these fields remains deferred to Cycle 25.

---

## Test Plan

Add or tighten tests in:

```text
tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Result.Tests.ps1
```

Keep the top-level parse-time import if the file uses direct type literals:

```powershell
using module ..\..\modules\Fun.Ffmpeg\internal\ConvertToVvc.Types.psm1
```

## Converted Factory Tests

Required cases:

```powershell
Describe 'ConvertToVvcResult' {
    Context 'Converted factory' {
        It 'creates a Converted result with Reason None' {}
        It 'requires a nonblank output path' {}
        It 'rejects invalid size values according to the live contract' {}
        It 'normalizes diagnostics' {}
        It 'sets Ok true and Skipped false as derived compatibility fields' {}
    }
}
```

Use Gintama-themed fake paths or diagnostics if new values are needed:

```powershell
'E:\Yorozuya\gintoki-input.mkv'
'E:\Yorozuya\gintoki-output.mkv'
'  Yorozuya conversion complete  '
```

## Skipped Factory Tests

Required cases:

```powershell
Context 'Skipped factory' {
    It 'creates a Skipped result with a non-None reason' {}
    It 'rejects Reason None' {}
    It 'normalizes diagnostics' {}
    It 'keeps native exit code null unless the live contract says otherwise' {}
    It 'sets Ok true and Skipped true as derived compatibility fields' {}
}
```

Good fake diagnostic:

```powershell
'  Shinsengumi existing output already valid  '
```

## Failed Factory Tests

Required cases:

```powershell
Context 'Failed factory' {
    It 'creates a Failed result with a non-None reason' {}
    It 'rejects Reason None' {}
    It 'allows null native exit code for pre-native failures' {}
    It 'allows native exit code when a native tool was invoked' {}
    It 'normalizes diagnostics' {}
    It 'sets Ok false and Skipped false as derived compatibility fields' {}
}
```

Good fake diagnostics:

```powershell
'  Elizabeth encode failed  '
'  Katsura probe failed  '
```

---

## Negative-State Tests

Add explicit contradiction tests. These are the most important part of Cycle 8.

Required examples:

```powershell
It 'rejects Converted with a non-None reason' {}
It 'rejects Skipped with Reason None' {}
It 'rejects Failed with Reason None' {}
It 'does not allow compatibility fields to contradict Status' {}
```

If compatibility fields are not constructor parameters, the last test can simply assert derived behavior for all three
factories.

---

## Implementation Notes

Keep changes localized to:

```text
modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1
tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Result.Tests.ps1
```

Avoid a broad refactor. Prefer this sequence:

1. Add failing tests for the missing or weak invariant.
2. Update the factory or constructor validation.
3. Re-run the focused result test file.
4. Repeat for the next invariant.

Do not introduce new helper abstractions unless duplication becomes obvious. If helpers are needed, keep them private
and close to the result type.

Good helper candidates:

```powershell
Assert-VvcReasonNone
Assert-VvcReasonNotNone
Assert-VvcNonBlankString
ConvertTo-VvcOptionalString
Assert-VvcNonNegativeNumber
```

Do not introduce a general validation framework.

---

## Constructor Strategy

Best practical rule:

```text
Factories are the supported construction path.
Constructor is an implementation detail.
```

If the constructor can be made hidden or private without fighting PowerShell class limitations, do it. Otherwise, do not
overengineer. The stronger guarantee comes from:

- all production code using factories
- tests demonstrating factory-only construction
- later quality gate tests preventing ad hoc result creation

Cycle 27 can add the static architecture rule:

```text
no ad hoc ConvertToVvcResult construction outside factories
```

---

## Traceability Update

Only update the traceability log after the focused result tests pass.

Suggested note:

```text
Cycle 8 — ConvertToVvcResult factories

Status:
- Existing Converted, Skipped, and Failed factories were preserved.
- Factory invariants were tightened around Status / Reason consistency.
- Compatibility fields Ok and Skipped remain derived compatibility fields.
- Nullable native exit-code behavior was preserved.
- No public command, worker, native-process, or filesystem behavior changed.
```

---

## Verification

Run the focused file first:

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Result.Tests.ps1
```

Then run the split domain suite, if applicable:

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.Domain*.Tests.ps1
```

Then run the broader module suite:

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg
```

Optional parser check:

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

---

## Completion Criteria

Cycle 8 is complete when:

- `Converted`, `Skipped`, and `Failed` factories are the documented construction path.
- `Converted` cannot have a non-`None` reason.
- `Skipped` cannot have `Reason = None`.
- `Failed` cannot have `Reason = None`.
- output path and size invariants match the live result contract.
- diagnostics are normalized consistently.
- native exit code remains nullable where appropriate.
- `Ok` and `Skipped` are derived from `Status`.
- focused result tests pass.
- broader `tests/Fun.Ffmpeg` passes.
- no worker, public command, native invocation, or filesystem behavior changed.
