---
id: SE-072
title: SE-072 — Verified Memory axiom (No Execution, No Memory)
status: APPROVED
origin: GenericAgent repo study 2026-04-25 — lsdefine/GenericAgent
author: Savia
priority: alta
effort: S 3h
related: memory-auto-capture.sh, memory-store.sh, feedback_root_cause_always
approved_at: "2026-04-25"
applied_at: null
expires: "2026-06-25"
era: 186
---

# SE-072 — Verified Memory axiom

## Why

GenericAgent (6.8k ⭐, Apr 2026) establece el axioma **"No Execution, No Memory"**: solo se persiste información verificada por la salida de una tool real. Prohibe memorizar intenciones, suposiciones o plans no ejecutados.

Savia hoy permite writes a `memory-store.sh save` y a `auto/MEMORY.md` sin gate de procedencia. Una reflexión o draft que luego resulta falsa puede quedar como "hecho" en memoria y sesgar futuras decisiones.

Cost of inaction: memoria ruidosa con claims no verificadas degrada la señal/ruido. Los agentes futuros tratarán opinions como facts. Violación silenciosa de `feedback_root_cause_always`.

## Scope (Slice 1 only, S-effort)

Minimal surgical hook que valida `memory-store.sh save` y `Write` sobre `~/.claude/external-memory/auto/`:

1. **Pattern detection**: el contenido de un save debe ir acompañado de `--source` CLI flag con uno de:
   - `tool:<tool_name>` (e.g. `tool:Bash`, `tool:Read`)
   - `file:<path>:<line>` (file reference con citation)
   - `verified:<sha>` (hash de commit que demuestra persistence)
   - `user:explicit` (user told agent to remember X)

2. **Rejection**: memory save SIN `--source` o con `--source speculation|plan|intent` → BLOCK con mensaje didáctico.

3. **Grandfathering**: entries existentes no se tocan. Solo gate NUEVAS.

## Acceptance criteria

- [ ] AC-01 `scripts/memory-store.sh save` rechaza sin `--source <origin>`
- [ ] AC-02 Valid sources enumerados: tool/file/verified/user
- [ ] AC-03 Hook PreToolUse `memory-verified-gate.sh` bloquea Write a auto/MEMORY.md sin citation pattern
- [ ] AC-04 Tests BATS (≥15) score ≥80
- [ ] AC-05 Doc en `docs/rules/domain/verified-memory-axiom.md` con rationale + examples

## No hacen

- NO migra memoria existente (grandfathering)
- NO bloquea memoria manual del usuario (user puede forzar con `--source user:explicit`)
- NO afecta session-hot.md (ephemeral, OK sin verification)

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Fricción: devs olvidan `--source` | Alta | Bajo | Mensaje de error con ejemplo copy-paste |
| Bypass via directo Write: agente puede escribir directo a MEMORY.md sin usar save | Media | Medio | Hook PreToolUse sobre Write cubre este caso |
| Rompe tests existentes | Baja | Alto | Tests locales primero, ratchet si necesario |

## Referencias

- GenericAgent `autonomous_operation_sop.md` — axioma original
- `feedback_root_cause_always` — memory rule aligned
- `scripts/memory-store.sh` — target de la modificación
- `.claude/hooks/memory-auto-capture.sh` — hook ya existente, complementar
