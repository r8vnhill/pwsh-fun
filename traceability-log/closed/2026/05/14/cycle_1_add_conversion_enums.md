# [DONE] Cycle 1 — Add Conversion Enums

## Purpose

Introduce the enum vocabulary for the `Convert-ToVvc` domain model before adding invariant classes, result factories, decisions, or worker changes.

This cycle is intentionally small: prove that the enum types exist, that they expose the expected names, and that the names are stable enough for later domain, decision, and result tests.

This aligns with the broader refactor direction: enum-backed `Status`, `Reason`, and `Action` values should become the canonical machine-readable contract for conversion outcomes. 

---

## Scope

Add or complete these enum types:

```powershell
VvcConversionStatus
VvcConversionAction
VvcConversionReason
```

Do **not** change:

```text
Convert-ToVvc behavior
worker behavior
parallel execution
request construction
result construction
native process execution
ffmpeg / ffprobe helpers
module version
```

The only production change should be the enum definitions needed for this cycle’s tests.

---

## Test File

Use:

```text
pwsh-fun/tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1
```

If the file already exists, add the enum tests near the top in a dedicated `Describe` block.

If it does not exist, create it.

Because PowerShell classes and enums require parse-time loading, put the type module import at the **top of the test file** with `using module`, not inside `BeforeAll`.

Example:

```powershell
using module ../../modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1

Describe 'VVC conversion enums' {
    Context 'VvcConversionStatus' {
        It 'defines the expected status names' {
            [enum]::GetNames([VvcConversionStatus]) | Should -Be @(
                'Converted'
                'Skipped'
                'Failed'
            )
        }
    }

    Context 'VvcConversionAction' {
        It 'defines the expected action names' {
            [enum]::GetNames([VvcConversionAction]) | Should -Be @(
                'Convert'
                'Skip'
                'Fail'
            )
        }
    }

    Context 'VvcConversionReason' {
        It 'defines the expected reason names' {
            [enum]::GetNames([VvcConversionReason]) | Should -Be @(
                'None'
                'InvalidInput'
                'ExistingOutputValid'
                'EncodeFailed'
                'EncodedOutputMissing'
                'ProbeFailed'
                'UnexpectedCodec'
                'DurationUnavailable'
                'DurationDrift'
                'DecodeFailed'
                'PromoteFailed'
                'SizeUnavailable'
                'UnexpectedFailure'
            )
        }
    }
}
```

Using `[enum]::GetNames(...)` is better than scattered `.ToString()` assertions because it verifies both presence and ordering. Ordering matters because enum integer values may become observable later through serialization, logging, or interop.

---

## Production File

Update:

```text
pwsh-fun/modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1
```

Add the smallest implementation:

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

    InvalidInput
    ExistingOutputValid

    EncodeFailed
    EncodedOutputMissing

    ProbeFailed
    UnexpectedCodec
    DurationUnavailable
    DurationDrift
    DecodeFailed

    PromoteFailed
    SizeUnavailable
    UnexpectedFailure
}
```

Keep these in the type module with the other VVC domain definitions. Do not scatter enum definitions across worker/helper files.

---

## Relevant Files

```text
pwsh-fun/tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1
```

Add the enum contract tests.

```text
pwsh-fun/modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1
```

Define or complete `VvcConversionStatus`, `VvcConversionAction`, and `VvcConversionReason`.

```text
pwsh-fun/modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1
```

Avoid changing this in Cycle 1 unless the focused test proves the type module cannot be loaded predictably.

---

## Red / Green / Refactor

### Red

Add the focused enum tests first.

Run:

```powershell
Invoke-Pester -Path 'pwsh-fun/tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1' -Output Detailed
```

Expected initial failure:

```text
Unable to find type [VvcConversionStatus]
```

or missing enum values.

### Green

Add or complete the enum definitions in `ConvertToVvc.Types.psm1`.

Run the focused test again.

### Refactor

Only clean up enum placement, spacing, or naming consistency.

Do not introduce classes, constructors, factories, decisions, or worker changes.

---

## Verification

Run the focused domain test:

```powershell
Invoke-Pester -Path 'pwsh-fun/tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1' -Output Detailed
```

Then verify module importability:

```powershell
Import-Module 'pwsh-fun/modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1' -Force
```

A broader suite run is optional for this cycle, but useful if the enum file is dot-sourced or loaded by the module manifest:

```powershell
Invoke-Pester -Path 'pwsh-fun/tests/Fun.Ffmpeg' -Output Detailed
```

---

## Acceptance Criteria

Cycle 1 is complete when:

```text
VvcConversionStatus exists.
VvcConversionAction exists.
VvcConversionReason exists.
Focused enum tests pass.
Fun.Ffmpeg imports cleanly.
No worker behavior changed.
No request/result classes were added in this cycle.
No result contract migration happened in this cycle.
No native execution code changed.
```

## Implementation Notes

The domain spec now loads the type module at parse time with `using module`, so the enum contract can be checked directly without a runtime import hook. The enum vocabulary in the type module has been aligned to the cycle plan: `ExistingOutputValid`, `EncodeFailed`, `EncodedOutputMissing`, `UnexpectedCodec`, `DurationUnavailable`, `DurationDrift`, `DecodeFailed`, `PromoteFailed`, `SizeUnavailable`, and `UnexpectedFailure` are now part of the canonical reason set.
