# [PLAN] Cycle 5 — Add `VvcConversionRequest`

## Summary

Formalize the internal `Convert-ToVvc` worker payload as a validated domain object.

This cycle is implemented in `modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1` as a validated, read-only request object that is directly testable without changing the public `Convert-ToVvc` command, the parallel execution model, or the worker orchestration flow.

The request object represents the current worker-facing encode settings and tool paths: `InputPath`, `OutputDir`, `Suffix`, `Qp`, `Preset`, `Overwrite`, `VerifyMode`, `MaxDriftSec`, `FfmpegPath`, `FfprobePath`, and `EncoderThreads`. It stays filesystem-independent and does not anticipate later pipeline design beyond preserving compatibility with the existing worker inputs.

Use Takahiro Seguchi-inspired fictional fixture names where fake paths or scenario labels are needed, for example `Seguchi_Source.mkv`, `Seguchi_Output.vvc.mkv`, or `Seguchi_Temp.vvc.tmp.mkv`.

---

## Goals

* Add or verify a focused `VvcConversionRequest` domain contract.
* Validate constructor invariants test-first.
* Keep the type filesystem-independent.
* Keep the type read-only after construction.
* Preserve all current public command behavior.
* Avoid wiring the public command or parallel worker to the new request object in this cycle.

---

## Non-Goals

Do **not** change:

* `Convert-ToVvc` public parameters.
* `ForEach-Object -Parallel` behavior.
* Worker invocation or serialization boundaries.
* ffmpeg or ffprobe command behavior.
* output result shape.
* temp-path generation.
* media probing, validation, promotion, or cleanup logic.

Those belong to later cycles.

---

## Target Contract

`VvcConversionRequest` should be a small immutable data carrier for the current worker boundary.

The constructor should validate:

* `InputPath` is non-null and non-blank.
* `OutputDir` is non-null and non-blank.
* `Suffix` is non-null and non-blank.
* `Qp` is within the supported range.
* `Preset` is non-null and non-blank.
* `Overwrite` is preserved as a boolean flag.
* `VerifyMode` is valid for the existing verify-mode contract.
* `MaxDriftSec` is zero or positive.
* `EncoderThreads` is zero or positive.
* `FfmpegPath` is non-null and non-blank.
* `FfprobePath` is non-null and non-blank.

The object should remain filesystem-independent:

* no file existence checks.
* no directory existence checks.
* no directory creation.
* no path normalization that depends on the filesystem.
* no temp-path generation.

---

## Implementation Steps

### 1. Add focused red tests

Update:

```text
tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1
```

Add a dedicated context:

```powershell
Context 'VvcConversionRequest'
```

Cover one successful construction case and explicit invalid cases.

Required invalid-construction scenarios:

* rejects blank input path.
* rejects blank suffix.
* rejects invalid verify mode.
* rejects negative max drift.
* rejects negative encoder thread count.
* rejects blank ffmpeg path.
* rejects blank ffprobe path.

Include null cases where the constructor accepts nullable inputs or where PowerShell overload resolution does not hide the failure.

Use fictional Takahiro Seguchi-inspired test values, for example:

```powershell
$inputPath = 'E:\Media\Seguchi_Source.mkv'
$outputDir = 'E:\Media\encoded'
$suffix = '.vvc'
$ffmpegPath = 'E:\Tools\Seguchi\ffmpeg.exe'
$ffprobePath = 'E:\Tools\Seguchi\ffprobe.exe'
```

Avoid asserting exact exception messages unless the existing domain test style already does so. Prefer asserting the exception type, likely `VvcConversionInvariantException`, if that is the established domain invariant failure type.

---

### 2. Confirm the actual worker boundary

Read only:

```text
modules/Fun.Ffmpeg/internal/ConvertToVvc.Worker.ps1
```


Do not refactor worker logic in this cycle.

The request type should model the worker’s current inputs, not an ideal future orchestration model.

---

### 3. Implement or refine `VvcConversionRequest`

Update:

```text
modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1
```

Implement `VvcConversionRequest` as an immutable class with constructor validation.

Prefer read-only properties:

```powershell
class VvcConversionRequest {
    [string] $InputPath
    [string] $OutputDir
    [string] $Suffix
    [int] $Qp
    [string] $Preset
    [bool] $Overwrite
    [string] $VerifyMode
    [double] $MaxDriftSec
    [int] $EncoderThreads
    [string] $FfprobePath

    VvcConversionRequest(
        [string] $inputPath,
        [string] $outputDir,
        [string] $suffix,
        [int] $qp,
        [string] $preset,
        [bool] $overwrite,
        [string] $verifyMode,
        [double] $maxDriftSec,
        [int] $encoderThreads,
        [string] $ffmpegPath,
        [string] $ffprobePath
    ) {
        # validation
        # assignment
    }
}
```

Adjust the exact property list and types to match the existing worker contract.

Use existing shared guard helpers where available. If validation becomes repetitive, add small private helpers in `ConvertToVvc.Types.psm1`, for example:

```powershell
Assert-VvcNonBlankString
Assert-VvcNonNegativeNumber
Assert-VvcValidVerifyMode
```

Keep helpers private to the types module unless there is already a shared internal validation pattern.

---

### 4. Keep validation domain-level only

The constructor should reject contradictory or invalid request state.

It should not perform operational checks.

Good constructor checks:

```powershell
[string]::IsNullOrWhiteSpace($inputPath)
$qp -lt 0 -or $qp -gt 63
$maxDriftSec -lt 0
$encoderThreads -lt 0
```

Avoid constructor checks like:

```powershell
Test-Path $inputPath
Test-Path $ffmpegPath
New-Item $outputDir
Resolve-Path $inputPath
```
Those would make the domain type environment-dependent and harder to unit test.

---

### 5. Do not wire yet

Do not change the public command to construct `VvcConversionRequest`.

Do not change the parallel scriptblock to pass `VvcConversionRequest`.

Do not change worker behavior to require the new object unless the worker already depends on it.

This cycle’s output is the tested request type, not orchestration integration.

---

## Verification

Run the focused domain tests first:

```powershell
Invoke-Pester ./tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1 -FullName '*VvcConversionRequest*'
```
Then run the full domain contract file:

```powershell
Invoke-Pester ./tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1
```

Expected result:

* `VvcConversionRequest` accepts one valid construction case.
* invalid constructor inputs throw the expected invariant exception.
* earlier enum, exception, result, and path-set contracts still pass.
* no public `Convert-ToVvc` behavior changes.
* no ffmpeg or ffprobe integration behavior changes.


## Acceptance Criteria

Cycle 5 is complete when:

* `VvcConversionRequest` exists in `ConvertToVvc.Types.psm1`.
* The class can be constructed directly from domain tests.
* Required request fields are exposed as read-only properties.
* Constructor validation rejects invalid request state.
* Tests cover valid construction and the agreed invariant failures.
* The type remains filesystem-independent.
* No public command wiring has changed.
* No worker orchestration behavior has changed.

---

## Files

### Primary

```text
modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1
tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1
```

### Reference Only

```text
modules/Fun.Ffmpeg/internal/ConvertToVvc.Worker.ps1
```

Use the worker file only to confirm the current boundary. Do not refactor it during this cycle.

---

## Design Decision

`VvcConversionRequest` should describe the current worker invocation contract, not the future conversion lifecycle.

Later cycles can introduce richer domain objects for path sets, probe results, output validation, native command results, and promotion behavior. This cycle should stay deliberately narrow: request shape, invariants, and tests.
