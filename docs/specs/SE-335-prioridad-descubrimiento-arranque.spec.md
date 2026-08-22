# SE-335 — Prioridad de descubrimiento de conocimiento en el arranque (cúpulas → memoria → grep)

**Status:** APPROVED (operadora, 2026-08-22) → IMPLEMENTED (2026-08-22)
**Fecha:** 2026-08-22
**Area:** Orquestación / Memoria / Contexto / Hooks
**Origen:** LP-20260822-b20596e1 (promesa vacía: orden de consulta declarado sin acción de respaldo)
**Developer Type:** agent-single
**Context risk:** low
**Estimación:** agente 2h / revisión humana 20min

---

## 1. Problema y objetivo

En la sesión 2026-08-22 se detectó un fallo de comportamiento repetible: ante una
pregunta de conocimiento, el primer movimiento fue `grep` sobre el filesystem, no
la consulta a las cúpulas de conocimiento (SaviaVaults) ni a las capas de memoria.
La respuesta corrigió verbalmente el orden ("la próxima vez cúpulas primero") pero
no tocó ningún hook ni regla. Eso es una promesa vacía: el orden correcto no está
escrito en ningún lugar que el modelo cargue al arrancar, así que nada lo garantiza.

El objetivo es hacer **mecánico** el orden de descubrimiento de conocimiento: al
arrancar sesión (Claude Code y OpenCode), cargar una regla que fije la prioridad
`cúpulas → capas de memoria → grafo de código → grep` como instrucción imperativa,
no como intención.

## 2. Alcance

### Incluido

- Crear la regla `docs/rules/domain/knowledge-discovery-priority.md` (texto plano,
  legible sin herramientas, CRIT-003).
- Cargarla de forma **eager** en el contexto de arranque de ambos frontends vía
  `@import` en el `CLAUDE.md` raíz (fuente única de verdad cross-frontend).
- Refuerzo en el hook `SessionStart` (`session-init.sh`): inyectar la directiva
  concisa en `additionalContext` (banner de sesión, Claude Code).
- Test de arranque que verifica que la regla se emite y que el orden aparece en el
  contexto de sesión.

### Excluido

- Editar `CRITERIO.md` ni `.claude/CONSTITUCION.md` (CRIT-031, ART-11). La entrada
  CRIT candidata que propone la LP queda como propuesta `INFERRED` pendiente de
  `human_authored`.
- Reescribir el mecanismo de hooks, plugins o symlinks existente.
- Cambiar la semántica de niveles N1-N4b ni de `provenance`.
- Implementar lógica de auto-consulta: esta spec solo *fija el orden* como regla
  cargada; no cablea un agente que ejecute las consultas.

## 3. Regla de prioridad (contenido del fichero a crear)

```text
## Prioridad de descubrimiento de conocimiento

Al resolver una pregunta de conocimiento, consultar SIEMPRE en este orden y no saltar:

1. Cúpulas de conocimiento (SaviaVaults MCP): vault_search, vault_read, vault_graph.
   Domos: savia-docs (reglas, specs, decisiones), SaviaLearning (lecciones),
   SaviaLabs (experimentos).
2. Capas de memoria: ~/.savia-memory/auto/MEMORY.md + bash scripts/memory-store.sh recall.
3. Grafo de código: codebase-memory (search_graph/trace_path) o codegraph.
4. Grep/glob a ficheros: SOLO último recurso, para literales, config o no-código,
   o cuando 1-3 no cubren el caso.

Regla: si empiezas por grep sin haber consultado 1-3, estás saltando el orden.
```

## 4. Slices y ficheros

### Slice 1 — Regla + carga eager + banner (2h)

**Crear:**

- `docs/rules/domain/knowledge-discovery-priority.md` — regla con el orden de §3.

**Modificar:**

- `CLAUDE.md` (raíz): añadir `@docs/rules/domain/knowledge-discovery-priority.md`
  como import crítico en la sección "Savia" (junto a radical-honesty /
  autonomous-safety / caveman-default), y actualizar la línea de cabecera
  "5 @imports criticos" → "6 @imports criticos".
- `.claude/hooks/session-init.sh`: añadir al bloque `ITEMS`/`CTX` una línea de
  directiva fija antes de generar el banner, p. ej.:
  `ITEMS+=("Prioridad: cupulas (SaviaVaults) -> memoria -> grafo de codigo -> grep")`.
  Best-effort, sin red, sin deps, dentro del presupuesto de 5s existente.

**Crear (test):**

- `tests/test-se335-prioridad-descubrimiento.bats` — ver §5.

### No tocar

- `CRITERIO.md`, `.claude/CONSTITUCION.md`, ledger.
- `.claude/settings.json` (el hook `session-init.sh` ya está registrado; no se
  añade un registro nuevo, se modifica el script existente).

## 5. Criterios de aceptación

- [x] AC-01: `docs/rules/domain/knowledge-discovery-priority.md` existe y su `cat`
  reconstruye el orden de 4 niveles sin ejecutar ningún script (CRIT-003).
- [x] AC-02: `grep -c "@docs/rules/domain/knowledge-discovery-priority.md" CLAUDE.md`
  devuelve exactamente 1.
- [x] AC-03: la cabecera de `CLAUDE.md` dice "6 @imports criticos" (no "5").
- [x] AC-04: `session-init.sh` emite en `additionalContext` la cadena de prioridad
  (test BATS ejecuta el hook en aislamiento y aserciona la cadena).
- [x] AC-05: el hook termina en menos de 5s y con exit 0 en el test (presupuesto
  de arranque intacto).
- [x] AC-06: hash de `CRITERIO.md` y `.claude/CONSTITUCION.md` invariante antes y
  después del cambio.
- [x] AC-07: `bash scripts/hooks-integrity-check.sh` pasa.
- [x] AC-08: la regla no contiene nombres de proveedor/modelo (CRIT-002/ADR-012,
  `grep` de vendor names = 0 coincidencias).
- [x] AC-09: regla <= 400 tokens (presupuesto de arranque, no inflar el eager).

> Verificación 2026-08-22: `bats tests/test-se335-prioridad-descubrimiento.bats` 8/8,
> suite previa `test-session-init.bats` 12/12, `hooks-integrity-check.sh` PASS,
> `criterio-validate.sh` 0 errores, `git diff --check` limpio, hashes fundacionales
> invariantes. El hook mide ~0.13s en ejecución (los 5.4s percibidos en frío vienen
> de jobs background preexistentes, no de esta spec).

## 6. Verification protocol

```bash
bats tests/test-se335-prioridad-descubrimiento.bats
bash scripts/hooks-integrity-check.sh
bash scripts/criterio-validate.sh   # 33 INFERRED, sin cambios
git diff --check
```

Verificación manual: arrancar una sesión nueva y confirmar que el banner de inicio
muestra la directiva de prioridad (Claude Code) y que el modelo tiene la regla
disponible vía `CLAUDE.md` (OpenCode).

## 7. Riesgos y rollback

- Inflar el contexto eager degrada el lazy-loading (el motivo por el que CLAUDE.md
  separa críticos de on-demand). Mitigación: la regla es corta (< 400 tokens) y
  reemplaza el coste de decisiones equivocadas que hoy cuestan más tokens en
  re-trabajo.
- El banner de `session-init.sh` ya está cerca de su presupuesto de 5s; la línea es
  un `ITEMS+=` estático, sin I/O añadido.
- Rollback: quitar el `@import` de `CLAUDE.md` y la línea de `session-init.sh`;
  eliminar el fichero de regla y su test. Sin migración de datos.

## 8. OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Regla de prioridad | `docs/rules/domain/knowledge-discovery-priority.md` (texto) | Mismo fichero (texto) |
| Carga eager | `CLAUDE.md` raíz `@import` | `.opencode/CLAUDE.md` redirige a `../CLAUDE.md` → mismo `@import` |
| Banner de sesión | `session-init.sh` `SessionStart` | No aplica (OpenCode no tiene SessionStart); cubierto por el `@import` |

### Verification protocol

- [ ] El `@import` es visible para ambos frontends (Claude Code nativo y OpenCode
      vía el redirect de `.opencode/CLAUDE.md`).
- [ ] El test BATS corre desde shell independiente del frontend.
- [ ] No se añade binding exclusivo de un frontend.

### Portability classification

- [x] **PURE_TEXT** para la regla; **DUAL_BINDING** para la carga (el `@import` es
  el mecanismo cross-frontend; el banner de `session-init.sh` es refuerzo Claude
  Code best-effort, no bloqueante).

## 9. Gate de aprobación y PR

La implementación requiere aprobación humana explícita de este fichero. Antes del
PR: `/pr-plan`, `.pr-summary.md` con párrafo plano, diff aislado en rama
`agent/se335-prioridad-descubrimiento`. No se aprueba ni mergea autónomamente.

## Referencias

- LP-20260822-b20596e1 (origen, en `docs/learning-proposals/` y vault SaviaLearning).
- `CLAUDE.md` raíz (lazy context, 5→6 imports críticos).
- `.claude/hooks/session-init.sh` (SessionStart, presupuesto 5s).
- `docs/rules/domain/scl-001-learning-loop.md` (métrica L, "aprendizaje medido").
- CRIT-002, CRIT-003, CRIT-006, CRIT-031; ART-11.
