---
spec_id: SE-222
title: OKF Adoptable Patterns — resource URI + log.md convention + index.md progressive disclosure
status: PROPOSED
priority: P2
effort: S (~8h total: S0 2h + S1 2h + S2 2h + S3 2h)
era: 208
value: 70
urgency: 55
effort_score: 28
priority_score: 71.4
confidence: alta — patrones concretos y acotados; sin riesgo de romper confidencialidad ni SDD
bucket: Q3 2026
origin: análisis OKF Google Cloud 2026-06-20. OKF v0.1 publicado 2026-06-12 en https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing. Repo: https://github.com/GoogleCloudPlatform/knowledge-catalog/tree/main/okf
resource: "https://github.com/GoogleCloudPlatform/knowledge-catalog"
related_specs:
  - SE-162 (Knowledge Graph SQLite — base para el grafo de relaciones)
  - SE-211 (Typed memory schema — complementa resource provenance)
  - SE-213 (Confidence + provenance en KG entries — adopción parcial solapada)
  - SPEC-185 (Critical-facts anchor — misma filosofía de disclosure progresivo)
  - docs/rules/domain/output-taxonomy.md (output/ taxonomy — misma filosofía de convenciones claras)
discarded:
  - Portabilidad inter-org (Savia es sistema cerrado; no hay consumidores externos)
  - Producer/consumer separation formal (Savia escribe y lee su propio knowledge — separar añade overhead sin beneficio)
  - OKF como formato de exportación (rompe modelo N1-N4b; bundle plano no tiene modelo de confidencialidad)
  - SDK / tooling OKF (dependencia externa innecesaria; Savia ya tiene su grafo SQLite)
  - Visualizador HTML de bundle (out of scope; Savia no necesita visualización externa)
---

# SE-222 — OKF Adoptable Patterns

## Why

Google publicó OKF v0.1 el 2026-06-12 como formalización del patrón LLM-wiki
(Karpathy gist). El análisis comparativo con Savia (2026-06-20) identifica tres
patrones concretos del spec que Savia puede adoptar sin romper el modelo de
cúpulas N1-N4b ni SDD:

1. **`resource:` URI** — cada regla/spec apunta a su origen canónico (ADO work
   item, paper, repo, RFC). Hoy las specs tienen `origin:` como texto libre sin
   formato. Formalizar como URI permite navegación directa y trazabilidad
   automatizable.

2. **`log.md` convention** — historial cronológico de cambios por concepto.
   Hoy el histórico está en CHANGELOG.md (repo-wide) o en commits git. Un
   `log.md` por directorio de propuestas/specs captura el historial conceptual
   (no solo el diff), visible sin `git log`.

3. **`index.md` progressive disclosure** — ficheros índice por directorio que
   describen qué contiene cada sección. Hoy `docs/propuestas/` no tiene índice;
   los agentes hacen `ls` o `glob` para orientarse. Un `index.md` generado
   automáticamente reduce el coste de descubrimiento en cada sesión nueva.

Estos tres patrones son ortogonales al modelo de confidencialidad de Savia —
aplican solo a ficheros N1 (docs/propuestas/, docs/rules/, .opencode/skills/).
No tocan N2-N4b.

## Lo que se descarta y por qué

| Patrón OKF | Descartado porque |
|---|---|
| Bundle portable inter-org | Savia es sistema cerrado; el knowledge de N2-N4b no puede exportarse plano |
| Separación formal producer/consumer | Overhead sin beneficio — Savia ya es author+reader de su propio sistema |
| OKF como formato de exportación | Rompe N1-N4b: un bundle OKF de Savia expondría datos de cliente |
| SDK y tooling OKF | Dependencia externa; Savia tiene grafo SQLite propio (SE-162) |
| Visualizador HTML | Out of scope; no hay caso de uso de visualización externa |
| `tags:` field | Savia ya usa frontmatter con campos equivalentes (context_tier, priority, etc.) |
| `timestamp:` field | Git ya provee timestamp canónico; duplicar genera drift |

## Slices

### S0 — Formalizar `resource:` URI en frontmatter de specs y reglas (~2h)

**Qué**: añadir campo `resource:` al template de SKILL.md, al template de specs
(`docs/propuestas/`), y a las reglas de dominio (`docs/rules/domain/`).

**Formato**:
```yaml
resource: "https://github.com/owner/repo"          # repo origen
# o
resource: "https://dev.azure.com/org/proj/_workitems/edit/1234"  # ADO work item
# o
resource: "https://arxiv.org/abs/2302.00000"        # paper
```

**Regla**: campo opcional pero recomendado. Si `origin:` ya existe como texto
libre, `resource:` es el URI extrae del origen. `origin:` queda como descripción
en prosa; `resource:` es el URI navegable.

**Alcance**: template `_template/SKILL.md` + `docs/rules/domain/skill-template-protocol.md`
+ validator en `scripts/spec-validator.sh` (warn si spec tiene `origin:` pero no `resource:`).

**Criterios de aceptación**:
- [ ] Template SKILL.md incluye campo `resource:` con comentario explicativo
- [ ] Template de spec incluye campo `resource:`
- [ ] `spec-validator.sh` emite WARN (no FAIL) si `origin:` presente sin `resource:`
- [ ] Al menos 5 specs existentes back-filled con `resource:` como ejemplo

---

### S1 — `log.md` convention por directorio de propuestas (~2h)

**Qué**: convención de fichero `CHANGELOG.d/propuestas-log.md` (o
`docs/propuestas/LOG.md`) con historial conceptual de las specs: cuándo
se propuso, cuándo se implementó, por qué se descartó si aplica.

**Formato** (append-only, más reciente primero):
```markdown
## 2026-06-20 SE-222 PROPOSED
OKF adoptable patterns — resource URI + log.md + index.md.
Origen: análisis comparativo OKF vs Savia.

## 2026-06-20 SE-221 PROPOSED
Inverted security patterns as context engineering.

## 2026-06-13 SPEC-195..200 IMPLEMENTED
DiffusionGemma patterns — iterative refinement, freeze-done, annealing...
```

**Regla**: `docs/propuestas/LOG.md` es append-only. El script
`scripts/spec-lifecycle.sh` añade entradas automáticamente cuando una spec
cambia de status (`PROPOSED` → `IMPLEMENTED` | `DISCARDED` | `DEPRECATED`).

**Criterios de aceptación**:
- [ ] `docs/propuestas/LOG.md` existe con entradas retroactivas de las últimas 10 specs
- [ ] `scripts/spec-lifecycle.sh` appends entrada al hacer `--status IMPLEMENTED|DISCARDED`
- [ ] Formato validado por BATS (estructura, append-only, sin edición de entradas pasadas)

---

### S2 — `index.md` auto-generado para `docs/propuestas/` (~2h)

**Qué**: script `scripts/propuestas-index-gen.sh` que genera
`docs/propuestas/INDEX.md` con tabla de todas las specs agrupadas por status.

**Formato** (auto-generado, marcado `@generated`):
```markdown
<!-- @generated by scripts/propuestas-index-gen.sh — DO NOT EDIT -->
# Specs Index

## PROPOSED
| ID | Título | Esfuerzo | Priority | Era |
|---|---|---|---|---|
| SE-222 | OKF Adoptable Patterns | S (~8h) | P2 | 208 |
...

## IMPLEMENTED
...

## DISCARDED
...
```

**Trigger**: PostToolUse hook cuando se edita un fichero en `docs/propuestas/`.
Rate-limit: 1 regeneración por minuto.

**Criterios de aceptación**:
- [ ] `scripts/propuestas-index-gen.sh` genera INDEX.md correctamente
- [ ] Hook PostToolUse dispara regeneración al modificar propuestas
- [ ] INDEX.md tiene marcador `@generated` (compatible con SPEC-180 sentinel)
- [ ] BATS suite: 10+ tests (genera, agrupa por status, no rompe con specs malformadas)

---

### S3 — Back-fill `resource:` en specs/reglas de alto valor (~2h)

**Qué**: añadir `resource:` a las 20 specs y reglas más referenciadas.
Prioridad: specs IMPLEMENTED con paper/repo de origen conocido + reglas de
dominio con fuente externa verificable.

**Lista inicial** (a completar durante implementación):
- SE-216 → `https://github.com/evo-hq/evo`
- SE-217 → `https://github.com/karpathy/autoresearch`
- SE-218 → `https://github.com/DeusData/codebase-memory-mcp`
- SE-219 → `https://github.com/graykode/abtop`
- SE-220 → papers Leviathan 2022 + EAGLE-3 NeurIPS'25
- SE-222 → `https://github.com/GoogleCloudPlatform/knowledge-catalog`
- SPEC-195..200 → `https://github.com/google-deepmind/gemma/tree/main/gemma/diffusion`

**Criterios de aceptación**:
- [ ] ≥20 specs/reglas con `resource:` añadido
- [ ] Ningún `resource:` apunta a URL interna de la organización (N1 solo)
- [ ] PR pasa confidentiality scan sin BLOCKED

---

## Esfuerzo total

| Slice | Esfuerzo | Prioridad |
|---|---|---|
| S0 — resource: URI template + validator | ~2h | P2 |
| S1 — log.md convention + spec-lifecycle.sh | ~2h | P2 |
| S2 — index.md auto-generado | ~2h | P2 |
| S3 — back-fill resource: en 20 specs | ~2h | P3 |
| **Total** | **~8h** | |

S0, S1, S2 son paralelizables. S3 depende de S0.

## Qué NO cambia

- Modelo de confidencialidad N1-N4b: intacto
- SDD obligatorio (Rule #8): intacto
- Estructura de memoria (MEMORY.md, tiers, rotación): intacta
- Knowledge Graph SQLite (SE-162): intacto — `resource:` lo complementa, no lo reemplaza
- Ningún fichero N2-N4b recibe `resource:` (datos privados no tienen URI pública)
