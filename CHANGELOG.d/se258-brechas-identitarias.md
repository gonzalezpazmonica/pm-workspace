---
spec: SE-258
---

## SE-258 — Cierre de brechas identitarias (5 slices)

### Slice 1 — Proteccion de activos identitarios

Destracking del ledger (git rm --cached). Guard block-sensitive-tracking
que bloquea Write/Edit sobre rutas N3+ declaradas en config/sensitive-paths.yaml.
Script tracked-vs-nivel.sh para auditoria de leaks.

### Slice 2 — Drill de restauracion

Runbook docs/restore-drill.md con procedimiento paso a paso (RTO <=60 min).
Script verify-ledger-chain.sh (verificacion criptografica de cadena de hashes).
Script restore-drill.sh (ejecucion + registro en log).

### Slice 3 — Self-audit

Comando /self-audit + script orquestador + bateria declarativa en
config/self-audit-battery.yaml (8 checks: 3 critical, 2 high, 3 medium).
Muestreo de regresion sobre specs-archive/.

### Slice 4 — Cierre SE-257 + gate de archivo

SE-257 archivado en specs-archive/2026/ con status por slice (S1 PENDING,
S2 DONE, S3 PENDING, S4 DONE, S5 ABANDONED). CHANGELOG.d completado.
CHANGELOG-spec-field check endurecido. Gate 8b en pr-guardian (WARN para
PRs feat(seXXX) sin CHANGELOG.d fragment).

### Slice 5 — Menores verificados

Workflow install-smoke.yml (weekly clean-install test). Workflow
dependency-audit.yml (npm audit + pip-audit). MODEL_TIER_MAP hot-reload
en savia-foundation.ts (mtime check en cada resolucion).
