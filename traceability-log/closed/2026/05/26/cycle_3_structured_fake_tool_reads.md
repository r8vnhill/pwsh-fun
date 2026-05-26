# [PLAN] Cycle 3 — Structured Fake-Tool Reads [implemented]

## Summary

Add a structured fake-tool marker reader and token-aware assertion helpers before changing fake-tool marker writers.
This cycle prepares for the later JSON marker migration by making tests consume fake-tool arguments through one
compatibility layer.

Status: implemented. The support layer now reads both legacy raw marker text and JSON marker records, and the
encoder-thread invocation scenario has been migrated to token-level assertions without changing fake-tool writers.

The fake tools must continue writing the current raw marker format in Cycle 3. Only the reader and the first consuming
assertion should change.

The immediate consumer is the encoder-thread invocation scenario, replacing brittle raw string matching with an
argument-level check for `-threads <value>`.

## Goals

- Introduce a single marker-reading contract for current and future fake-tool marker formats.
- Keep fake `ffmpeg` / `ffprobe` writer behavior unchanged.
- Replace the encoder-thread raw marker regex/string assertion with a structured token assertion.
- Prepare Cycle 4 to switch marker writing to JSON with minimal test churn.
- Keep helper scope narrow and test-support-only.

Completed in the current workspace:

- `Read-FakeToolArguments` now reads the current raw marker format and future JSON marker format.
- `Assert-FakeToolArgumentValue` provides a narrow token-pair assertion.
- The invocation suite includes reader characterization coverage for both raw and JSON marker samples.
- The encoder-thread scenario now asserts `-threads <value>` through the reader helper.
- `FakeMediaTools.ps1` writer behavior remains unchanged for Cycle 3.

## Non-goals

- No fake-tool writer changes.
- No marker file layout changes.
- No multi-invocation marker accounting yet.
- No per-file marker isolation yet.
- No production code changes.
- No broad fake-tool abstraction or fluent assertion DSL.
- No unrelated marker-consuming test rewrites unless required by the encoder-thread scenario.

## Important constraint

The current raw marker format is space-joined argv text. That format is not a lossless representation of an argv array
when paths, quoted values, escaped characters, or spaces are involved.

So Cycle 3 should treat legacy parsing as **compatibility-only**:

- JSON marker parsing should be the future authoritative path.
- Raw marker parsing should support only the current simple assertions safely.
- Do not add broad path-sensitive argv assertions until Cycle 4 switches writers to structured JSON.

## Relevant files

- `tests/Fun.Ffmpeg/Support/FakeMediaTools.ps1`

  - Keep writer behavior unchanged.
- `tests/Fun.Ffmpeg/Support/ConvertToVvc.SpecSupport.ps1`

  - Add marker reader and token assertion helpers.
- `tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1`

  - Migrate the encoder-thread assertion.
- `traceability-log/refactor_convert_tovvc_invocation_characterization.md`

  - Keep cycle notes aligned.

## Reader contract

Add `Read-FakeToolArguments` to `ConvertToVvc.SpecSupport.ps1`.

### Contract

The helper should:

- Accept a marker path.
- Read the marker content.
- Detect JSON vs legacy raw text.
- Return a normalized record.
- Preserve raw content for diagnostics.
- Provide an `Argv` array where possible.
- Expose the marker format so tests can distinguish compatibility behavior if needed.
- Throw clear assertion-friendly errors for missing or unreadable markers.

Suggested return shape:

```powershell
[pscustomobject]@{
    Format = 'LegacyRaw' # or 'Json'
    ToolName = $null     # populated by JSON later when available
    WorkingDirectory = $null
    Raw = $raw
    Argv = $argv
}
```

Suggested signature:

```powershell
function Read-FakeToolArguments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $MarkerPath
    )

    if (-not (Test-Path -LiteralPath $MarkerPath)) {
        throw "Fake tool marker was not found: $MarkerPath"
    }

    $raw = Get-Content -LiteralPath $MarkerPath -Raw

    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Fake tool marker was empty: $MarkerPath"
    }

    $trimmed = $raw.Trim()

    if ($trimmed.StartsWith('{')) {
        $record = $trimmed | ConvertFrom-Json

        return [pscustomobject]@{
            Format = 'Json'
            ToolName = $record.tool
            WorkingDirectory = $record.workingDirectory
            Raw = $raw
            Argv = @($record.argv)
        }
    }

    return [pscustomobject]@{
        Format = 'LegacyRaw'
        ToolName = $null
        WorkingDirectory = $null
        Raw = $raw
        Argv = @(Split-LegacyFakeToolArguments -RawArguments $trimmed)
    }
}
```

Add the legacy splitter as a private support helper:

```powershell
function Split-LegacyFakeToolArguments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RawArguments
    )

    # Compatibility-only: current marker text is not a lossless argv format.
    # This is sufficient for simple token pairs such as "-threads 2".
    $RawArguments -split '\s+' | Where-Object { $_ }
}
```

That limitation should be intentional. Cycle 4’s JSON writer will remove the ambiguity.

## Token assertion helper

Add a narrow token-pair helper:

```powershell
function Assert-FakeToolArgumentValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]] $Argv,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $ExpectedValue
    )

    $index = [array]::IndexOf($Argv, $Name)

    $index | Should -BeGreaterOrEqual 0
    ($index + 1) | Should -BeLessThan $Argv.Count
    [string] $Argv[$index + 1] | Should -Be $ExpectedValue
}
```

Keep it deliberately small. Do not add helpers for ordering, repeated arguments, optional arguments, or full
command-line equality yet.

## Support coverage

Do not put Pester tests inside `ConvertToVvc.SpecSupport.ps1`. That file should stay as support code.

Use one of these options:

### Preferred for Cycle 3

Add a small support-focused `Context` inside `Convert-ToVvc.Invocation.Tests.ps1`, near the encoder configuration
context:

```powershell
Context 'when fake-tool markers are read through support helpers' {
    It 'reads legacy raw marker text as compatibility argv tokens' { }
    It 'reads future JSON marker text as argv tokens' { }
}
```

This avoids creating a new support-spec file just for two tests.

### Alternative if helper surface grows

Create:

```text
tests/Fun.Ffmpeg/Convert-ToVvc.FakeToolSupport.Tests.ps1
```

Only do this if the reader/helper surface grows beyond two or three focused examples.

## TDD sequence

### Step 1 — Baseline

Run:

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.InputValidation.Tests.ps1
```

Do not continue if either suite is already failing.

### Step 2 — Add reader characterization

Add focused examples for:

1. legacy raw marker text:

```powershell
'-i asakawa-source.mkv -threads 2 output.mkv'
```

Expected:

- `Format = 'LegacyRaw'`
- `Argv` contains `-threads`
- token after `-threads` is `2`
- `Raw` preserves the source text

2. future JSON marker text:

```json
{
  "tool": "ffmpeg",
  "argv": ["-i", "asakawa-source.mkv", "-threads", "2", "output.mkv"],
  "workingDirectory": "Nenya"
}
```

Expected:

- `Format = 'Json'`
- `ToolName = 'ffmpeg'`
- `WorkingDirectory = 'Nenya'`
- `Argv` preserves tokens exactly
- token after `-threads` is `2`

Use Ringu-themed filenames in examples.

### Step 3 — Implement `Read-FakeToolArguments`

Implement the smallest reader that passes the two characterization examples.

Keep parsing logic in `ConvertToVvc.SpecSupport.ps1`.

Do not modify `FakeMediaTools.ps1`.

### Step 4 — Add token assertion helper

Add `Assert-FakeToolArgumentValue`.

Use it in the reader characterization tests first, then in the real encoder-thread scenario.

### Step 5 — Migrate encoder-thread scenario

Replace direct marker reads like:

```powershell
$ffmpegArgs = Get-Content -LiteralPath $scenario.FfmpegMarker -Raw
$ffmpegArgs | Should -Match ('-threads {0}' -f $EncoderThreads)
```

with:

```powershell
$ffmpegMarker = Read-FakeToolArguments -MarkerPath $scenario.FfmpegMarker

Assert-FakeToolArgumentValue `
    -Argv $ffmpegMarker.Argv `
    -Name '-threads' `
    -ExpectedValue ([string] $EncoderThreads)
```

Do not assert the full argv sequence in Cycle 3. The purpose is to harden the thread token check only.

### Step 6 — Verify writer behavior did not change

Confirm `FakeMediaTools.ps1` is unchanged:

```powershell
git diff -- tests/Fun.Ffmpeg/Support/FakeMediaTools.ps1
```

Expected result: no diff.

Run:

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.Invocation.Tests.ps1
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.InputValidation.Tests.ps1
```

## Acceptance criteria

Cycle 3 is complete when:

- `Read-FakeToolArguments` exists.
- The reader accepts current raw marker text.
- The reader accepts future JSON marker text.
- The reader returns a normalized record with `Format`, `Raw`, and `Argv`.
- Token assertion helper exists.
- Encoder-thread scenario no longer uses raw `Get-Content -Raw` plus substring/regex matching.
- Fake-tool writers remain unchanged.
- Marker file layout remains unchanged.
- Invocation and input-validation suites pass.
- Test counts remain unchanged except for the intentionally added reader characterization examples.

## Workspace outcome

The reader-first migration is now in place in the tests. The next planned change is Cycle 4, which will switch fake
tool writers to structured JSON and then broaden marker-consuming assertions.

## Stop conditions

Stop and reassess if:

- `FakeMediaTools.ps1` changes.
- Marker file layout changes.
- Raw legacy parsing requires complex command-line parsing.
- The helper starts asserting full command lines.
- Path-sensitive argv behavior is added before JSON writer migration.
- Production code changes.
- More than one current scenario needs migration to make the suite pass.
- The reader begins to look like a general command-line parser.

## Decision refinements

### Return array or rich record?

Return a rich record.

Reason: Cycle 4 can populate `ToolName`, `WorkingDirectory`, timestamp, and exact `Argv` from JSON without changing
downstream test assertions again.

### Inline support coverage or dedicated support test file?

Use a small support-focused context in the invocation suite for now.

Reason: this repo does not yet have a support-spec precedent, and two reader tests do not justify a new file. Create a
dedicated support test file later only if helper coverage grows.

### Assert token pair or surrounding sequence?

Assert only the token pair.

Reason: the behavior under test is “encoder thread setting reaches fake ffmpeg as `-threads <value>`.” Full argv
ordering belongs either in a lower-level command construction test or after JSON marker writing becomes authoritative.

## Main improvement over the original plan

The key improvement is explicitly acknowledging that the current raw marker format cannot support reliable general argv
parsing. Cycle 3 should introduce a compatibility reader for the narrow current need, while making JSON the future
authoritative marker format in Cycle 4.
