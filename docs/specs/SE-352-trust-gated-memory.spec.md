# SE-352 — Trust-Gated Memory: provenance de origen + taint + exclusión de consolidación

**Status:** APPROVED (2026-08-31, operadora grant merge sesión nocturna)
**Fecha:** 2026-08-31
**Área:** Memoria persistente / Epistemología (Labs L1-L6, SCL)
**Fuente de inspiración:** OpenClaw 2.0 (trust boundary + memory provenance, `docs/start/why-openclaw.md`)
**Criterio humano aplicable:** CRIT-001 (todo local, N3+ jamás a cloud)

---

## Objetivo

Añadir a la memoria de Savia el **gating de confianza por origen** que OpenClaw
aplica a su memoria: cada entrada llevará una **clase de origen**
(`owner | agent | untrusted | system`) almacenada **fuera del prosa**, los
resultados de herramientas con origen de red **contaminarán** el turno, y la
consolidación **excluirá** entradas `untrusted`/`system` del paso de
promoción. Una entrada recuperada **nunca podrá promover su propio nivel de
confianza**.

## Contexto

Verificado en esta sesión: `scripts/memory-store.sh` escribe entradas
idempotentes por `topic_key` con `type: title [key]`, pero **no hay origen,
trust class ni taint**. Esto es la brecha de seguridad epistémica mayor que
encontramos al cruzar con OpenClaw. El riesgo es real: una entrada inyectada
por una herramienta de red (fetch, web-research) o por un subagente no
verificado puede ser promovida a "hecho" en la consolidación y reaparecer como
decisión. Savia ya tiene las piezas epistemológicas (SCL-002, L2 ignorancia,
L13 metacognición) pero ninguna opera sobre el **origen** de la memoria.

**Rechazo explícito (CRIT-001):** no se adopta ningún backend de memoria cloud
de OpenClaw (SQLite local sí, Graphiti/Zep no). El diseño es un esquema JSONL
local sobre la infraestructura existente.

## Diseño

### 1. Clase de origen (origin class)

Nueva columna en `MEMORY.md` / ficheros de entrada (formato `- {type}: {title} [{topic_key}]` extendido):

```
- {type}: {title} [{topic_key}] · src:{origin}  # origin ∈ owner|agent|untrusted|system
```

- `owner` — escrita por la operadora (default: activar como `owner`)
- `agent` — escrita por un agente Savia sobre hechos verificados localmente
- `untrusted` — origen de herramienta de red (fetch/webfetch), subagente no verificado, o entrada que nunca pasó verificación
- `system` — generada por hooks/scripts de infra (sin semántica de decisión)

Regla: **sin `src:` explícito → se clasifica `untrusted`** (fail-safe, nunca
`owner` por defecto). Esta es la regla clave de OpenClaw: "classification never
defaults to owner".

### 2. Taint de turno

Cuando una herramienta con origen de red devuelve resultado, **todas las
mensajes posteriores del turno** se marcan tainted y las entradas que se
guarden de ese turno se clasifican `untrusted`, sin importar quién habla.

### 3. Exclusión de consolidación

`memory-store.sh consolidate` (o el paso equivalente) **descarta** candidatas
`untrusted` y `system` antes de construir el prompt de consolidación. Solo
`owner`/`agent` entran en el paso de promoción. Esto es equivalente al
"dreaming" de OpenClaw.

### 4. Interfaz

- `memory-store.sh save --origin owner|agent|untrusted|system` (default `untrusted` salvo flag)
- `memory-store.sh recall --min-origin` filtro opcional
- `memory-store.sh audit-origins` — reporte de distribución de orígenes
- `scripts/memory-origin-gate.sh` — hook PostToolUse que marca taint tras herramientas de red

## Criterios de aceptación

- **AC-0** Toda entrada nueva sin `src:` se clasifica `untrusted` (test)
- **AC-1** Entrada `untrusted` recuperada no promueve su trust class (test de no-promoción)
- **AC-2** Consolidación excluye `untrusted`/`system` (dataset sintético, test)
- **AC-3** Taint de turno: tras fetch, la siguiente entrada guardada es `untrusted` (test e2e con hook)
- **AC-4** `audit-origins` produce distribución en <2s (test)
- **AC-5** Sin regresión: suite de memoria existente (tests/scripts/test_memory*) verde

## OpenCode Implementation Plan

### Bindings touched
- `scripts/memory-store.sh`, `scripts/memory-save.sh`, `scripts/memory-search.sh`
- `.claude/settings.json` (registro hook PostToolUse `memory-origin-gate.sh`)
- `docs/rules/domain/memory-system.md`

### Verification protocol
```bash
bats tests/bats/test-memory-origin-gate.bats
pytest tests/scripts/test_memory_origin.py -q
bash scripts/memory-store.sh audit-origins
```

### Portability classification
- Hooks: Claude Code + OpenCode compartidos vía symlink `.opencode/hooks/` (portable)
- Scripts: bash + python3 stdlib (portable a todos los frontends)

## Trabajo futuro (fuera de scope)
- Forget con tombstones (OpenClaw `memory forget`) — spec independiente
- Retention por origen — spec independiente

## Referencias
- OpenClaw: `docs/start/why-openclaw.md` (Provenance section, dreaming, taint)
- Savia: `docs/memory-system.md`, SCL-002, Labs L2/L13
- CRIT-001 · `autonomous-safety.md`
