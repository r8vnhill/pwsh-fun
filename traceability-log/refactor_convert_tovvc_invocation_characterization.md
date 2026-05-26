# [PLAN] Refactor `Convert-ToVvc` Invocation Characterization

## Summary

Refactor the active `Convert-ToVvc` invocation suite into a clearer BDD-style integration characterization suite. Keep
production behavior unchanged. The refactor should improve readability, reduce duplicated scenario setup, strengthen
fake native-tool assertions, and add missing public-surface behavior coverage.

This remains a **test-only refactor**. Production `Convert-ToVvc` logic, result semantics, and public parameter behavior
are out of scope.

## Goals

- Make invocation behavior easier to scan by grouping scenarios into clear BDD contexts.
- Preserve characterization coverage while reducing fixture noise.
- Replace brittle fake-tool argument assertions with structured, token-aware assertions.
- Add missing edge coverage for invalid existing outputs, ffprobe failure, path-sensitive filenames, and multi-file
  parallel execution.
- Keep the test harness general, small, and extensible without introducing a broad fluent DSL.

## Non-goals

- Do not refactor production `Convert-ToVvc`.
- Do not move these tests into worker-internal unit tests.
- Do not introduce repo-wide dependency policy changes.
- Do not add Pester pinning, PSScriptAnalyzer, or property-based testing dependencies in this cycle.
- Do not broaden the fake-tool harness beyond what the new invocation scenarios require.

## Key Changes

### 1. Invocation suite structure

Split the current flat `Describe` body into behavior-focused contexts:

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

Keep standalone examples where shared DDT would hide meaningful risk:

- progress noise filtering
- parallel worker import/execution
- `WhatIf`
- existing-output skip vs overwrite
- ffmpeg failure cleanup
- post-validation failure cleanup
- multi-file parallel isolation

Use Ringu-themed scenario filenames consistently, for example:

```powershell
'asakawa-source.mkv'
'ryuji-threaded-encode.mkv'
'sadako-parallel-run.mkv'
'cursed-tape-existing-output.mkv'
'shizuko-progress-noise.mkv'
'well-scene-bad-convert.mkv'
```

### 2. Shared scenario support

Add a small helper in `ConvertToVvc.SpecSupport.ps1`:

```powershell
function New-ValidConvertScenarioParams {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $FileName,

        [hashtable] $Override = @{}
    )

    $params = @{
        FileName         = $FileName
        InputContent     = ('Ringu media payload' * 4096)
        FfprobeScenarios = New-ValidVvcScenarioSet -FileName $FileName
        CreateOutput     = $true
    }

    foreach ($key in $Override.Keys) {
        $params[$key] = $Override[$key]
    }

    $params
}
```

Add a narrow artifact-state helper:

```powershell
function Assert-ScenarioArtifactState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Scenario,

        [Parameter(Mandatory)]
        [bool] $ExpectOutput,

        [Parameter(Mandatory)]
        [bool] $ExpectPartialOutput
    )

    (Test-Path -LiteralPath $Scenario.OutputPath) |
        Should -Be $ExpectOutput

    (Test-Path -LiteralPath $Scenario.PartialOutputPath) |
        Should -Be $ExpectPartialOutput
}
```

Cycle 2 has been implemented with this narrow support extraction. The invocation suite now uses the shared valid-scenario helper for the basic success, encoder-thread, and literal-path cases, and the artifact helper for the simple output-state checks. Specialized scenarios remain explicit. The known valid-existing-output skip characterization failure remains unchanged.

Keep `Invoke-ConvertScenario` as the main harness. Extend it only for:

- multiple input files in one public invocation
- per-file fake-tool marker accounting
- explicit path-edge cases, if current support cannot arrange them cleanly

### 3. Fake native-tool marker contract

Improve the marker format from raw joined argument text to structured JSON. But avoid a risky big-bang migration.

Recommended migration:

1. Add `Read-FakeToolArguments`.
2. Make it tolerate both current raw text and new JSON temporarily.
3. Update fake tools to write JSON argv.
4. Migrate marker-consuming tests.
5. Remove legacy raw-text fallback only after all affected suites are updated.

Suggested shape:

```json
{
  "tool": "ffmpeg",
  "argv": ["-i", "asakawa-source.mkv", "-threads", "2"],
  "workingDirectory": "...",
  "timestampUtc": "2026-05-21T00:00:00Z"
}
```

For parallel tests, prefer **one marker record per tool invocation** instead of a single overwritten marker file. Use
either:

- JSONL records in a per-scenario marker log, or
- one JSON file per invocation under a marker directory.

For parallel safety, the second option is cleaner:

```text
markers/
  ffmpeg/
    0001.json
    0002.json
  ffprobe/
    0001.json
    0002.json
    0003.json
```

Then add helpers like:

```powershell
Read-FakeToolInvocation -Scenario $scenario -ToolName ffmpeg
Read-FakeToolInvocation -Scenario $scenario -ToolName ffprobe
Assert-FakeToolArgumentToken -Arguments $argv -Name '-threads' -Value '2'
```

This will make multi-file parallel assertions much safer than checking one shared marker path.

### 4. DDT improvements

Use named `It -ForEach` data for repeated scenario shapes:

```powershell
It 'passes encoder thread settings to ffmpeg: <Name>' -ForEach @(
    @{ Name = 'automatic threads'; EncoderThreads = 0 }
    @{ Name = 'bounded threads'; EncoderThreads = 2 }
) {
    # ...
}
```

Add named literal-path cases:

```powershell
@(
    @{ Name = 'spaces'; FileName = 'asakawa interview.mkv' }
    @{ Name = 'brackets'; FileName = 'cursed-tape[copy].mkv' }
    @{ Name = 'uppercase extension'; FileName = 'ryuji-source.MKV' }
    @{ Name = 'unicode filename'; FileName = '貞子-source.mkv'; Enabled = $true }
)
```

Keep Unicode only if the repo, shell, and CI encoding are already known to handle it cleanly. Otherwise, add it as a
separate skipped or pending scenario with a clear reason.

### 5. Coverage additions

Add these missing characterization scenarios.

#### Invalid existing output without overwrite

Expected behavior:

- source probing occurs
- existing output probing occurs
- conversion proceeds
- ffmpeg is invoked
- final output exists
- partial output does not remain

#### Input probing fails

Expected behavior:

- failed result is emitted
- ffprobe is invoked
- ffmpeg is not invoked
- final output is absent
- partial output is absent
- failure reason is specific enough to distinguish probe failure from encode failure

#### Path-sensitive filenames

Cover:

- spaces
- brackets
- uppercase extension
- Unicode, only if encoding is reliable

Expected behavior:

- literal path behavior does not wildcard-expand
- output path is derived correctly
- result file identity matches the input file
- fake tool argv receives the intended literal path

#### Multi-file parallel conversion

Expected behavior:

- public invocation receives multiple inputs
- `MaxParallel = 2`
- one result per input
- one final output per input
- no partial outputs remain
- ffmpeg invocations are counted per input
- ffprobe invocations are attributable per input
- marker records do not overwrite or leak across files

## Revised TDD Cycles

### Cycle 1 — Restructure only [implemented]

- Run current invocation and input-validation suites as baseline.
- Add behavior `Context` blocks.
- Rename generic scenario filenames to Ringu-themed names.
- Keep all current assertions and outcomes unchanged.
- Harden `AfterAll` with a null guard.

Acceptance gate:

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.InputValidation.Tests.ps1
```

Cycle 1 landed as a move-only characterization pass:

- the invocation suite is grouped into the planned behavior contexts
- the input-validation suite has matching invalid-input context structure
- fake scenario filenames were renamed without adding new coverage
- `AfterAll` fake-tool restoration is null-safe in both suites

Baseline verification found an existing invocation-suite failure before the restructure: 13 tests were discovered,
12 passed, and the valid-existing-output skip scenario failed because the result was not marked skipped. The
input-validation baseline discovered and passed 2 tests. The cycle does not repair that pre-existing behavior.

### Cycle 2 — Extract scenario setup helpers [implemented]

- Add focused support tests or small characterization examples for `New-ValidConvertScenarioParams`.
- Add `New-ValidConvertScenarioParams`.
- Migrate repeated valid scenario setup gradually.
- Add `Assert-ScenarioArtifactState`.
- Replace repeated output/partial `Test-Path` checks only where the expected state remains obvious.

Acceptance gate:

- existing invocation scenarios still pass
- scenario bodies are shorter
- no behavior-specific setup is hidden inside defaults

### Cycle 3 — Add structured fake-tool reads before changing writes [implemented]

- Add `Read-FakeToolArguments`.
- Initially support both raw text and JSON marker formats.
- Add token-level helper assertions.
- Update the encoder-thread test to use helper assertions.
- Keep fake tools writing the old format for this cycle.

Implemented in the workspace:

- `Read-FakeToolArguments` now parses legacy raw markers and JSON markers.
- `Assert-FakeToolArgumentValue` is available for narrow argv token checks.
- The invocation suite now includes reader characterization coverage for raw and JSON marker samples.
- The encoder-thread test now validates `-threads <value>` through the reader helper.
- `FakeMediaTools.ps1` still writes the legacy marker format.

Acceptance gate:

- current marker tests pass through the new reader
- no fake-tool writer behavior has changed yet

### Cycle 4 — Switch fake tools to structured markers

- Change fake `ffmpeg` and `ffprobe` writers to JSON.
- Prefer per-invocation marker records rather than one overwritten marker file.
- Update all affected marker-consuming VVC tests.
- Verify invocation and input-validation suites.

Implemented in the workspace:

- Fake `ffmpeg` and `ffprobe` now write JSON marker records under per-tool marker directories.
- Marker records include `schemaVersion`, `tool`, `argv`, `workingDirectory`, and `timestampUtc`.
- `Read-FakeToolInvocations` reads directory records in stable filename order.
- `Read-LatestFakeToolInvocation` supports tests that only care about the final invocation.
- `Assert-ToolInvocationState` now checks marker directory records instead of marker file existence.
- The encoder-thread test reads the latest structured `ffmpeg` invocation and validates `-threads <value>`.

Acceptance gate:

- encoder-thread assertion proves `-threads` and its value as separate argv tokens
- marker invocation counts are reliable
- parallel marker accounting is possible without shared-file ambiguity

### Cycle 5 — Improve DDT readability

- Add named `It -ForEach` cases for thread settings.
- Add named path-binding cases.
- Add path-edge DDT cases.
- Keep cleanup-sensitive and stream-sensitive scenarios standalone.

Acceptance gate:

- failed DDT cases show useful names in Pester output
- path-edge cases assert literal path behavior, not only successful conversion

### Cycle 6 — Add missing branch coverage

Add scenarios for:

- invalid existing output re-encode without `-Overwrite`
- input probe failure blocking ffmpeg
- multi-file parallel conversion

Acceptance gate:

- result cardinality is explicit
- output cleanup is explicit
- fake-tool invocation counts are explicit
- parallel tests prove isolation across files

### Cycle 7 — Final isolation pass

- Keep `BeforeEach` and `AfterEach` reset behavior.
- Ensure `AfterAll` cannot mask earlier initialization failures.
- Confirm support helpers do not retain scenario state across examples.
- Re-run focused suites.

Final gate:

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.InputValidation.Tests.ps1
```

## Acceptance Checklist

The refactor is complete when these remain covered:

- valid conversion emits one success result and produces final output
- encoder thread settings reach fake ffmpeg argv structurally
- explicit `LiteralPath` input works
- pipeline literal path input works
- filenames with spaces/brackets do not regress literal-path handling
- uppercase extension behavior is characterized
- progress output does not pollute the result stream
- parallel execution reaches the worker path
- multi-file parallel execution produces isolated results and outputs
- valid existing output skips unless overwrite is requested
- invalid existing output re-encodes without overwrite
- `WhatIf` emits no conversion result and avoids native conversion work
- unmatched extensions emit no conversion result and avoid native conversion work
- ffmpeg exit failure cleans up temporary output
- post-validation failure cleans up temporary output
- ffprobe input failure blocks ffmpeg
- fake-tool markers are structured and test-support-only
