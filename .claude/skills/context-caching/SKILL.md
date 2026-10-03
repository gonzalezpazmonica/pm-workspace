---
layer: peripheral
name: context-caching
description: Usar cuando se optimiza el orden de carga de contexto para maximizar cache hits.
metadata:
  # --- metadata.savia.* (SE-333) ---
  savia.category: quality
  savia.maturity: beta
  savia.priority: medium
  savia.summary: "Optimiza orden de carga de contexto para prompt caching. 4 niveles: foundation -> project -> task -> dynamic. Mide el efecto con scripts/cache-metrics.sh (ledger local)."
  savia.tags: "caching, performance, tokens, cost-optimization"
  savia.version: 1.0.0
---

# Context Caching Skill

Optimiza el orden de carga de contexto para maximizar cache hits. La skill es
criterio (orden de carga); lo ejecutable es la medición y la higiene del prefijo.

## Paths autoritativos

| Qué | Path |
|---|---|
| Regla de orden en 4 niveles | `docs/rules/domain/prompt-caching.md` |
| Medir hit ratio y ahorro (ledger local) | `scripts/cache-metrics.sh` |
| Estabilidad del prefijo entre turnos | `scripts/cache-hygiene.sh` + `config/cache-prefix.txt` |
| Spec de origen | `docs/specs/SE-371-cache-hygiene.spec.md` |
| Tests | `tests/test-context-caching.bats`, `tests/bats/test-cache-hygiene.bats` |

`/cache-optimize`, `/cache-strategy`, `/cache-warm`, `/cache-invalidate` y
`/cache-analytics` son comandos en prosa: no tienen script detrás ni reordenan
nada por sí solos. La única medición real es `cache-metrics.sh`.

## Orden de carga (Levels 1→4, de más a menos estable)

1. Globales de pm-workspace (CLAUDE.md, reglas) → breakpoint
2. Contexto del proyecto (CLAUDE.md, reglas de negocio, equipo) → breakpoint
3. Skill y plantillas de la tarea → breakpoint
4. Petición del usuario e historial (nunca se cachea)

El cache del provider es prefijo-exacto: un byte distinto invalida desde ese
punto. No metas en Levels 1-3 nada que cambie por turno (MEMORY.md, ficheros
auto-regenerados). No cambies de modelo a mitad de conversación (SE-371 §4).

## Patrones

- **PBI decomposition**: Levels 1-2 fijos; varía solo el PBI (Level 3-4).
- **Spec generation**: Levels 1-3 fijos (globales, proyecto, skill SDD); cada spec nueva reutiliza el prefijo.
- **Dev session**: Levels 1-3 fijos; cada slice sustituye solo spec-slice y ficheros objetivo.

Los ahorros por patrón (30-90 %) no están medidos en este workspace: son
estimaciones. Para saber el real, mide.

## Medir (antes vs después)

```bash
# Registrar usage de cada respuesta (formato Anthropic) o a mano
bash scripts/cache-metrics.sh record --model M --usage-json '{"input_tokens":120,"cache_read_input_tokens":4800,"cache_creation_input_tokens":0}'
bash scripts/cache-metrics.sh record --model M --input 120 --cache-read 4800 --cache-creation 0 --session S
# OpenCode: ingesta desde la DB local (lo hace el hook al cerrar sesión)
bash scripts/cache-metrics.sh ingest-opencode [--days 7]
# Informe
bash scripts/cache-metrics.sh report [--session S] [--model M]
bash scripts/cache-metrics.sh --validate
```

- Ledger: `data/cache-metrics.jsonl`, o `SAVIA_CACHE_METRICS_DIR` (fichero o directorio). Local, sin red (CRIT-001).
- Recuentos: enteros ≥ 0. `1.000` o `1,5` (formato es_ES) se rechazan con exit 2; no se guardan mal.
- `--usage-json` inválido, que no sea objeto o con recuentos no enteros → exit 2, sin fila. Se trata como dato, nunca como código.
- `cache_hit_ratio` = `cache_read / (input + cache_read)` (fórmula de SE-371). Excluye `cache_creation` del denominador: con escrituras de cache grandes, el ratio sale más alto que la fracción real de prompt servida desde cache.
- `est_saving_pct`: coste relativo con lecturas ×0.1 y escrituras ×1.25 frente a input ×1.0.
- `skipped_lines`: filas corruptas del ledger que el informe ignora (no aborta).
- Exit codes: 0 OK · 1 `--validate` con líneas malas o DB de OpenCode sin esquema de sesiones · 2 uso inválido.

## Anti-pattern: thrashing

Señales medibles:
- `report` con `cache_creation` alto y `cache_read` bajo en la misma sesión: el prefijo se reescribe en vez de reutilizarse.
- `cache-hygiene.sh check` informa `MUTATED`: un fichero del prefijo cambió entre turnos.

Solución: cargar en orden de estabilidad (Levels 1→4) y sacar del prefijo lo mutable.
