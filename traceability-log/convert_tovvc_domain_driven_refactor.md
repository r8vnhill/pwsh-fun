# [PLAN] Convert-ToVvc Domain-Driven Refactor

## Summary

Refactor `Convert-ToVvc` into a domain-first conversion pipeline with enum-backed statuses/reasons, invariant-checking domain types, explicit decisions, and thin orchestration around native process and filesystem infrastructure.

This is an intentional breaking refactor for the public result contract. The new contract should prefer `Status` and `Reason` over the legacy `Ok` / `Skipped` booleans.

Before any behavioral work, restore module importability by fixing the misplaced `[OutputType([scriptblock])]` attribute in `ConvertToVvc.Worker.ps1`. Move the attribute to the function declaration position or remove it.

## Primary Goals

* Make conversion behavior explicit through domain types.
* Replace ad hoc result objects with invariant-checked result construction.
* Replace stringly typed reasons with enum-backed reasons.
* Centralize native process execution.
* Centralize temp output creation, validation, promotion, and cleanup.
* Keep parallel execution working through a stable internal entrypoint.
* Align `Convert-ToVvc` result style with `VvcAudit` and `VvcRemoval`.
* Use BDD-style Pester tests, with DDT for decision matrices and argument generation.

## Non-Goals

* Do not replace `ForEach-Object -Parallel` in this refactor.
* Do not redesign the public command parameters beyond already planned additions like `-EncoderThreads`.
* Do not rename verify mode strings in this pass.
* Do not introduce a new job backend.
* Do not add a property-based testing dependency unless a separate decision is made.
* Do not expose low-level helper functions as public user-facing commands.

## Important PowerShell Class Boundary Decision

PowerShell classes are useful here, but they need to be handled deliberately.

Classes and enums are not consumed like ordinary exported functions. Any script file that references `[VvcConversionStatus]`, `[VvcConversionReason]`, or `[VvcConversionRequest]` directly should load the type definitions at parse time with `using module`, or be structured so the class references only occur in files that already have access to those definitions.

Recommended approach:

* Keep domain types in `ConvertToVvc.Types.psm1`.
* Ensure files that reference the types directly load them predictably.
* Keep the public command returning objects created inside the module.
* Tests that directly reference enum/class names should import/load the type module explicitly.
* Add a parallel boundary test to prove domain result objects survive the `ForEach-Object -Parallel` runspace boundary as expected.

If class loading becomes brittle, use classes internally but return a stable `[pscustomobject]` DTO with `PSTypeName = 'Fun.Ffmpeg.ConvertToVvcResult'`. However, the preferred direction for this refactor is a real `ConvertToVvcResult` domain result, provided tests prove it is reliable.

## Public API Contract

### Keep Existing Public Parameters

Preserve current `Convert-ToVvc` parameters and behavior, including:

* input discovery behavior,
* output directory behavior,
* suffix behavior,
* QP behavior,
* preset behavior,
* overwrite behavior,
* `-MaxParallel`,
* verify mode strings: `none`, `quick`, `strict`.

### Add or Preserve

Keep/add:

```powershell
-EncoderThreads <int>
```

Default should preserve the current ffmpeg behavior. If `0` means ffmpeg automatic threading and matches current behavior, default to `0`.

### Breaking Result Contract

Update `ConvertToVvcResult` to make these properties authoritative:

```powershell
File
InputPath
OutputPath
Status
Reason
OriginalMB
NewMB
Ratio
ExitCode
Diagnostic
```

Where:

```powershell
Status = [VvcConversionStatus]::Converted
Status = [VvcConversionStatus]::Skipped
Status = [VvcConversionStatus]::Failed
```

and:

```powershell
Reason = [VvcConversionReason]::<value>
```

Remove `Ok` and `Skipped` as authoritative fields.

Recommended transitional choice:

* Keep `Ok` and `Skipped` as derived read-only compatibility properties for one minor release if low effort.
* Mark tests and docs as migrated to `Status` and `Reason`.
* Do not use `Ok` / `Skipped` internally.

If this refactor is allowed to be fully breaking immediately, remove them entirely and make the changelog explicit.

## Versioning

Bump:

```text
modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1
0.3.0 -> 0.4.0
```

Because the result contract changes, this should be treated as a breaking change even if the module is still pre-1.0.

## Domain Model

### Enums

```powershell
enum VvcConversionStatus {
    Converted
    Skipped
    Failed
}
```

Recommended reason enum:

```powershell
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

I would add `ProbeFailed`, `DurationUnavailable`, and `SizeUnavailable`. They prevent overloading `UnexpectedFailure` for ordinary media/metadata failures.

Avoid `ExistingOutputInvalid` as a final result reason unless you actually return a skipped/failed result for that case. If invalid existing output causes re-encoding, it is a decision detail, not the final result reason.

### Core Classes

Add or update `ConvertToVvc.Types.psm1` with:

```powershell
class VvcConversionRequest
class VvcConversionPathSet
class VvcNativeResult
class VvcMediaProbe
class VvcOutputValidation
class VvcConversionDecision
class ConvertToVvcResult
```

The extra `VvcConversionDecision` is useful. It separates “what should happen?” from “perform the filesystem/native side effect.”

Example decision states:

```powershell
enum VvcConversionAction {
    Convert
    Skip
    Fail
}
```

A decision can carry:

```powershell
Action
Reason
Diagnostic
ExistingOutputProbe
```

This makes skip/fail/convert decisions testable without invoking ffmpeg.

## Domain Invariants

### `ConvertToVvcResult`

Enforce:

* `Converted` must have `Reason = None`.
* `Skipped` must have non-`None` reason.
* `Failed` must have non-`None` reason.
* `Converted` must have non-empty `OutputPath`.
* `Converted` should have `NewMB -gt 0`.
* `Ratio` is `$null` or non-negative.
* `Diagnostic` is `$null` or non-whitespace.
* `ExitCode` is `$null` unless a native process was actually invoked.

### `VvcConversionRequest`

Enforce:

* file is non-null,
* output directory is non-null or resolvable,
* suffix is non-null,
* QP is within accepted range,
* preset is non-empty,
* verify mode is one of `none`, `quick`, `strict`,
* max drift is non-negative,
* encoder threads is non-negative,
* ffmpeg path is non-empty,
* ffprobe path is non-empty.

### `VvcConversionPathSet`

Enforce:

* input path is non-empty,
* output path is non-empty,
* temp path is non-empty,
* temp path is not equal to output path,
* temp path directory equals output path directory,
* temp path extension equals output path extension.

### `VvcNativeResult`

Enforce:

* tool path is non-empty,
* argument list is not null,
* exit code is present,
* `Succeeded` equals `ExitCode -eq 0`.

### `VvcOutputValidation`

Enforce:

* valid output has `Reason = None`,
* invalid output has non-`None` reason,
* duration drift is `$null` or non-negative,
* diagnostic is `$null` or non-whitespace.

## File / Responsibility Split

Recommended structure:

```text
ConvertToVvc.Types.psm1
  Domain enums and classes.

ConvertToVvc.Domain.ps1
  Pure decisions, validation interpretation, result factories.

ConvertToVvc.Infrastructure.ps1
  Native command wrapper, filesystem operations, probing, temp paths.

ConvertToVvc.Worker.ps1
  Worker entrypoint and conversion application service.

Convert-ToVvc.ps1
  Public command orchestration only.
```

If adding another file is too much churn, keep `Helpers.ps1` and `Worker.ps1`, but still separate domain-pure logic from infrastructure logic internally.

## Worker Entry Point

Keep an exported internal entrypoint for parallel runspaces:

```powershell
Invoke-FunFfmpegInternalVvcWorker
```

This should do as little as possible:

```powershell
function Invoke-FunFfmpegInternalVvcWorker {
    [CmdletBinding()]
    [OutputType([ConvertToVvcResult])]
    param(
        [Parameter(Mandatory)]
        [VvcConversionRequest] $Request
    )

    Invoke-VvcConversion -Request $Request
}
```

The public command’s parallel scriptblock should:

```powershell
Import-Module $request.ModulePath -Force
Invoke-FunFfmpegInternalVvcWorker -Request $request
```

Do not put conversion lifecycle logic in the parallel scriptblock.

## Application Service

Add:

```powershell
Invoke-VvcConversion
```

This is the domain application service. It coordinates pure decisions and infrastructure calls.

Suggested flow:

```text
Resolve paths
Probe input
If invalid input -> Failed / InvalidInput
Probe existing output if present and overwrite is false
If existing output valid -> Skipped / ExistingOutputValid
Create conversion attempt
Encode to GUID temp path
Validate temp output
Promote temp to final output
Return Converted / None
Cleanup temp on all non-committed paths
```

## Native Tool Boundary

Add:

```powershell
Invoke-NativeTool
```

Return:

```powershell
[VvcNativeResult]
```

All ffmpeg and ffprobe calls must go through this function.

No direct calls to:

```powershell
ffmpeg
ffprobe
& $FfmpegPath
& $FfprobePath
```

outside the native wrapper, unless a test fixture intentionally does so.

## Temp Output Policy

Use GUID temp paths in the same output directory:

```text
video.<guid>.partial.mkv
```

Rules:

* same directory as final output,
* same extension as final output,
* unique per attempt,
* never equal to final output,
* only temp path is removed during cleanup,
* final output is only replaced during the promote step.

The temp path should be created once inside `VvcConversionPathSet` and passed through the attempt. Do not recalculate it in multiple helpers.

## Result Factories

Use factory methods or static constructors. Do not create `ConvertToVvcResult` ad hoc across the codebase.

Recommended factories:

```powershell
[ConvertToVvcResult]::Converted(...)
[ConvertToVvcResult]::Skipped(...)
[ConvertToVvcResult]::Failed(...)
```

or private helpers:

```powershell
New-VvcConvertedResult
New-VvcSkippedResult
New-VvcFailedResult
```

The factories should be the only place where result invariants are enforced.

## Error Mapping

Use explicit mappings.

| Condition                                         |                                                     Status |                          Reason |
| ------------------------------------------------- | ---------------------------------------------------------: | ------------------------------: |
| Input cannot be probed or decoded enough to trust |                                                   `Failed` | `InvalidInput` or `ProbeFailed` |
| Existing output is valid and overwrite is false   |                                                  `Skipped` |           `ExistingOutputValid` |
| ffmpeg exits non-zero                             |                                                   `Failed` |                  `EncodeFailed` |
| ffmpeg exits zero but temp output missing         |                                                   `Failed` |          `EncodedOutputMissing` |
| output codec is not expected VVC codec            |                                                   `Failed` |               `UnexpectedCodec` |
| duration cannot be read when required             |                                                   `Failed` |           `DurationUnavailable` |
| duration drift exceeds threshold                  |                                                   `Failed` |                 `DurationDrift` |
| strict decode check fails                         |                                                   `Failed` |                  `DecodeFailed` |
| moving temp to final path fails                   |                                                   `Failed` |                 `PromoteFailed` |
| size calculation fails after conversion           | `Failed` or `Converted` with diagnostic, decide explicitly |               `SizeUnavailable` |
| unhandled exception                               |                                                   `Failed` |             `UnexpectedFailure` |

Make `Diagnostic` carry human-readable details. Make `Reason` machine-readable and stable.

## Verify Mode Semantics

Keep public names:

```text
none
quick
strict
```

But define their domain behavior explicitly:

```text
none:
  no output validation beyond temp file existence, unless current behavior already checks more.

quick:
  validate codec and duration metadata.

strict:
  validate codec, duration metadata, and decode sample/full segment according to current behavior.
```

If current `strict` only decodes a sample, preserve that behavior and avoid implying full-file verification.

## Test Plan

### ~~Phase 0: Importability Hotfix~~

First test:

```powershell
Import-Module modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1 -Force
```

This must pass before deeper refactoring.

Add a regression test for the `[OutputType]` placement bug if practical.

### ~~Phase 1: Characterization Tests~~

Before changing internals, capture current behavior at the user-visible scenario level.

Since the result contract is intentionally changing, characterize behavior as scenarios, not exact old fields:

* successful conversion,
* valid existing output skipped,
* invalid input failed,
* ffmpeg failure failed,
* missing temp output failed,
* verification failure failed,
* overwrite behavior,
* parallel behavior.

These tests can later be updated to assert `Status` and `Reason`.

### ~~Phase 2: Domain Invariant Tests~~

Implemented in `traceability-log/phase_2_domain_invariant_tests.md`.

Match the `VvcAudit.Tests.ps1` style.

Add tests for:

```powershell
VvcConversionRequest
VvcConversionPathSet
VvcNativeResult
VvcMediaProbe
VvcOutputValidation
ConvertToVvcResult
```

Examples:

```powershell
Describe 'ConvertToVvcResult invariants' {
    Context 'Converted result' {
        It 'requires Reason None' {}
        It 'requires an output path' {}
        It 'requires positive NewMB' {}
    }

    Context 'Failed result' {
        It 'requires a non-None reason' {}
        It 'normalizes blank diagnostics to null or rejects them' {}
    }

    Context 'Skipped result' {
        It 'requires a non-None reason' {}
    }
}
```

### Phase 3: Decision Tests

Add pure BDD tests for conversion decisions.

Examples:

```text
Given input probe fails
When deciding conversion
Then decision is Fail / InvalidInput

Given existing output is valid and overwrite is false
When deciding conversion
Then decision is Skip / ExistingOutputValid

Given existing output is invalid and overwrite is false
When deciding conversion
Then decision is Convert
```

This is where DDD pays off most: the decision matrix should not need fake ffmpeg processes.

### Phase 4: Native / Infrastructure Tests

Test `Invoke-NativeTool` contract:

* captures stdout,
* captures stderr,
* captures exit code,
* maps `Succeeded`,
* handles missing executable predictably.

Test probing helpers using fake tools:

* codec parse success,
* duration parse success,
* non-numeric duration,
* empty duration,
* non-zero ffprobe exit,
* stderr diagnostic propagation.

### Phase 5: Argument Generation Tests

Use DDT for `New-FfmpegArgumentList`:

* overwrite enabled,
* overwrite disabled,
* QP values,
* preset values,
* encoder thread values,
* paths with spaces,
* paths with quotes/special characters if supported,
* no null/empty arguments.

### Phase 6: Conversion Attempt Tests

BDD contexts:

```powershell
Describe 'Invoke-VvcConversionAttempt' {
    Context 'when encode succeeds and validation succeeds' {
        It 'promotes temp output and returns Converted / None'
    }

    Context 'when encode exits non-zero' {
        It 'returns Failed / EncodeFailed and removes temp output'
    }

    Context 'when encode exits zero but temp output is missing' {
        It 'returns Failed / EncodedOutputMissing and does not promote'
    }

    Context 'when validation fails' {
        It 'returns Failed with the validation reason and removes temp output'
    }

    Context 'when promotion fails' {
        It 'returns Failed / PromoteFailed and leaves no stale temp output when possible'
    }
}
```

### Phase 7: Parallel Boundary Test

Keep and strengthen the parallel test:

* `MaxParallel > 1` imports the module,
* request object can cross into the parallel runspace,
* `Invoke-FunFfmpegInternalVvcWorker` is callable,
* returned object has `Status` and `Reason`,
* enum values are usable by consumers after the command returns.

This catches the biggest PowerShell-specific risk in the design.

### Phase 8: Integration Tests

Keep fake media tools for fast tests.

Tag actual ffmpeg tests separately:

```powershell
-Tag Integration
```

Integration scenarios:

* real ffmpeg available,
* real ffprobe available,
* quick verification,
* strict verification if runtime is acceptable,
* custom `FfmpegPath`,
* custom `FfprobePath`,
* overwrite false,
* overwrite true,
* parallel conversion of multiple small files.

## Quality Gates

Run:

```powershell
Invoke-Pester -Path 'pwsh-fun/tests/Fun.Ffmpeg' -Output Detailed
./pwsh-fun/tools/Invoke-PSSA.ps1
```

Add or preserve gates for:

* no direct ffmpeg/ffprobe invocation outside `Invoke-NativeTool`,
* no large generated here-string worker body,
* no ad hoc `ConvertToVvcResult` construction outside result factories,
* no string reason matching in new tests,
* public tests use `Status` and `Reason`.

## Migration Sequence

### Step 1: Fix Importability

Fix `[OutputType([scriptblock])]` placement or remove it.

Run import test and existing Pester suite.

### Step 2: Add Domain Types Without Rewiring Everything

Introduce enums/classes and invariant tests.

Do not yet replace the worker.

### Step 3: Add Result Factories

Create `Converted`, `Skipped`, and `Failed` result construction paths.

Update tests to assert the new contract.

### Step 4: Add Native Wrapper

Introduce `Invoke-NativeTool` returning `VvcNativeResult`.

Route ffprobe helpers through it first, then ffmpeg encode.

### Step 5: Add Request and Path Types

Replace hashtable/`pscustomobject` request construction with `VvcConversionRequest`.

Add `VvcConversionPathSet` and GUID temp path generation.

### Step 6: Extract Pure Decisions

Add `VvcConversionDecision` and pure decision helpers.

Cover with BDD/DDT tests.

### Step 7: Rebuild Worker Around Application Service

Implement:

```powershell
Invoke-VvcConversion
Invoke-FunFfmpegInternalVvcWorker
```

Keep parallel scriptblock thin.

### Step 8: Remove Legacy Worker Logic

Delete the old here-string/generator path once tests pass.

### Step 9: Finalize Breaking Result Contract

Remove or derive `Ok` / `Skipped`.

Update all tests to use:

```powershell
$result.Status
$result.Reason
```

### Step 10: Version and Migration Notes

Bump module version to `0.4.0`.

Update changelog/migration notes.

## Acceptance Criteria

The refactor is complete when:

* The module imports cleanly.
* The here-string worker body is gone.
* `Convert-ToVvc` returns the new domain-first result contract.
* `Ok` and `Skipped` are either removed or derived compatibility accessors only.
* `Status` and `Reason` are authoritative.
* All terminal outcomes map to `VvcConversionStatus` and `VvcConversionReason`.
* Domain classes enforce invariants.
* Native execution goes through `Invoke-NativeTool`.
* ffprobe path is explicit and honored.
* Temp paths are GUID-based, same-directory, and cleaned safely.
* Parallel execution still works.
* Existing fake media tests are updated to assert enum statuses/reasons.
* Pester passes.
* PSScriptAnalyzer passes.
