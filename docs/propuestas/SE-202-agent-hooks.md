---
spec_id: SE-202
title: Agent-based hooks semanticos
status: APPROVED
tier: 1
priority: P2
effort: M
era: 200
wave: 1
deps:
  - SE-201
unblocks:
  - SE-203
origin: output/research/openhands-savia-20260607.md
inspiration: OpenHands agent-as-tool pattern — LLM agents as hook decision-makers
---

# SE-202 — Agent-based hooks semanticos

> Estado: APPROVED · Tier 1 · P2 · Estimacion M · Era 200 · Wave 1

## Resumen

Script `agent-hook-runner.sh` que permite definir hooks en `settings.json` cuyo executor es un agente LLM en lugar de un script bash. El agente recibe el evento (nombre de tool + input) y devuelve una decision `allow` o `deny` con razon. Compatible con el sistema de hooks existente: exit 0 = allow, exit 2 = deny.

## Motivacion

- Los hooks bash actuales solo pueden hacer deteccion lexica (regex, patrones fijos). No pueden razonar sobre la semantica de un tool call.
- OpenHands usa agentes LLM como evaluadores en su pipeline de ejecucion de acciones — el mismo patron aplicado a hooks.
- `security-guardian` y `commit-guardian` ya existen como agentes con logica de evaluacion; reutilizarlos como hooks evita duplicacion.
- El protocolo de exit codes es compatible hacia atras: los hooks bash existentes siguen funcionando sin cambios.

## Scope

1. `scripts/agent-hook-runner.sh` — ejecuta un agente LLM como hook. Recibe `--agent <nombre>` y `--event <JSON>`, invoca el agente con el contexto del evento, y traduce la respuesta a exit code.
2. Formato de definicion en `settings.json`: `{type: agent, name: security-guardian, event: PreToolUse}` — nueva propiedad `type` con valor `agent`.
3. El agente evalua el evento y devuelve JSON `{decision: allow|deny, reason: ...}` — el runner lo parsea y sale con exit 0 o exit 2.
4. Timeout configurable: `SAVIA_AGENT_HOOK_TIMEOUT=30` segundos (default). Si el agente no responde en tiempo, fallback configurable.
5. `docs/rules/domain/agent-hook-protocol.md` — protocolo de integracion: contrato de entrada/salida, exit codes, convencion de naming, fail-open vs fail-closed.

## Acceptance Criteria

- AC1: `agent-hook-runner.sh --agent security-guardian --event '{tool:Bash,input:comando-destructivo}`' devuelve JSON con `decision` y `reason`.
- AC2: Exit 0 cuando `decision == allow`, exit 2 cuando `decision == deny` — compatible con sistema de hooks Claude Code/OpenCode.
- AC3: Hook de tipo `agent` puede coexistir con hooks bash en `settings.json` sin conflicto ni modificaciones al runtime existente.
- AC4: `SAVIA_AGENT_HOOK_TIMEOUT=30` configurable; si el agente supera el timeout, el comportamiento de fallback se aplica segun config.
- AC5: Comportamiento de fallback ante fallo del agente configurable: `SAVIA_AGENT_HOOK_FAILOPEN=true` (default) → allow; `false` → deny.
- AC6: Cada decision registrada en `output/agent-hook-decisions.jsonl` con campos: `timestamp`, `agent`, `tool`, `decision`, `reason`, `duration_ms`.

## Slices

1. **Slice 1 (2h)** — `agent-hook-runner.sh` core: invocacion de agente + parseo de respuesta JSON + exit codes + BATS basicos.
2. **Slice 2 (2h)** — Soporte de `type: agent` en `settings.json` + coexistencia con hooks bash + timeout y failopen/failclosed.
3. **Slice 3 (1h)** — Registro en `output/agent-hook-decisions.jsonl` + `agent-hook-protocol.md`.
4. **Slice 4 (1h)** — BATS E2E: hook `security-guardian` en PreToolUse bloquea llamadas destructivas y permite operaciones seguras.

## Out of scope

- Hooks de tipo agente en modo asincrono (los hooks son sincronos por diseno).
- Encadenamiento de multiples agentes por evento (un evento → un agente).
- Cache de decisiones para el mismo tool input (cada invocacion es independiente).
- Soporte para agentes externos fuera del catalogo `.opencode/agents/`.

## Riesgo principal

La latencia de invocar un agente LLM en cada tool call (PreToolUse) puede hacer la experiencia inaceptablemente lenta para herramientas frecuentes como Bash o Edit. Mitigacion: limitar los hooks tipo agent a eventos de alto impacto (PreCommit, PrePush, destructive tools) y documentar la restriccion en el protocolo.
