# [DONE] Phase 1 Steps 1–4 — Domain Foundation Verification and `VvcOutputValidation` Tightening

## Summary

Bring Phase 1 steps 1–4 into a clean, traceable state for `Convert-ToVvc`.

The branch already contains most of the Phase 1 domain foundation, including the baseline enums, invariant exception,
core value objects, `VvcMediaProbe`, and apparently `VvcOutputValidation`. This step set should therefore be treated as
a **verification and contract-tightening pass**, not a broad refactor.

The only active contract gap is `VvcOutputValidation` diagnostic handling:

```text
Current implementation:
  blank diagnostics normalize to $null

Target Step 4 contract:
  invalid output rejects blank diagnostics
```

The larger roadmap already defines Cycle 7 as a domain-only `VvcOutputValidation` cycle whose tests include reason
invariants, non-negative duration drift, and rejection of blank diagnostics.

## Implementation Status

Completed in:

```text
modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1
tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1
```

The final `VvcOutputValidation` diagnostic contract is:

```text
Valid output:
  diagnostic optional; blank normalizes to $null

Invalid output:
  diagnostic required; blank throws VvcConversionInvariantException
```

No public command, worker, filesystem, native-process, or later-cycle behavior was intentionally changed.

## Scope

### Included

- Keep the domain test import model stable.
- Verify baseline domain contracts from steps 1–3.
- Tighten `VvcOutputValidation` to match the active Phase 1 plan.
- Update focused domain tests.
- Update traceability notes if the stricter diagnostic rule is now the authoritative contract.

### Excluded

- `ConvertToVvcResult` factories.
- `VvcConversionDecision`.
- public command behavior.
- worker orchestration.
- parallel scriptblock changes.
- native process invocation.
- filesystem existence checks.
- temp path generation.
- output validation execution logic.

Existing later-cycle code already present in the branch may remain in place, but should not be redesigned or cleaned up
as part of this step set.

---

## Step 1 — Preserve Parse-Time Type Loading

Keep the top-level `using module` in:

```powershell
tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1
```

Expected shape:

```powershell
using module ..\..\modules\Fun.Ffmpeg\internal\ConvertToVvc.Types.psm1
```

Do not replace this with only `Import-Module` inside `BeforeAll` if the tests use direct class or enum references such
as:

```powershell
[VvcOutputValidation]
[VvcConversionReason]
[VvcConversionInvariantException]
```

PowerShell needs class and enum type literals to be visible at parse time.

**Done when:**

- The domain test file parses cleanly.
- Direct type references continue to work.
- The domain suite does not depend on public manifest import order.

---

## Step 2 — Verify Baseline Enum and Exception Contracts

Treat this as verification only.

Confirm that these remain stable:

```powershell
[VvcConversionStatus]
[VvcConversionAction]
[VvcConversionReason]
[VvcConversionInvariantException]
```

Do not rename enum members, remove reasons, or reclassify existing reasons in this step set.

Recommended checks:

```powershell
[VvcConversionStatus]::Converted.ToString() | Should -Be 'Converted'
[VvcConversionStatus]::Skipped.ToString()   | Should -Be 'Skipped'
[VvcConversionStatus]::Failed.ToString()    | Should -Be 'Failed'

[VvcConversionAction]::Convert.ToString() | Should -Be 'Convert'
[VvcConversionAction]::Skip.ToString()    | Should -Be 'Skip'
[VvcConversionAction]::Fail.ToString()    | Should -Be 'Fail'
```

And:

```powershell
{
    throw [VvcConversionInvariantException]::new('Invalid state')
} | Should -Throw -ExceptionType ([VvcConversionInvariantException])
```

**Done when:**

- Enum tests assert names, not numeric values.
- `VvcConversionInvariantException` remains directly throwable and catchable.
- No behavior outside the domain type module changes.

---

## Step 3 — Verify Existing Value Objects Without Redesign

Confirm the existing domain value objects remain side-effect-free:

```powershell
[VvcNativeResult]
[VvcConversionPathSet]
[VvcConversionRequest]
[VvcMediaProbe]
```

This step should not rewrite these types unless a test exposes an actual inconsistency.

For `VvcMediaProbe`, preserve the current implemented contract:

```text
Valid
Reason
Codec
DurationSec
Diagnostic
```

Also preserve its current optional-string behavior:

```text
blank optional strings normalize to $null
```

That is acceptable for `VvcMediaProbe` because probe diagnostics may be absent. Do not force `VvcMediaProbe` to follow
the stricter `VvcOutputValidation` invalid-diagnostic rule. The roadmap already documents that `VvcMediaProbe` blank
optional values normalize to `$null`, while Cycle 7 separately calls for `VvcOutputValidation` to reject blank
diagnostics.

**Done when:**

- Existing tests for these value objects pass.
- No ffmpeg or ffprobe calls are introduced.
- No filesystem checks are introduced.
- No worker or public command code is touched.

---

## Step 4 — Tighten `VvcOutputValidation`

## Goal

Make `VvcOutputValidation` represent an already-known output validation outcome, not perform validation itself.

It should answer:

```text
Given validation facts, is the output valid?
```

It should not:

```text
probe media
decode media
inspect files
calculate drift
call native tools
promote output
clean temp files
```

## Target Contract

Expected shape, adjusted to match the existing class names if already implemented:

```powershell
class VvcOutputValidation {
    [bool] $Valid
    [VvcConversionReason] $Reason
    [Nullable[double]] $DurationDriftSec
    [string] $Diagnostic
}
```

## Required Invariants

1. Valid output requires:

```powershell
Reason = [VvcConversionReason]::None
```

2. Invalid output requires:

```powershell
Reason -ne [VvcConversionReason]::None
```

3. `DurationDriftSec` must be either:

```powershell
$null
```

or:

```powershell
>= 0
```

4. Diagnostics are trimmed.

5. Invalid output rejects blank diagnostics.

6. Valid output may allow blank diagnostics to normalize to `$null`.

That last distinction is important. A valid output does not necessarily need a diagnostic, but an invalid output should
explain why it failed. This preserves the current blank-to-`$null` normalization where it is harmless while enforcing
useful diagnostics for invalid states.

## Recommended Test Cases

Add or split tests under:

```powershell
Describe 'VvcOutputValidation'
```

Use explicit scenario names:

```powershell
It 'accepts valid output with Reason None' {}
It 'accepts invalid output with a non-None reason and diagnostic' {}
It 'rejects valid output with a non-None reason' {}
It 'rejects invalid output with Reason None' {}
It 'rejects negative duration drift' {}
It 'rejects blank diagnostic for invalid output' {}
It 'trims diagnostics' {}
It 'normalizes blank diagnostic for valid output to null' {}
```

Use Gintama-themed fake diagnostics where sample data is needed:

```powershell
'  Yorozuya validation passed  '
'  Shinsengumi duration drift detected  '
'  Elizabeth output validation failed  '
```

## Suggested Red Test First

Start with the current gap:

```powershell
It 'rejects blank diagnostic for invalid output' {
    {
        [VvcOutputValidation]::new(
            $false,
            [VvcConversionReason]::DurationDrift,
            1.25,
            '   '
        )
    } | Should -Throw -ExceptionType ([VvcConversionInvariantException])
}
```

Then update the constructor so this passes.

A clean implementation rule would be:

```powershell
$normalizedDiagnostic = ConvertTo-VvcOptionalString $diagnostic

if (-not $valid -and [string]::IsNullOrWhiteSpace($normalizedDiagnostic)) {
    throw [VvcConversionInvariantException]::new(
        'Invalid output validation requires a diagnostic.'
    )
}
```

The helper name is illustrative; keep the actual helper aligned with the existing type module.

---

## Implementation Notes

Keep the change localized to:

```text
modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1
tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1
```

Prefer a minimal constructor change over introducing factories in this step set.

Do not add:

```powershell
[VvcOutputValidation]::Valid(...)
[VvcOutputValidation]::Invalid(...)
```

unless those already exist or the constructor has become genuinely hard to read. Factory cleanup can remain a later
refinement.

## Verification

Run the focused suite first:

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1
```

Then run the broader module suite:

```powershell
Invoke-Pester -Path tests/Fun.Ffmpeg
```

Optional parser check:

```powershell
$tokens = $null
$errors = $null

[System.Management.Automation.Language.Parser]::ParseFile(
    'modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1',
    [ref] $tokens,
    [ref] $errors
) | Out-Null

$errors | ForEach-Object {
    '{0}:{1}:{2}: {3} [{4}]' -f
        $_.Extent.File,
        $_.Extent.StartLineNumber,
        $_.Extent.StartColumnNumber,
        $_.Message,
        $_.ErrorId
}
```

## Traceability Update

Update the Phase 1 traceability entry to record the resolved diagnostic decision:

```text
Step 4 / Cycle 7 resolved diagnostic handling:
- Valid output may omit diagnostics.
- Invalid output must include a nonblank diagnostic.
- Blank diagnostics are trimmed and rejected for invalid validation states.
- No filesystem, native-process, worker, or public command behavior changed.
```

## Completion Criteria

This step set is complete when:

- `using module` remains the domain test loading model.
- Enum and exception contracts are unchanged.
- Existing value objects remain side-effect-free.
- `VvcOutputValidation` rejects invalid output with blank diagnostics.
- Valid output can still omit diagnostics if that matches current constructor semantics.
- Negative duration drift is rejected.
- Diagnostics are trimmed.
- No later-cycle types are refactored.
- No public command, worker, filesystem, or native invocation behavior changes.
- Focused domain tests pass.
- Broader `tests/Fun.Ffmpeg` passes.

## Main Improvement Over the Draft

The draft says “invalid output rejects blank diagnostics,” but it could be read as “all blank diagnostics are invalid.”
I’d make the rule narrower and more useful:

```text
Valid output:
  diagnostic optional; blank may normalize to $null

Invalid output:
  diagnostic required; blank throws VvcConversionInvariantException
```

That gives you stricter failure diagnostics without disturbing the existing normalization style used by `VvcMediaProbe`
and other optional diagnostic fields.
