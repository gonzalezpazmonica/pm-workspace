# SE-071 hook fix + spec triage + roadmap update

**Date:** 2026-04-24
**Version:** 5.93.0

## Summary

1. **SE-071** resolved: safety hook `block-branch-switch-dirty.sh` fixed (invalid tier bug).
2. **Spec triage**: 74 PROPOSED specs categorizados por prioridad, 5 promovidos a APPROVED.
3. **Roadmap** actualizado con milestones hook coverage + triage results.

## Cambios

### A. SE-071 safety hook fix (approved by Monica)

`.claude/hooks/block-branch-switch-dirty.sh` linea 9:

```diff
- source "$LIB_DIR/profile-gate.sh" && profile_gate "minimal"
+ source "$LIB_DIR/profile-gate.sh" && profile_gate "security"
```

**Bug**: "minimal" NO es tier valido (tiers: security/standard/strict). Bajo profile default (`standard`), la funcion salia silent → checkout con arbol sucio NO bloqueaba, contra la intencion declarada "Tier: security (always active)".

**Impact**: proteccion contra perdida de datos al cambiar de rama estuvo rota.

**Audit**: ejecutado `grep -rn 'profile_gate' .claude/hooks/` sobre los 58 hooks. Resultado:
- 27 hooks tier `standard` (valid)
- 8 hooks tier `security` (valid, incluyendo el fix)
- 3 hooks tier `strict` (valid)
- 0 hooks con tier invalido

Bug unico — solo block-branch-switch-dirty.sh estaba afectado.

**Test update**: `tests/test-block-branch-switch-dirty.bats`:
- Removido `SAVIA_HOOK_PROFILE=strict` bypass de los 10 block-path tests (ya no necesario)
- Actualizado test `security tier correctly declared`
- Anadido test regression `SE-071 regression: no invalid tier 'minimal' remains`
- 36/36 tests PASS

**Verificacion manual**: dirty checkout ahora bloquea con exit 2 y mensaje "BLOQUEADO: Cambio de rama con cambios sin commitear" bajo profile default.

### B. Spec triage (2026-04-24)

74 specs PROPOSED categorizados:

| Accion | Cantidad | Ejemplos |
|---|---:|---|
| Promovidos a APPROVED | **5** | SE-038, SE-039, SE-065, SE-070, SPEC-120 |
| Priority alta | 9 | SE-030, SE-040, SPEC-122, SPEC-124, SPEC-121... |
| Priority media | 33 | SPEC-027, SPEC-032-037, SPEC-042-052... |
| Priority baja | 21 | SPEC-004-009 (robotics/zeroclaw), SPEC-100 (GAIA), SPEC-060/062 (SaviaDivergent), PDF chain... |
| Skipped (meta/ADR/TEMPLATE) | 6 | adr-connectors-vs-mcp, investigacion-*, propuesta-*, TEMPLATE |

Priority normalization: `Baja` a `baja`, `Alta` a `alta`, `Media` a `media` aplicado globalmente.

### C. Nuevos APPROVED (queue ready for sprint)

Total APPROVED despues de triage: **9 specs** (5 nuevos + 4 pre-existentes del training pipeline).

| Spec | Titulo | Rationale |
|---|---|---|
| SE-038 | Agent catalog size audit | Rule #22 compliance mecanico |
| SE-039 | Test-auditor global sweep ≥80 | Aligned con batch 48 hook coverage |
| SE-065 | responsibility-judge S-06 i18n | ES false positives ya debugged |
| SE-070 | Opus 4.7 calibration scorecard | Era 186 focus |
| SPEC-120 | Spec template alignment github/spec-kit | Small cleanup |

(Pre-existentes: SE-028 oumi, SE-042 voice training, SPEC-023 LLM Trainer, SPEC-080 Unsloth — bloqueados por GPU hardware)

### D. ROADMAP.md actualizado

- Nueva seccion "Era 186 extension — Hook coverage ratchet + triage"
- Tabla milestones hook coverage (18/58 a 48/58)
- Lista bugs descubiertos via tests (incluido SE-071)
- Tabla resultados triage
- Tabla nuevos APPROVED con rationale

## Validacion

- `bats tests/test-block-branch-switch-dirty.bats`: 36/36 PASS
- `grep -rn 'profile_gate "\(minimal\|ci\)"' .claude/hooks/`: 0 matches (audit clean)
- Verificacion manual: `dirty checkout a exit 2` confirmado

## Progreso Era 186

Al cierre de este PR:
- Hook coverage: 82.7% (48/58)
- SE-071 resolved, safety hook working correctly
- Backlog APPROVED: 9 specs ready
- Priority asignada a 63 PROPOSED specs (era 74 sin prioridad)

## Referencias

- SE-071: `docs/propuestas/SE-071-profile-gate-invalid-tier-audit.md`
- Audit script: `grep -rn 'profile_gate "[^"]*"' .claude/hooks/`
- Spec triage one-shot script: eliminado post-uso (no se deja en repo)
