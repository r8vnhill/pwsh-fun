# [DONE] Phase 2: Domain Invariant Tests

## Implementation status

Completed.

Added pure domain invariant coverage in:

```text
tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1
```

Updated the conversion domain type module in:

```text
modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1
```

The phase introduces enum-backed conversion domain types and invariant-checked
constructors/factories without rewiring `Convert-ToVvc`, worker execution,
native ffmpeg/ffprobe invocation, or parallel behavior.

Verification run:

```powershell
Invoke-Pester -Path 'pwsh-fun/tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1' -Output Detailed
# Passed: 30

Invoke-Pester -Path 'pwsh-fun/tests/Fun.Ffmpeg' -Output Detailed
# Passed: 65

Import-Module ./pwsh-fun/modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1 -Force -ErrorAction Stop
# Passed

./pwsh-fun/tools/Invoke-PSSA.ps1
# Completed with existing repository warnings; no remaining ConvertToVvc.Types.psm1 warnings.
```

## Summary

Add test-first coverage for the new `Convert-ToVvc` domain model before any worker rewiring occurs. This phase defines the invariant contract for enum-backed conversion types and validates impossible states at construction time.

The tests should follow the existing `VvcAudit.Tests.ps1` / `VvcRemoval.Types.psm1` pattern:

* Direct type construction inside `InModuleScope Fun.Ffmpeg`.
* Explicit `Should -Throw` assertions for invalid states.
* Enum assertions via `.ToString()` or `.GetType().Name`.
* Pure domain tests only: no fake ffmpeg, no ffprobe, no filesystem mutation, and no conversion execution.

This phase may add the new domain types, but it must not change the observable behavior of `Convert-ToVvc`.

---

# Goals

## Primary goals

1. Define the invariant contract for the conversion domain model.
2. Introduce enum-backed status, reason, and action types.
3. Prevent impossible conversion states from being representable.
4. Keep the new model isolated from worker execution until later phases.
5. Preserve existing `Convert-ToVvc` behavior and current test coverage.

## Non-goals

This phase must not:

* Rewire `Convert-ToVvc`.
* Modify `ConvertToVvc.Worker.ps1` behavior.
* Change native ffmpeg / ffprobe invocation.
* Change parallel execution behavior.
* Change the current public command result contract.
* Depend on real or fake media tools.
* Create, delete, or mutate real media files.

---

# Files

## Add

```text
tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1
```

## Update

```text
internal/ConvertToVvc.Types.psm1
```

Only update this file enough to satisfy the new domain tests.

---

# Domain Types to Add

Add the following exception, enums, and classes.

## Exception

```powershell
VvcConversionInvariantException
```

Used when domain construction would create an invalid or contradictory state.

Prefer throwing this exception type consistently from constructors and static factories instead of using generic `ArgumentException` or ad hoc string failures.

## Enums

```powershell
VvcConversionStatus
VvcConversionReason
VvcConversionAction
```

Recommended initial enum shape:

```powershell
enum VvcConversionStatus {
    Converted
    Skipped
    Failed
}

enum VvcConversionAction {
    Convert
    Skip
    Fail
}

enum VvcConversionReason {
    None
    AlreadyExists
    InvalidInput
    ProbeFailed
    UnsupportedCodec
    FfmpegFailed
    VerificationFailed
    OutputMissing
    SizeUnavailable
    WhatIf
    ExtensionFiltered
}
```

The exact names can be adjusted to match existing project terminology, but the important invariant is that `None` must only be valid for successful/positive states.

## Classes

```powershell
VvcConversionRequest
VvcConversionPathSet
VvcNativeResult
VvcMediaProbe
VvcOutputValidation
VvcConversionDecision
ConvertToVvcResult
```

---

# Design Rules

## Constructor and factory policy

Use constructors for small immutable value objects where the invariant is obvious.

Use static factories for objects with semantic variants, especially:

```powershell
[ConvertToVvcResult]::Converted(...)
[ConvertToVvcResult]::Skipped(...)
[ConvertToVvcResult]::Failed(...)
```

and optionally:

```powershell
[VvcConversionDecision]::Convert(...)
[VvcConversionDecision]::Skip(...)
[VvcConversionDecision]::Fail(...)
```

This keeps tests readable and makes invalid combinations harder to express.

## Immutability

Prefer read-only properties after construction.

PowerShell classes do not provide perfect immutability, but the domain model should avoid mutable public setters unless there is a strong reason.

Example style:

```powershell
class VvcNativeResult {
    [string] $ToolPath
    [string[]] $Arguments
    [int] $ExitCode
    [string] $Stdout
    [string] $Stderr
    [bool] $Succeeded

    VvcNativeResult(
        [string] $toolPath,
        [string[]] $arguments,
        [int] $exitCode,
        [string] $stdout,
        [string] $stderr
    ) {
        # validate
        # assign
        # derive Succeeded
    }
}
```

Do not accept constructor parameters for derived fields such as `Succeeded`, `Ok`, or `Skipped`.

## Derived legacy fields

If `ConvertToVvcResult` retains legacy fields such as `Ok` and `Skipped`, they should be derived from `Status`.

They must not be independent authoritative state.

Recommended mapping:

```text
Status = Converted -> Ok = true,  Skipped = false
Status = Skipped   -> Ok = true,  Skipped = true
Status = Failed    -> Ok = false, Skipped = false
```

This preserves the likely existing public semantics while allowing the enum-backed model to become authoritative internally.

---

# Test Structure

Create `Convert-ToVvc.Domain.Tests.ps1` with scenario groups by type.

Recommended shape:

```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../../src/Fun.Ffmpeg/Fun.Ffmpeg.psd1" -Force
}

Describe 'Convert-ToVvc domain invariants' {
    InModuleScope Fun.Ffmpeg {
        Context 'ConvertToVvcResult' {
            It 'creates a converted result with enum-backed status and reason' {
                # ...
            }

            It 'rejects converted results with non-None reasons' {
                # ...
            }
        }

        Context 'VvcConversionRequest' {
            # ...
        }
    }
}
```

Keep helper functions local to the test file and small. Prefer explicit test data over broad helper abstractions unless duplication becomes distracting.

---

# Test Cases

## `ConvertToVvcResult`

### Valid states

* Converted result requires:

  * `Status = Converted`
  * `Reason = None`
  * non-empty `InputPath`
  * non-empty `OutputPath`
  * positive `NewMB`
* Skipped result requires:

  * `Status = Skipped`
  * `Reason -ne None`
  * non-empty `InputPath`
* Failed result requires:

  * `Status = Failed`
  * `Reason -ne None`
  * non-empty `InputPath`

### Invalid states

* Converted result rejects any non-`None` reason.
* Skipped result rejects `Reason = None`.
* Failed result rejects `Reason = None`.
* `Ratio` must be `$null` or non-negative.
* `NewMB` must be positive for converted results.
* Blank diagnostics must either normalize to `$null` or throw. Pick one rule and test it explicitly.
* Legacy `Ok` and `Skipped` must not be independently settable as authoritative state.

### Enum assertions

Assert enum-backed fields like this:

```powershell
$result.Status.GetType().Name | Should -Be 'VvcConversionStatus'
$result.Status.ToString() | Should -Be 'Converted'
$result.Reason.GetType().Name | Should -Be 'VvcConversionReason'
$result.Reason.ToString() | Should -Be 'None'
```

---

## `VvcConversionRequest`

### Valid state

A valid request preserves the worker boundary data:

* Input file path.
* Output directory.
* Output suffix.
* QP.
* Preset.
* Overwrite flag.
* Verify mode.
* Max drift.
* ffmpeg path.
* ffprobe path.
* optional encoder thread count.

### Invalid states

Reject:

* `$null` or blank input file path.
* blank output directory.
* blank suffix.
* blank preset.
* blank ffmpeg path.
* blank ffprobe path.
* verify mode outside:

  * `none`
  * `quick`
  * `strict`
* negative `MaxDriftSec`.
* negative `EncoderThreads`.
* out-of-range QP.

Recommended QP invariant:

```text
QP must be between 0 and 63 inclusive.
```

That matches common video encoder QP ranges and is safer than leaving the domain unconstrained.

---

## `VvcConversionPathSet`

### Valid state

A valid path set contains:

* input path
* output path
* temp path

### Invalid states

Reject:

* blank input path.
* blank output path.
* blank temp path.
* temp path equal to output path.
* temp path in a different directory than output path.
* temp path extension different from output path extension.

This type should not require paths to exist. It should only validate path string relationships.

---

## `VvcNativeResult`

### Valid state

A valid native result contains:

* non-blank tool path.
* non-null argument list.
* required exit code.
* optional stdout.
* optional stderr.
* derived `Succeeded`.

### Invalid states

Reject:

* blank tool path.
* `$null` argument list.
* any attempt to construct inconsistent success state.

Prefer not to accept `Succeeded` as a constructor parameter. Derive it from:

```powershell
$ExitCode -eq 0
```

Test both cases:

```powershell
$result = [VvcNativeResult]::new('ffmpeg', @('-version'), 0, '', '')
$result.Succeeded | Should -BeTrue

$result = [VvcNativeResult]::new('ffmpeg', @('-bad'), 1, '', 'error')
$result.Succeeded | Should -BeFalse
```

---

## `VvcMediaProbe`

### Valid states

A valid probe requires:

* `Reason = None`
* optional non-negative duration
* optional normalized codec
* optional normalized diagnostic

An invalid probe requires:

* `Reason -ne None`
* optional diagnostic

### Invalid states

Reject:

* valid probe with non-`None` reason.
* invalid probe with `Reason = None`.
* negative duration.
* blank codec if codec is required for a valid probe.
* blank diagnostics, according to the chosen normalization rule.

Recommended normalization rule:

```text
Blank optional strings normalize to $null.
Non-blank strings are trimmed.
```

This avoids unnecessary throwing for harmless native-output edge cases.

---

## `VvcOutputValidation`

### Valid states

A valid output validation requires:

* `Reason = None`
* nullable non-negative duration drift
* optional normalized diagnostic

An invalid output validation requires:

* `Reason -ne None`
* optional normalized diagnostic

### Invalid states

Reject:

* valid validation with non-`None` reason.
* invalid validation with `Reason = None`.
* negative duration drift.
* blank diagnostics, according to the chosen normalization rule.

---

## `VvcConversionDecision`

### Valid states

A convert decision requires:

* `Action = Convert`
* `Reason = None`
* no precomputed result

A skip decision requires:

* `Action = Skip`
* `Reason -ne None`
* explicit result or enough data to produce one

A fail decision requires:

* `Action = Fail`
* `Reason -ne None`
* explicit result or enough data to produce one

### Invalid states

Reject:

* convert decision with a precomputed result.
* convert decision with non-`None` reason.
* skip decision with `Reason = None`.
* fail decision with `Reason = None`.
* skip/fail decision without either an explicit result or enough data to construct one.
* action/reason values that are not enum-backed.

---

# Suggested Test Ordering

Implement tests in this order to keep failures focused:

1. `ConvertToVvcResult`
2. `VvcConversionRequest`
3. `VvcConversionPathSet`
4. `VvcNativeResult`
5. `VvcMediaProbe`
6. `VvcOutputValidation`
7. `VvcConversionDecision`

This order starts with the final domain output contract, then works backward toward worker inputs and intermediate decisions.

---

# Implementation Notes

## Exception helper

Add a small internal assertion helper to reduce repeated validation noise:

```powershell
function Assert-VvcInvariant {
    param(
        [bool] $Condition,
        [string] $Message
    )

    if (-not $Condition) {
        throw [VvcConversionInvariantException]::new($Message)
    }
}
```

This keeps class constructors shorter and more consistent.

## String normalization helper

Use one helper for optional strings:

```powershell
function Normalize-VvcOptionalString {
    param([AllowNull()][string] $Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    return $Value.Trim()
}
```

Use a separate helper for required strings:

```powershell
function Assert-VvcRequiredString {
    param(
        [AllowNull()][string] $Value,
        [string] $Name
    )

    Assert-VvcInvariant `
        -Condition (-not [string]::IsNullOrWhiteSpace($Value)) `
        -Message "$Name must not be blank."
}
```

These helpers should stay private to the module.

---

# Verification

Run the focused domain test first:

```powershell
Invoke-Pester -Path 'pwsh-fun/tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1' -Output Detailed
```

Then run the full `Fun.Ffmpeg` suite:

```powershell
Invoke-Pester -Path 'pwsh-fun/tests/Fun.Ffmpeg' -Output Detailed
```

Then run static analysis:

```powershell
./pwsh-fun/tools/Invoke-PSSA.ps1
```

Finally, verify clean import:

```powershell
Import-Module ./pwsh-fun/src/Fun.Ffmpeg/Fun.Ffmpeg.psd1 -Force
```

---

# Completion Criteria

Phase 2 is complete when:

1. `Convert-ToVvc.Domain.Tests.ps1` exists and covers all new domain types.
2. All new domain invariant tests pass.
3. Existing `Fun.Ffmpeg` tests still pass.
4. The module imports cleanly.
5. PSScriptAnalyzer passes.
6. No worker execution behavior has changed.
7. No native ffmpeg / ffprobe behavior has changed.
8. No parallel behavior has changed.
9. Public `Convert-ToVvc` behavior remains compatible with Phase 1 characterization tests.

---

# Assumptions

* Phase 1 characterization tests already capture the current public behavior of `Convert-ToVvc`.
* This phase introduces domain types only; it does not yet route the worker through them.
* Tests use direct type references inside `InModuleScope Fun.Ffmpeg`, matching the existing PowerShell class-loading approach.
* `internal/ConvertToVvc.Types.psm1` is the correct home for these types.
* `SizeUnavailable` should exist as a domain reason now, but whether it ultimately produces `Failed` or `Converted` with diagnostics remains a later worker-policy decision.
* Any retained legacy result fields exist only for compatibility and must be derived from enum-backed state.
