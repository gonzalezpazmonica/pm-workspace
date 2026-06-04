# Sentinel-Safe Regeneration Primitive

> Ref SPEC-180. Applied 2026-06-04.

Contract for regenerable docs. Auto-regen modifies only generated blocks. User blocks persist.

## Markers

Generated block:

    <!-- @generated:section-id START hash=abcd1234 -->
    ... auto content ...
    <!-- @generated:section-id END -->

User block:

    <!-- @user:section-id -->
    ... human notes ...

## Rules

- section-id is kebab-case, unique per file.
- hash is first 8 chars of sha256 over inner content.
- user block has no end marker. Content owned by human until next sentinel or EOF.
- Two generated blocks with same id in one file is an error.

## CLI

scripts/sentinel-regen.sh modes:

- inject FILE ID stdin: replace generated block, recompute hash.
- extract FILE ID: print inner content.
- verify-hash FILE: exit 1 if any stored hash mismatches recomputed.

## Example

    <!-- @generated:agents-table START hash=a1b2c3d4 -->
    table content
    <!-- @generated:agents-table END -->

    <!-- @user:operator-notes -->
    Free human text.

## Idempotence

Re-running inject with same content yields same bytes.

## Drift

If human edits inside generated block, verify-hash reports the id and hashes.
