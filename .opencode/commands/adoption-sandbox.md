---
name: adoption-sandbox
description: Entorno seguro de práctica — experimentar con Savia sin miedo a errores
developer_type: all
agent: task
context_cost: high
---

# /adoption-sandbox

> 🦉 "Prueba todo, no pasa nada." Sandbox aislado con datos ficticios.

Experimentar libremente sin riesgo: datos de prueba, sin Azure DevOps real, sin commits.

---

## Objetivo

Que los devs y PMs practiquen comandos de Savia con total seguridad antes de usarlos
en producción. Feedback inmediato. Sin estrés.

---

## Estructura del Sandbox

```
sandbox/
├── projects/
│   └── sandbox-demo/
│       ├── CLAUDE.md                ← Config sandbox
│       ├── equipo.md                ← Team ficticio
│       ├── reglas-negocio.md        ← Domain model ficticio
│       └── data/
│           ├── sprints.json         ← Sprint data ficticios
│           ├── work-items.json      ← PBIs/Tasks ficticias
│           └── board-state.json     ← Board snapshot
├── docs/
│   └── sandbox-guide.md             ← Guía de qué experimentar
└── .env.sandbox                     ← Vars de entorno sandbox
```

---

## Flujo

### Paso 1 — Crear sandbox project
- Crear `projects/sandbox-demo/` con estructura estándar
- Generar datos de prueba: 2 sprints ficticios, 20 PBIs, 5 personas
- Configura `AZURE_DEVOPS_PROJECT` en `.env.sandbox` → null/offline
- Copiar plantillas de specs, diagramas, para experimentar

### Paso 2 — Habilitar comandos en "safe mode"
- Todos los comandos ejecutan pero NO afectan:
  - Azure DevOps real (queries simuladas)
  - Repos reales (cambios en memoria, no commits)
  - Informes reales (generados en `sandbox/output/`)
- Mostrar banner: ⚠️ SANDBOX MODE — cambios no persisten

### Paso 3 — Invitar a experimentar
- "Intenta `/sprint-status` aquí — sin riesgo"
- "Crea un PBI ficticio con `/pbi-create`"
- "Genera una spec ficticia con `/spec-generate`"
- "Escribe código en el sandbox sin commits"
- Feedback inmediato: ✅ esto funcionaría, 🔴 aquí te equivocarías

### Paso 4 — Rastrear experimentos
- Log: `sandbox/usage-log.json` con cada comando ejecutado
- Qué intentó: suceso/error
- Duración: ¿rápido o lento?
- Feedback: ¿comprensible? ¿útil?

### Paso 5 — Feedback post-sesión
- Resumen: "Ejecutaste 12 comandos, 11 éxito, 1 confusión"
- Áreas de mejora: "La `/pbi-create` podría ser más clara"
- Siguiente paso: "¿Listo para usar esto en tu proyecto real?"

---

## Comandos Recomendados en Sandbox (Beginner)

1. `/sprint-status` → ver dashboard ficticio
2. `/pbi-create` → crear PBI sin afectar Azure DevOps
3. `/spec-generate` → generar spec para feature ficticia
4. `/qa-dashboard` → ver métricas de calidad simuladas
5. `/risk-predict` → análisis de riesgos con datos de prueba

---

## Output

- Log de sesión: `sandbox/session-{YYYYMMDD-HHMMSS}.json`
- Informe de retroalimentación: `output/sandbox-feedback-{usuario}-YYYYMMDD.md`
- Suggestions para próximo comando a aprender
- Invitación: "¿Listo para usar Savia en tu proyecto?" → `/adoption-plan`

---

## Restricciones

- NUNCA escribir en Azure DevOps real desde sandbox
- NUNCA hacer commits reales desde sandbox
- Todo sandbox es local — no sincronizar con origen
- Borrar sandbox cada 7 días (datos de prueba)
