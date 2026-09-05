# SE-375 — Canonical Capability Registry

**Estado:** PROPOSED (pendiente de aprobación humana — Fase E, audit GPT-5.6 2026-09-05)
**Prioridad:** P0 · **Developer Type:** agent-team · **Context Risk:** high
**Origen:** auditoría externa §6 (CONFIRMED) + §13 Cross-Frontend (fusionada)

## 1. Motivación

El workspace representa sus capacidades en múltiples superficies que hoy divergen:

- Contadores de comandos: 532 (`README.md:5`), 567 (disco `.opencode/commands`), 571 (`CLAUDE.md`), 295 (`.scm/INDEX.scm:3`).
- `.scm` solo registra `categoría — keywords — source` (sin intents, riesgo, lifecycle, tests, dependencias, frontends).
- `docs/RESOLVER.md` AUTO cubre intents solo de skills/agents.
- `.claude/rules/domain/rule-manifest.json` generado 2026-03-14 (stale).

Cada capability nueva multiplica superficies que pueden quedar obsoletas (F1 del audit).

## 2. Alcance

Extender **`.scm`** (RN-02 de la propuesta: no competir, evolucionar) a registry canónico que responda sin ambigüedad: qué existe, qué tipo es, dónde está, qué intents cubre, qué riesgo tiene, qué frontends soporta, de qué depende, qué tests lo verifican y cuál es su lifecycle.

### Campos mínimos por capability

```yaml
id:            # único
kind:          # agent | skill | command | hook | script | rule
source:        # path canónico
status:        # active | experimental | deprecated | retired (SE-380)
owner_domain:  # categoría funcional
intents: []    # de RESOLVER AUTO + frontmatter
risk_level:    # L0-L4
frontend_support: []  # claude | opencode | unsupported
depends_on: []
tests: []
replaced_by: null
generated_views: []
```

### Vistas derivadas (nunca editadas a mano)

AGENTS.md · SKILLS.md · RESOLVER AUTO · contadores de README y traducciones · vista de parity cross-frontend (expected gap vs accidental gap) · contadores de CLAUDE.md.

## 3. Reglas de negocio

| # | Regla | Severidad si falla |
|---|---|---|
| RN-01 | No duplicar narrativas; el registry es estructural | — |
| RN-02 | Evoluciona `.scm`; no crea fuente paralela | — |
| RN-03 | Todo contador público se calcula del registry | P1 |
| RN-04 | Capability sin entrada → warning (L0-L1) / error (L2+) | P1/P0 |
| RN-05 | L2+ sin test asociado → fallo CI (fase 2) | P1 |
| RN-06 | Referencia a capability inexistente → fallo | P0 |
| RN-07 | IDs únicos | P0 |
| RN-08 | Aliases conflictivos detectados | P1 |
| RN-09 | Regeneración determinista (hash estable) | P0 |
| RN-10 | Vistas generadas: edición manual = fallo CI | P1 |

## 4. Criterios de aceptación

- Dos ejecuciones sin cambios → hash idéntico.
- Una capability eliminada desaparece de todas las vistas.
- Drift manual detectado por CI (fixture por tipo).
- Los 4 contadores de comandos convergen a 1 valor derivado.
- Parity cross-frontend clasifica expected vs accidental; accidental = 0 como gate.
- El prefijo de contexto estable no crece.

## 5. Tests

duplicate ID · missing source · orphan capability · dead dependency · dependency cycle · alias collision · deterministic regeneration · manual drift · unsupported frontend · deprecated capability.

## 6. Non-goals

Router LLM nuevo · rediseñar agents/skills · base de datos obligatoria · reemplazar RESOLVER OVERRIDE (hand-curated se preserva).

## 7. OpenCode Implementation Plan

PENDING-APPROVAL — al aprobar, añadir clasificación + slices + presupuesto según `docs/rules/domain/spec-opencode-implementation-plan.md`. Feasibility probe previo recomendado (schema sobre .scm real).

## Referencias

- Auditoría externa GPT-5.6 §6 y §13 (2026-09-05)
- `scripts/generate-capability-map.py` · `scripts/resolver-md-generate.sh` · SE-047 · SE-077 · SE-273 · SE-333
