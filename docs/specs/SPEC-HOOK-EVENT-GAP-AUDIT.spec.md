# Spec: Hook Event Gap Audit — Auditar eventos no cubiertos

**Task ID:**        SPEC-HOOK-EVENT-GAP-AUDIT
**PBI padre:**      Hook coverage improvement (research: claude-code-from-source)
**Sprint:**         2026-15
**Fecha creacion:** 2026-04-10
**Creado por:**     Savia (research: claude-code-from-source Ch12)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     3h
**Estado:**         Pendiente
**Prioridad:**      MEDIA
**Max turns:**      20
**Modelo:**         claude-sonnet-4-6

---

## 1. Contexto y motivacion

Claude Code expone 28 eventos de hooks en 4 tipos de ejecucion: shell,
single-shot LLM prompt, multi-turn agent conversation, HTTP webhook. Los hooks
pueden bloquear tool execution, modificar inputs, inyectar contexto y
short-circuit el query loop.

pm-workspace cubre actualmente 17/28 eventos (61%), documentado en
`docs/rules/domain/async-hooks-config.md`. Hay 11 eventos no cubiertos.
Necesitamos auditar cuales tienen valor real para Savia y cuales descartar
con justificacion documentada.

Fuente: https://claude-code-from-source.com/ch12-extensibility/

## 2. Objetivo

Generar `output/hook-event-gap-audit.md` con analisis de los 11 eventos no
cubiertos, clasificacion por valor (HIGH/MEDIUM/LOW/SKIP) y plan de
implementacion para los HIGH. Implementar los HIGH en hooks concretos y
actualizar la documentacion.

## 3. Requisitos funcionales

- **REQ-01** Script `scripts/hook-event-gap-audit.sh` que:
  - Lee `.claude/settings.json` y extrae los hook events configurados
  - Lee el catalogo de eventos en `docs/rules/domain/async-hooks-config.md`
  - Lista los eventos no cubiertos
  - Genera tabla markdown con columnas: event, tipo, descripcion, valor (HIGH/MEDIUM/LOW/SKIP), justificacion
- **REQ-02** Auditoria manual de los 11 gaps con decision:
  - **Implementar**: eventos con valor claro para Savia (probablemente 3-5)
  - **Diferir**: eventos con valor condicional
  - **Descartar**: eventos sin aplicacion en pm-workspace
- **REQ-03** Para cada evento HIGH, crear un hook concreto en `.claude/hooks/`
  con tier correcto (minimal/standard/strict) y registrar en `settings.json`.
- **REQ-04** Actualizar `docs/rules/domain/async-hooks-config.md` con la
  nueva cobertura y los eventos descartados con justificacion.
- **REQ-05** Eventos candidatos a evaluar:
  `PermissionRequest`, `Notification`, `SessionPause`, `SessionResume`,
  `MCPServerStart`, `MCPServerStop`, `ToolError`, `FileWriteRejected`,
  `AgentRetry`, `ContextWarning`, `MCPMessage`.
- **REQ-06** Output final: `output/hook-event-gap-audit.md` con conclusiones
  accionables.

## 4. Criterios de aceptacion

- **AC-01** `bash scripts/hook-event-gap-audit.sh` genera el informe sin error.
- **AC-02** El informe lista los 11 eventos no cubiertos con decision de cada uno.
- **AC-03** Al menos 3 eventos clasificados HIGH tienen un hook correspondiente
  implementado en `.claude/hooks/`.
- **AC-04** `docs/rules/domain/async-hooks-config.md` refleja la nueva
  cobertura (>=75% = 21/28 eventos).
- **AC-05** Los nuevos hooks implementados tienen test BATS correspondiente.
- **AC-06** CI quality gate sigue pasando tras los cambios.

## 5. Test scenarios

1. **Audit script execution**: ejecuta el script y verifica que genera
   `output/hook-event-gap-audit.md`.
2. **Gap count**: el informe identifica 11 eventos no cubiertos inicialmente.
3. **Classification**: cada gap tiene una clasificacion (HIGH/MEDIUM/LOW/SKIP).
4. **HIGH implementation**: los eventos HIGH tienen hook .sh correspondiente.
5. **Documentation update**: `async-hooks-config.md` actualizado con nueva tabla.
6. **Settings.json valid**: JSON sigue siendo valido tras añadir hooks.

## 6. Arquitectura / ficheros afectados

**Nuevos:**
- `scripts/hook-event-gap-audit.sh` (~100 lineas)
- `output/hook-event-gap-audit.md` (informe generado)
- 3-5 nuevos hooks en `.claude/hooks/` (segun clasificacion HIGH)
- `tests/test-hook-event-gap-audit.bats`

**Modificados:**
- `docs/rules/domain/async-hooks-config.md`: actualizar cobertura
- `.claude/settings.json`: añadir hooks HIGH
- `CHANGELOG.md`

## 7. Ejemplo de output esperado

```markdown
# Hook Event Gap Audit — 2026-04-10

## Cobertura actual
17/28 eventos (61%)

## Gaps analizados

| Event | Tipo | Descripcion | Valor | Decision |
|---|---|---|---|---|
| PermissionRequest | shell | Antes de pedir permiso al user | HIGH | Implementar |
| Notification | shell | Al emitir notificacion nativa | MEDIUM | Diferir |
| MCPServerStart | shell | Cuando un MCP server inicia | LOW | Descartar — pocos MCPs locales |
| ... |

## Nueva cobertura objetivo
21/28 eventos (75%)

## Hooks a implementar
1. permission-request-audit.sh (event: PermissionRequest)
2. tool-error-telemetry.sh (event: ToolError)
3. context-warning-prelim.sh (event: ContextWarning)
```

## 8. Fuera de alcance

- No implementa eventos MEDIUM ni LOW (solo documenta la decision).
- No reescribe hooks existentes.
- No cambia el formato de settings.json mas alla de añadir entradas.

## 9. Referencias

- [claude-code-from-source Ch12](https://claude-code-from-source.com/ch12-extensibility/)
- [Claude Code hooks docs](https://code.claude.com/docs/en/hooks)
- `docs/rules/domain/async-hooks-config.md`
- `docs/rules/domain/intelligent-hooks.md`
