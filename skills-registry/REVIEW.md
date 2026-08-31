# Skills Registry — Review (SE-356)

> Registry local de skills con dos capas (core/peripheral). CRIT-001: local, sin
> registro cloud. Regla de inversión (OpenClaw "two layers, two bars"):
> **peripheral por defecto**, core solo por promoción explícita.

## Reglas de capa

- **peripheral** (default): toda skill nueva nace aquí. Se descubre bajo demanda
  (catálogo, smart-routing). No paga tax de carga per-turn.
- **core**: skills de alta frecuencia y bajo coste que se cargan en el contexto
  per-turn o en el lazy-load crítico. Pagan tax de carga → escrutinio estricto.

## Criterios de promoción a core

Para promover una skill de peripheral a core, debe cumplir TODOS:

1. **Uso**: ≥ 3 sesiones/mes en telemetría local (dato, no estimación).
2. **Calidad**: score ≥ 80 (test-auditor, SE-167 kanban).
3. **No duplicación**: no duplica otra skill (recurring demand → merge/contrato,
   no duplicado). Si 2+ skills repiten capacidad, se fusionan ANTES de promocionar.

## Proceso

1. Abrir PR que cambie `layer:` en `SKILL.md` y en `skills-registry/INDEX.json`.
2. Adjuntar evidencia de uso + calidad en el body del PR (dato, no estimación).
3. Review humano (la operadora) aprueba la promoción.
4. `scripts/skill-layer-check.sh --check` debe pasar en CI.

## Estado actual (2026-08-31)

- 132 skills registradas · 0 core · 132 peripheral
- Promoción inicial propuesta (requiere evidencia): sprint-management, savia-memory,
  spec-driven-development, tabular-intelligence, web-research (candidatas, SIN aprobar)
