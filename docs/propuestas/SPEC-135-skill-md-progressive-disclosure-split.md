---
spec_id: SPEC-135
title: SKILL.md split — progressive disclosure para skills superdimensionadas
status: PROPOSED
origin: Investigación 2026-05-23 (P14). Agent Skills 1.0 limita el cuerpo a 500 líneas; el resto va en subdirs `references/`, `scripts/`, `assets/`. Algunas skills (pentesting, enterprise-onboarding, savia-memory) probablemente superan.
severity: Media — reduce tokens en context y habilita portabilidad cross-tool (SPEC-130).
effort: ~6h (S) — 1h por skill superdimensionada.
priority: P14 — token efficiency.
confidence: alta — depende del scan de SPEC-130.
bucket: Q2 2026
related_specs:
  - SPEC-130 (SKILL.md conformance audit — detecta cuáles necesitan split)
---

# SPEC-135 — SKILL.md Progressive Disclosure Split

## Why

Agent Skills 1.0 (publicada dic-2025) define un cuerpo máximo de 500 líneas para SKILL.md. El detalle adicional va en subdirectorios bajo el directorio del skill:

- `references/` — documentos extensos, ejemplos, decision tables.
- `scripts/` — utilidades invocables (bash, python).
- `assets/` — plantillas, fixtures.

El runtime solo carga el cuerpo de SKILL.md en context (frontmatter listing); los subdirs se leen bajo demanda cuando el skill los referencia. Beneficio: menos tokens en cada turno hasta que la skill realmente necesite el detalle.

Savia tiene varias skills con cuerpos >500 líneas (estimación basada en muestra: `pentesting`, `enterprise-onboarding`, `savia-memory`, `voice-inbox`, `azure-devops-queries`, `architecture-intelligence`). El conteo exacto saldrá de SPEC-130. Este SPEC-135 acepta esa entrada como dependencia y aplica la remediación.

## Scope

### Funcional

1. **Lista de skills target**: viene del informe de SPEC-130 (skills con body >500 líneas).

2. **Patrón de split por skill**:
   - Identificar 3-5 secciones independientes del cuerpo (eg. "Casos avanzados", "Apéndices de comandos", "Tablas de configuración").
   - Mover cada sección a `references/<topic>.md`.
   - En el cuerpo de SKILL.md sustituir por un puntero: "Para casos avanzados ver `references/advanced-cases.md`".
   - Si el cuerpo aún excede 500 líneas tras mover, identificar más secciones.

3. **Preservar comportamiento**:
   - Tests existentes de cada skill deben seguir pasando.
   - Si la skill tiene comandos bash inline, moverlos a `scripts/` y referenciar con path absoluto relativo al skill dir.

4. **Tooling de ayuda**:
   - `scripts/skill-md-split-helper.sh <skill>` — analiza un SKILL.md, propone secciones candidatas a split, genera un draft `references/` sin aplicar.

5. **Documentar el patrón** en `docs/rules/domain/skill-md-spec-1.0.md` (creado en SPEC-130).

### No funcional

- Cada split es una commit separada (auditable).
- Tests BATS de cada skill deben seguir verdes.
- Tokens medidos pre/post split — esperar reducción mínima 30% en context cargado.

## Design

### Estructura ejemplo (pentesting tras split)

```
.claude/skills/pentesting/
├── SKILL.md                            # ≤500 líneas, solo overview + cuándo usar
├── references/
│   ├── shannon-pipeline.md             # 200 líneas — detalle del pipeline
│   ├── nuclei-integration.md           # 150 líneas
│   ├── recon-techniques.md             # 180 líneas
│   ├── exploitation-playbooks.md       # 120 líneas
│   └── reporting-template.md           # 80 líneas
└── scripts/
    └── pentest-orchestrate.sh          # bash invocable
```

### Algoritmo de split (helper)

```bash
# scripts/skill-md-split-helper.sh
skill_dir="$1"
skill_md="$skill_dir/SKILL.md"

# 1. Extraer headers nivel ## como candidatos
headers=$(grep '^## ' "$skill_md" | head -20)

# 2. Por cada header, contar líneas hasta el siguiente
for h in $headers; do
  count_lines_in_section "$h"
done

# 3. Proponer top 5 secciones más grandes
suggest_splits

# 4. Generar refs en references/draft-*.md SIN tocar SKILL.md
```

## Acceptance Criteria

- [ ] AC-01: Todas las skills target (≥1, exacto según SPEC-130) con cuerpo ≤500 líneas tras split.
- [ ] AC-02: `references/` poblado con secciones movidas, cada una con frontmatter mínimo (parent_skill, topic).
- [ ] AC-03: SKILL.md tras split contiene punteros explícitos a cada `references/X.md`.
- [ ] AC-04: BATS tests de cada skill afectada siguen verdes.
- [ ] AC-05: `audit-skill-md-spec.sh` (SPEC-130) reporta 100% conformidad en body length.
- [ ] AC-06: Métrica de tokens en context — reducción medida ≥30% en skills splitadas.
- [ ] AC-07: `scripts/skill-md-split-helper.sh` documentado en `docs/rules/domain/skill-authoring.md`.

## Agent Assignment

- **Capa**: Infrastructure / Documentation
- **Agente**: `architect` (split planning) + `tech-writer` (movimientos)
- **Skills**: `workspace-integrity`, `verification-lattice`

## Slicing

- **Slice 1** (1.5h) — Helper script + ejecutar sobre 1 skill piloto (la más grande según SPEC-130).
- **Slice 2** (3h) — Aplicar split a resto de skills target.
- **Slice 3** (1.5h) — Validación tokens, tests BATS, doc en `docs/rules/domain/`.

## Feasibility Probe

Slice 1 piloto: si el split de la skill más grande resulta en regresión de comportamiento (tests rotos, contexto perdido), reevaluar el patrón. Si el cuerpo restante sigue >500 líneas tras mover 5 secciones, plantear si la skill debe descomponerse en 2 skills.

## Riesgos

- **Pérdida de cohesión**: separar contenido relacionado puede romper la narrativa del skill. Mitigación — el cuerpo mantiene un "table of contents" con links a refs.
- **Tests rotos**: si una skill depende de strings exactos del SKILL.md (poco probable), tests rompen. Mitigación — Slice 2 corre tests tras cada split.
- **Sobre-fragmentación**: 10 archivos en references/ es peor que 1 cuerpo de 600 líneas. Cap suave: máximo 5 references por skill, si supera, repensar la skill.
