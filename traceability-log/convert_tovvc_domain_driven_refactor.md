# [PLAN] Convert-ToVvc Domain Refactor as Short TDD Cycles

## Cycle 0 — Restore Importability

**Goal:** Make the module importable before any refactor work.

**Red**

Add or keep a regression test:

```powershell
Describe 'Fun.Ffmpeg importability' {
    It 'imports cleanly' {
        {
            Import-Module "$PSScriptRoot/../../modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1" -Force
        } | Should -Not -Throw
    }
}
```

**Green**

Fix the misplaced:

```powershell
[OutputType([scriptblock])]
```

in `ConvertToVvc.Worker.ps1`.

Either move it to the function declaration or remove it.

**Refactor**

Do not change behavior yet.

**Done when**

```powershell
Import-Module modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1 -Force
Invoke-Pester -Path tests/Fun.Ffmpeg
```

passes.

---

## ~~Cycle 1 — Add Conversion Enums~~

**Goal:** Introduce stable machine-readable status, reason, and action values.

**Red**

Create `tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1`.

Add tests that enums exist and expose expected names:

```powershell
Describe 'VVC conversion enums' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1" -Force
    }

    It 'defines conversion statuses' {
        [VvcConversionStatus]::Converted.ToString() | Should -Be 'Converted'
        [VvcConversionStatus]::Skipped.ToString()   | Should -Be 'Skipped'
        [VvcConversionStatus]::Failed.ToString()    | Should -Be 'Failed'
    }

    It 'defines conversion actions' {
        [VvcConversionAction]::Convert.ToString() | Should -Be 'Convert'
        [VvcConversionAction]::Skip.ToString()    | Should -Be 'Skip'
        [VvcConversionAction]::Fail.ToString()    | Should -Be 'Fail'
    }
}
```

**Green**

Add:

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

**Refactor**

Keep enum names aligned with `VvcAudit` / `VvcRemoval` style.

**Done when**

Enum tests pass without touching `Convert-ToVvc`.

---

## ~~Cycle 2 — Add Invariant Exception~~

**Goal:** Create one explicit exception type for impossible domain states.

**Red**

```powershell
Describe 'VvcConversionInvariantException' {
    It 'can be thrown for invalid domain state' {
        {
            throw [VvcConversionInvariantException]::new('Invalid state')
        } | Should -Throw -ExceptionType ([VvcConversionInvariantException])
    }
}
```

**Green**

Add:

```powershell
class VvcConversionInvariantException : System.Exception {
    VvcConversionInvariantException([string] $message) : base($message) {}
}
```

**Refactor**

Use this exception only for programming/domain invariant failures, not normal ffmpeg failures.

**Done when**

The exception type is directly testable.

**Completed**

Covered by `traceability-log/cycle_2_verify_vvcconversioninvariantexception.md`.

---

## ~~Cycle 3 — Add `VvcNativeResult`~~

**Goal:** Model native process output before writing the process wrapper.

**Red**

Test the invariants:

```powershell
Describe 'VvcNativeResult' {
    It 'requires a non-empty tool path' {
        {
            [VvcNativeResult]::new('', @(), 0, '', '')
        } | Should -Throw -ExceptionType ([VvcConversionInvariantException])
    }

    It 'requires a non-null argument list' {
        {
            [VvcNativeResult]::new('ffmpeg', $null, 0, '', '')
        } | Should -Throw -ExceptionType ([VvcConversionInvariantException])
    }

    It 'sets Succeeded from ExitCode' {
        $result = [VvcNativeResult]::new('ffmpeg', @('-version'), 0, 'ok', '')
        $result.Succeeded | Should -BeTrue
    }
}
```

**Green**

Implement only the class and its constructor.

**Refactor**

Normalize `$null` stdout/stderr to empty strings, if that is the preferred contract.

**Done when**

No native process is invoked yet.

---

## ~~Cycle 4 — Add `VvcConversionPathSet`~~

**Goal:** Make path safety rules testable before worker changes.

**Red**

Test:

```powershell
Describe 'VvcConversionPathSet' {
    It 'rejects temp path equal to output path' {}
    It 'requires temp path to be in the output directory' {}
    It 'requires temp path to use the output extension' {}
}
```

**Green**

Implement:

```powershell
class VvcConversionPathSet {
    [string] $InputPath
    [string] $OutputPath
    [string] $TempPath

    VvcConversionPathSet(
        [string] $inputPath,
        [string] $outputPath,
        [string] $tempPath
    ) {
        # invariant checks
    }
}
```

**Refactor**

Extract small private guard helpers if constructors get noisy.

**Done when**

Path invariants are enforced independently of filesystem existence.

---

## ~~Cycle 5 — Add `VvcConversionRequest`~~

**Goal:** Capture worker input as a validated object.

**Completed**

Implemented in `modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1` and covered by `tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1`.

**Red**

Test invalid construction cases:

```powershell
Describe 'VvcConversionRequest' {
    It 'rejects blank input' {}
    It 'rejects blank output' {}
    It 'rejects blank suffix' {}
    It 'rejects blank preset' {}
    It 'rejects invalid qp' {}
    It 'rejects unsupported verify mode' {}
    It 'rejects negative max drift' {}
    It 'rejects negative encoder threads' {}
    It 'rejects blank ffmpeg path' {}
    It 'rejects blank ffprobe path' {}
}
```

**Green**

Implement the request class with the current worker-facing boundary:

* `InputPath`
* `OutputDir`
* `Suffix`
* `Qp`
* `Preset`
* `Overwrite`
* `VerifyMode`
* `MaxDriftSec`
* `FfmpegPath`
* `FfprobePath`
* `EncoderThreads`

**Refactor**

Keep constructor validation short. Prefer private static guard methods if needed.

**Done when**

A valid request can be created in tests, the constructor rejects invalid state, and the public command still need not use it.

---

## Cycle 6 — Add `VvcMediaProbe`

**Goal:** Represent ffprobe interpretation without calling ffprobe yet.

**Red**

Test:

```powershell
Describe 'VvcMediaProbe' {
    It 'can represent a successful probe' {}
    It 'can represent a failed probe with a diagnostic' {}
    It 'rejects blank diagnostics on failed probes' {}
    It 'rejects negative duration' {}
}
```

**Green**

Implement `VvcMediaProbe`.

**Refactor**

Decide whether failed probe state is represented by `Succeeded = $false` or by a separate result factory.

**Done when**

Probe state is expressible without infrastructure.

---

## Cycle 7 — Add `VvcOutputValidation`

**Goal:** Represent output validation results independently of ffmpeg/ffprobe.

**Red**

Test:

```powershell
Describe 'VvcOutputValidation' {
    It 'requires Reason None for valid output' {}
    It 'requires a non-None reason for invalid output' {}
    It 'rejects negative duration drift' {}
    It 'rejects blank diagnostics' {}
}
```

**Green**

Implement `VvcOutputValidation`.

**Refactor**

Use factory methods if the constructor becomes hard to read:

```powershell
[VvcOutputValidation]::Valid(...)
[VvcOutputValidation]::Invalid(...)
```

**Done when**

Validation outcomes are domain-only.

---

## Cycle 8 — Add `ConvertToVvcResult` Factories

**Goal:** Make result construction invariant-checked and centralized.

**Red**

Test the new result contract:

```powershell
Describe 'ConvertToVvcResult' {
    Context 'Converted' {
        It 'requires Reason None' {}
        It 'requires an output path' {}
        It 'requires positive NewMB' {}
    }

    Context 'Skipped' {
        It 'requires a non-None reason' {}
    }

    Context 'Failed' {
        It 'requires a non-None reason' {}
        It 'allows native ExitCode when a native process was invoked' {}
    }
}
```

**Green**

Implement:

```powershell
[ConvertToVvcResult]::Converted(...)
[ConvertToVvcResult]::Skipped(...)
[ConvertToVvcResult]::Failed(...)
```

**Refactor**

Prevent ad hoc result creation. Make constructors private if feasible; otherwise document factory-only usage in tests and code review rules.

**Done when**

Tests only construct results through factories.

---

## Cycle 9 — Add Pure Decision Type

**Goal:** Separate “what should happen?” from side effects.

**Red**

Test:

```powershell
Describe 'VvcConversionDecision' {
    It 'requires Convert action to have Reason None' {}
    It 'requires Skip action to have a non-None reason' {}
    It 'requires Fail action to have a non-None reason' {}
}
```

**Green**

Implement `VvcConversionDecision`.

**Refactor**

Use factories:

```powershell
[VvcConversionDecision]::Convert()
[VvcConversionDecision]::Skip(...)
[VvcConversionDecision]::Fail(...)
```

**Done when**

Decision state is impossible to misuse.

---

## Cycle 10 — Add Existing Output Decision Tests

**Goal:** Test conversion decision logic without fake native tools.

**Red**

Create DDT cases:

```powershell
Describe 'Get-VvcExistingOutputDecision' {
    It 'decides <ExpectedAction> / <ExpectedReason> when <CaseName>' -ForEach @(
        @{
            CaseName = 'output is missing'
            OutputExists = $false
            Overwrite = $false
            ValidationIsValid = $false
            ExpectedAction = 'Convert'
            ExpectedReason = 'None'
        }
        @{
            CaseName = 'output is valid and overwrite is false'
            OutputExists = $true
            Overwrite = $false
            ValidationIsValid = $true
            ExpectedAction = 'Skip'
            ExpectedReason = 'ExistingOutputValid'
        }
        @{
            CaseName = 'output exists and overwrite is true'
            OutputExists = $true
            Overwrite = $true
            ValidationIsValid = $true
            ExpectedAction = 'Convert'
            ExpectedReason = 'None'
        }
    ) {
        # assertion
    }
}
```

**Green**

Implement the smallest pure helper.

**Refactor**

Keep it free of filesystem calls. Pass in facts, not paths.

**Done when**

Existing output behavior is decided by pure logic.

---

## Cycle 11 — Add Input Probe Decision Tests

**Goal:** Map input probe outcomes to decisions.

**Red**

```powershell
Describe 'Get-VvcInputDecision' {
    It 'fails when input probe fails' {}
    It 'converts when input probe succeeds' {}
}
```

**Green**

Implement pure mapping:

```powershell
Probe failed -> Fail / InvalidInput or ProbeFailed
Probe succeeded -> Convert / None
```

**Refactor**

Choose one reason consistently:

* `InvalidInput` for user-facing invalid media.
* `ProbeFailed` for infrastructure/tool failure.

**Done when**

Probe failures no longer require ad hoc string mapping.

---

## Cycle 12 — Add Native Wrapper Contract

**Goal:** Route native execution through one tested boundary.

**Red**

Using fake tools, test:

```powershell
Describe 'Invoke-NativeTool' {
    It 'captures stdout' {}
    It 'captures stderr' {}
    It 'captures exit code' {}
    It 'sets Succeeded from exit code' {}
    It 'handles missing executable predictably' {}
}
```

**Green**

Implement:

```powershell
function Invoke-NativeTool {
    [CmdletBinding()]
    [OutputType([VvcNativeResult])]
    param(
        [Parameter(Mandatory)]
        [string] $FilePath,

        [Parameter()]
        [string[]] $ArgumentList = @()
    )

    # invoke process and return VvcNativeResult
}
```

**Refactor**

Avoid direct `ffmpeg` / `ffprobe` calls outside this function.

**Done when**

A static grep can find no new direct native invocations except fixtures and this wrapper.

---

## Cycle 13 — Route ffprobe Through Native Wrapper

**Goal:** Convert probing helpers to use `Invoke-NativeTool`.

**Red**

Add tests for:

```text
codec parse success
duration parse success
non-numeric duration
empty duration
non-zero ffprobe exit
stderr diagnostic propagation
```

**Green**

Update existing probe helpers to call `Invoke-NativeTool`.

**Refactor**

Return `VvcMediaProbe`, not loose objects.

**Done when**

Probe behavior is covered through fake tools and has typed outcomes.

---

## Cycle 14 — Add ffmpeg Argument Generation

**Goal:** Make encode command construction deterministic and testable.

**Red**

DDT for `New-FfmpegArgumentList`:

```text
overwrite enabled
overwrite disabled
QP values
preset values
encoder thread values
paths with spaces
no null/empty arguments
```

**Green**

Implement or extract `New-FfmpegArgumentList`.

**Refactor**

Keep argument generation independent from invocation.

**Done when**

The worker no longer assembles ffmpeg args inline.

---

## Cycle 15 — Route Encoding Through Native Wrapper

**Goal:** Replace direct ffmpeg invocation with typed native result.

**Red**

Test that the encode function:

```text
calls Invoke-NativeTool
returns EncodeFailed on non-zero exit
returns EncodedOutputMissing when exit is zero but temp output is absent
```

**Green**

Add:

```powershell
Invoke-VvcEncode
```

or equivalent internal helper.

**Refactor**

Do not promote output in the encode helper. Encoding only writes temp output.

**Done when**

ffmpeg is invoked in exactly one place through `Invoke-NativeTool`.

---

## Cycle 16 — Add Temp Path Generation

**Goal:** Create safe GUID temp output paths.

**Red**

Test:

```powershell
Describe 'New-VvcConversionPathSet' {
    It 'creates temp path in the output directory' {}
    It 'creates temp path with the output extension' {}
    It 'creates temp path different from output path' {}
    It 'uses a GUID-like partial name' {}
}
```

**Green**

Implement path-set creation.

**Refactor**

Ensure temp path is generated once and passed through the conversion attempt.

**Done when**

No helper recalculates temp output independently.

---

## Cycle 17 — Add Conversion Attempt Success Path

**Goal:** Implement the first vertical slice of the conversion attempt.

**Red**

Test:

```powershell
Describe 'Invoke-VvcConversionAttempt' {
    Context 'when encode succeeds and validation succeeds' {
        It 'promotes temp output and returns Converted / None'
    }
}
```

**Green**

Implement the smallest flow:

```text
encode temp
validate temp
promote temp to final
return Converted / None
```

**Refactor**

Extract filesystem operations only when duplication appears.

**Done when**

One complete successful conversion path works with fake tools/files.

---

## Cycle 18 — Add Conversion Attempt Failure Paths

**Goal:** Make terminal failure mapping explicit.

**Red**

Add one test at a time:

```text
encode exits non-zero -> Failed / EncodeFailed
encode exits zero but temp output missing -> Failed / EncodedOutputMissing
validation fails -> Failed / validation reason
promotion fails -> Failed / PromoteFailed
unexpected exception -> Failed / UnexpectedFailure
```

**Green**

Implement each mapping incrementally.

**Refactor**

Centralize failure result construction.

**Done when**

Every failure path returns `Status = Failed` and a non-`None` reason.

---

## Cycle 19 — Add Temp Cleanup Guarantees

**Goal:** Prevent stale temp outputs.

**Red**

Test:

```text
temp is removed after encode failure
temp is removed after validation failure
temp is removed after promotion failure when possible
final output is not removed during cleanup
```

**Green**

Add cleanup in `finally` or a narrow cleanup helper.

**Refactor**

Keep cleanup logic small and path-safe.

**Done when**

Only temp paths are deleted.

---

## Cycle 20 — Add Application Service

**Goal:** Coordinate the full conversion lifecycle outside the parallel scriptblock.

**Red**

Test `Invoke-VvcConversion`:

```text
invalid input -> Failed / InvalidInput or ProbeFailed
valid existing output and no overwrite -> Skipped / ExistingOutputValid
missing output -> conversion attempt is invoked
invalid existing output -> conversion attempt is invoked
```

**Green**

Implement:

```powershell
function Invoke-VvcConversion {
    [CmdletBinding()]
    [OutputType([ConvertToVvcResult])]
    param(
        [Parameter(Mandatory)]
        [VvcConversionRequest] $Request
    )

    # probe input
    # decide existing output
    # invoke attempt
}
```

**Refactor**

Keep it as orchestration only. No direct native or filesystem details beyond helper calls.

**Done when**

`Invoke-VvcConversion` can be tested with mocks/fakes.

---

## Cycle 21 — Add Internal Worker Entrypoint

**Goal:** Create the stable parallel-runspace boundary.

**Red**

Test:

```powershell
Describe 'Invoke-FunFfmpegInternalVvcWorker' {
    It 'delegates to Invoke-VvcConversion' {}
    It 'returns a ConvertToVvcResult' {}
}
```

**Green**

Implement:

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

**Refactor**

Keep it intentionally boring.

**Done when**

The function is callable after module import.

---

## Cycle 22 — Thin the Parallel Scriptblock

**Goal:** Remove conversion lifecycle logic from the parallel worker.

**Red**

Add a characterization/contract test:

```text
MaxParallel > 1 imports the module
request object reaches the worker
worker result returns Status and Reason
```

**Green**

Change the parallel scriptblock to:

```powershell
Import-Module $request.ModulePath -Force
Invoke-FunFfmpegInternalVvcWorker -Request $request
```

**Refactor**

Delete duplicated logic from the scriptblock only after tests pass.

**Done when**

Parallel behavior still works and the scriptblock is tiny.

---

## Cycle 23 — Wire Public Command to Request Object

**Goal:** Make `Convert-ToVvc` construct `VvcConversionRequest`.

**Red**

Update public-command tests for:

```text
suffix
output directory
QP
preset
verify mode
max drift
encoder threads
ffmpeg path
ffprobe path
```

**Green**

Replace hashtable/loose argument passing with `VvcConversionRequest`.

**Refactor**

Extract request construction:

```powershell
New-VvcConversionRequestFromCommandInput
```

or:

```powershell
Get-ConvertToVvcWorkerArguments
```

**Done when**

The public command no longer passes loosely typed worker state.

---

## Cycle 24 — Migrate Public Result Assertions

**Goal:** Switch tests from legacy fields to `Status` and `Reason`.

**Red**

Update tests to assert:

```powershell
$result.Status.ToString() | Should -Be 'Converted'
$result.Reason.ToString() | Should -Be 'None'
```

or:

```powershell
$result.Status | Should -Be ([VvcConversionStatus]::Converted)
```

**Green**

Adjust public command output to return the new result.

**Refactor**

Remove string reason comparisons from new tests.

**Done when**

Scenario tests use enum-backed contract.

---

## Cycle 25 — Decide Compatibility Properties

**Goal:** Finalize `Ok` and `Skipped`.

**Red**

Pick one path.

### Option A: fully breaking

Tests assert:

```powershell
$result.PSObject.Properties.Name | Should -Not -Contain 'Ok'
$result.PSObject.Properties.Name | Should -Not -Contain 'Skipped'
```

### Option B: transitional compatibility

Tests assert:

```powershell
$result.Ok      | Should -BeTrue
$result.Skipped | Should -BeFalse
```

but only as derived values.

**Green**

Implement the chosen contract.

**Refactor**

Remove all internal use of `Ok` / `Skipped`.

**Done when**

The result contract is intentional and documented.

---

## Cycle 26 — Remove Legacy Worker Logic

**Goal:** Delete the here-string/generated worker path.

**Red**

Add a quality test or static assertion:

```powershell
It 'does not contain generated worker here-string conversion logic' {
    $worker = Get-Content $workerPath -Raw
    $worker | Should -Not -Match 'here-string-pattern-or-old-entrypoint'
}
```

**Green**

Remove the old worker implementation.

**Refactor**

Clean up dead helpers and unused parameters.

**Done when**

There is one conversion pipeline.

---

## Cycle 27 — Add Quality Gate Tests

**Goal:** Prevent regression to the old architecture.

**Red**

Add static tests:

```text
no direct ffmpeg/ffprobe invocation outside Invoke-NativeTool
no ad hoc ConvertToVvcResult construction outside factories
no stringly typed reason matching in new tests
no large parallel here-string worker body
```

**Green**

Fix violations.

**Refactor**

Keep these tests coarse but useful.

**Done when**

Architecture rules fail loudly.

---

## Cycle 28 — Update Version and Migration Notes

**Goal:** Complete the breaking-change packaging work.

**Red**

Add a manifest/version test:

```powershell
It 'bumps Fun.Ffmpeg to 0.4.0' {
    $manifest = Import-PowerShellDataFile $manifestPath
    $manifest.ModuleVersion.ToString() | Should -Be '0.4.0'
}
```

**Green**

Update:

```text
modules/Fun.Ffmpeg/Fun.Ffmpeg.psd1
0.3.0 -> 0.4.0
```

Add changelog/migration notes.

**Refactor**

Mention that `Status` and `Reason` are authoritative.

**Done when**

Versioning reflects the result-contract break.

---

# Recommended Commit Shape

Use one commit per cycle where practical:

```text
test(ffmpeg): add importability regression for Convert-ToVvc
fix(ffmpeg): restore Fun.Ffmpeg importability
test(ffmpeg): define VVC conversion enum contract
feat(ffmpeg): add VVC conversion enums
test(ffmpeg): define native result invariants
feat(ffmpeg): add VvcNativeResult
...
```

# Execution Order Summary

```text
0  Importability
1  Enums
2  Invariant exception
3  Native result type
4  Path set type
5  Request type
6  Media probe type
7  Output validation type
8  Result factories
9  Decision type
10 Existing output decisions
11 Input probe decisions
12 Native wrapper
13 ffprobe through wrapper
14 ffmpeg argument generation
15 ffmpeg through wrapper
16 Temp path generation
17 Conversion attempt success
18 Conversion attempt failures
19 Temp cleanup
20 Application service
21 Internal worker entrypoint
22 Thin parallel scriptblock
23 Public command request wiring
24 Public result contract migration
25 Compatibility-property decision
26 Remove legacy worker
27 Quality gate tests
28 Version and migration notes
```

This gives you a clean TDD path: **domain first, then infrastructure, then worker orchestration, then public contract migration**.
