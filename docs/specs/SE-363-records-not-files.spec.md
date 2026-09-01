# SE-363 — Registros-no-archivos: capa consultable sobre Markdown

**Status:** APPROVED (2026-08-31, operadora grant merge sesión nocturna)
**Fecha:** 2026-08-31
**Área:** Arquitectura de conocimiento / Gobernanza
**Fuente de inspiración:** Anthropic AI-Native SDLC Playbook ("registros, no archivos": Markdown como interfaz, registro gobernado y consultable debajo)
**Criterio humano aplicable:** CRIT-001 (todo local)

---

## Objetivo

Añadir a los documentos fundacionales de Savia (CONSTITUCION.md, CRITERIO.md) la
distinción del playbook: el Markdown es la **interfaz legible**, y debajo existe
una **capa de registro estructurada y consultable** que responde quién aprobó,
en qué estado está, qué política aplicó, a escala. Esta capa convierte los
criterios en datos consultables (decisión → registro con estado), no solo texto.

## Contexto

El playbook distingue entre un Markdown como interfaz y un registro gobernado
debajo. Verificado en Savia: `CONSTITUCION.md` y `CRITERIO.md` son Markdown con
frontmatter (dureza, enforcement, provenance), pero **no hay una capa
estructurada consultable** que registre: quién aprobó cada CRIT, en qué estado
vive (ACTIVE/SUPERSEDED), qué políticas aplican a qué artefacto. `decision-trace-writer.py`
(SPEC-188) existe pero es para traces de decisiones arquitectónicas, no para el
estado de los criterios. El gap: no se puede consultar "¿qué criterios están
activos hoy y quién los aprobó?" como dato, solo leyendo el Markdown.

**Rechazo explícito (CRIT-001):** la capa de registro es SQLite/JSONL local,
versionada y consultable. Sin servicio externo.

## Diseño

### 1. Capa de registro `data/governance/`

- `criterios.jsonl` — registro de cada CRIT: id, texto, dureza, enforcement,
  estado (ACTIVE/SUPERSEDED/DRAFT), aprobado_por, fecha, policy ref
- `decisiones.jsonl` — decisiones de gobernanza: qué criterio aplicó, a qué
  artefacto, resultado
- Espejo de CRITERIO.md generado por script (el Markdown es la vista; el JSONL
  es el registro)

### 2. Sincronizador `scripts/governance-sync.py`

- Lee CRITERIO.md, extrae los CRIT (frontmatter + cuerpo), genera/actualiza
  `criterios.jsonl` (idempotente por crit_id)
- Detecta drift: CRIT en MD sin registro, o registro sin MD (FAIL en check mode)

### 3. Consulta `scripts/governance-query.sh`

- `--status ACTIVE` → lista criterios activos
- `--approved-by X` → criterios aprobados por X
- `--policy-ref SE-XXX` → criterios que referencian una spec
- `--json` salida consultable

### 4. CONSTITUCION.md

- Análisis (sin modificar el texto fundacional): un registro de estado de los
  artículos (T1-T5) con aprobación (la operadora). La CONSTITUCION sigue siendo
  el texto; el registro es su estado consultable.

## Criterios de aceptación

- **AC-0** Sincronizador genera criterios.jsonl desde CRITERIO.md (test con fixture)
- **AC-1** Idempotente: re-ejecución no duplica entradas
- **AC-2** Query `--status ACTIVE` y `--approved-by` correctos (test)
- **AC-3** Drift-check detecta CRIT sin registro (exit 1)
- **AC-4** CONSTITUCION.md no se modifica (solo se registra su estado)
- **AC-5** Sin regresión: CRITERIO.md intacto

## OpenCode Implementation Plan

### Bindings touched
- `scripts/governance-sync.py` (nuevo), `scripts/governance-query.sh` (nuevo)
- `data/governance/` (nuevo, versionado)
- `docs/rules/domain/governance-records.md` (nuevo, doc del patrón)

### Verification protocol
```bash
bats tests/bats/test-governance-records.bats
bash scripts/governance-sync.py --check
bash scripts/governance-query.sh --status ACTIVE
```

### Portability classification
- Python3 stdlib + bash; local; portable
## Validación (ejecutada en esta sesión)

- `governance-sync.py`: extrae CRIT de CRITERIO.md → criterios.jsonl (idempotente, --check drift); 5 pytest + 5 bats verdes
- `governance-query.sh`: consulta por status/approved-by; CRITERIO.md intacto (verificado por hash)

## Referencias

- Anthropic: claude.com/blog/the-ai-native-sdlc-playbook ("registros, no archivos")
- Savia: CONSTITUCION.md, CRITERIO.md, decision-trace-writer (SPEC-188), CRIT-001
