---
spec_id: SE-097
title: Regenerate docs/rules/INDEX.md from filesystem (manifest desync)
status: APPROVED
approved_by: operator (2026-05-27)
priority: P1
effort: M
estimated_time: 90 min
depends_on: SE-057 Slice 2, SE-096
source: output/20260527-auditoria-obsoleto-legado.md (Tier 2.5)
---

# SE-097 — Rules INDEX & manifest regeneration

## Problema

`rule-manifest-integrity.sh` reporta FAIL severo:
- INDEX.md = 165 líneas (>150, autoincumple Rule #22)
- 25 entries del manifest apuntan a ficheros inexistentes
- 202 ficheros de reglas no listados en manifest

El manifest está obsoleto en masa. Sin trazabilidad real.

## Solución

### Slice 1: Auto-regenerador (~45 min)
Script `scripts/rule-manifest-regenerate.sh`:
- Escanea `docs/rules/` filesystem
- Lee frontmatter de cada regla (categoría, tier, consumers)
- Emite manifest + INDEX.md con sub-índices por categoría (compliance, hooks, memory, etc.)
- Cada sub-índice ≤150 líneas

### Slice 2: Ejecutar + validar (~30 min)
- Correr el regenerador
- Verificar `rule-manifest-integrity.sh` PASS
- Smoke test que ningún @import sigue roto

### Slice 3: CI gate (~15 min)
- Hook pre-commit: si tocas `docs/rules/**.md`, regenera y comprueba

## Aceptación

- INDEX.md ≤150 líneas
- 0 entries → ficheros inexistentes
- 0 ficheros no listados
- `rule-manifest-integrity.sh` PASS
