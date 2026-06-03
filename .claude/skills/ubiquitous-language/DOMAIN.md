# DOMAIN — Ubiquitous Language Extractor

> SE-086. Patrón: `mattpocock/skills/ubiquitous-language + domain-model` (MIT, clean-room).
> Complementa SE-082 (vocabulario arquitectónico universal) — este skill es per-proyecto.

## Por que existe esta skill

Cada proyecto tiene términos de dominio propios. Sin glosario centralizado, cada
agente o persona nueva descubre el vocabulario por osmosis o lo inventa, generando
drift entre specs, código y conversaciones. Esta skill automatiza el paso 1 de DDD:
nombrar las cosas igual en todo el equipo.

Coste de no tenerla: vocabulario divergente, agentes que malinterpretan términos,
specs que reinventan nombres. Coste de tenerla: ~5 minutos para generar el primer
glosario de un proyecto.

## Conceptos de dominio

- **Ubiquitous language**: Vocabulario compartido entre código, specs y conversaciones
  en un bounded context (Eric Evans, DDD).
- **CONTEXT.md**: Fichero de glosario per-proyecto. Single source of truth para
  términos de dominio.
- **Domain term**: Término específico del negocio/proyecto, no técnico-infraestructura.
  Ejemplo: "Era", "Slice", "PBI" son términos de dominio; "function", "git push" no.
- **status=inconsistent**: Un término existe en CONTEXT.md con definición distinta
  al uso reciente detectado.

## Limites y no-objetivos

- No sustituye ADRs para decisiones arquitectónicas.
- No genera definiciones autoritativas — siempre marca [REVIEW] en auto-update.
- No gestiona vocabulario arquitectónico universal — eso es SE-082.
- No crea CONTEXT.md automáticamente sin confirmación del usuario.

## Diferencia con SE-082

| | SE-082 | SE-086 |
|---|---|---|
| Scope | Universal (todos los proyectos) | Per-proyecto |
| Términos | Arquitectónicos: Module, Seam, Adapter… | De negocio: Era, Slice, PBI, AC… |
| Fuente | Rule doc + auditor de código | Conversaciones + memory-store |
| Output | `architectural-vocabulary.md` | `projects/<p>/CONTEXT.md` |

## Confidencialidad

- Nivel: N2 (interno workspace).
- CONTEXT.md va en `projects/<proyecto>/` — gitignored si el proyecto es privado.
- Output report: `output/domain-entity-report-*.md` (gitignored).

## Referencias

- Spec: `docs/propuestas/SE-086-ubiquitous-language-extractor.md`
- Rule: `docs/rules/domain/ubiquitous-language.md`
- Extractor: `scripts/extract-domain-entities.py`
- SE-082: `docs/rules/domain/architectural-vocabulary.md`
- SE-162: `docs/rules/domain/knowledge-graph.md` (DOMAIN_TERM edge)
