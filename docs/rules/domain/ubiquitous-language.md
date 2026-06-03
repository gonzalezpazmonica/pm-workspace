# Ubiquitous Language — Glosario per-proyecto

> SE-086. Skill: `.claude/skills/ubiquitous-language/`. Extractor: `scripts/extract-domain-entities.py`.
> Patrón: DDD "Ubiquitous Language" (Eric Evans). Clean-room de mattpocock/skills (MIT).

## Por qué

Sin glosario centralizado el vocabulario de cada proyecto deriva: specs reinventan términos,
agentes los malinterpretan, nuevas incorporaciones aprenden por osmosis. Coste de tenerlo:
~5 minutos para el primer glosario. Coste de no tenerlo: drift acumulativo en cada sprint.

## Scope: per-proyecto, no universal

- **SE-086** (este fichero): términos de dominio del proyecto — "Era", "Slice", "PBI", "AC".
- **SE-082** (`architectural-vocabulary.md`): vocabulario arquitectónico universal — "Module", "Seam", "Adapter".

No se solapan. SE-082 aplica a todos los proyectos; SE-086 es específico de cada uno.

## CONTEXT.md — fuente de verdad del glosario

Ubicación canónica: `projects/<proyecto>/CONTEXT.md`.

```markdown
# Domain Glossary — <Project>
> Review all [REVIEW] entries before promoting to stable.

| Term | Definition | Status |
|------|------------|--------|
| Era  | Ciclo de desarrollo de ~2 semanas agrupando specs relacionadas. | stable |
| Slice | Unidad vertical de implementación dentro de una spec. | stable |
| AC   | Acceptance Criterion — condición testable de una spec. | [REVIEW] |
```

Status: `stable` / `[REVIEW]` / `[INCONSISTENT]`.

## Extractor: extract-domain-entities.py

```bash
# Reporte desde memory-store (sin modificar CONTEXT.md)
python3 scripts/extract-domain-entities.py --project pm-workspace

# Auto-añadir nuevos términos con [REVIEW]
python3 scripts/extract-domain-entities.py --project pm-workspace --auto-update

# Desde un fichero específico
python3 scripts/extract-domain-entities.py --project X --input docs/spec.md
```

Output: `output/domain-entity-report-<project>-YYYYMMDD.md`
Columnas: `term | mentions | inferred definition | status`

## Bridge a Knowledge Graph (SE-162)

```bash
# Después de build, añade edges DOMAIN_TERM al grafo
python3 scripts/knowledge-graph-domain-bridge.py
```

Cada término de `CONTEXT.md` genera: `[project] --DOMAIN_TERM--> [concept] term`.

## Invariantes (AC spec SE-086)

- AC-01: SKILL.md ≤150 LOC (Rule #11).
- AC-02: Atribución MIT a Pocock en SKILL.md.
- AC-03: Proceso de 5 pasos documentado.
- AC-05: Extractor genera report con tabla.
- AC-06: 3 status: new / existing / inconsistent.
- AC-07: --auto-update marca [REVIEW], nunca sobreescribe definiciones existentes.
- AC-08: Sin --auto-update, no modifica CONTEXT.md.

## No-objetivos

- No genera definiciones autoritativas — siempre [REVIEW] en auto-update.
- No borra términos existentes de CONTEXT.md.
- No sustituye ADRs para decisiones arquitectónicas.
- No crea CONTEXT.md sin confirmación (skill) o sin --auto-update (script).
