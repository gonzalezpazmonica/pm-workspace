# SPEC-XXX — Short Title

> **Priority:** P0 | P1 | P2 · **Estimate (human):** Nd · **Estimate (agent):** Nh · **Category:** trivial|standard|complex|novel|legacy · **Type:** category

> **Dual estimate**: `Estimate (human)` es el esfuerzo end-to-end en dias-persona
> si el pipeline lo hace un humano sin asistencia. `Estimate (agent)` es el
> wall-clock esperado del pipeline completo asistido por agentes (discovery +
> spec writing + implementation + review + PM) con supervision humana en los
> puntos de decision. Formula baseline: `agent_hours ≈ human_days`. Ajuste por
> categoria y detalles en `@docs/rules/domain/dual-estimation.md`.

## Objective

One paragraph stating what this spec delivers and why it matters. Anchor the
reader in the problem before the solution. Radical honesty: if something is
a trade-off, say so.

## Principles affected

List the foundational principles this spec touches, with a one-line note on
how it preserves each one:

- #1 Data sovereignty — ...
- #2 Vendor independence — ...
- #5 Humans decide — ...

Any spec that contradicts an immutable principle must be rejected in review.
There is no override path.

## Design

### Overview

High-level description of the approach. Diagrams in Mermaid or ASCII if they
clarify. No marketing prose — engineering prose only.

### Components

| Name | Kind | Purpose |
|------|------|---------|
| component-a | script | ... |
| component-b | hook | ... |

### Contracts

Describe the public interfaces this spec introduces. Every contract must be
testable. Input → output, error modes, idempotency.

### Configuration

Any new configuration keys, files, or environment variables. Default values
must be conservative (opt-in, reversible, safe).

## Acceptance criteria

Numbered list of verifiable conditions. Each item must be a concrete test or
manual check. Pretend the reviewer has never seen this spec.

1. Condition A is true, verified by script X.
2. Condition B is true, verified by BATS test Y.
3. Full-suite regression passes.

## Out of scope

Bulleted list of deliberate exclusions. Being explicit about what this spec
does NOT do prevents scope creep during review.

- ...
- ...

## Dependencies

Which other specs must ship before this one can be implemented, and which
specs this one unblocks.

- Blocked by: SPEC-XXX
- Blocks: SPEC-YYY, SPEC-ZZZ

## Migration path (if applicable)

If the change affects existing installations, describe the reversible
activation path. Mention feature flags, fallbacks, and rollback procedure.

## Impact statement

Two or three sentences on the strategic or operational impact once shipped.
Ground it in facts, not aspirations.
