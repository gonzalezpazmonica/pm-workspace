## [6.18.0] — 2026-04-26

Batch 67 — SE-079 spec APPROVED — pr-plan G13 scope-trace gate.

### Added
- `docs/propuestas/SE-079-pr-plan-scope-trace-gate.md` — APPROVED, priority media, effort S 3h, Era 189. Slice único: nueva G-gate `g13_scope_trace` en `scripts/pr-plan-gates.sh` que verifica que cada archivo cambiado en un PR trace a (1) un AC del spec referenciado, (2) una whitelist hard-coded (`CHANGELOG.d/`, `.scm/`, `.confidentiality-signature`), o (3) override explícito `Scope-trace: skip — <razón ≥10 chars>` en `.pr-summary.md`. Heurística pure-bash sin LLM (target <1s overhead). Soft-skip cuando no hay spec ref detectable (PRs legítimos sin spec).
- ROADMAP entry bajo Era 189.

### Why this matters
Karpathy "Surgical Changes" pasa de principio implícito (en `radical-honesty.md`) a gate enforced pre-push. Anti scope-creep en un mundo de paralelismo (SE-074), donde el revisor humano ya no puede ser el único firewall. Origen: review del repo `forrestchang/andrej-karpathy-skills` por sub-agente 2026-04-26.

### Spec ref
SE-079 — APPROVED, sin implementación todavía. La rama de implementación (`agent/se079-...`) saldrá de aquí.
