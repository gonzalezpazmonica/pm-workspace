# SE-258 — Cierre de brechas identitarias: proteccion de activos propios, drill de restauracion y auto-auditoria

**Status:** PROPOSED
**Fecha:** 2026-07-08
**Area:** Security architecture / Resilience / Self-audit / Process integrity
**Branch:** agent/se258-brechas-identitarias
**Estimacion total:** ~21h (5 slices independientes)
**Relacion con programas previos:** SE-253/255/256/257 mergeados (#895-#898).

---

## Origen

Auditoria externa 2026-07-08 sobre HEAD d473cbc5 (#898). Hallazgos:

1. **CRITICO — El libro de la relacion esta trackeado en un repo PUBLICO.**
   `data/relacion/ledger.jsonl` esta en git. El .gitignore tiene `/data/*` pero el fichero quedo trackeado igualmente. Hoy contiene solo SEED-001 (inocuo). Agravante: el hash encadenado del ledger hace que limpiar despues rompa la cadena.

2. **Backups jamas restaurados.** Existen savia-backup.sh, backup.sh, test-backup.sh pero cero evidencia de drill de restauracion. CONSTITUCION.md, CRITERIO.md y el ledger son activos identitarios irreemplazables.

3. **Tercer incidente de drift de estado de specs.** SE-257 no esta en specs-archive/, Slice 5 no entregado (cero campos tier en SKILL.md de maturity). Patron acumulado: 3 incidentes en 3 semanas.

4. **Menores verificados:** install.sh sin smoke en CI, sin audit de dependencias, MODEL_TIER_MAP sin hot-reload.

---

## Slices

### Slice 1 — Proteccion de activos identitarios (4h)

- Destracking: `git rm --cached data/relacion/ledger.jsonl` + regla en .gitignore (`/data/relacion/`)
- Guard `block-sensitive-tracking`: hook pre-commit que bloquea `git add` de rutas con nivel N3+
- `config/sensitive-paths.yaml`: lista declarativa de rutas por nivel
- Script `scripts/tracked-vs-nivel.sh`: cruza `git ls-files` contra paths declarados

### Slice 2 — Drill de restauracion (4h)

- Runbook `docs/restore-drill.md`: procedimiento paso a paso
- Script `scripts/verify-ledger-chain.sh`: verificacion criptografica de hashes
- `docs/restore-drill-log.md`: registro de drills
- Primer drill ejecutado como parte del slice

### Slice 3 — /self-audit (6h)

- Comando `.opencode/commands/self-audit.md` + script `scripts/self-audit.sh`
- `config/self-audit-battery.yaml`: bateria declarativa de checks
- Muestreo de regresion: re-verifica 3 specs aleatorios de specs-archive/
- Integracion con ledger: hallazgo confirmado genera entrada error_reconocido

### Slice 4 — Cierre honesto SE-257 + gate de archivo (3h+)

- SE-257 archivado en specs-archive/2026/ con status por slice
- Gate BLOCK en pr-guardian: PR feat(seXXX) sin CHANGELOG.d con spec → bloqueado
- CHANGELOG.d retro-completado para se257

### Slice 5 — Menores verificados (4h)

- Smoke de instalacion: job CI semanal que ejecuta install.sh en contenedor limpio
- Audit de dependencias: jobs npm audit + pip-audit
- MODEL_TIER_MAP hot-reload en el plugin de resolucion

---

## Verification method

1. Clon anonimo fresco post-S1: sin ledger en HEAD ni historia
2. Drill #1 con RTO medido y cadena de hashes verificada
3. /self-audit baseline ejecutado con muestreo de regresion demostrado
4. SE-257 archivado con status por slice; gate BLOCK demostrado
5. Menores: smoke verde, audits con informe, hot-reload testeado

## Riesgos

- R1 (S1): force-push rompe clones ajenos → 3 ramas remotas, ventana coordinada
- R2 (S1): guard bloquea flujo legitimo → allowlist para tests/fixtures/**
- R3 (S2): drill destapa que backup no cubre activos identitarios → esperado, se corrige
- R4 (S3): fatiga de hallazgos → severidades con cap, decision explicita por hallazgo
- R5 (S4): gate BLOCK atasca PRs legitimos → label override spec-gate-override
- R6 (S3): muestreo sobre ACs manuales → solo auto, reporta ratio de cobertura

## Orden recomendado

1 → 2 → 4 → 3 → 5
