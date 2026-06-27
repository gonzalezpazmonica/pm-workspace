---
spec_id: SE-228
slice: S3
context_tier: L2
token_budget: 680
---

# Loop Run Log — Schema

> Historial append-only de ejecuciones de skills autónomas.
> Complementa `SE-217 results.tsv` (machine-readable) con un formato legible por humanos.

## Ubicación

```
output/loop-run-log/<skill-name>/run-log.md
```

Ejemplo: `output/loop-run-log/overnight-sprint/run-log.md`

## Formato de entrada

Una sección por run. Formato exacto:

```markdown
## YYYY-MM-DD HH:MM UTC — <skill> — <outcome>
- started: <ISO 8601 timestamp, e.g. 2026-06-25T01:00:00Z>
- ended: <ISO 8601 timestamp>
- items_found: N
- actions_taken: N
- escalations: N
- tokens_estimated: N
- outcome: DONE | ESCALATED | ABORTED | TIMEOUT
- notes: <texto libre, una línea>
```

### Valores de outcome

| Valor | Significado |
|---|---|
| `DONE` | Run completado sin incidentes |
| `ESCALATED` | Se detectaron items que requieren intervención humana |
| `ABORTED` | Run cancelado manualmente o por gate (presupuesto, revisor no disponible) |
| `TIMEOUT` | Superado `AGENT_TASK_TIMEOUT_MINUTES` o tiempo total de sesión |

### Ejemplo real

```markdown
## 2026-06-25 02:15 UTC — overnight-sprint — DONE
- started: 2026-06-25T01:00:00Z
- ended: 2026-06-25T02:15:00Z
- items_found: 8
- actions_taken: 6
- escalations: 1
- tokens_estimated: 42000
- outcome: DONE
- notes: 2 tareas descartadas por aumento de complejidad
```

## Reglas de integridad

1. **Append-only**: nunca editar ni borrar entradas pasadas.
2. **Una entrada por run**: no acumular múltiples runs en una sola sección.
3. **Timestamp UTC**: siempre en UTC para coherencia cross-timezone.
4. **Campos obligatorios**: todos los campos listados arriba son obligatorios. Si un valor es desconocido, usar `0` para numéricos o `unknown` para texto.

## Retención

- Retención por defecto: **90 días**.
- Entradas más antiguas se podan con `loop-run-log.sh prune --skill <n> [--days N]`.
- Las entradas podadas no se archivan (son descartadas); el fichero results.tsv de SE-217 actúa como respaldo machine-readable si se necesita historial largo.

## Complemento machine-readable

`results.tsv` (SE-217) es el formato canónico para queries programáticas (awk, jq, scripts CI).
`run-log.md` es el formato canónico para revisión humana y audit log legible.

Ambos coexisten. `loop-run-log.sh stats` puede leer `run-log.md` directamente sin necesidad de `results.tsv`.

## CLI

Gestión via `scripts/loop-run-log.sh`:

```bash
# Registrar inicio de run
bash scripts/loop-run-log.sh append \
  --skill overnight-sprint \
  --items 0 --actions 0 --escalations 0 --tokens 0 \
  --outcome DONE --notes "started"

# Ver últimas 10 entradas
bash scripts/loop-run-log.sh tail --skill overnight-sprint

# Estadísticas
bash scripts/loop-run-log.sh stats --skill overnight-sprint

# Podar entradas > 90 días
bash scripts/loop-run-log.sh prune --skill overnight-sprint
```

## Referencias

- `scripts/loop-run-log.sh` — CLI de gestión
- `docs/rules/domain/autonomous-safety.md` — Gates de seguridad para modos autónomos
- SE-217 results.tsv — Complemento machine-readable
- SE-228 — Especificación completa de Loop Engineering patterns
