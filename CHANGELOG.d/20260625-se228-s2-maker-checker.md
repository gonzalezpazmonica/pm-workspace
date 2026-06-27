---
type: feat
spec: SE-228
slice: S2
date: 2026-06-25
---

# SE-228 S2 — Maker/Checker split protocol

Implementa el patron maker/checker split de Loop Engineering (SE-228 Slice 2).

## Cambios

- docs/rules/domain/maker-checker-protocol.md — Regla formal con 5 invariantes.
  El agente implementador NO puede marcar su propio trabajo como done. Verifier
  stance: default REJECT. Obligatorio en L2+.

- scripts/loop-verify.sh — Genera prompt adversarial estructurado para el
  verificador. NO ejecuta Claude automaticamente. Soporta
  --worktree, --skill, --spec, --dry-run.

- docs/rules/domain/autonomous-safety.md — Seccion nueva al final:
  Maker/Checker Split SE-228 S2 con referencias canonicas.

- tests/test-se228-s2-maker-checker.bats — Tests BATS, certificados.

## ACs cubiertos

- AC-06: Regla maker-checker-protocol.md con invariantes
- AC-07: loop-verify.sh genera prompt adversarial
- AC-09: Verifier prompt incluye default REJECT
- AC-10: Tests BATS >= 8, score >= 80
