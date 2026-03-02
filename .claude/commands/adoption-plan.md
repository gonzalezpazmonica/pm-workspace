---
name: adoption-plan
description: Plan personalizado de adopción de Savia por rol — qué aprender, en qué orden
developer_type: all
agent: task
context_cost: medium
---

# /adoption-plan

> 🦉 Roadmap de aprendizaje personalizado: "Tú eres {rol}, empieza por aquí".

Cada rol tiene una ruta diferente para máxima productividad rápido.

---

## Roles Soportados

- **PM / Scrum Master** — Sprint, backlog, reportes
- **Tech Lead** — Architecture, PRs, deuda técnica
- **Developer** — Code patterns, specs, workflows
- **QA Engineer** — Testing, coverage, regression
- **Product Owner** — Outcomes, value, stakeholder alignment
- **DevOps** — Infrastructure, pipelines, integrations
- **CEO / CTO** — Portfolio, metrics, strategy

---

## Estructura de Learning Path

```
Nivel 1: Beginner (Semana 1-2)
├─ Comandos "watch-only" (no escriben en Azure DevOps)
├─ Dashboard viewing: /sprint-status, /team-workload, /qa-dashboard
└─ Goal: Familiaridad sin riesgo

Nivel 2: Intermediate (Semana 3-4)
├─ Comandos que leen + crean borradores
├─ PBI planning, spec generation, PR reviews
└─ Goal: Participación segura en sprint

Nivel 3: Advanced (Semana 5-8)
├─ SDD agent orchestration, infra provisioning
├─ Autonomía en fljos complejos
└─ Goal: Power user + mentor
```

---

## Flujo

### Paso 1 — Detectar rol del usuario
- Leer `identity.md` (si existe)
- Si no: preguntar interactivamente

### Paso 2 — Cargar rol-workflow
- Por rol: consultar `@.claude/rules/domain/role-workflows.md`
- Extraer comandos prioritarios para ese rol

### Paso 3 — Seleccionar comandos por nivel
- **L1 (Beginner)**: Top 3 comandos lectura pura
- **L2 (Intermediate)**: Top 4 comandos lectura+escritura
- **L3 (Advanced)**: Top 3 comandos complejos + skills

### Paso 4 — Crear hitos y milestones
- Semana 1: Ejecutar todos L1 (6 comandos)
- Semana 2-3: Practicar L2 sin commit
- Semana 4: Usar L2 en sprint real
- Semana 5-8: L3 bajo supervisión → autonomía
- Métrica: "3 usos exitosos sin ayuda" = dominado

### Paso 5 — Generar roadmap personal
- Fichero `adoption-plan-{rol}-{YYYYMMDD}.md`
- Incluir: comandos, orden, objetivos por semana, criterios éxito
- Sugerir: pairing sessions con mentor (si hay early adopters)

---

## Output

- Tabla de comandos por nivel (L1/L2/L3) con descripciones
- Timeline visual: 8 semanas con hitos semanales
- Criterios de éxito (demos, PRs mergeados, etc.)
- Sugerencia de mentor (si existe equipo adoptante)
- Guardar en `output/adoption-plan-{rol}-{proyecto}-YYYYMMDD.md`

---

## Restricciones

- Máximo 3 comandos nuevos/semana (no sobrecargar)
- Siempre Beginner→Intermediate→Advanced (sin saltos)
- Evitar comandos que modifiquen repos hasta L2
