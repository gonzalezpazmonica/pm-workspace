# /context-update — Auditoría y actualización de contexto del workspace

> Slice 6 de SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2.
> Pipeline F0→F4 que audita la calidad de los ficheros de contexto (.md)
> y propone un plan de mejora organizado por bloques de prioridad.

---

## Uso rápido

```bash
# Dry-run: audita sin escribir nada
/context-update --dry-run

# Auditar solo ficheros de contenido (skills, agents, commands, rules)
/context-update --scope content --dry-run

# Ejecutar y obtener JSON estructurado
/context-update --json --dry-run

# Ejecutar con confirmación interactiva de cambios (modo completo)
/context-update
```

---

## Flags disponibles

| Flag | Descripción |
|---|---|
| `--dry-run` | Auditar sin aplicar cambios. Genera el plan pero no lo ejecuta (F4). |
| `--scope <scope>` | Ámbito: `all` (default), `opencode`, `content`, `vault`, `raw`. |
| `--slug <slug>` | Filtrar por prefijo de ruta (ej. `agents/`, `skills/`). |
| `--only structural` | Ejecutar solo F1 (jobs estructurales) — omite F2 (LLM) y F3 (consolidación). |
| `--json` | Salida JSON estructurada en lugar de texto plano. |
| `--non-interactive` | Aplicar cambios sin confirmación (para pipelines CI). |
| `--conf-max <level>` | Procesar solo ficheros con nivel de confidencialidad ≤ N (1–5). |

---

## Pipeline F0→F4

```
F0 Discovery    → enumera ficheros del workspace según scope/slug/conf
F1 Analysis     → 8 jobs estructurales en paralelo (Threading)
F2 LLM Review   → 4 agentes LLM (o fallback heurístico si no disponibles)
F3 Consolidate  → produce F3_plan.md + F3_plan.json con composite_quality
F4 Apply        → confirmación por bloque + delegación de comandos
```

### F1 — 8 jobs estructurales

| Job | Qué detecta |
|---|---|
| `inventory` | Conteo y clasificación de ficheros por tipo |
| `frontmatter-lint` | Frontmatter ausente o con campos requeridos faltantes |
| `wikilink-check` | Wikilinks `[[...]]` rotos o apuntando a ficheros inexistentes |
| `tag-consistency` | Tags incoherentes entre ficheros del mismo tipo |
| `confidentiality-leak` | Datos con nivel de confidencialidad alto en ubicaciones públicas |
| `secret-scan` | Patrones de credenciales (connection strings, tokens, claves privadas) |
| `staleness` | Ficheros sin modificar más allá del umbral de su tipo |
| `duplicate-detection` | Ficheros con contenido similar (Jaccard ≥ 0.70 via MinHash+LSH) |

### F2 — 4 agentes LLM

Requieren `claude` CLI o `run-agent.sh` en `$PATH`. Si no disponibles, se ejecutan
heurísticos locales equivalentes:

| Agente | Análisis |
|---|---|
| `context-quality-judge` | Calidad de prosa, claridad, completitud |
| `context-coherence-judge` | Contradicciones internas |
| `context-obsolescence-judge` | Contenido obsoleto o no actualizado |
| `context-redundancy-judge` | Redundancias y solapamientos entre ficheros |

### F3 — Composite quality

El consolidador produce una puntuación `composite_quality` (0.0–1.0):

| Grado | Rango | Significado |
|---|---|---|
| A | 0.85–1.00 | Workspace en excelente estado |
| B+ | 0.70–0.84 | Pocas mejoras pendientes |
| B | 0.55–0.69 | Mejoras recomendadas |
| C | 0.40–0.54 | Trabajo de limpieza necesario |
| D | < 0.40 | Estado crítico — acción urgente |

El plan se organiza en 4 bloques por prioridad:

1. **CRÍTICO** — problemas que rompen integridad (leaks, secrets, wikilinks rotos)
2. **IMPORTANTE** — degradan usabilidad (stale, duplicados, coherencia)
3. **MANTENIMIENTO** — mejoras estructurales (frontmatter, tags)
4. **CALIDAD** — mejoras de prosa y completitud

---

## Artefactos generados

Los artefactos se guardan en `~/.savia/context-update-tmp/{run_id}/`:

| Fichero | Descripción |
|---|---|
| `F0/discovery.json` | Manifest de ficheros descubiertos |
| `F1/{job}.json` | Findings por job |
| `F1/_aggregate.json` | Agregado F1 con totales |
| `F2/consolidated.json` | Análisis LLM/heurístico consolidado |
| `F3/F3_plan.md` | Plan de mejora en Markdown (human-readable) |
| `F3/F3_plan.json` | Plan estructurado JSON |
| `F3/consolidated.json` | Datos completos incluyendo backlog |
| `F4/F4_apply_log.json` | Log de acciones aplicadas en F4 |

El ledger de tendencia histórica se acumula en:
`~/.savia/context-update-metrics.jsonl`

---

## MCP server

El pipeline expone 6 tools vía MCP (stdio, JSON-RPC 2.0):

```bash
python3 -m scripts.lib.context_update.mcp_server
```

| Tool | Descripción |
|---|---|
| `context_update_discover` | F0: descubrir ficheros |
| `context_update_f1_run` | F1: análisis estructural |
| `context_update_f2_run` | F2: análisis LLM/heurístico |
| `context_update_f3_consolidate` | F3: consolidar y puntuar |
| `context_update_apply` | F4: aplicar plan |
| `context_update_status` | Estado del último run |

---

## Falsos positivos conocidos

- `secret_scan` detecta 4 errores en ficheros de documentación de ejemplo
  (`savia-shield.md`, `data-sovereignty.md`) que contienen patrones de credenciales
  como ejemplos. Son **falsos positivos esperados** — no requieren acción.
- `staleness` puede marcar ficheros de reglas con `status: archived` — son exentos
  automáticamente si el frontmatter incluye ese campo.

---

## Referencias

- Spec: `SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2.spec.md`
- Skill: `.opencode/skills/context-update/SKILL.md`
- Decisiones de diseño: `.opencode/skills/context-update/DOMAIN.md`
- Jobs F1: `.opencode/skills/context-update/references/f1-jobs.md`
- Agentes F2: `.opencode/skills/context-update/references/f2-agents.md`
- Schema F3: `.opencode/skills/context-update/references/f3-plan-schema.md`
