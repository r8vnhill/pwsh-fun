# [DONE] Cycle 2 — Verify `VvcConversionInvariantException`

## Summary

Add focused test coverage for `VvcConversionInvariantException`, the domain exception used to represent impossible or contradictory `Convert-ToVvc` internal states.

This cycle is intentionally narrow. It should verify that the exception type is available from the VVC domain type module and that Pester can match it by exact exception type. Since `VvcConversionInvariantException` already exists in `modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1`, this cycle is primarily a verification and traceability step unless replaying the refactor from an earlier branch.

## Scope

This cycle covers only:

* Loading the VVC domain type module.
* Verifying that `VvcConversionInvariantException` exists.
* Verifying that it can be thrown and matched with `Should -Throw -ExceptionType`.

This cycle does **not** change conversion behavior, worker orchestration, validation flow, result contracts, native process execution, or filesystem behavior.

## Target Files

Primary test file:

```powershell
tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1
```

Primary implementation file:

```powershell
modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1
```

## Test-First Steps

### 1. Confirm parse-time type loading

At the top of `Convert-ToVvc.Domain.Tests.ps1`, ensure the file uses a top-level `using module` import for the type module.

Example:

```powershell
using module ../../modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1
```

Keep this as a parse-time import, not a runtime `Import-Module`, because PowerShell classes and enums must be known before the test file executes.

### 2. Add a focused exception context

Add a dedicated context near the existing enum/domain contract tests:

```powershell
Describe 'Convert-ToVvc domain types' {
    Context 'VvcConversionInvariantException' {
        It 'can be thrown and matched by exact exception type' {
            {
                throw [VvcConversionInvariantException]::new('Invalid state')
            } | Should -Throw -ExceptionType ([VvcConversionInvariantException])
        }
    }
}
```

If the file already has a `Describe` block for VVC domain types, place this in that existing block instead of adding a competing top-level structure.

### 3. Keep or add the minimal implementation

Confirm that `ConvertToVvc.Types.psm1` contains the exception type:

```powershell
class VvcConversionInvariantException : System.Exception {
    VvcConversionInvariantException([string]$Message) : base($Message) {}
}
```

Do not add extra constructors unless a failing test demonstrates that they are needed. The goal of this cycle is a minimal invariant exception contract, not a broader exception hierarchy.

## Explicit Non-Goals

Do not modify any of the following in Cycle 2:

* `Convert-ToVvc`
* `Invoke-VvcConversionWorker`
* Worker runspace orchestration
* ffmpeg or ffprobe invocation
* Result factories
* Request objects
* Path validation
* Output validation
* Probe or decode verification logic
* Public command behavior
* User-facing error handling

Also do not convert normal operational failures into `VvcConversionInvariantException`. Missing files, invalid user input, failed native commands, invalid media, and filesystem problems should continue to use the existing public failure paths.

`VvcConversionInvariantException` is reserved for states that should be impossible if the domain model and worker code are correct.

## Test Plan

Run the focused domain tests:

```powershell
Invoke-Pester -Path 'pwsh-fun/tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1' -Output Detailed
```

Confirm the public module still imports:

```powershell
Import-Module 'pwsh-fun/modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1' -Force
```

Optionally run the full Fun.Ffmpeg suite:

```powershell
Invoke-Pester -Path 'pwsh-fun/tests/Fun.Ffmpeg' -Output Detailed
```

## Acceptance Criteria

Cycle 2 is complete when:

* `Convert-ToVvc.Domain.Tests.ps1` has focused coverage for `VvcConversionInvariantException`.
* The test file loads `ConvertToVvc.Types.psm1` with top-level `using module`.
* This assertion passes:

```powershell
{
    throw [VvcConversionInvariantException]::new('Invalid state')
} | Should -Throw -ExceptionType ([VvcConversionInvariantException])
```

* Existing enum/domain type tests still pass.
* `Fun.Ffmpeg.psd1` still imports successfully.
* No operational error paths are changed to throw `VvcConversionInvariantException`.
* No conversion worker behavior changes are introduced.

## Implementation Notes

The exception already existed in `modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1`, so the production type module did not need changes in this cycle.

The regression lock was added to `tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1` in a dedicated `VvcConversionInvariantException` context. The test throws the exception directly and verifies that Pester matches it with `Should -Throw -ExceptionType`.

This gives later cycles a stable invariant-failure primitive without mixing that concern into user-facing conversion behavior.

## Completion Notes

Completed on 2026-05-16.

Changed:

* Added focused Pester coverage for `VvcConversionInvariantException`.
* Kept the existing top-level `using module` import for parse-time type loading.
* Confirmed no conversion behavior, worker orchestration, native execution, or filesystem behavior was changed.
