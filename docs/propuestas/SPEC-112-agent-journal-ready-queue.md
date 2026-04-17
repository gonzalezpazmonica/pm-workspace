---
id: SPEC-112
title: Agent-runs JSONL journal + ready-queue filter
status: ACCEPTED
origin: Research henriquebastos/beans (2026-04-17)
author: Savia
---

# SPEC-112 — Agent Journal + Ready Queue

## Why

`henriquebastos/beans` usa dos patrones coordinación-para-agentes que pm-workspace puede adoptar sin incompatibilidad:

1. **Append-only JSONL journal** — cada acción autónoma emite una línea JSON a `journal.jsonl`. Git-friendly (diff limpio), auditoría barata, compatible con Rule #24 (Radical Honesty: hechos inmutables).
2. **Ready-queue query** — PBIs listos para trabajar = sin bloqueos abiertos. Pm-workspace tiene `dependency-map` pero no un filtro `--ready` directo.

## Scope

### Item 1 — JSONL journal en overnight-sprint

Estandarizar formato de audit log de agent-runs:
- Ruta: `output/agent-runs/{date}/journal.jsonl`
- Formato: `{"ts":"ISO8601","actor":"agent/overnight-20260417","action":"task_claimed|pr_created|task_skipped|crash","target":"AB#123","result":"...","meta":{}}`
- Append-only: cada evento = 1 línea, nunca modificar líneas existentes.
- Rotación: diaria (un fichero por día).

### Item 2 — `--ready` filter en flow-sprint-board

`flow-sprint-board --ready {sprint_id}` muestra solo PBIs:
- En el sprint activo
- Sin `blockedBy` abierto
- En columna `todo` o `in-progress`

Permite pregunta rápida: "¿qué puedo empezar ahora?"

## Implementation

### 1. `scripts/agent-journal.sh` (nuevo)

Helper reutilizable:
```bash
bash scripts/agent-journal.sh append \
  --actor "agent/overnight-20260417" \
  --action "pr_created" \
  --target "AB#456" \
  --result "PR#587 draft"
```

Escribe a `output/agent-runs/$(date +%Y%m%d)/journal.jsonl`. Crea directorio si no existe.

### 2. `flow-sprint-board.md` extensión

Añadir flag `--ready` que invoca `savia-flow-sprint.sh board --ready <sprint_id>`. El script filtra por `blockedBy=[]`.

## Acceptance criteria

1. `scripts/agent-journal.sh append` añade línea JSON válida al fichero del día.
2. El fichero es parseable línea-a-línea con `jq`.
3. `/flow-sprint-board --ready <sprint>` retorna solo PBIs sin bloqueos.
4. Ambos integrados con `output/` gitignored (audit local, no público).

## Rejected from Beans

- Filosofía "no hooks" — incompatible con `feedback_friction_is_teacher.md`.
- SQLite como SoT — pm-workspace delega a Azure DevOps/Jira.
- Python 3.14 + Typer stack — no aplica.

## Risks

- **BAJO**: journal append es atómico si el FS soporta `O_APPEND` (Linux/macOS sí).
- **BAJO**: `--ready` flag es additivo, no rompe el comportamiento default.
