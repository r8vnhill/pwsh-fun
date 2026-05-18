# [PLAN] Add `Convert-AudioToMp3` to `Fun.Ffmpeg`

## Summary

Add a public `Convert-AudioToMp3` command to `Fun.Ffmpeg` for batch conversion of `.flac`, `.opus`, and `.m4a` files to MP3 using `ffmpeg`.

The command should follow the same practical orchestration model as `Convert-ToVvc`: directory discovery, explicit path and pipeline input, optional recursion, output directory creation, overwrite control, `-WhatIf`, parallel execution, safe temporary outputs, and one structured result per attempted file.

This first cycle should focus on a reliable MP3 conversion workflow without post-conversion media validation. Success is defined as:

1. `ffmpeg` exits with code `0`;
2. the temporary `.partial.mp3` output exists;
3. the temporary file is successfully promoted to the final `.mp3` path.

## Scope

### In scope

* Add `Convert-AudioToMp3` to `modules/Fun.Ffmpeg/public`.
* Export it from `Fun.Ffmpeg.psd1`.
* Add it to `tests/Fun.Ffmpeg/Setup.ps1` required command checks.
* Support directory, explicit path, and pipeline input.
* Support sequential and parallel execution.
* Use `ffmpeg` with `libmp3lame` VBR encoding.
* Emit per-file result objects.
* Add focused Pester coverage with fake media tooling.

### Out of scope

* `ffprobe` validation of MP3 outputs.
* Bitrate mode selection beyond LAME VBR quality.
* Metadata editing beyond copying source metadata.
* Removing or repurposing the existing empty `Fun.OCD/public/Convert-AudioToMp3.ps1` stub.
* Preserving source directory structure under `OutputDir`, unless explicitly added in a later cycle.

## Public Contract

Add command:

```powershell
Convert-AudioToMp3
```

Recommended declaration shape:

```powershell
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(ParameterSetName = 'Directory')]
    [string] $InputDir = '.',

    [Parameter(
        ParameterSetName = 'LiteralPath',
        ValueFromPipeline,
        ValueFromPipelineByPropertyName
    )]
    [Alias('FullName', 'PSPath', 'OriginalPath')]
    [string[]] $LiteralPath,

    [string] $OutputDir = '.\mp3_out',

    [switch] $Recurse,

    [switch] $Overwrite,

    [ValidateRange(1, 128)]
    [int] $MaxParallel = 1,

    [ValidateNotNullOrEmpty()]
    [string[]] $Extensions = @('.flac', '.opus', '.m4a'),

    [ValidateRange(0, 9)]
    [int] $Quality = 2
)
```

### Parameter notes

Prefer not to alias `LiteralPath` as `Path` unless the existing module convention strongly favors it. In PowerShell, `Path` usually implies wildcard-aware behavior, while `LiteralPath` implies exact paths. If `Path` is kept as an alias for convenience, tests should document that it is treated literally.

`MaxParallel` should validate to at least `1`. A high upper bound such as `128` is enough to prevent accidental runaway values without being overly restrictive.

`Quality` should map directly to LAME VBR `-q:a`, where lower numbers mean higher quality. Default remains `2`.

## Default Encoding Behavior

For each source file, invoke `ffmpeg` approximately as:

```powershell
ffmpeg `
  -hide_banner `
  -y or -n `
  -i <source> `
  -map_metadata 0 `
  -c:a libmp3lame `
  -q:a <Quality> `
  <temporary-output>
```

Recommended details:

* Resolve `ffmpeg` once with `Get-Command ffmpeg -CommandType Application`.
* Treat missing `ffmpeg` as a command setup failure, not a per-file media failure.
* Do not require `ffmpeg` resolution during `-WhatIf`, since no conversion should run.
* Use `-y` only when writing to a unique temporary file. Existing final output handling should remain controlled by the command’s own `-Overwrite` logic.
* Avoid relying on `ffmpeg -n` for overwrite protection because final-output decisions are already handled before invoking `ffmpeg`.

## Input Discovery

Directory mode should:

* Resolve `InputDir` to a literal directory.
* Search only direct children unless `-Recurse` is set.
* Match extensions case-insensitively.
* Normalize configured extensions so both `flac` and `.flac` are accepted.
* Ignore directories.
* Produce deterministic ordering before processing, especially for predictable tests.

Explicit path and pipeline mode should:

* Accept file paths from `-LiteralPath`.
* Accept pipeline input by value and by property name.
* Support objects with `FullName`, `PSPath`, or `OriginalPath`.
* Validate that each resolved item is a file.
* Filter by `-Extensions`, unless the design intentionally allows explicit paths outside the extension list. The safer first version should filter consistently.

## Output Path Rules

Default output path:

```text
<OutputDir>\<SourceBaseName>.mp3
```

Example:

```text
music\album\track.flac -> .\mp3_out\track.mp3
```

Make this collision behavior explicit:

* If multiple source files map to the same output path in the same invocation, treat the later duplicate as a failed result with reason `OutputCollision`.
* Do the collision preflight before parallel execution.
* Do not allow parallel workers to race on the same final output path.

This is important because `song.flac`, `song.opus`, and files from different directories can all map to the same `song.mp3`.

## Safe Write Strategy

For each conversion:

1. Create `OutputDir` if needed.

2. Compute final output path.

3. If final output exists and `-Overwrite` is not set, emit a skipped result.

4. Generate a unique temp path in the same output directory, for example:

   ```text
   <basename>.<guid>.partial.mp3
   ```

5. Invoke `ffmpeg` against the temp path.

6. If `ffmpeg` fails, remove the temp file and emit a failed result.

7. If `ffmpeg` succeeds but the temp file is missing, emit a failed result.

8. If final output exists and `-Overwrite` is set, remove or replace it immediately before promotion.

9. Promote the temp file to the final path.

10. Remove partial outputs in `finally` where safe.

Using the same directory for temp and final files makes promotion closer to atomic on the same filesystem.

## Result Contract

Emit one result per attempted input file, except for `-WhatIf`, which should mirror the existing `Convert-ToVvc` behavior and emit no results.

Recommended result shape:

```powershell
[pscustomobject] @{
    PSTypeName  = 'Fun.Ffmpeg.AudioToMp3.Result'
    File        = <source path>
    OutputFile  = <final mp3 path>
    Ok          = <bool>
    Skipped     = <bool>
    Reason      = <string>
    OriginalMB  = <double?>
    NewMB       = <double?>
    Ratio       = <double?>
}
```

Keep the requested fields:

* `File`
* `Ok`
* `Skipped`
* `Reason`
* `OriginalMB`
* `NewMB`
* `Ratio`

But add `OutputFile` because it is operationally useful and makes tests clearer.

Recommended reasons:

```text
Converted
ExistingOutput
InvalidInput
UnsupportedExtension
OutputCollision
FfmpegMissing
EncodeFailed
TempOutputMissing
PromoteFailed
UnexpectedFailure
WhatIf
```

Since `-WhatIf` emits no results, `WhatIf` may not be needed immediately. Keep it only if a future mode returns planned actions.

## Internal Design

Add small internal helpers instead of putting all logic in the public command.

Suggested helpers:

```powershell
Normalize-AudioExtension
Test-AudioExtension
Resolve-AudioToMp3Input
Get-AudioToMp3OutputPath
Get-AudioToMp3Request
Get-AudioToMp3Result
Invoke-AudioToMp3Worker
Invoke-NativeTool
```

If `Invoke-NativeTool` already exists or is being introduced for `Convert-ToVvc`, reuse or extract it so both commands capture native process behavior consistently.

Recommended native result shape:

```powershell
[pscustomobject] @{
    FilePath = <string>
    Arguments = <string[]>
    ExitCode = <int>
    StdOut = <string>
    StdErr = <string>
}
```

Avoid constructing native command lines as a single string. Pass arguments as an array to preserve paths with spaces and special characters.

## Parallel Execution

Keep the established module pattern:

* `MaxParallel -eq 1`: process sequentially.
* `MaxParallel -gt 1`: process with `ForEach-Object -Parallel`.

Parallel workers should not depend on caller runspace state. Pass a request object containing all required values:

```powershell
SourcePath
OutputPath
TempPath
Quality
Overwrite
FfmpegPath
ModulePath
```

The parallel scriptblock should import the module or the necessary internal implementation exactly as the existing `Convert-ToVvc` worker pattern does.

Avoid passing live scriptblocks, closures, or non-serializable objects into parallel runspaces.

## TDD Implementation Plan

### Cycle 1 — Public command contract

Add tests first:

* `Fun.Ffmpeg` imports successfully.
* `Convert-AudioToMp3` is exported.
* `tests/Fun.Ffmpeg/Setup.ps1` requires the command.
* Parameters exist with expected names and validation attributes.

Then implement the minimal public function and export.

### Cycle 2 — Extension normalization and input discovery

Add tests for:

* default extensions `.flac`, `.opus`, `.m4a`;
* case-insensitive matching;
* extension inputs with and without leading dot;
* directory mode without recursion;
* directory mode with `-Recurse`;
* explicit `-LiteralPath`;
* pipeline input from strings;
* pipeline input from objects with `FullName`.

Then implement discovery helpers.

### Cycle 3 — Output path and collision handling

Add tests for:

* output directory defaulting to `.\mp3_out`;
* output filename using source basename plus `.mp3`;
* output directory creation;
* duplicate output collisions detected before conversion;
* existing output skipped when `-Overwrite` is absent.

Then implement output request construction.

### Cycle 4 — Sequential conversion worker

Extend fake media tooling so fake `ffmpeg` can:

* capture arguments;
* create a requested MP3 output;
* simulate non-zero exit;
* simulate success without output;
* handle paths with spaces.

Add tests for:

* default args include `-c:a libmp3lame`;
* default args include `-q:a 2`;
* custom `-Quality` changes `-q:a`;
* metadata copy uses `-map_metadata 0`;
* successful conversion emits `Ok = $true`;
* result includes size fields;
* failed `ffmpeg` emits `Ok = $false`;
* partial output is removed on failure;
* missing temp output after exit `0` is a failure.

Then implement `Invoke-AudioToMp3Worker`.

### Cycle 5 — Overwrite and promotion behavior

Add tests for:

* existing output skipped without `-Overwrite`;
* existing output replaced with `-Overwrite`;
* temp file promoted only after successful encode;
* final output is not replaced if encode fails;
* promotion failure emits failed result and cleans partial file where possible.

Then implement robust promotion behavior.

### Cycle 6 — `ShouldProcess` / `-WhatIf`

Add tests for:

* `-WhatIf` invokes no fake `ffmpeg`;
* `-WhatIf` creates no output directory unless already required by existing behavior;
* `-WhatIf` emits no results, matching `Convert-ToVvc`.

Then add `SupportsShouldProcess` wiring.

### Cycle 7 — Parallel execution

Add tests for:

* `-MaxParallel 2` processes multiple requests;
* parallel mode imports the module correctly;
* parallel mode uses the same result contract as sequential mode;
* duplicate output paths are handled before parallel execution;
* fake `ffmpeg` captures one invocation per converted file.

Then implement the parallel branch.

## Test File Layout

Recommended files:

```text
tests/Fun.Ffmpeg/Convert-AudioToMp3.Invocation.Tests.ps1
tests/Fun.Ffmpeg/Convert-AudioToMp3.Discovery.Tests.ps1
tests/Fun.Ffmpeg/Convert-AudioToMp3.Worker.Tests.ps1
```

If the project prefers fewer files, keep one file but separate contexts clearly:

```powershell
Describe 'Convert-AudioToMp3' {
    Context 'command contract' {}
    Context 'input discovery' {}
    Context 'output planning' {}
    Context 'sequential conversion' {}
    Context 'WhatIf behavior' {}
    Context 'parallel conversion' {}
}
```

## Fake Media Tooling Updates

Extend the existing fake media support instead of creating a separate harness.

Add fake `ffmpeg` capabilities for:

* logging executable arguments;
* creating the final argument path as output;
* configurable exit code;
* configurable stderr text;
* configurable “success without output” mode;
* safe handling of quoted paths and spaces.

The fake tool should behave predictably enough to test command orchestration without requiring real media files.

## Implementation Notes

* Keep the command in `Fun.Ffmpeg`, not `Fun.OCD`.
* Use `[CmdletBinding(SupportsShouldProcess)]`.
* Prefer internal helpers with narrow responsibilities.
* Keep functions short and directly testable.
* Avoid global mutable state.
* Avoid string-built native command lines.
* Use deterministic sorting before conversion.
* Do collision detection before parallel execution.
* Capture `ffmpeg` stdout, stderr, and exit code through a shared native tool wrapper.
* Prefer emitting structured objects over formatted strings.
* Use `Write-Verbose` for diagnostic details, especially native command failures.
* Do not add `ffprobe` validation in this cycle.

## Revised Assumptions

* MP3 output goes to `.\mp3_out` by default.
* Output filenames use only the source basename plus `.mp3`.
* Duplicate output paths in one invocation are failed as `OutputCollision`.
* VBR `-q:a 2` is the default quality.
* `ffmpeg` is resolved from `PATH`.
* Missing `ffmpeg` is a setup failure unless `-WhatIf` is used.
* The first version does not validate output with `ffprobe`.
* `-WhatIf` performs no conversion and emits no result objects, matching the stated `Convert-ToVvc` behavior.
* No changes are made to the `Fun.OCD` stub in this cycle.
