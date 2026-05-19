# [DONE] Cycle 6 — Add `VvcMediaProbe`

## Summary

Cycle 6 defines `VvcMediaProbe` as the domain value object for interpreted media-probe state. The cycle is implemented
and verified as a domain-only contract.

`VvcMediaProbe` should model only the result of interpreting probe data. It must not invoke `ffprobe`, touch the
filesystem, validate output files, or participate in worker orchestration. It should provide a small,
constructor-assigned object with normalized values and invariant checks that prevent contradictory probe states.

## Target Contract

`VvcMediaProbe` represents either a successful probe or a failed probe.

Current shape:

- `Valid`: `[bool]`
- `Reason`: `[VvcConversionReason]`
- `Codec`: `[string]`
- `DurationSec`: nullable numeric value, `[Nullable[double]]`
- `Diagnostic`: `[string]`

Keep the current `Valid` name for this cycle to avoid a premature contract break. A later rename to `Succeeded` or
`IsValid` can be considered only as a coordinated API cleanup.

## Invariants

The constructor should enforce these rules:

1. A valid probe must have `Reason = [VvcConversionReason]::None`.
2. A valid probe must have a nonblank `Codec`.
3. An invalid probe must have a non-`None` `Reason`.
4. `DurationSec`, when supplied, must be greater than or equal to zero.
5. Probe construction failures should throw `VvcConversionInvariantException`, matching the adjacent domain-object
   style.

Do not add codec allow-list validation here. `VvcMediaProbe` should describe what was found, not decide whether it is
acceptable for a later conversion stage.

## Normalization Rules

Make normalization explicit and testable:

- Trim nonblank `Codec`.
- Trim nonblank `Diagnostic`.
- Normalize blank optional strings to `$null`.
- Preserve `$null` only for absent `DurationSec`.
- Do not infer a duration from diagnostics or codec data.

This keeps blank string handling consistent with the current adjacent domain types while keeping duration absence
semantically distinct.

## Test Plan

Add or verify a focused `Context 'VvcMediaProbe'` in:

`tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1`

Required scenarios:

1. Accepts a valid probe with:

   - `Valid = $true`
   - `Reason = None`
   - nonblank codec
   - optional duration
   - optional diagnostic

2. Normalizes valid probe strings:

   - trims codec, for example `'  hevc  '` becomes `'hevc'`
   - trims diagnostic, using Gintama-themed fake text such as `'  Yorozuya probe ok  '`

3. Accepts a failed probe with:

   - `Valid = $false`
   - non-`None` reason, for example `ProbeFailed`
  - optional blank codec normalized to `$null`
   - optional diagnostic normalized consistently

4. Rejects valid probe with non-`None` reason.

5. Rejects valid probe with blank codec.

6. Rejects failed probe with `Reason = None`.

7. Rejects negative duration.

8. Confirms the tests require no:

   - real media files
   - `ffprobe`
   - filesystem setup
   - worker invocation

## Implementation Notes

- Keep the implementation in:

  `modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1`

- Follow the style already used by:

  - `VvcConversionRequest`
  - `VvcConversionPathSet`
  - `VvcNativeResult`

- Prefer a single constructor for now. Static factories like `FromSuccess()` / `FromFailure()` are not necessary unless
  the constructor becomes hard to read or call sites become ambiguous in later cycles.

- Keep the object constructor-assigned and mutation-free by convention. PowerShell class properties are not truly
  immutable without extra ceremony, so avoid overengineering this cycle unless adjacent domain types already use hidden
  backing members.

- Use private normalization helpers only if they reduce duplication across nearby domain types. Do not introduce a
  broader utility layer just for this class.

- The current implementation uses `Codec` and `DurationSec`, so any future rename should be coordinated with the tests
  and downstream call sites rather than treated as a doc-only change.

## Relevant Files

- `pwsh-fun/modules/Fun.Ffmpeg/internal/ConvertToVvc.Types.psm1` Holds `VvcMediaProbe` and adjacent domain types.

- `pwsh-fun/tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1` Holds the constructor and invariant tests.

- `pwsh-fun/traceability-log/convert_tovvc_domain_driven_refactor.md` Update Cycle 6 only if the final tested contract
  differs from the roadmap text.

## Verification

Verified with:

```powershell
Invoke-Pester -Path 'pwsh-fun/tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1' -FullName '*VvcMediaProbe*'
```

Also keep this broader domain run as the regression check:

Run the focused domain test file:

```powershell
Invoke-Pester -Path 'pwsh-fun/tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1'
```

For tighter feedback during development, run only the probe context if your Pester version and test layout support it:

```powershell
Invoke-Pester -Path 'pwsh-fun/tests/Fun.Ffmpeg/Convert-ToVvc.Domain.Tests.ps1' -FullName '*VvcMediaProbe*'
```

The cycle is complete when:

- `VvcMediaProbe` tests pass.
- Existing domain tests still pass.
- No ffprobe, filesystem, encoding, output-validation, or worker behavior was added.
- The traceability log matches the implemented/tested contract.

## Decisions for This Cycle

- Keep `Valid` as the success-state property name.
- Normalize blank optional strings to `$null`.
- Use `$null` only for missing nullable duration.
- Use `VvcConversionReason` for machine-readable probe failure classification.
- Defer `VvcOutputValidation` to Cycle 7.
- Do not add factories unless the constructor becomes unclear.

## Deferred Questions

These are worth keeping out of Cycle 6:

1. Whether `Valid` should later be renamed to `Succeeded`, `IsValid`, or `SucceededProbe`.
2. Whether probe-specific factory methods would improve readability once worker call sites are introduced.
3. Whether probe reasons should later be narrowed to a probe-specific subset of `VvcConversionReason`.
4. Whether the traceability log should preserve the original roadmap wording or be updated as a living implementation
   record.
