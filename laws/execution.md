# Execution Laws

## LAW-EXEC-001 — Read-only audit
An audit MUST NOT modify the systems it audits (SE-374 RN-12 invariant).
- Verificación: guardrail-audit.sh aborta (exit 2) si git status cambia fuera de output/.

## LAW-EXEC-002 — Deterministic enforcement
A "never" prohibition MUST have deterministic enforcement (hook block), not prose (SE-374 LEC-2).
- Verificación: guardrail-audit RN-02 (prohibición sin enforcement = P0).

## LAW-EXEC-003 — Transport vs policy
Transport MUST NOT contain domain authorization policy (SE-386 §7).
- Verificación: contract-check en descriptors (sin policy en transport).

## LAW-EXEC-004 — Import-pure descriptors
Importing a capability descriptor MUST NOT produce side effects (SE-386 §8).
- Verificación: contract-check (import-pure).
