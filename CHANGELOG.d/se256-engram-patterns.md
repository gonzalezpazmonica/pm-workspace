---
spec: SE-256
---

## SE-256 — Patrones de engram aplicados a Savia

### Slice 1 — Save-nudge: captura automatica periodica

`scripts/save-nudge.sh`: hook PostToolUse que recuerda cada ~15 min registrar
eventos en el libro de la relacion. Debounce: solo emite si hubo overrides/
edit/revert no registrados desde el ultimo nudge. Exit 0 siempre.

### Slice 2 — Deteccion de conflictos en el ledger

`scripts/relacion-detect-conflicts.sh`: agrupa entradas del ledger por tipo,
detecta pares contradictorios (mismo ambito, decision opuesta), clasifica
como supersedes o conflicts_with. Soporta --json.

### Slice 3 — Verificacion de principal unico

`scripts/verify-principal.sh`: comprueba que la sesion actual corresponde al
principal declarado (ART-16). Sin dependencias cloud.

### Tests

10 BATS tests green.
