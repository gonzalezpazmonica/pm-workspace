---
name: context-update
description: Auditar y actualizar el contexto markdown del workspace — frontmatter lint, wikilinks rotos, staleness, duplicados, leaks, tag consistency. Pipeline F0→F4 con composite_quality (A-D). SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 Slice 6.
---

# SKILL: context-update

**Propósito**: Auditar y actualizar el contexto markdown del workspace de Savia — specs, reglas, notas vault, agents, commands — produciendo un plan de acción priorizado con métricas de calidad.

**Comando**: `/context-update`
**Spec**: `SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2` Slice 6
**Implementación**: `scripts/context_update_main.py` + `scripts/lib/context_update/`

---

## Cuándo usarlo

- Antes de un sprint planning para auditar el estado del conocimiento del workspace
- Tras incorporar muchos docs nuevos (onboarding, spec dump, reuniones)
- Cuando sospechas que hay notas obsoletas, duplicadas o con secretos filtrados
- Periódicamente (recomendado: 1x/semana en un workspace activo)

---

## Pipeline F0 → F4

| Fase | Qué hace | Output |
|------|----------|--------|
| **F0** Discovery | Descubre ficheros por scope y filtros | `manifest.json` |
| **F1** Structural | 8 jobs: inventory, frontmatter, wikilinks, tags, confidencialidad, secretos, staleness, duplicados | `F1/*.json` |
| **F2** Semantic | 4 agentes LLM: quality, coherence, obsolescence, redundancy (fallback heurístico si no hay claude CLI) | `F2/*.json` |
| **F3** Consolidate | Plan 4 bloques + composite_quality + trend | `F3_plan.md`, `F3_plan.json`, `consolidated.json` |
| **F4** Apply | Confirmación por bloque, delegación a comandos dueños | `F4_apply_log.json` |

---

## Uso

```bash
# Scan completo, sin escrituras
/context-update --dry-run

# Solo checks estructurales en un proyecto
/context-update --scope vault --slug acme-project --only structural

# Scan completo + aplicar fixes con confirmación
/context-update --apply

# Output JSON (para integración con otros comandos)
/context-update --json
```

## Opciones

| Opción | Descripción |
|--------|-------------|
| `--scope` | `all` \| `opencode` \| `content` \| `vault` \| `raw` (default: `all`) |
| `--slug` | Filtra a un proyecto concreto |
| `--only` | `structural` (solo F1) \| `semantic` (F2/F3) |
| `--apply` | Activa F4: confirmación por bloque + delegación |
| `--non-interactive` | Con `--apply`: acepta bloques sin confirmación (CI) |
| `--dry-run` | Sólo escanea, sin escribir nada en disco |
| `--json` | Emite JSON a stdout al final |
| `--run-id` | Referencia o retoma un run anterior |

---

## Métricas F3

| Métrica | Descripción |
|---------|-------------|
| `composite_quality` | 0.0–1.0; grado A/B+/B/C/D |
| `coverage_frontmatter` | % ficheros con frontmatter válido |
| `confidentiality_integrity` | 1.0 si cero leaks detectados |
| `trend` | Delta vs run anterior del mismo scope |

---

## Bloques del plan F3

1. **CRÍTICO** — ERRORs, secretos, leaks de confidencialidad
2. **IMPORTANTE** — frontmatter roto, wikilinks rotos, coherencia
3. **MANTENIMIENTO** — staleness, duplicados, obsolescencia
4. **CALIDAD** — prose vaga, incoherencias semánticas, tags

---

## Artefactos (en `~/.savia/context-update-tmp/{run_id}/`)

```
F0/discovery.json
F1/{job}.json, F1/_aggregate.json
F2/{agent}.json, F2/_aggregate.json
F3/F3_plan.md          ← informe principal
F3/F3_plan.json        ← plan estructurado (machine-readable)
F3/consolidated.json   ← todos los findings
F4/F4_apply_log.json   ← log de aplicación
```

Ledger de tendencia: `~/.savia/context-update-metrics.jsonl`

---

## Agentes F2

Los 4 agentes LLM están en `.opencode/agents/`:
- `context-quality-judge` — prose quality
- `context-coherence-judge` — contradictions between related notes
- `context-obsolescence-judge` — obsolete content (age ≥ 180 days)
- `context-redundancy-judge` — confirms near-duplicates from F1

El agente F3 consolidator: `context-update-consolidator`

---

## Referencias

- `DOMAIN.md` — domain knowledge y decisiones de diseño
- `references/f1-jobs.md` — schema de findings por job F1
- `references/f2-agents.md` — contrato de los 4 agentes F2
- `references/f3-plan-schema.md` — schema canónico F3_plan.json
