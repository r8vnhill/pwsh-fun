# [IMPLEMENTED] Cycle 2 — Extract Scenario Setup Helpers

## Summary

Extract a small amount of repeated valid-scenario setup from the `Convert-ToVvc` invocation characterization suite into
shared test support. This cycle should reduce duplication while preserving the current public-behavior test matrix,
production behavior, fake-tool behavior, and existing assertions.

The extraction must stay narrow: add helpers only for the repeated “valid conversion scenario” shape and repeated
final/partial output artifact checks. Do not introduce a fluent scenario DSL, fake-tool marker changes, new scenarios,
or production changes.

## Goals

- Reduce repeated valid scenario setup in `Convert-ToVvc.Invocation.Tests.ps1`.
- Keep test intent visible at each call site.
- Preserve all current behavior expectations.
- Avoid hiding failure-specific or cleanup-sensitive assertions behind generic helpers.
- Keep support helpers small, composable, and easy to delete if they stop carrying their weight.

## Non-goals

- No production code changes.
- No fake `ffmpeg` / `ffprobe` marker contract changes.
- No new coverage.
- No DDT restructuring.
- No new support-spec file unless a concrete failure makes it necessary.
- No broad fluent test DSL.
- No migration of highly specialized scenarios unless the call site becomes clearer.

## Relevant files

- `tests/Fun.Ffmpeg/Support/ConvertToVvc.SpecSupport.ps1`
- `tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1`
- `tests/Fun.Ffmpeg/Convert-ToVvc.InputValidation.Tests.ps1`
- `traceability-log/refactor_convert_tovvc_invocation_characterization.md`

## Pre-change baseline

Run both focused suites and capture result counts before editing:

```powershell
$invocationBaseline = Invoke-Pester `
    -Path tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1 `
    -PassThru

$inputValidationBaseline = Invoke-Pester `
    -Path tests/Fun.Ffmpeg/Convert-ToVvc.InputValidation.Tests.ps1 `
    -PassThru
```

Record:

- total test count
- passed count
- failed count
- skipped count
- any existing known skips

Cycle 2 should not change these counts unless a change is explicitly justified.

## Helper contracts

### `New-ValidConvertScenarioParams`

Add this to `ConvertToVvc.SpecSupport.ps1`.

Contract:

- Returns a hashtable intended for splatting into `Invoke-ConvertScenario`.
- Requires `FileName`.
- Defaults to:

  - valid non-empty input content
  - `New-ValidVvcScenarioSet -FileName $FileName`
  - `CreateOutput = $true`
- Accepts explicit overrides for scenario-specific fields.
- Does not invoke `Invoke-ConvertScenario`.
- Does not touch the filesystem.
- Does not mutate the caller-provided override hashtable.
- Does not encode behavior-specific assumptions like overwrite, failure, existing output, stream noise, or parallelism.

Suggested shape:

```powershell
function New-ValidConvertScenarioParams {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $FileName,

        [hashtable] $Override = @{}
    )

    $params = @{
        FileName         = $FileName
        InputContent     = ('Ringu valid source media' * 4096)
        FfprobeScenarios = New-ValidVvcScenarioSet -FileName $FileName
        CreateOutput     = $true
    }

    foreach ($key in $Override.Keys) {
        $params[$key] = $Override[$key]
    }

    $params
}
```

Example use:

```powershell
$params = New-ValidConvertScenarioParams -FileName 'asakawa-source.mkv'
$scenario = Invoke-ConvertScenario @params
```

### `Assert-ScenarioArtifactState`

Add this to `ConvertToVvc.SpecSupport.ps1`.

Contract:

- Asserts only final output existence and partial output existence.
- Requires explicit booleans from the caller.
- Does not assert result status, reason, fake-tool invocation state, or native-tool output.
- Does not replace cleanup-sensitive assertions where explicit `Test-Path` checks communicate the behavior better.

Suggested shape:

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

    Test-Path -LiteralPath $Scenario.OutputPath |
        Should -Be $ExpectOutput

    Test-Path -LiteralPath $Scenario.PartialOutputPath |
        Should -Be $ExpectPartialOutput
}
```

## TDD sequence

### Step 1 — Baseline

Run:

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.InputValidation.Tests.ps1
```

Do not continue if either suite is already failing.

### Step 2 — Add `New-ValidConvertScenarioParams`

Add only the helper. Do not migrate all call sites yet.

Then migrate exactly one low-risk example first: the basic successful conversion case.

Before:

```powershell
$scenario = Invoke-ConvertScenario `
    -FileName 'asakawa-source.mkv' `
    -InputContent ('Ringu valid source media' * 4096) `
    -FfprobeScenarios (New-ValidVvcScenarioSet -FileName 'asakawa-source.mkv') `
    -CreateOutput
```

After:

```powershell
$params = New-ValidConvertScenarioParams -FileName 'asakawa-source.mkv'
$scenario = Invoke-ConvertScenario @params
```

Run the invocation suite immediately after this single migration.

Acceptance:

- suite passes
- result shape is unchanged
- output behavior is unchanged
- fake-tool invocation expectations are unchanged

### Step 3 — Migrate only straightforward valid scenarios

Migrate examples that exactly match the extracted setup shape:

- basic successful conversion
- explicit literal-path binding, if it uses the same valid scenario shape
- pipeline literal-path binding, if it uses the same valid scenario shape
- simple encoder-thread setup, only if the override remains obvious

Use overrides only where they improve clarity:

```powershell
$params = New-ValidConvertScenarioParams `
    -FileName 'ryuji-threaded-encode.mkv' `
    -Override @{
        EncoderThreads = 2
    }

$scenario = Invoke-ConvertScenario @params
```

Do not migrate these yet:

- valid existing output skip
- overwrite existing output
- `WhatIf`
- unmatched extension
- ffmpeg failure
- post-validation failure
- progress-noise filtering
- parallel execution

Those scenarios have behavior-specific setup that should stay explicit in Cycle 2.

### Step 4 — Add `Assert-ScenarioArtifactState`

Add the artifact helper after the setup helper has proven safe.

Use it only for obvious repeated checks:

```powershell
Assert-ScenarioArtifactState `
    -Scenario $scenario `
    -ExpectOutput $true `
    -ExpectPartialOutput $false
```

Leave assertions explicit when the test is specifically about cleanup, partial-output deletion, or failure behavior. In
those cases, explicit checks are more readable than abstraction.

### Step 5 — Run focused verification

Run after each small migration group:

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1
```

Run the input-validation suite after support-file edits:

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.InputValidation.Tests.ps1
```

## Acceptance criteria

Cycle 2 is complete when:

- `New-ValidConvertScenarioParams` exists and is used only for matching valid scenario shapes.
- `Assert-ScenarioArtifactState` exists and is used only where it improves readability.
- Existing behavior assertions remain semantically unchanged.
- No new scenarios are added.
- No fake-tool marker output changes.
- No production files change.
- The invocation and input-validation suites pass.
- Test counts match the pre-change baseline.
- Specialized scenarios remain explicit.

## Implementation result

Cycle 2 landed as a narrow support/helper extraction.

- `New-ValidConvertScenarioParams` now centralizes the repeated valid-conversion setup in `tests/Fun.Ffmpeg/Support/ConvertToVvc.SpecSupport.ps1`.
- `Assert-ScenarioArtifactState` now collapses the repeated final/partial output checks in the same support file.
- The invocation suite now uses the shared helper for the basic success case, encoder-thread cases, and literal-path cases.
- Specialized scenarios remain explicit, including output-exists, `WhatIf`, failure, noise, and parallel cases.
- `Convert-ToVvc.InputValidation.Tests.ps1` remains unchanged because this extraction did not require import or behavior adjustments there.
- The invocation suite still reports the pre-existing valid-existing-output skip characterization failure; Cycle 2 does not change that behavior.

Focused verification should still be run after this change set:

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.InputValidation.Tests.ps1
```

Observed verification:

- `Convert-ToVvc.InputValidation.Tests.ps1` passed: 2 tests, 0 failed, 0 skipped.
- `Convert-ToVvc.Invocation.Tests.ps1` still exposes the known skip characterization failure in the valid-existing-output case.

Expected changed files:

```text
tests/Fun.Ffmpeg/Support/ConvertToVvc.SpecSupport.ps1
tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1
traceability-log/refactor_convert_tovvc_invocation_characterization.md
```

`Convert-ToVvc.InputValidation.Tests.ps1` should only change if it directly benefits from the new artifact helper or
needs import alignment. Otherwise, verify it but leave it untouched.

## Stop conditions

Stop and reassess before continuing if:

- a production module file changes
- helper extraction requires changing `Invoke-ConvertScenario`
- a specialized scenario becomes harder to read
- a failure scenario needs hidden defaults to pass
- fake-tool marker behavior changes
- test count changes unexpectedly
- helper use spreads into cases where behavior-specific setup is no longer visible
- input-validation tests require unrelated edits

## Recommendation on support-helper characterization

Do not create a dedicated support-spec file in this cycle. Also avoid direct tests like
“`New-ValidConvertScenarioParams` returns this exact hashtable,” because that can overfit the helper implementation.

Instead, characterize the helper through one migrated successful conversion example first. That proves the helper works
through the public command path and keeps this cycle aligned with the invocation suite’s purpose.
