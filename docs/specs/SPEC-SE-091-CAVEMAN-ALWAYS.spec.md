# Spec: Caveman Always-On — Radical Honesty + Token Efficiency as Default

**Task ID:**        SPEC-SE-091-CAVEMAN-ALWAYS
**PBI padre:**      Era 195 — Savia Agentic Foundation
**Sprint:**         2026-05
**Fecha creacion:** 2026-05-02
**Creado por:**     Savia (requisito Monica: eficiencia + fiabilidad maxima)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion agent:** ~30 min
**Estado:**         Pendiente
**Prioridad:**      ALTA
**Modelo:**         claude-sonnet-4-6
**Max turns:**      15

---

## 1. Contexto y Objetivo

Actualmente `caveman`, `zoom-out` y `grill-me` son skills bajo demanda en
`.opencode/skills/`. Hay que invocarlos explicitamente. Monica quiere que la
honestidad radical y la eficiencia de tokens se apliquen SIEMPRE por defecto,
sin invocacion manual.

**Objetivo:** Convertir caveman de "skill opcional" a "comportamiento por defecto"
de Savia. La identidad de Savia debe incluir las restricciones de caveman como
parte de su system prompt base. Los tribunales (grill-me, zoom-out) se activan
automaticamente via hooks cuando el contexto lo requiere.

---

## 2. Requisitos Funcionales

### Slice 1 — Caveman siempre activo (~15 min)

- **REQ-01** Anadir las restricciones de caveman al system prompt de Savia
  (AGENTS.md o archivo de reglas cargado en cada sesion):
  ```
  Savia applies caveman constraints by default:
  - Zero filler words. No "I think", "it seems", "maybe", "perhaps".
  - Maximum token efficiency. Every token must earn its place.
  - No sugar-coating. No unearned praise. Radical honesty (Rule #24).
  - Default response: 1-3 lines unless detail is explicitly requested.
  - Strip every sentence: if a word can be removed without losing meaning, remove it.
  ```

- **REQ-02** El skill `caveman/SKILL.md` existente se mantiene como documentacion
  y referencia, pero ya no requiere invocacion manual.

- **REQ-03** Verificar que el cambio no rompe respuestas que requieren detalle.
  Savia debe seguir dando respuestas largas cuando el contexto lo exige
  (specs, roadmap, PR descriptions).

### Slice 2 — Activacion automatica de tribunales (~15 min)

- **REQ-04** Crear hook `auto-grill-me.sh` en `.opencode/hooks/` que se dispara
  en evento `PreToolUse` cuando la herramienta es `Edit` o `Write` sobre
  archivos de codigo (`.py`, `.sh`, `.ts`, `.js`, `.cs`, `.go`, `.rs`).
  El hook inyecta una instruccion de grill-me: "Hunt weaknesses: edge cases,
  unstated assumptions, error paths, untested branches."

- **REQ-05** Crear hook `auto-zoom-out.sh` en `.opencode/hooks/` que se dispara
  en `PreToolUse` cuando la herramienta es `Edit` o `Write` sobre archivos
  de arquitectura (`docs/architecture/`, `docs/propuestas/`, `*.arch.md`).
  El hook inyecta: "Zoom out: what dependencies does this affect? Second-order
  effects? What would break?"

- **REQ-06** Ambos hooks son non-blocking (WARN). No detienen la operacion,
  solo inyectan contexto adicional en el system prompt del turno.

---

## 3. Ficheros a Crear/Modificar

| Fichero | Accion |
|---------|--------|
| `docs/rules/domain/caveman-default.md` | CREAR — regla de comportamiento por defecto |
| `AGENTS.md` | MODIFICAR — anadir @import a caveman-default |
| `CLAUDE.md` | MODIFICAR — anadir referencia en lazy context |
| `.opencode/hooks/auto-grill-me.sh` | CREAR — hook PreToolUse para codigo |
| `.opencode/hooks/auto-zoom-out.sh` | CREAR — hook PreToolUse para arquitectura |
| `.opencode/skills/caveman/SKILL.md` | SIN CAMBIOS — queda como referencia |
| `.claude/settings.json` | MODIFICAR — registrar los 2 hooks nuevos |

---

## 4. Criterios de Aceptacion

- **AC-01** Pregunta simple ("que hora es?") → respuesta en 1-3 lineas sin
  filler. Verificable: comparar longitud de respuesta antes/despues.
- **AC-02** Pregunta compleja ("genera spec completo para...") → respuesta
  detallada pero sin filler. Las secciones tecnicas mantienen su contenido.
- **AC-03** `auto-grill-me.sh` se ejecuta al editar `zeroclaw/host/llm_backend.py`.
  Verificable: `grep grill-me` en logs de hooks.
- **AC-04** `auto-zoom-out.sh` se ejecuta al editar `docs/ROADMAP.md`.
  Verificable: `grep zoom-out` en logs de hooks.
- **AC-05** Ningun hook bloquea la operacion (todos WARN o INFO).

---

## 5. Impacto en Roadmap

Este spec cambia el comportamiento base de Savia. Es fundacional: todo lo
que Savia haga a partir de ahora usara caveman por defecto. Se coloca en
slot 8 (antes de SE-084 Slice 2) porque afecta a todos los specs posteriores.
