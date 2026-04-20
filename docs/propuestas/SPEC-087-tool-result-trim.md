---
spec_id: SPEC-087
title: Tool Result Trimming — hard cap determinista por resultado
status: IMPLEMENTED
origin: Claudepedia pattern analysis (2026-04-08)
severity: Media
effort: ~2h
---

# SPEC-087: Tool Result Trimming

## Problema

Los resultados de herramientas (Bash, Read, Grep) son la causa mas comun
de inflacion de contexto. Un solo `git log` o `grep` puede devolver cientos
de lineas que consumen tokens equivalentes a 20 turnos de conversacion.

Tenemos `output-compress.sh` como hook async PostToolUse, pero:
- Es async (el resultado ya esta en contexto cuando comprime)
- Comprime con 7 filtros heuristicos, no con hard cap
- No hay limite deterministico por resultado individual

Claudepedia documenta un patron simple: trim a 5K chars ANTES de inyectar
el resultado en el contexto. Es la primera linea de defensa, zero-cost.

## Solucion

1. Configurar `BASH_MAX_TOOL_RESULT_CHARS=5000` como constante en pm-config
2. Hook PreToolUse o PostToolUse (sync, rapido) que trunca resultados > 5K chars
   con mensaje `[...truncado a 5K chars. Usa Read con offset para ver mas]`
3. Excepciones configurables por herramienta:
   - Read: no truncar (el usuario pidio leer)
   - Bash: truncar por defecto
   - Grep: truncar si output_mode=content, no si files_with_matches

Alternativa: si Claude Code ya soporta `BASH_MAX_OUTPUT_LENGTH` (actualmente
en 80K), bajar a un valor mas conservador para comandos no criticos.

## Criterios de aceptacion

- [ ] Hard cap de 5K chars implementado para resultados de Bash
- [ ] Mensaje de truncamiento informativo (no silencioso)
- [ ] Excepciones para Read y Grep files_with_matches
- [ ] Constante configurable en pm-config.md
- [ ] Tests BATS con >= 5 casos (truncamiento, excepciones, mensaje)
- [ ] Medicion antes/despues: tokens consumidos por sesion tipica
