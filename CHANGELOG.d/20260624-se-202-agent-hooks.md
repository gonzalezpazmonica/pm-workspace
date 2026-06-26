# SE-202 — Agent-based hooks semanticos

Date: 2026-06-24
Spec: docs/propuestas/SE-202-agent-hooks.md
Status: APPROVED → IMPLEMENTED

## Ficheros

- `scripts/agent-hook-runner.sh` — ejecuta agente LLM como gate; exit 0=allow, exit 2=deny
- `docs/rules/domain/agent-hook-protocol.md` — protocolo de contratos, exit codes, fail-open/closed
- `.claude/settings.json` — _doc_se202_example documenta patrón de uso; type:agent compatible
- `tests/scripts/test_se202_agent_hook_runner.py` — 8 tests

## ACs cubiertos

- AC1: --dry-run muestra agente y evento sin invocar LLM
- AC2: exit 0 (allow), exit 2 (deny); compatible con sistema de hooks Claude Code/OpenCode
- AC3: hooks bash coexisten con hook de tipo agent sin conflicto
- AC4: SAVIA_AGENT_HOOK_TIMEOUT=30 configurable
- AC5: SAVIA_AGENT_HOOK_FAIL_OPEN=true (allow) / false (deny) cuando agente no responde
- AC6: decisiones registradas en output/agent-hook-decisions.jsonl con timestamp, agent, tool, decision, reason, duration_ms

## Notas

Default OFF por diseño: latencia de agente (~5-30s) inaceptable en hooks frecuentes.
Restringir a eventos de alto impacto (PreCommit, PrePush) per protocol.
