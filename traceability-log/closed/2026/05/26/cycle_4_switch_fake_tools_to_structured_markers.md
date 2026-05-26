# [DONE] Cycle 4 — Switch Fake Tools to Structured Markers

Status: implemented. Fake `ffmpeg` and `ffprobe` markers are now JSON records in per-tool marker directories, and the
VVC test support reads those records through directory-aware helpers.

## Summary

Switch the VVC fake `ffmpeg` and `ffprobe` tools from raw space-joined marker text to structured JSON marker records.

This remains a **test-support-only** cycle. Production `Convert-ToVvc` behavior, command semantics, result objects, and
worker logic must remain unchanged.

Use one JSON record per fake-tool invocation under per-tool marker directories. This removes single-marker overwrite
ambiguity and prepares later multi-file and parallel characterization tests.

## Goals

- Replace raw marker text written by fake tools with structured JSON records.
- Preserve the existing scenario-facing marker properties: `FfmpegMarker` and `FfprobeMarker`.
- Treat those properties as marker directories instead of marker files.
- Keep `Read-FakeToolArguments` compatible with existing single-file legacy samples.
- Add directory-aware marker readers for invocation counting.
- Update existing tests to consume marker records through support helpers only.
- Preserve current behavior expectations for success, skip, failure, `WhatIf`, extension bypass, and cleanup scenarios.

## Non-goals

- No production module changes.
- No public behavior changes.
- No new conversion scenarios.
- No DDT expansion.
- No removal of legacy raw marker reader compatibility.
- No full argv-sequence assertions unless the test already requires them.
- No broad fake-tool harness rewrite beyond marker persistence.

## Relevant files

- `tests/Fun.Ffmpeg/Support/FakeMediaTools.ps1`
- `tests/Fun.Ffmpeg/Support/FakeToolArgumentSupport.ps1`
- `tests/Fun.Ffmpeg/Support/ConvertToVvc.SpecSupport.ps1`
- `tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1`
- `tests/Fun.Ffmpeg/Convert-ToVvc.InputValidation.Tests.ps1`
- `traceability-log/refactor_convert_tovvc_invocation_characterization.md`

No files under `modules/Fun.Ffmpeg/` should change.

---

## Marker record contract

Each fake-tool invocation record should be a single JSON object.

Recommended schema:

```json
{
  "schemaVersion": 1,
  "tool": "ffmpeg",
  "argv": ["-i", "asakawa-source.mkv", "-threads", "2", "asakawa-source_vvc.__partial__.mkv"],
  "workingDirectory": "E:\\path\\to\\scenario",
  "timestampUtc": "2026-05-26T12:34:56.7890000Z"
}
```

Field contract:

| Field              | Required | Notes                                                 |
| ------------------ | -------: | ----------------------------------------------------- |
| `schemaVersion`    |      yes | Start with `1` so future marker changes are explicit. |
| `tool`             |      yes | Expected values: `ffmpeg`, `ffprobe`.                 |
| `argv`             |      yes | Exact argument array received by the fake tool.       |
| `workingDirectory` |      yes | Captured with `Get-Location`.                         |
| `timestampUtc`     |      yes | Use UTC ISO-8601 round-trip format.                   |

Use `ConvertTo-Json -Compress -Depth 5`.

---

## Marker directory layout

Change scenario layout from single marker files to per-tool marker directories:

```text
markers/
  ffmpeg/
    <record>.json
  ffprobe/
    <record>.json
```

`New-ScenarioLayout` should still expose:

```powershell
$scenario.FfmpegMarker
$scenario.FfprobeMarker
```

But after this cycle, those values point to directories:

```text
.../markers/ffmpeg
.../markers/ffprobe
```

This keeps test churn low while making marker accounting reliable.

---

## Record filename strategy

Avoid “count existing files and add one” if fake invocations can happen concurrently. That pattern is race-prone under
parallel execution.

Use one of these instead.

### Preferred

Use a sortable timestamp plus GUID suffix:

```powershell
$recordName = '{0}-{1}.json' -f `
    ([DateTimeOffset]::UtcNow.ToString('yyyyMMddHHmmssfffffff')), `
    ([guid]::NewGuid().ToString('N'))
```

Benefits:

- no shared counter
- no collision risk
- stable sort by filename is approximately chronological
- safe enough for parallel fake-tool invocations

### Avoid

```powershell
$next = (Get-ChildItem $markerDir -Filter '*.json').Count + 1
$recordName = '{0:0000}.json' -f $next
```

That is fine for single-threaded tests, but this cycle is explicitly preparing for marker isolation under parallel
scenarios.

---

## Fake tool writer behavior

Update fake writers in `FakeMediaTools.ps1`.

### Shared writer behavior

Each generated fake tool should have a small local helper equivalent to:

```powershell
function Write-FakeToolInvocationRecord {
    param(
        [Parameter(Mandatory)]
        [string] $MarkerDirectory,

        [Parameter(Mandatory)]
        [string] $ToolName,

        [Parameter(Mandatory)]
        [string[]] $ArgumentList
    )

    New-Item -ItemType Directory -Path $MarkerDirectory -Force | Out-Null

    $record = [pscustomobject]@{
        schemaVersion    = 1
        tool             = $ToolName
        argv             = @($ArgumentList)
        workingDirectory = (Get-Location).Path
        timestampUtc     = [DateTimeOffset]::UtcNow.ToString('o')
    }

    $recordName = '{0}-{1}.json' -f `
        ([DateTimeOffset]::UtcNow.ToString('yyyyMMddHHmmssfffffff')), `
        ([guid]::NewGuid().ToString('N'))

    $recordPath = Join-Path $MarkerDirectory $recordName

    $record |
        ConvertTo-Json -Compress -Depth 5 |
        Set-Content -LiteralPath $recordPath -NoNewline -Encoding utf8NoBOM
}
```

### `ffmpeg` behavior

Preserve current semantics:

- `ffmpeg -encoders` must not write conversion marker records.
- Only conversion-style invocations containing `-i` should write marker records.
- Existing fake success/failure behavior should remain unchanged.
- Existing stdout/stderr behavior should remain unchanged.

### `ffprobe` behavior

Preserve current semantics:

- Write one marker record for each probe invocation.
- Write the marker before scenario lookup or failure handling, matching current observability.
- Existing fake probe responses and failure behavior should remain unchanged.

---

## Reader support changes

Update `FakeToolArgumentSupport.ps1`.

### Keep existing reader

Preserve:

```powershell
Read-FakeToolArguments -MarkerPath <file>
```

It should still support:

- legacy raw marker files
- JSON marker files

This keeps Cycle 3 characterization valid and allows legacy sample tests to remain.

### Add directory readers

Add:

```powershell
Read-FakeToolInvocations -MarkerPath <directory>
```

Contract:

- accepts a marker directory
- returns zero or more normalized records
- sorts records by filename
- validates JSON shape enough to fail clearly
- returns `@()` when the directory does not exist or contains no `*.json` files, unless the caller asks for strict
  behavior

Suggested return shape per record:

```powershell
[pscustomobject]@{
    Format           = 'Json'
    SchemaVersion    = 1
    ToolName         = 'ffmpeg'
    WorkingDirectory = '...'
    TimestampUtc     = '2026-05-26T12:34:56.7890000Z'
    Raw              = '...'
    Argv             = @(...)
    MarkerPath       = '.../markers/ffmpeg/....json'
}
```

Add:

```powershell
Read-LatestFakeToolInvocation -MarkerPath <directory>
```

Contract:

- returns the last record from `Read-FakeToolInvocations`
- throws a clear error if no invocation exists

Keep:

```powershell
Assert-FakeToolArgumentValue
```

unchanged.

---

## Scenario support changes

Update `ConvertToVvc.SpecSupport.ps1`.

### `New-ScenarioLayout`

Change marker paths to directories:

```powershell
FfmpegMarker = Join-Path $markerRoot 'ffmpeg'
FfprobeMarker = Join-Path $markerRoot 'ffprobe'
```

Ensure directories are created during scenario setup, or let fake writers create them. Prefer creating them in setup for
clarity and easier “no marker records” assertions.

### `Assert-ToolInvocationState`

Update implementation only. Keep its public call shape.

Old meaning:

- marker file exists or does not exist

New meaning:

- marker directory contains at least one `*.json` record or does not

Suggested internal logic:

```powershell
$ffmpegInvocations = Read-FakeToolInvocations -MarkerPath $Scenario.FfmpegMarker
$ffprobeInvocations = Read-FakeToolInvocations -MarkerPath $Scenario.FfprobeMarker

$ffmpegInvocations.Count -gt 0 | Should -Be $ExpectFfmpeg
$ffprobeInvocations.Count -gt 0 | Should -Be $ExpectFfprobe
```

Do not change call sites unless they directly read marker file content.

---

## Test migration

### Encoder-thread test

Replace file-based reader usage with latest invocation reader:

```powershell
$ffmpegInvocation = Read-LatestFakeToolInvocation -MarkerPath $scenario.FfmpegMarker

Assert-FakeToolArgumentValue `
    -Argv $ffmpegInvocation.Argv `
    -Name '-threads' `
    -ExpectedValue ([string] $EncoderThreads)
```

Do not assert the full argv sequence.

### Marker reader characterization

Update characterization to include:

- legacy raw file parsing still works
- single JSON file parsing still works
- directory JSON invocation parsing works
- latest invocation reader returns the final sorted record
- empty or missing marker directory returns zero records for `Read-FakeToolInvocations`
- `Read-LatestFakeToolInvocation` throws on empty or missing marker directory

### Existing tests

Update only direct marker-content readers. Tests that use `Assert-ToolInvocationState` should not need call-site
changes.

---

## TDD sequence

### Step 1 — Baseline

Run:

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.InputValidation.Tests.ps1
```

Stop if either suite is already failing.

### Step 2 — Add directory reader tests

Before changing writers, add characterization for:

- reading a directory with two JSON records
- records returned in filename order
- latest record returned correctly
- empty directory returns `@()`
- latest reader throws on empty directory

Use synthetic marker directories, not fake `ffmpeg` yet.

### Step 3 — Implement directory readers

Add `Read-FakeToolInvocations` and `Read-LatestFakeToolInvocation`.

Keep existing `Read-FakeToolArguments` behavior intact.

Run the reader characterization tests.

### Step 4 — Update scenario layout and invocation-state helper

Change `New-ScenarioLayout` marker paths to directories.

Update `Assert-ToolInvocationState` to use `Read-FakeToolInvocations`.

At this point, tests may fail until fake writers switch to directories. Keep this as a small commit or proceed
immediately to Step 5.

### Step 5 — Switch fake writers to JSON directory records

Update fake `ffmpeg` and `ffprobe` scripts.

Preserve all current fake behavior except marker persistence.

Run the invocation suite.

### Step 6 — Update direct marker consumers

Update the encoder-thread scenario and any other direct marker readers to use:

```powershell
Read-LatestFakeToolInvocation
```

or:

```powershell
Read-FakeToolInvocations
```

Run the invocation suite again.

### Step 7 — Verify input-validation suite

Run:

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.InputValidation.Tests.ps1
```

This catches shared support import/layout regressions.

---

## Verification

Run:

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.InputValidation.Tests.ps1
```

Then check production files were not touched:

```powershell
git diff --name-only -- modules/Fun.Ffmpeg
```

Expected: no output.

Check fake writer changed only in marker persistence behavior, not success/failure behavior.

Implemented verification:

- `Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1 -FullName '*fake-tool markers*'` passed:
  6 tests, 0 failed.
- `Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.InputValidation.Tests.ps1` passed: 2 tests, 0 failed.
- `Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1` still has the pre-existing valid-output
  skip characterization failure documented before this cycle; the marker-related tests pass.
- `git status`/`git diff` could not be used from the sandbox because Git rejected the repository as a dubious owner for
  the `CodexSandboxOffline` user. The implemented edits were kept to `tests/Fun.Ffmpeg/` support/tests and traceability
  logs; no `modules/Fun.Ffmpeg/` files were edited.

---

## Explicit scenarios to verify

- successful conversion creates at least one `ffprobe` record and one `ffmpeg` conversion record
- `ffmpeg -encoders` creates no conversion marker record
- `WhatIf` creates no conversion marker records
- extension-filter bypass creates no conversion marker records
- existing valid output without `Overwrite` creates `ffprobe` records but no `ffmpeg` conversion record
- encoder-thread test validates `-threads <value>` as separate argv tokens
- ffmpeg failure still emits failure result and cleans partial output
- post-validation failure still emits failure result and cleans partial output
- single-file parallel test still passes with directory-based marker accounting

---

## Acceptance criteria

Cycle 4 is complete when:

- fake tools write JSON marker records
- marker paths are directories
- one fake-tool invocation creates one JSON record
- records include `schemaVersion`, `tool`, `argv`, `workingDirectory`, and `timestampUtc`
- `ffmpeg -encoders` does not create conversion markers
- `ffmpeg` conversion calls containing `-i` create marker records
- `ffprobe` probe calls create marker records before scenario handling
- `Read-FakeToolArguments` still supports legacy raw samples
- `Read-FakeToolInvocations` reads directory records in stable order
- `Read-LatestFakeToolInvocation` works for tests that care about the latest invocation
- `Assert-ToolInvocationState` works against marker directories
- invocation and input-validation suites pass
- no production module files changed

---

## Stop conditions

Stop and reassess if:

- production code changes are needed
- marker support requires changes to public scenario behavior
- fake success/failure behavior changes
- `ffmpeg -encoders` starts producing conversion markers
- marker records overwrite each other
- parallel tests become flaky
- direct tests start depending on raw JSON field order
- legacy raw reader compatibility breaks
- broad argv-sequence assertions appear in unrelated tests

---

## Assumptions

- Legacy raw reader compatibility remains until a later cleanup cycle.
- Marker directory paths can reuse the existing `FfmpegMarker` and `FfprobeMarker` property names to reduce call-site
  churn.
- Filename generation should be GUID/timestamp based, not count based, to avoid race conditions.
- JSON marker field order is not significant; tests should assert parsed properties, not raw JSON text.
- This cycle is allowed to change test-support marker persistence only.
