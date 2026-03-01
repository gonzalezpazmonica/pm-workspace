---
name: stakeholder-report
description: Informe para stakeholders — progreso por epics, roadmap visual, riesgos
developer_type: all
agent: none
context_cost: medium
---

# /stakeholder-report

> 🦉 Savia genera informes claros para stakeholders no técnicos.

---

## Cargar perfil de usuario

Grupo: **Reporting** — cargar:

- `identity.md` — nombre, empresa
- `preferences.md` — language, report_format, date_format
- `projects.md` — proyecto(s) a reportar
- `tone.md` — formality (stakeholders = formal)

---

## Subcomandos

- `/stakeholder-report` — informe completo del período actual
- `/stakeholder-report --epic {nombre}` — progreso de un epic específico
- `/stakeholder-report --roadmap` — vista de roadmap con timeline
- `/stakeholder-report --risks` — solo sección de riesgos

---

## Flujo

### Paso 1 — Recopilar estado de epics

Para cada epic activo del proyecto:

| Epic | Progreso | PBIs Done | PBIs WIP | PBIs Pending | ETA |
|---|---|---|---|---|---|
| {epic 1} | ████░░ 67% | 8 | 2 | 2 | Sprint 5 |
| {epic 2} | ██░░░░ 33% | 4 | 3 | 5 | Sprint 7 |

### Paso 2 — Generar roadmap visual

```
Roadmap — {proyecto} — {fecha}

  Q1 2026          Q2 2026          Q3 2026
  ─────────────────────────────────────────
  ████████████░░░  Epic 1 (67%)
       ████░░░░░░░░░░░  Epic 2 (33%)
                   ░░░░░░░░  Epic 3 (planificado)
```

### Paso 3 — Resumen ejecutivo

```
📋 Resumen para Stakeholders — {fecha}

Proyecto: {nombre}
Período: Sprint {N} ({fecha inicio} — {fecha fin})

✅ Logros del período:
  - {logro 1 en lenguaje de negocio}
  - {logro 2}

🔄 En progreso:
  - {feature en curso + ETA}

⚠️ Riesgos y dependencias:
  - {riesgo 1} — Mitigación: {acción}
  - {dependencia externa} — Estado: {estado}

📅 Próximos hitos:
  - {hito 1} — {fecha estimada}
```

### Paso 4 — Adaptar lenguaje

Traducir términos técnicos a lenguaje de negocio:
- "Sprint velocity" → "ritmo de entrega"
- "Technical debt" → "mejoras de infraestructura pendientes"
- "Bug fix" → "corrección de incidencia"
- "Deploy" → "puesta en producción"

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: stakeholder_report
project: sala-reservas
epics_active: 3
overall_progress: 52%
risks: 2
next_milestone: "Sprint 5 — Módulo reservas"
output_file: output/reports/stakeholder-2026-03-01.md
```

---

## Restricciones

- **NUNCA** usar jerga técnica sin traducir — el público es no técnico
- **NUNCA** minimizar riesgos — transparencia ante todo
- **NUNCA** incluir métricas técnicas (cobertura, coupling, etc.)
- Tono profesional y orientado a resultados de negocio
- Progreso siempre con evidencia (PBIs completados, no estimaciones)
