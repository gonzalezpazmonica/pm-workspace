---
id: SE-319
title: "SE-319 — Commit Archaeologist: reconstrucción del porqué del código"
status: PROPOSED
priority: baja
---

# SE-319 — Commit Archaeologist: reconstrucción del porqué del código

**Status:** PROPOSED
**Fecha:** 2026-08-09
**Area:** Code comprehension / Context dome / Bus factor
**Branch sugerida:** `agent/se319-commit-archaeologist`
**Estimacion total:** ~18h (3 slices)
**Inspiracion:** `Shubhamsaboo/awesome-llm-apps` → agent_skills/commit-archaeologist

---

## Contexto y evidencia (2026-08-09)

Cuando un dev nuevo (o un agente) toca un módulo sin mapa, el conocimiento
tácito está en el historial de git: *qué commit introdujo este fichero,
por qué, y qué cambios posteriores lo modelaron*. El skill `commit-archaeologist`
de awesome-llm-apps reconstruye la intención de un fichero/región desde su
commit introductorio, ediciones posteriores, co-changes y pistas de intención.

Savia tiene:
- `human-code-map`, `context-dome` (capturan conocimiento tácito *a posteriori*,
  tras analizar el código),
- `bus-factor-analysis` (CST: detecta módulos con 1 owner),
- `code-comprehension-report` (modelo mental post-implementación).

**El hueco.** Ninguna herramienta de Savia *excava git* para reconstruir la
intención: los context domes se generan desde el código actual, no desde la
historia de por qué llegó a ser así. Para módulos con bus factor bajo, la
historia de commits es la única fuente de intención que queda.

---

## Objetivo

Añadir `scripts/commit-archaeologist.sh` que, dado un fichero o región, extrae
del historial git: commit introductorio (git blame/log -S), commits posteriores
que lo tocaron, co-changes (ficheros que cambiaron juntos) y mensajes de
intención. Output estructurado usable por `context-dome` y `human-code-map`.

---

## Out of scope

- NO hacer análisis semántico del diff (eso es code-review).
- NO reescribir la lógica de `context-dome`/`human-code-map`: solo añadir la
  fuente de historia que alimenta esos flujos.
- NO tocar historia de ramas ajenas (solo el repo actual, read-only).

---

## Diseno

### S1 — Reconstrucción por fichero

`scripts/commit-archaeologist.sh --file <path>`:
- `git log --follow` para el commit introductorio,
- `git log -S <fragmento clave>` (pickaxe) para cambios semánticos,
- lista de commits posteriores con fechas y autores,
- co-changes: ficheros que aparecieron en los mismos commits (top-N).

### S2 — Reconstrucción por región/línea

`--region <file> <line>`:
- `git blame` para el commit de cada línea,
- agrupa por commit y muestra el mensaje de intención de los commits
  dominantes (los que introdujeron la mayoría de líneas).

### S3 — Output para domes + integración

- JSONL: `{file, introduced_by: {commit, author, date, message},
  evolved_by: [...], co_changes: [...], region_summary}`.
- `context-dome` y `human-code-map` leen este JSON como fuente de intención.
- Integración con `bus-factor-analysis`: los módulos con 1 owner y sin
  archaeologist reporte se marcan como "historia no excavada" (prioridad).

---

## Criterios de aceptacion

### AC-S1: Fichero

- [ ] AC-S1.1: fichero con historia → `introduced_by` con commit real del repo
  (fixture) y co-changes no vacíos.
- [ ] AC-S1.2: fichero nuevo sin commit previo → `introduced_by: null`, exit 0.

### AC-S2: Región

- [ ] AC-S2.1: región de 5+ líneas de un mismo commit → resumen apunta a ese
  commit dominante.
- [ ] AC-S2.2: región con líneas de múltiples commits → los lista ordenados
  por líneas aportadas.

### AC-S3: Output e integración

- [ ] AC-S3.1: JSONL válido consumible por `context-dome` (schema documentado).
- [ ] AC-S3.2: reporte para un módulo de ejemplo en `output/archaeologist/`
  incluido en la PR de implementación.

---

## Ref

- `Shubhamsaboo/awesome-llm-apps` → `agent_skills/commit-archaeologist`
- `.opencode/skills/context-dome/SKILL.md`, `.opencode/skills/bus-factor-analysis/SKILL.md`
