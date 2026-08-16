# Spec: SE-332 — Handback Obligation: escalación normativa de agentes autónomos bloqueados

**Status:** APPROVED
**Fecha:** 2026-08-15
**Fecha aprobación:** 2026-08-16 (operadora, sesión opencode)
**Area:** Autonomous safety / Escalación de autoridad / Handoff
**Estimación:** 3h
**Inspirado por:** ai-project-system v7.1.0 (github.com/panchew/ai-project-system) — P10-M35 `governance/systems/fleet-operator.md`, "handback obligation"

**Developer Type:** agent-single
**Asignado a:** claude-agent

---

## Origen

El análisis de `panchew/ai-project-system` (v7.1.0, 111 epics, dogfooding público)
reveló un mecanismo que Savia no tiene: la **handback obligation**. En su P10-M35,
cuando una instancia autónoma queda bloqueada, "escala a su padre inmediato, un
nivel a la vez, terminando en un nivel manual por construcción".

Savia tiene piezas sueltas de esto, pero no la cadena:
- `autonomous-safety.md` define `AUTONOMOUS_REVIEWER` como un **único valor estático**
  resuelto en arranque. Si no resuelve, el modo autónomo "NO arranca". Si resuelve
  pero el revisor no responde, el agente **espera** (SPEC-122) sin cadena de
  escalación.
- La escalación existente es de **modelo** (fast→mid→agent→abort), no de **autoridad**.
- SE-146 (Subagent Scope Guard) devuelve `BLOCKED` al orquestador, pero no hay norma
  que diga qué hace un orquestador cuando toda su cadena está bloqueada salvo
  "requiere intervención humana" — sin artefacto que permita **retomar sin re-derivar
  contexto**.
- `terminal-state-protocol.md` enum `unrecoverable_error` → "escalar a humano
  inmediatamente", pero no define **quién es el humano** (el padre) ni deja un
  handback artifact.

El gap de fondo: Savia no garantiza "alcanzar al humano **por construcción**". Hoy
se alcanza "por esperanza" — asumiendo que el AUTONOMOUS_REVIEWER estático responde.

## Problema actual

- Un agente autónomo bloqueado (recurso no disponible, guardrail rechaza, modelo no
  coincide) aborta silenciosamente o espera al revisor estático, sin escalar a su
  padre inmediato.
- No existe cadena de escalación normativa por modo autónomo.
- Cuando un humano retoma una instancia bloqueada, re-deriva el contexto desde cero:
  no hay handback artifact **reference-first** (rutas, no eco de cuerpo).
- No hay registro en el audit trail de a quién se escaló (`handback_to`).

## Diseño

### 1. Nueva sección "Handback Obligation" en `autonomous-safety.md`

Regla normativa + tabla de cadena por modo:

```
Una instancia autónoma bloqueada escala a su padre inmediato, un nivel a la
vez. Toda cadena termina en un nivel manual POR CONSTRUCCIÓN — no existen
cadenas infinitas de agentes.
```

| Modo autónomo | Padre inmediato | Manual terminal |
|---|---|---|
| overnight-sprint / code-improvement-loop / tech-research-agent | AUTONOMOUS_REVIEWER | operadora (perfil activo) |
| court-orchestrator / truth-tribunal-orchestrator / recommendation-tribunal-orchestrator | dev-orchestrator | operadora (perfil activo) |
| subagente delegado (SE-146, `BLOCKED`) | orquestador que lo invocó | operadora (perfil activo) |

### 2. Nuevo `termination_reason: handback` + schema de artifact

- Extender el enum en `terminal-state-protocol.md` con `handback`.
- Extender `agent-handoff-protocol.md` (handoff-as-function) con un schema de
  artifact **reference-first** — contiene rutas a artifacts, no el cuerpo:

```yaml
handback:
  escalado_desde: <modo|agente>
  escalado_a: <padre resuelto>
  motivo: <recurso_no_disponible | guardrail_rechazo | modelo_mismatch | otro>
  contexto_ref:                     # reference-first, no eco de cuerpo
    - <ruta artifacts/run-record>
    - <ruta terminal-state.jsonl>
  intentos_restantes: <n>
  timestamp: <ISO-8601>
```

### 3. Script determinista `scripts/handback-resolve.sh`

Dado `--modo` + `--contexto-dir`, resuelve el padre de la cadena y emite el artifact:

- Consulta `scripts/savia-env.sh` (`savia_autonomous_reviewer()`), no re-deriva la
  cadena de fuentes.
- Si la cadena NO termina en manual → `exit 5` (imposible por construcción; test de
  seguridad que garantiza la invariante).
- Emite artifact handback en `output/agent-runs/{modo}-{fecha}-handback.md`.

### 4. Audit trail

Añadir campo `handback_to` a `output/agent-runs/{modo}-{fecha}-audit.log`
(campos mínimos ya definidos en `autonomous-safety.md`).

## Acceptance criteria

- [ ] AC-1 `autonomous-safety.md` tiene sección "Handback Obligation" con la tabla de cadena por modo.
- [ ] AC-2 `terminal-state-protocol.md` enum añade `handback` con política de reintento (no reintentar) y acción del orquestador (escalar a padre).
- [ ] AC-3 `agent-handoff-protocol.md` documenta el schema `handback` reference-first.
- [ ] AC-4 `scripts/handback-resolve.sh` resuelve el padre correcto para los 3 modos autónomos (exit 0 + artifact).
- [ ] AC-5 `handback-resolve.sh` devuelve exit 5 si la cadena no termina en manual (invariante de seguridad).
- [ ] AC-6 El artifact handback contiene solo rutas (`contexto_ref`), no contenido de los artifacts.
- [ ] AC-7 `audit.log` registra `handback_to` en cada escalación.
- [ ] AC-8 Tests BATS: 8+ (resolución por modo, invariante exit 5, schema reference-first, enum, audit log).

## Ficheros

| Acción | Path |
|---|---|
| MODIFY | `docs/rules/domain/autonomous-safety.md` (sección Handback Obligation) |
| MODIFY | `docs/rules/domain/terminal-state-protocol.md` (enum + exit code) |
| MODIFY | `docs/rules/domain/agent-handoff-protocol.md` (schema handback) |
| MODIFY | `scripts/savia-env.sh` (exponer `savia_handback_chain()`) |
| CREATE | `scripts/handback-resolve.sh` |
| CREATE | `tests/test-se-332-handback.bats` |
| CREATE | `docs/specs/SE-332-handback-obligation.spec.md` |

## No modifica

- Escalación de **modelo** existente (fast→mid→agent→abort) — se mantiene ortogonal.
- `AUTONOMOUS_REVIEWER` como fallback de primer nivel.
- Subagent Scope Guard SE-146 (DONE/DONE_WITH_CONCERNS/BLOCKED) — la handback
  obligation lo consume, no lo reemplaza.
- `double-optin-protocol.md` y `maker-checker-protocol.md`.

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| script handback | `scripts/handback-resolve.sh` | Mismo script bash (sin binding de frontend) |
| reglas | `docs/rules/domain/*.md` | Leídas via CLAUDE.md lazy reference |
| tests | BATS | Mismo runner bash |

### Verification protocol

- [ ] Funciona en runtime OpenCode (bash puro, sin dependencia de hook)
- [ ] Tests BATS cubren resolución de cadena + invariante exit 5 + schema
- [ ] No añade hooks nuevos (no requiere registro en plugin `savia-gates`)

### Portability classification

- [x] **PURE_BASH**: lógica en bash + docs + BATS, sin bindings de frontend.

## Follow-up candidates (leverage de ai-project-system aún no especificado)

1. **Reference-first handoff** (SN-23) — extender `agent-notes-protocol.md` para
   mandatar handoffs por referencia en vez de eco de cuerpo (relacionado con este
   spec pero de alcance propio).
2. **Default-accept para epics limpios** (§11.6) — reducir ceremonia de artefactos
   en tribunales cuando el DoD se cumple, preservando el gate humano (Layer 8).
3. **Model-routing policy desde telemetría** — formalizar `model-routing-policy.md`
   alimentado por SE-313 telemetría (espejo del P9 `measure-token-burn` de ai-project).
4. **Execution matrix "mode is not authority"** — ratificar matriz explícita de qué
   niveles ejecutan agenticamente sin que el modo confiera autoridad de merge.

## Lesson learned (potencial)

> ai-project-system documenta el gap con honestidad: "a blocked autonomous instance
> can now hand back, normatively, with the human reached by construction rather than
> by hope". Savia hoy alcanza al humano "por esperanza" — la handback obligation lo
> convierte en garantía estructural.
