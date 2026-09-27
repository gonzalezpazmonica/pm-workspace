---
context_tier: L2
token_budget: 1500
---

# Seguridad en modos autónomos — referencia

> Anexo bajo demanda de `autonomous-safety.md` (SPEC-181). Los gates viven en
> el núcleo, que se carga al arrancar; aquí está el detalle operativo. Leer
> cuando se lance, audite o depure un run autónomo.

### Convención de ramas autónomas

| Modo | Patrón de rama | Ejemplo |
|------|----------------|---------|
| Overnight Sprint | `agent/overnight-{YYYYMMDD}-{tarea}` | `agent/overnight-20260312-fix-linter-warnings` |
| Code Improvement | `agent/improve-{tipo}-{id}` | `agent/improve-coverage-auth-service` |
| Tech Research | `agent/research-{tema}` | `agent/research-ef-alternatives` |

## Reglas de investigación — Notificación humana

```
NUNCA  → Crear tareas en el backlog sin aprobación
NUNCA  → Modificar configuración del proyecto basándose en hallazgos
NUNCA  → Instalar dependencias nuevas

SIEMPRE → Generar informe en output/research/{tema}-{YYYYMMDD}.md
SIEMPRE → Notificar a AUTONOMOUS_RESEARCH_NOTIFY al completar
SIEMPRE → Las recomendaciones son PROPUESTAS, no acciones
```

## Configuración requerida

`AUTONOMOUS_REVIEWER` y `AUTONOMOUS_RESEARCH_NOTIFY` se resuelven en runtime
desde **fuentes locales gitignored** (NUNCA del repo público — Rule #20):

```
1) .claude/rules/pm-config.local.md  (gitignored)
2) ~/.savia/preferences.yaml          (SPEC-127)
3) Slug del usuario activo en .claude/profiles/active-user.md (fallback genérico "@local-user")
```

scripts/savia-env.sh expone `savia_autonomous_reviewer()` que aplica esta cadena.
### Gate de arranque

Reviewer distinto elegible: solicitar revisión. Si la operadora autenticada es
la única colaboradora, usar PR Draft y revisión propia con CI y grant expreso;
GitHub rechaza self-review. Sin operadora ni reviewer elegible: abortar.

## Auditoría

Cada sesión autónoma genera `output/agent-runs/{modo}-{fecha}-audit.log`. Campos mínimos:
- Timestamp inicio/fin
- Tareas intentadas (pr-created / discarded / crash / timeout)
- Ramas creadas · PRs creados (URLs) · métricas agregadas
- Razón de parada (completado / max-tasks / max-failures / timeout global / abort manual)
- `handback_to` — a quién se escaló en cada handback (SE-332; vacío si no hubo escalación)

## Auto Mode — Capa complementaria (Claude Code 2026-03-24)

`claude --enable-auto-mode` bloquea acciones destructivas pre-tool-call. NO
reemplaza esta regla; añade defensa en profundidad (Settings → Auto Mode).
Ref: anthropic.com/engineering/claude-code-auto-mode

## Escalamiento de modelo

Si un agente falla consecutivamente en una tarea:
- Intento 1: tier `fast`
- Intento 2: tier `mid`
- Intento 3: tier `heavy`
- Intento 4+: ABORT — registrar como "requiere intervención humana"

OOM, timeout o error de infra: NO escalar — descartar y continuar.

## Emergency-mode (LocalAI fallback) — SPEC-122

`/emergency-mode` cambia SOLO el endpoint (`ANTHROPIC_BASE_URL` → LocalAI), **no bypassa** los gates. Rama `agent/*`, PR Draft y revisión de la operadora o reviewer elegible siguen obligatorios. Ver `emergency-mode/SKILL.md` y `emergency-mode-protocol.md`.

## Subagent Scope Guard — SE-146

Cuando un agente o skill se invoca como **subagente delegado** (recibe una tarea concreta desde un orquestador), debe:

```
1. EJECUTAR solo la tarea asignada — sin activar workflows de orquestación completos
2. REPORTAR resultado: DONE | DONE_WITH_CONCERNS | BLOCKED
3. RETORNAR — no continuar en bucle ni lanzar sub-agentes adicionales
```

**Por qué**: las skills de alto impacto (overnight-sprint, code-improvement-loop, adversarial-security, etc.) tienen bucles de orquestación que, activados íntegramente por un subagente, generan runs en cascada fuera de control.

**Detección de contexto subagente**: tarea vía `Task` tool, env `SAVIA_SUBAGENT=1`, o flag `--subagent` → aplicar este guard. **Skills con este guard**: adversarial-security, code-improvement-loop, consensus-validation, dag-scheduling, overnight-sprint, spec-driven-development, tdd-vertical-slices, verification-lattice.

## Handback Obligation — SE-332

Instancia autónoma bloqueada **escala a su padre inmediato, un nivel a la vez**; toda cadena termina en manual **POR CONSTRUCCIÓN**. Resolución: `scripts/handback-resolve.sh`. Handback **reference-first** (`contexto_ref` solo rutas), `termination_reason: handback` (exit 6), `handback_to` en audit. Cadena por modo y schema: `agent-handoff-protocol.md`, `terminal-state-protocol.md`, spec SE-332.

## Doble opt-in para skills autónomas — SPEC-186

Era 199 Wave 1. Toda skill autónoma exige **dos confirmaciones independientes** en cada invocación: variable de entorno persistente Y flag `--confirm-autonomous`. Helper canónico:
```
bash scripts/savia-double-optin-check.sh --skill <nombre> --confirm-autonomous
```
Detalle completo (mapeo skill→variable, auditoría, bypass de tests, exit codes): ver `docs/rules/domain/double-optin-protocol.md`. Modos L2+: `maker-checker-protocol.md` + `loop-verify.sh`.

## Dual Pool — Proposal vs Result State (SE-235)
Proposal = rama `agent/*` o nido no mergeado. Result = en main con PR aprobado humano. Ver `SE-235-dual-pool-proposal-result.md`.
