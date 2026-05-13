---
name: /cache-analytics
description: "Reporta hit rate del cache de prompts y desglose por agente/modelo/proyecto desde ~/.savia/usage.db. Lee de la base agregada poblada por scripts/cache-scanner.py (lee a su vez ~/.local/share/opencode/opencode.db, read-only). Permite filtros temporales (--since 7d), por proyecto, agente o modelo, y export CSV. SPEC-CACHE-HIT-TRACKING."
developer_type: all
agent: task
context_cost: low
---

# /cache-analytics — Cache hit rate y desglose de uso

Reporta el hit rate del cache de prompts (Anthropic prompt caching) y el desglose de uso por agente, modelo y proyecto. Fuente única: `~/.savia/usage.db` (espejo agregado de `opencode.db`, poblado incrementalmente por `scripts/cache-scanner.py`).

**hit rate** = `cache_read / (cache_read + cache_write)` — ratio canónico de SPEC-CACHE-HIT-TRACKING v2.

## Sintaxis

```bash
/cache-analytics [--since 7d|24h|30m|all] [--project SUBSTR] [--agent NAME] [--model NAME] [--export csv]
```

## Parámetros

- `--since` — Ventana temporal. Formatos: `Nd` (días), `Nh` (horas), `Nm` (minutos), `all`. Default: `7d`.
- `--project` — Filtro por substring del `directory` de la sesión (ej: `savia`, `trazabios`).
- `--agent` — Filtro exacto por nombre de agente (ej: `architect`, `general`).
- `--model` — Filtro exacto por `modelID` (ej: `claude-sonnet-4-6`).
- `--export csv` — Exporta turnos filtrados a CSV.

## Salida

- **Totales globales** del filtro aplicado: turnos, hit rate, tokens, coste.
- **Top 5 agents** por número de turnos con hit rate individual.
- **Top 3 models** por turnos con hit rate y coste medio.

## Prerequisitos

1. **`~/.savia/usage.db` debe existir.** Crearlo con:
   ```bash
   python3 scripts/cache-scanner.py
   ```
   Re-ejecutar cuando se quiera actualizar (scanner es incremental, ~50ms).

2. **`~/.local/share/opencode/opencode.db` debe estar presente** para que el scanner tenga fuente.

## Ejecución

```bash
# Default: últimos 7 días, totales + breakdown
python3 scripts/cache-analytics.py

# Última hora
python3 scripts/cache-analytics.py --since 1h

# Solo agente architect
python3 scripts/cache-analytics.py --agent architect

# Todo el histórico, filtrado por proyecto Trazabios
python3 scripts/cache-analytics.py --since all --project trazabios

# Export CSV
python3 scripts/cache-analytics.py --since 30d --export csv > cache-30d.csv
```

## Interpretación

- **Hit rate < 60%** — Cache mal aprovechado. Revisar invalidaciones (cambios en CLAUDE.md, agentes, skills cargados antes de prompts grandes).
- **Hit rate 60-80%** — Aceptable. Margen de mejora con orden de loading.
- **Hit rate > 80%** — Saludable. Cache estable.

Hit rate baseline objetivo: **≥80%** sostenido a 14 días tras SPEC-D02 (CLAUDE.md split static/dynamic).

## Errores comunes

| Error | Causa | Fix |
|---|---|---|
| `usage.db not found` | Scanner nunca ejecutado | `python3 scripts/cache-scanner.py` |
| `no turns in window` | Filtro demasiado estrecho | Ampliar `--since` o relajar filtros |
| Hit rate 0% | Cache no activo o modelo sin soporte | Verificar `prompt_caching` en provider settings |

## Referencias

- Implementación: `scripts/cache-analytics.py`
- Scanner: `scripts/cache-scanner.py`
- Spec: `docs/specs/SPEC-CACHE-HIT-TRACKING.spec.md`
- Tests: `tests/test-cache-scanner.bats`
- Schema: tabla `turns` (`message_id`, `session_id`, `agent`, `model`, `cache_read`, `cache_write`, `cost`, `ts`)
