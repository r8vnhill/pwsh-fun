using namespace System

<#
.SYNOPSIS
    Reasons why a single-file inspection is missing, invalid, or unusable.

.DESCRIPTION
    Represents the canonical failure or non-success reason for one
    `VvcMediaInspection`.

    `None` is reserved for valid inspections. Invalid inspections should use a
    specific reason that explains why probing or validation failed.

.VALUES
    - `None`: The inspection is valid and requires no failure reason.
    - `Missing`: The target file was not present.
    - `EmptyFile`: The target file exists but is empty.
    - `ProbeFailed`: Metadata/probe inspection failed.
    - `UnexpectedCodec`: The file was readable but did not match the expected
      codec.
    - `DecodeFailed`: Decoding validation failed.
#>
enum VvcInspectionReason {
    None
    Missing
    EmptyFile
    ProbeFailed
    UnexpectedCodec
    DecodeFailed
}

<#
.SYNOPSIS
    High-level audit classifications for an original/VVC pair.

.DESCRIPTION
    Represents the derived state of an audit after combining the original-media
    inspection, the `_vvc` inspection, and the workflow rules that interpret
    them.

    These statuses are intended to support reporting and cleanup decisions.
    They do not replace the more detailed inspection data stored in `Original`
    and `Vvc`.

.VALUES
    - `OriginalValidNoVvc`: The original is valid and no VVC counterpart exists.
    - `OriginalCorruptNoVvc`: The original is invalid/corrupt and no VVC
      counterpart exists.
    - `OriginalValidAndVvcValid`: Both the original and the VVC counterpart are
      valid.
    - `OriginalCorruptAndVvcValid`: The original is invalid/corrupt but the VVC
      counterpart is valid.
    - `VvcSuspiciousOrCorrupt`: A VVC counterpart exists but is suspicious or
      invalid.
    - `VvcValidOriginalMissing`: The VVC counterpart is valid and the original
      is missing.
    - `Unclassified`: The audit result does not fit another explicit category.
#>
enum VvcAuditStatus {
    OriginalValidNoVvc
    OriginalCorruptNoVvc
    OriginalValidAndVvcValid
    OriginalCorruptAndVvcValid
    VvcSuspiciousOrCorrupt
    VvcValidOriginalMissing
    Unclassified
}
