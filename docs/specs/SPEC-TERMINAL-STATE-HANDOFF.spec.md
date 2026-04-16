# Spec: Terminal State Handoff — Capturar razon de terminacion

**Task ID:**        SPEC-TERMINAL-STATE-HANDOFF
**PBI padre:**      Agent handoff clarity (research: claude-code-from-source)
**Sprint:**         2026-15
**Fecha creacion:** 2026-04-10
**Creado por:**     Savia (research: claude-code-from-source Ch05)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     2h
**Estado:**         Pendiente
**Prioridad:**      MEDIA
**Max turns:**      15
**Modelo:**         claude-sonnet-4-6

---

## 1. Contexto y motivacion

Claude Code nativo tiene un **Terminal state discriminado** en su query loop:
un subagente termina con una de 6 razones:

1. `completed` — tarea finalizada correctamente
2. `user_abort` — usuario interrumpio
3. `token_budget` — agotado el presupuesto de tokens
4. `stop_hook` — un hook invoco stop
5. `max_turns` — alcanzado max_turns del agente
6. `unrecoverable_error` — error irrecuperable

pm-workspace delega a la Task tool de forma opaca: no captura esta informacion
en los handoffs entre agentes. Sin el `termination_reason`, la orquestadora no
puede aplicar politicas de reintento precisas (por ejemplo, `token_budget`
deberia escalar modelo, `max_turns` deberia escalar a humano, `unrecoverable`
deberia abortar).

Fuente: https://claude-code-from-source.com/ch05-agent-loop/ — el agent loop
usa un tipo de retorno discriminado para capturar el motivo exacto de parada.

## 2. Objetivo

Añadir el campo `termination_reason` a las 7 plantillas en
`docs/rules/domain/handoff-templates.md` y actualizar
`docs/rules/domain/verification-before-done.md` para usar esta informacion
en la retry policy. Permite decisiones de escalacion mejor informadas.

## 3. Requisitos funcionales

- **REQ-01** Actualizar las 7 plantillas en `handoff-templates.md` con un nuevo
  campo YAML: `termination_reason: enum`. Enum de valores validos:
  `completed | user_abort | token_budget | stop_hook | max_turns | unrecoverable_error`
- **REQ-02** Actualizar `verification-before-done.md` con una retry policy
  que usa `termination_reason`:
  - `completed` → continuar al siguiente paso
  - `user_abort` → respetar decision del usuario, no reintentar
  - `token_budget` → escalar al siguiente modelo (FAST → MID → AGENT)
  - `stop_hook` → revisar el hook que paro, no reintentar hasta fix
  - `max_turns` → escalar a humano (tarea demasiado compleja)
  - `unrecoverable_error` → abortar, registrar en lessons.md
- **REQ-03** Actualizar `scripts/validate-handoff.sh` (si existe) o crearlo
  para validar que el campo esta presente y el valor es del enum.
- **REQ-04** Actualizar las plantillas concretas:
  1. Standard Handoff
  2. QA Pass
  3. QA Fail
  4. Escalation
  5. Phase Gate (SDD)
  6. Sprint Review
  7. Status Report
- **REQ-05** Añadir seccion en `handoff-templates.md`: "Termination Reasons —
  Reference" con descripcion de cada valor del enum.
- **REQ-06** Test BATS `tests/test-handoff-termination.bats` verifica:
  - Validacion del enum (solo valores permitidos)
  - Retry policy correcta para cada valor

## 4. Criterios de aceptacion

- **AC-01** Las 7 plantillas en `handoff-templates.md` incluyen `termination_reason`.
- **AC-02** `verification-before-done.md` tiene la retry policy documentada por
  cada valor del enum.
- **AC-03** `scripts/validate-handoff.sh` acepta handoffs con valores validos y
  rechaza los invalidos (exit 2 con mensaje claro).
- **AC-04** Test BATS `test-handoff-termination.bats` certificado por el auditor.
- **AC-05** CI quality gate sigue pasando tras los cambios.
- **AC-06** `handoff-templates.md` no excede 150 lineas (Rule #11).

## 5. Test scenarios

1. **Valid enum**: handoff con `termination_reason: completed` → pasa validacion.
2. **Invalid enum**: handoff con `termination_reason: foo` → falla validacion (exit 2).
3. **Missing field**: handoff sin `termination_reason` → warning pero no bloquea.
4. **Retry policy token_budget**: verifica que la doc menciona escalacion de modelo.
5. **Retry policy max_turns**: verifica que la doc menciona escalacion a humano.
6. **Retry policy unrecoverable**: verifica que la doc menciona abortar + lessons.md.

## 6. Arquitectura / ficheros afectados

**Modificados:**
- `docs/rules/domain/handoff-templates.md`: +termination_reason en las 7 plantillas + seccion reference
- `docs/rules/domain/verification-before-done.md`: +retry policy por termination_reason

**Nuevos o modificados:**
- `scripts/validate-handoff.sh` (nuevo o update)
- `tests/test-handoff-termination.bats`

## 7. Ejemplo de plantilla actualizada

```yaml
# Standard Handoff (post-update)
from_agent: "dotnet-developer"
to_agent: "test-runner"
task_id: "AB#1234"
termination_reason: "completed"  # NUEVO: enum
artifacts:
  - "src/UserService.cs"
  - "tests/UserServiceTests.cs"
context_for_next:
  files_modified: [...]
  decisions_made: [...]
next_steps: "Run unit tests and report coverage"
```

## 8. Ejemplo de retry policy en verification-before-done.md

```markdown
## Retry Policy by Termination Reason

| termination_reason | Accion | Motivo |
|---|---|---|
| completed | Continuar | Exito |
| user_abort | Respetar | Usuario decidio parar |
| token_budget | Escalar modelo | FAST→MID→AGENT |
| stop_hook | Revisar hook | Causa deterministica |
| max_turns | Escalar a humano | Tarea compleja |
| unrecoverable_error | Abortar + lessons.md | Bug del agente |
```

## 9. Fuera de alcance

- No cambia como Claude Code nativo reporta terminacion (es opaco para nosotros).
- Los agentes deben auto-reportar el motivo; no hay deteccion automatica.
- Los handoffs existentes (historicos) no se actualizan retroactivamente.

## 10. Referencias

- [claude-code-from-source Ch05](https://claude-code-from-source.com/ch05-agent-loop/)
- `docs/rules/domain/handoff-templates.md`
- `docs/rules/domain/verification-before-done.md`
- `docs/rules/domain/autonomous-safety.md` (AGENT_MAX_CONSECUTIVE_FAILURES=3)
