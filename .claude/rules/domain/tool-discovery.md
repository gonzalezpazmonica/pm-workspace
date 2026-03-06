---
name: tool-discovery
description: Agrupación semántica de 360+ comandos en capability groups para reducir tool overload
auto_load: false
paths: []
---

# Regla: Tool Discovery — Capability Groups

> Fuente: AI Engineering Guidebook (2025) p.270-275 — "More tools ≠ better results."

---

## Problema

pm-workspace tiene 360+ comandos. Cuando un agente o el NL-resolver necesitan
elegir qué herramienta usar, procesar todo el catálogo degrada la precisión.
El Guidebook documenta que limitar herramientas visibles mejora el acierto.

---

## Solución: Capability Groups

Agrupar comandos en ~15 grupos semánticos. Al resolver una petición,
primero identificar el grupo relevante, luego buscar dentro de ese grupo.

---

## Grupos definidos

| Grupo | Prefijos | Ejemplo de comandos |
|---|---|---|
| **sprint** | sprint-, daily-, velocity- | sprint-plan, daily-generate |
| **project** | project-, onboard- | project-audit, project-release-plan |
| **backlog** | pbi-, backlog-, task- | pbi-create, backlog-prioritize |
| **architecture** | arch-, adr-, diagram- | arch-review, adr-create |
| **debt** | debt-, legacy- | debt-track, legacy-assess |
| **security** | security-, a11y-, aepd- | security-review, a11y-audit |
| **testing** | test-, spec-verify-, coverage- | test-run, spec-verify-ui |
| **devops** | pipeline-, deploy-, infra- | pipeline-status, deploy-check |
| **reporting** | report-, executive-, dora- | report-sprint, dora-metrics |
| **risk** | risk-, incident- | risk-log, incident-postmortem |
| **team** | team-, capacity-, wellbeing- | team-health, capacity-plan |
| **memory** | memory-, context-, nl- | memory-recall, context-load |
| **ai-governance** | ai-, adoption-, agent- | ai-exposure-audit, agent-trace |
| **communication** | msg-, voice-, community- | msg-send, voice-inbox |
| **spec-driven** | spec-, sdd-, implement- | spec-generate, sdd-status |

---

## Protocolo de uso

### Para NL-resolver (nl-command-resolution.md)

1. Analizar la petición del usuario
2. Identificar el capability group (1-2 grupos máximo)
3. Buscar dentro del grupo (reducido a ~20-25 comandos)
4. Si no hay match → ampliar a grupos adyacentes

### Para subagentes

Los agentes deberían recibir solo los comandos de su grupo:
- `business-analyst` → sprint, backlog, reporting
- `architect` → architecture, debt, security
- `tester` → testing, spec-driven
- `developer-*` → spec-driven, devops, testing

### Para el usuario

`/help --group {nombre}` puede listar comandos del grupo con descripciones.

---

## Reglas de asignación

1. Un comando pertenece al grupo de su prefijo principal
2. Comandos sin prefijo claro → asignar por funcionalidad
3. Nuevos comandos DEBEN especificar grupo en su frontmatter (futuro)
4. Máximo 30 comandos por grupo — si se excede, subdividir

---

## Métricas

Medir eficacia via `/eval-output --agent-trace`:
- ¿El agente seleccionó el comando correcto al primer intento?
- ¿Cuántos intentos necesitó?
- ¿El grupo correcto se identificó en el primer paso?
