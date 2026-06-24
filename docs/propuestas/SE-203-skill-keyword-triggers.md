---
spec_id: SE-203
title: Keyword triggers para skills
status: IMPLEMENTED
tier: 1
priority: P2
effort: S
era: 200
wave: 1
deps:
  - SE-202
unblocks:
  - SE-204
origin: output/research/openhands-savia-20260607.md
inspiration: OpenHands keyword-based skill routing — declarative trigger maps
---

# SE-203 — Keyword triggers para skills

> Estado: IMPLEMENTED · Tier 1 · P2 · Estimación S · Era 200 · Wave 1

## Resumen

Añadir `trigger.keywords` al frontmatter de 10-15 skills críticos y construir un detector que, dado un texto de input, determine qué skills deben activarse automáticamente. Un hook PreTurn invoca el detector y emite la lista de skills a auto-cargar. Elimina la fricción de tener que recordar el nombre exacto del skill antes de una tarea.

## Motivación

- El workspace tiene 98+ skills — los usuarios no recuerdan cuál invocar para cada tarea.
- Los triggers actuales son textuales en SKILL.md (descripción) pero no hay detección automática.
- OpenHands implementa keyword routing para dirigir tareas al sub-agente correcto sin intervención manual.
- Un mapa de triggers declarativo (frontmatter) es auditable, testeable y extensible sin cambiar código.

## Scope

1. Añadir `trigger.keywords` al frontmatter de 10 skills críticos (lista en AC2).
2. `scripts/skill-keyword-detector.sh` — dado un texto de input (argumento `$1`), detecta qué skills deben activarse. Búsqueda case-insensitive, español e inglés. Devuelve lista JSON de skill names.
3. Hook PreTurn en `.claude/settings.json` que invoca el detector con el texto del turno y emite lista de skills a auto-cargar.
4. `docs/rules/domain/skill-trigger-map.md` — tabla de todos los triggers registrados: skill → keywords.

## Skills a anotar con triggers

| Skill | Keywords |
|---|---|
| savia-memory | recuerda, memory, guarda, memoriza, olvidas |
| tdd-vertical-slices | tdd, test-first, red-green, vertical slice |
| spec-driven-development | spec, sdd, especificacion ejecutable |
| security-guardian | vulnerabilidad, pentest, sql injection, xss, inyeccion |
| performance-audit | performance, hotspot, lento, optimiza, bottleneck |
| knowledge-graph | grafo, knowledge graph, entidades, relaciones |
| weekly-report | informe semanal, weekly, reporte |
| caveman | brutal, caveman, sin filtros, honestidad brutal |
| zoom-out | zoom out, big picture, segunda orden, impacto |
| grill-me | grill, weaknesses, edge cases, adversarial |

## Acceptance Criteria

- AC1: `skill-keyword-detector.sh "quiero hacer tdd"` → `["tdd-vertical-slices"]`.
- AC2: Los 10 skills de la tabla anterior tienen `trigger.keywords` en su frontmatter SKILL.md.
- AC3: `skill-trigger-map.md` lista todos los triggers documentados con formato tabla.
- AC4: Detección case-insensitive, funciona con términos en español e inglés.
- AC5: Multi-match: si el input contiene keywords de varios skills, devuelve todos. Ejemplo: `"spec de seguridad"` → `["spec-driven-development", "security-guardian"]`.
- AC6: `skill-keyword-detector.sh --list` muestra todos los triggers registrados en formato tabla.

## Slices

1. **Slice 1 (1h)** — `skill-keyword-detector.sh` core: lectura de frontmatter + detección + output JSON + `--list`.
2. **Slice 2 (2h)** — Añadir `trigger.keywords` a los 10 SKILL.md + BATS de cada skill con su keyword principal.
3. **Slice 3 (1h)** — Hook PreTurn en `settings.json` + `skill-trigger-map.md` generado desde frontmatter.
4. **Slice 4 (30min)** — BATS E2E con 10 casos de test (uno por skill) incluyendo multi-match y case-insensitive.

## Out of scope

- Detección semántica (embedding similarity) — solo keyword matching en esta spec.
- Auto-ejecución del skill detectado (solo se sugiere, el usuario confirma).
- Triggers por regex o expresiones complejas (keywords simples por ahora).
- Integración con RESOLVER.md (futuro SPEC).

## Riesgo principal

Los keywords pueden ser demasiado genéricos y producir falsos positivos frecuentes (e.g., "spec" dispara spec-driven-development en casi cualquier conversación técnica). Mitigación: revisar keywords en el BATS E2E con ejemplos de contexto real, y permitir `--threshold` para ajustar sensibilidad.
