# SE-356 — Skills Two-Layers: núcleo vs periferia con tax de carga

**Status:** APPROVED (2026-08-31, operadora grant merge sesión nocturna)
**Fecha:** 2026-08-31
**Área:** Arquitectura de conocimiento / Skills
**Fuente de inspiración:** OpenClaw 2.0 (VISION.md: "two layers, two bars"; core per-call tax; plugin/SDK registry)
**Criterio humano aplicable:** CRIT-001

---

## Objetivo

Introducir la separación **núcleo vs periferia** en el catálogo de skills de
Savia, con la regla de OpenClaw: el núcleo paga una **tax por carga** (cada
línea de skill en el núcleo llega a todos los operadores en cada turno), así
que las adiciones al núcleo enfrentan el escrutinio más estricto; las skills
periféricas no pagan esa tax y se descubren bajo demanda. Resultado: catálogo
con dos capas, un registry local con review, y reglas de promoción explícitas.

## Contexto

Savia tiene **133 skills** (verificado: `.opencode/skills/` = 133 directorios,
reflejado en SKILLS.md). El lazy context ya reduce la carga, pero **no hay
distinción formal core vs peripheral**: una skill experimental paga el mismo
coste de indexación/catálogo que una calibrada. OpenClaw resuelve con: core
slim, "recurring demand defines interfaces" (una capacidad repetida → contrato,
no cola de merges), y promoción a core solo con razón clara (producto,
seguridad, ownership). Su bar para añadir al core es intencionalmente alto.

**Rechazo explícito (CRIT-001):** el registry es **local** (`skills-registry/`
versionado), no un ClawHub cloud. No se sube metadata a ningún servicio.

## Diseño

### 1. Dos capas + metadato

`SKILL.md` frontmatter gana campo obligatorio `layer: core|peripheral`:

- **core** — skills de alta frecuencia y bajo coste que se cargan en el
  contexto per-turn o en el lazy-load crítico (ej. las 6 del CLAUDE.md)
- **peripheral** — el resto; se descubren bajo demanda (catálogo, smart-routing)

Regla de inversión: **peripheral por defecto**, core solo por promoción
explícita. Una skill nueva nace peripheral.

### 2. Registry local con review

`skills-registry/` (versionado, local):
- `INDEX.json` — capa, estado (calibrated/incomplete/stub/deprecated), owner
- `REVIEW.md` — criterios de promoción a core:
  - uso ≥ N sesiones/mes en telemetría local (dato, no estimación)
  - calidad ≥80 (test-auditor, SE-167 kanban)
  - no duplica otra skill (recurring demand → merge/contrato, no duplicado)
- Script `scripts/skill-layer-check.sh`: valida `layer` en frontmatter, drift entre SKILLS.md y registry

### 3. Impacto en carga

- `SKILLS.md` y el catálogo separan visualmente core vs peripheral
- `smart-routing` prioriza core en resolución ambigua
- El lazy-context del CLAUDE.md referencia solo core; peripheral se carga por
  ruta exacta (ya es el patrón)

## Criterios de aceptación

- **AC-0** 100% de skills con `layer:` en frontmatter (drift-check falla si no)
- **AC-1** `skill-layer-check.sh` detecta skill sin `layer` y lo reporta
- **AC-2** Skill nueva (test) nace peripheral por defecto
- **AC-3** Promoción a core requiere entradas en REVIEW.md con dato de uso + calidad (test de shape)
- **AC-4** `smart-routing` no cambia resolución para periféricas (regresión cero)
- **AC-5** `SKILLS.md` regenerado refleja las dos capas

## OpenCode Implementation Plan

### Bindings touched
- `scripts/skill-layer-check.sh` (nuevo), `scripts/skills-md-generate.sh` (extensión)
- 133 SKILL.md frontmatters (batch con default peripheral)
- `docs/SKILLS.md` (auto-regenerado), `docs/rules/domain/skill-template-protocol.md`

### Verification protocol
```bash
bats tests/bats/test-skill-layer.bats
bash scripts/skill-layer-check.sh
```

### Portability classification
- Bash; local; portable

## Trabajo futuro (fuera de scope)
- Publicación de skills a un registry externo — NO (CRIT-001, local forever)
- Runtime plugin API estilo OpenClaw — arquitectura mayor, spec aparte

## Referencias
- OpenClaw: `VISION.md` (two layers two bars, recurring demand, promotion bar)
- Savia: SE-167 skill maturity kanban, `skill-template-protocol.md`, CRIT-001
