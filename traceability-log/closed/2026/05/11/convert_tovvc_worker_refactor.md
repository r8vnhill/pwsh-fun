# [IMPLEMENTED] Convert-ToVvc Worker Refactor

## Implementation Status

Implemented in the Fun.Ffmpeg module:

* Replaced the generated worker here-string with a small scriptblock.
* Added exported internal runspace entrypoint `Invoke-FunFfmpegInternalVvcWorker`.
* Moved conversion lifecycle logic into normal private module functions.
* Added explicit `FfprobePath` flow through the worker request.
* Routed ffmpeg/ffprobe execution through `Invoke-NativeTool`.
* Replaced deterministic partial output names with GUID same-directory temp paths.
* Collapsed encode / validate / promote / cleanup into one conversion attempt path.
* Added public `-EncoderThreads`, defaulting to `0`.
* Preserved the existing `ConvertToVvcResult` compatibility properties.
* Updated README and focused Pester coverage.

Verification:

* `Invoke-Pester -Path 'pwsh-fun/tests/Fun.Ffmpeg' -Output Detailed` passed with 35 tests.
* `./pwsh-fun/tools/Invoke-PSSA.ps1` completed with exit code `0`; warning-level findings remain in the broader repository and touched files.

## Summary

Refactor the VVC conversion worker so the conversion lifecycle is implemented as normal module code instead of a generated here-string scriptblock. The refactor should improve testability, static analysis, native command handling, and safety under parallel execution while preserving the current public behavior of `Convert-ToVvc`.

The first pass should be behavior-preserving by default. It should not change the public execution backend, verify mode names, result shape, or default ffmpeg behavior unless explicitly called out below.

## Goals

* Remove the large worker here-string.
* Centralize ffmpeg/ffprobe invocation.
* Make encode / verify / promote / cleanup logic reusable and testable.
* Avoid temp-file collisions during parallel conversion.
* Preserve existing public behavior and current result properties.
* Enable BDD-style Pester coverage around the worker lifecycle.
* Keep the refactor incremental enough to review safely.

## Non-Goals

* Do not migrate from `ForEach-Object -Parallel` to `Start-ThreadJob` in this refactor.
* Do not redesign the public result contract.
* Do not rename public verify modes.
* Do not add broad new dependencies.
* Do not change default conversion quality, preset, overwrite, or verification behavior.
* Do not export implementation helpers as normal user-facing commands.

## Important Design Correction

A parallel scriptblock that imports the module cannot normally call private module functions directly by name, because only exported commands are visible in the caller session state.

Therefore, choose one of these strategies deliberately:

### Preferred: exported internal entrypoint, hidden from public docs

Add a narrowly scoped exported command such as:

```powershell
Invoke-ConvertToVvcWorker
```

or:

```powershell
Invoke-FunFfmpegInternalVvcWorker
```

This command becomes the only worker entrypoint visible to the parallel runspace. It delegates immediately to private helpers.

Pros:

* Simple.
* Reliable in `ForEach-Object -Parallel`.
* Easy to test.
* Avoids generated code.
* Keeps most implementation private.

Cons:

* Technically exported, even if treated as internal.
* Needs naming that strongly signals “not public API.”

### Alternative: call a module-scoped scriptblock

Use module session-state invocation to execute inside the imported module context.

Pros:

* Keeps worker entrypoint private.

Cons:

* More complex.
* Easier to get wrong.
* Less discoverable for tests.
* Higher maintenance cost.

Recommendation: use the **exported internal entrypoint** for this refactor, and mark it as internal by convention and tests. Do not document it as public API.

## Key Changes

* Replace the large here-string worker body with a small parallel scriptblock that:

  * imports the module in the parallel runspace,
  * receives a request object,
  * calls the internal worker entrypoint,
  * returns a `ConvertToVvcResult`-compatible result.

* Keep `ForEach-Object -Parallel` and `-ThrottleLimit` behavior unchanged.

* Introduce an internal request object built before entering the parallel block. Include:

  * `File`
  * `OutputDirectory`
  * `Suffix`
  * `Qp`
  * `Preset`
  * `Overwrite`
  * `VerifyMode`
  * `MaxDriftSec`
  * `ModulePath`
  * `FfmpegPath`
  * `FfprobePath`
  * `EncoderThreads`

* Add `FfprobePath` explicitly. Never call literal `ffprobe` from worker logic.

* Add a private `Invoke-NativeTool` wrapper and route all ffmpeg/ffprobe calls through it.

* Replace deterministic temp outputs like:

```text
name.__partial__.mkv
```

with same-directory GUID temp paths.

* Collapse duplicated encode / validate / promote / cleanup / result construction into a single conversion attempt helper using `try` / `finally`.

* Keep result compatibility by preserving:

  * `File`
  * `Ok`
  * `Skipped`
  * `Reason`
  * `OriginalMB`
  * `NewMB`
  * `Ratio`

## Proposed Worker Flow

```powershell
Convert-ToVvc
  └─ Get-ConvertToVvcWorkerRequest
      └─ ForEach-Object -Parallel
          └─ Import-Module $request.ModulePath
          └─ Invoke-FunFfmpegInternalVvcWorker -Request $request
              ├─ Resolve-VvcConversionPath
              ├─ Test-VvcInput
              ├─ Test-VvcExistingOutput
              ├─ Invoke-VvcConversionAttempt
              │   ├─ New-VvcTempPath
              │   ├─ Invoke-VvcEncode
              │   ├─ Test-VvcOutput
              │   ├─ Move-VvcTempOutput
              │   └─ finally cleanup
              └─ New-ConvertToVvcResult
```

## Public Interfaces

### Preserve

Keep `Convert-ToVvc` behavior compatible:

* same default execution model,
* same `-MaxParallel` behavior,
* same verify modes,
* same default overwrite behavior,
* same result properties,
* same default ffmpeg threading behavior.

### Add

Add:

```powershell
-EncoderThreads <int>
```

Default:

```powershell
0
```

Pass it to ffmpeg as:

```powershell
-threads 0
```

only if this is already equivalent to current behavior. If adding `-threads 0` changes command-line shape but not behavior, that is acceptable, but tests should make the expected argument generation explicit.

Consider allowing:

```powershell
-EncoderThreads $null
```

internally to mean “omit `-threads` entirely,” but keep the public default behavior clear.

### Result Additions

Optional additive properties:

* `Status`
* `InputPath`
* `OutputPath`
* `ExitCode`
* `Diagnostic`
* `Elapsed`

Only add these if existing tests and consumers remain unaffected. Existing properties must remain authoritative for compatibility.

Recommended mapping:

```text
Ok=$true,  Skipped=$false => Status='Converted'
Ok=$true,  Skipped=$true  => Status='Skipped'
Ok=$false, Skipped=$false => Status='Failed'
```

## Internal Types / Objects

Use simple internal `pscustomobject` request and probe-result objects for now.

Avoid introducing public classes unless there is a clear need. PowerShell classes can be useful, but they increase module loading and compatibility complexity. This refactor benefits more from clearer boundaries than from strong typing everywhere.

Recommended internal request shape:

```powershell
[pscustomobject]@{
    File           = $File
    OutputDir      = $OutputDir
    Suffix         = $Suffix
    Qp             = $Qp
    Preset         = $Preset
    Overwrite      = [bool] $Overwrite
    VerifyMode     = $VerifyMode
    MaxDriftSec    = $MaxDriftSec
    ModulePath     = $ModulePath
    FfmpegPath     = $FfmpegPath
    FfprobePath    = $FfprobePath
    EncoderThreads = $EncoderThreads
}
```

Recommended native result shape:

```powershell
[pscustomobject]@{
    FilePath  = $FilePath
    Arguments = $ArgumentList
    ExitCode  = $exitCode
    StdOut    = $stdout
    StdErr    = $stderr
    Succeeded = $exitCode -eq 0
}
```

Recommended probe result shape:

```powershell
[pscustomobject]@{
    Succeeded   = $true
    CodecName   = $codecName
    DurationSec = $duration
    Diagnostic  = $null
}
```

## Implementation Changes

### Worker Entrypoint

Add one internal-facing exported command:

```powershell
function Invoke-FunFfmpegInternalVvcWorker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Request
    )

    Invoke-VvcConversionWorker -Request $Request
}
```

Only this function needs to be visible to the parallel scriptblock. All real implementation remains private.

### Native Invocation

Add:

```powershell
Invoke-NativeTool
```

Responsibilities:

* execute native command,
* capture stdout,
* capture stderr,
* capture exit code,
* return structured result,
* avoid scattered `$LASTEXITCODE` reads.

All direct ffmpeg/ffprobe calls should be removed from worker helpers.

### Path Resolution

Add:

```powershell
Resolve-VvcConversionPath
```

Responsibilities:

* calculate input path,
* calculate final output path,
* calculate output directory,
* validate output directory existence or create it if current behavior already does so,
* avoid string concatenation spread across worker logic.

### Temp Path Generation

Add:

```powershell
New-VvcTempPath
```

Rules:

* same directory as final output,
* same extension as final output,
* unique per attempt,
* not equal to final output,
* safe under parallel execution.

### Argument Generation

Rename `Build-Args` to:

```powershell
New-FfmpegArgumentList
```

Responsibilities:

* produce only the ffmpeg argument array,
* no process execution,
* no file mutation,
* deterministic output for easy DDT coverage.

Include DDT cases for:

* overwrite enabled,
* overwrite disabled,
* verify modes if they affect args,
* `EncoderThreads`,
* paths with spaces,
* special characters in paths.

### Probing

Add helpers such as:

```powershell
Get-VvcMediaProbe
Test-VvcInput
Test-VvcOutput
```

Use `[double]::TryParse()` for duration parsing.

Avoid sentinel values like `-1`. Prefer:

```powershell
$null
```

or a structured result with:

```powershell
Succeeded = $false
Diagnostic = 'Could not parse duration.'
```

### Conversion Attempt

Add:

```powershell
Invoke-VvcConversionAttempt
```

Responsibilities:

* create temp path,
* invoke encode,
* ensure temp output exists,
* validate temp output,
* promote temp output into final output,
* cleanup temp output on failure,
* return success/failure result.

Use one `try` / `finally` cleanup block.

Pseudo-flow:

```powershell
$committed = $false
$tempPath = New-VvcTempPath -FinalPath $finalPath

try {
    $encode = Invoke-VvcEncode -Request $Request -InputPath $inputPath -OutputPath $tempPath

    if (-not $encode.Succeeded) {
        return New-VvcFailureResult ...
    }

    if (-not (Test-Path -LiteralPath $tempPath)) {
        return New-VvcFailureResult ...
    }

    $validation = Test-VvcOutput -Request $Request -Path $tempPath

    if (-not $validation.Succeeded) {
        return New-VvcFailureResult ...
    }

    Move-Item -LiteralPath $tempPath -Destination $finalPath -Force -ErrorAction Stop
    $committed = $true

    return New-VvcSuccessResult ...
}
finally {
    if (-not $committed -and (Test-Path -LiteralPath $tempPath)) {
        Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
    }
}
```

### Result Construction

Add dedicated helpers:

```powershell
New-VvcSuccessResult
New-VvcSkippedResult
New-VvcFailureResult
```

These should preserve the old result shape and optionally add new diagnostic properties.

Avoid constructing result objects ad hoc across the worker.

## Error Handling Policy

Use consistent categories:

```text
InvalidInput
ExistingOutputValid
ExistingOutputInvalid
EncodeFailed
EncodedOutputMissing
ValidationFailed
PromoteFailed
SizeCalculationFailed
UnexpectedFailure
```

Map these to existing `Reason` strings carefully to avoid breaking tests that assert exact messages.

Recommendation:

* keep existing `Reason` text where tests likely depend on it,
* add richer detail in `Diagnostic`,
* add machine-readable `Status` / `FailureKind` only if additive properties are safe.

## Test Plan

Use TDD for each extracted helper before wiring the full worker.

### Unit Tests

#### `New-FfmpegArgumentList`

BDD/DDT cases:

* overwrite enabled emits expected overwrite behavior,
* overwrite disabled emits expected overwrite behavior,
* QP is passed correctly,
* preset is passed correctly,
* encoder threads are passed correctly,
* input/output paths are passed as separate arguments,
* paths with spaces are not split,
* no empty/null arguments are emitted.

#### `New-VvcTempPath`

Randomized tests:

* same directory as final path,
* same extension as final path,
* not equal to final path,
* unique across repeated calls,
* safe for filenames with spaces and multiple dots.

#### `Invoke-NativeTool`

Mock or test with a harmless native command if cross-platform-safe.

Cases:

* exit code `0`,
* non-zero exit code,
* stdout capture,
* stderr capture,
* missing executable behavior.

If cross-platform native-command behavior is awkward, keep most tests at the wrapper boundary with mocks and add a small number of integration tests.

#### Probe Helpers

Cases:

* valid codec parse,
* valid duration parse,
* empty duration,
* non-numeric duration,
* ffprobe non-zero exit,
* stderr diagnostic preserved.

### Worker Lifecycle Tests

Use Pester mocks around:

```powershell
Invoke-NativeTool
Test-Path
Move-Item
Remove-Item
Get-Item
```

or around higher-level helpers if testing one layer above.

BDD contexts:

```powershell
Describe 'Invoke-VvcConversionWorker' {
    Context 'when input is invalid' {
        It 'returns failure and does not encode'
    }

    Context 'when existing output is valid and overwrite is disabled' {
        It 'returns skipped and does not encode'
    }

    Context 'when existing output is invalid' {
        It 're-encodes and replaces the final output'
    }

    Context 'when ffmpeg exits non-zero' {
        It 'returns failure and removes temp output'
    }

    Context 'when ffmpeg exits zero but temp output is missing' {
        It 'returns failure and does not promote output'
    }

    Context 'when validation fails after encode' {
        It 'returns failure and removes temp output'
    }

    Context 'when promotion fails' {
        It 'returns failure and cleans temp output when safe'
    }

    Context 'when conversion succeeds' {
        It 'returns a backward-compatible success result'
    }
}
```

### Parallel Boundary Tests

Add a small test for the actual parallel entrypoint shape:

* request object can be serialized into the parallel runspace,
* module imports correctly,
* internal worker entrypoint is callable,
* result returns with expected compatibility properties.

This test does not need to perform real ffmpeg work. Mock the worker internals.

### Integration Tests

Tag slow tests:

```powershell
-It 'converts a small fixture video' -Tag Integration
```

Integration coverage:

* actual ffmpeg available,
* actual ffprobe available,
* quick verify mode,
* strict verify mode if runtime is acceptable,
* output replacement behavior,
* custom `FfmpegPath` / `FfprobePath`.

Do not require these tests in every fast local run unless the repo already does so.

## Static Analysis / Quality Gates

Run after each major step:

```powershell
tools/Invoke-PSSA.ps1
Invoke-Pester
```

Add or maintain CI gates for:

* Pester fast tests,
* PSScriptAnalyzer,
* no direct `ffmpeg` / `ffprobe` calls outside `Invoke-NativeTool` or test fixtures,
* no large generated worker here-string.

Useful custom assertion:

```powershell
It 'does not call ffprobe directly from worker code' {
    # Search private source files for direct native call patterns if useful.
}
```

## Migration Sequence

### Phase 1: Characterization Tests

Before changing behavior, add tests around the current externally visible behavior:

* result shape,
* skip behavior,
* overwrite behavior,
* verify mode behavior,
* failure behavior,
* max parallel behavior if practical.

These protect the refactor.

### Phase 2: Native Tool Wrapper

Introduce `Invoke-NativeTool`.

Route probe helpers through it first.

Then route encode through it.

Keep behavior unchanged.

### Phase 3: Request Object

Replace positional worker arguments with a request object.

Keep the existing `Get-ConvertToVvcWorkerArguments` name if that minimizes churn, but make it return one object per file instead of loose argument arrays.

### Phase 4: Extract Worker Helpers

Extract private helpers:

* `Resolve-VvcConversionPath`
* `New-FfmpegArgumentList`
* `Get-VvcMediaProbe`
* `Test-VvcInput`
* `Test-VvcExistingOutput`
* `Test-VvcOutput`
* `Invoke-VvcEncode`
* `Invoke-VvcConversionAttempt`
* result constructors.

Keep functions short and single-purpose.

### Phase 5: Replace Here-String Worker

Add the internal worker entrypoint.

Replace the generated here-string with a small parallel scriptblock.

Verify the entrypoint works from a fresh parallel runspace.

### Phase 6: Temp Path Safety

Replace deterministic partial paths with GUID temp paths.

Add cleanup tests.

### Phase 7: Add Optional Metadata

Add optional result fields only after compatibility tests pass.

## Acceptance Criteria

The refactor is complete when:

* The large here-string worker body is gone.
* All ffmpeg/ffprobe calls go through `Invoke-NativeTool`.
* `FfprobePath` is explicit and honored.
* Temp output paths are unique and same-directory.
* Encode / validate / promote / cleanup logic exists in one reusable path.
* Existing public result properties are preserved.
* Existing verify mode names still work.
* Existing `-MaxParallel` behavior is preserved.
* New `-EncoderThreads` has DDT coverage.
* Pester fast tests pass.
* PSScriptAnalyzer passes.
* Integration tests are either passing or clearly tagged/skipped when ffmpeg is unavailable.

## Risks and Mitigations

| Risk                                                        | Mitigation                                                           |
| ----------------------------------------------------------- | -------------------------------------------------------------------- |
| Private worker function is not visible in parallel runspace | Use one intentionally exported internal entrypoint                   |
| Result shape breaks consumers                               | Add characterization tests before refactor                           |
| Exact `Reason` strings change                               | Preserve old strings; put richer details in `Diagnostic`             |
| ffmpeg argument order changes unexpectedly                  | Add DDT tests for argument generation                                |
| Temp cleanup deletes final output accidentally              | Track `$committed`; only remove temp path, never final path          |
| Parallel conversion collides on temp files                  | Use GUID same-directory temp paths                                   |
| Custom ffmpeg path still uses PATH ffprobe                  | Add explicit `FfprobePath`; test custom paths                        |
| Native stderr/stdout behavior differs across platforms      | Centralize behavior in `Invoke-NativeTool` and test wrapper contract |

## Assumptions

* Pester v5 remains the test framework.
* PSScriptAnalyzer remains the lint tool.
* No new test dependency is required for the first implementation.
* Lightweight randomized Pester tests are sufficient for temp-path properties.
* Full property-based testing can be deferred unless more pure transformation logic emerges.
* The first implementation prioritizes safety, testability, and compatibility over a new job backend or public API redesign.
