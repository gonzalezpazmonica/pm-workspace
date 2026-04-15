---
spec_id: SPEC-101
title: SAVIA-GENESIS — Recovery document + launcher script
status: Implemented
origin: User request (2026-04-15) — dual-purpose recovery + best-practices doc
severity: Alta
effort: ~4h
---

# SPEC-101: SAVIA-GENESIS Recovery

## Problema

Si un cambio rompe a Savia (hook mal configurado, regla diluida, gate
bypassed), no existe un documento único que permita a una instancia limpia
de Claude diagnosticar y proponer fix. El conocimiento está repartido en
78+ rules, 56 agents, 87 skills. Sin una vista consolidada, la recuperación
requiere ingeniería manual prolongada.

Paralelamente, no hay documento accesible a humanos que enseñe los
principios de ingeniería de contexto y programación agéntica que hacen
funcionar pm-workspace. Los principios existen pero dispersos.

## Solucion

Un documento dual-purpose (`docs/SAVIA-GENESIS.md`) + un script launcher
(`scripts/recover-savia.sh`) que:

1. **Para un Claude limpio (reparación):**
   - Lee el genesis completo (11 partes + 2 apéndices)
   - Ejecuta el recovery playbook (Parte 8) contra el repo concreto
   - Propone fix mínimo como reporte (NO modifica el repo)
2. **Para humanos (aprendizaje):**
   - 7 principios inmutables
   - Arquitectura de 5 capas
   - Niveles N1-N4b de confidencialidad
   - 10 best practices de ingeniería de contexto
   - 10 best practices de programación agéntica

El script `recover-savia.sh` crea un sandbox fuera del repo, copia el
genesis, y lanza `claude` con permisos READ-ONLY sobre el repo roto.
El Claude limpio NUNCA aplica cambios automáticamente.

## Arquitectura

```
scripts/recover-savia.sh [repo-path]
    ↓ (valida pm-workspace + genesis existen)
    ↓ (detecta binario claude)
mkdir /tmp/savia-recovery-{ts}/
cp SAVIA-GENESIS.md sandbox/
write RECOVERY-PROMPT.md sandbox/
    ↓
exec claude --append-system-prompt "..." (en sandbox, READ-ONLY repo)
    ↓
Claude limpio produce reporte en sandbox/savia-recovery-report-{ts}.md
    ↓
Humano revisa y aplica via /pr-plan manualmente
```

## Acceptance criteria

- [x] `docs/SAVIA-GENESIS.md` creado con 11 partes + 2 apéndices
- [x] Los 7 principios inmutables explícitos
- [x] Recovery playbook paso a paso en Parte 8
- [x] 10 best practices context engineering en Parte 9
- [x] 10 best practices agentic programming en Parte 10
- [x] Referencias canónicas en Parte 11 (orden de lectura)
- [x] `scripts/recover-savia.sh` con 4 exit codes distintos
- [x] Sandbox siempre fuera del repo (TMPDIR)
- [x] Permisos READ-ONLY sobre el repo original
- [x] NO aplica cambios automáticamente
- [x] BATS tests (test-recover-savia.bats, ≥80 score)

## Restricciones

- **GENESIS-01**: SAVIA-GENESIS.md NUNCA contiene datos de proyecto o cliente
- **GENESIS-02**: El script NUNCA ejecuta git commit/push/reset sobre el repo
- **GENESIS-03**: El sandbox SIEMPRE en TMPDIR, nunca dentro del repo
- **GENESIS-04**: El recovery Claude recibe mandato explícito de NO modificar
- **GENESIS-05**: Cualquier fix propuesto requiere /pr-plan humano para aplicar

## Out of scope

- Aplicación automática de fixes (viola principio #5 — humano decide)
- Reparación de datos corruptos (solo config/reglas/hooks)
- Tests end-to-end del launcher (requieren binario claude real)

## Referencias

- docs/SAVIA-GENESIS.md (el documento en sí)
- scripts/recover-savia.sh (el launcher)
- tests/test-recover-savia.bats (25 tests)
- .claude/rules/domain/savia-foundational-principles.md (los 7 principios)
- .claude/rules/domain/critical-rules-extended.md (reglas 9-25)
