# Hoja de Ruta: Optimización de Contexto en pm-workspace

**Por Savia** — Marzo 2026 · Derivada del artículo de Ingeniería de Contexto Sináptica

> 🦉 Las fases de optimización de contexto (1-7) están completadas. Ahora expandimos con features específicas por rol.

---

## Estado Actual (v0.44.0)

Todas las optimizaciones de contexto Fase 1-7 completadas (detalle en `context-optimization-completed.md`):

- ✅ Context-Map Dinámico (v0.40.0) · ✅ Compresión Session-Init (v0.41.0)
- ✅ Pre-compactación CLAUDE.md (v0.41.0) · ✅ Subagentes con Budget (v0.42.0)
- ✅ Context Aging (v0.43.0) · ✅ Posicionamiento Verificado (v0.43.0)
- ✅ Hub Semántico (v0.44.0)

---

## Próximas Fases — Role-Specific Features

### Fase 8 — Informes Ejecutivos por Rol (v0.45.0)

**Roles beneficiados:** CEO/CTO, Product Owner

1. **`/ceo-report`** — Informe ejecutivo multi-proyecto: portfolio status, risk exposure, team utilization, budget burn, delivery velocity trend. Output: PDF/PPTX para comité de dirección.
2. **`/ceo-alerts`** — Alertas estratégicas: proyectos en riesgo, equipos con burnout, deuda técnica acumulada, sprints fallidos consecutivos. Solo alertas que requieren decisión de dirección.
3. **`/portfolio-overview`** — Vista bird's-eye: semáforo por proyecto, velocidad comparada, dependencias inter-proyecto.

---

### Fase 9 — Toolkit QA y Testing (v0.46.0)

**Roles beneficiados:** QA Engineer, Tech Lead

1. **`/qa-dashboard`** — Dashboard de calidad: cobertura por módulo, tests flaky, bugs por severidad, escape rate, test execution trends.
2. **`/qa-regression-plan`** — Plan de regresión basado en ficheros cambiados: impacto de cambios → suites a ejecutar.
3. **`/qa-bug-triage`** — Triage asistido: clasificación, detección de duplicados, sugerencia de asignación.
4. **`/testplan-generate`** — Generación de plan de pruebas desde specs SDD o PBIs.

---

### Fase 10 — Developer Productivity (v0.47.0)

**Roles beneficiados:** Developer, Tech Lead

1. **`/my-sprint`** — Vista personal: items asignados, progreso, cycle time personal, PRs pendientes.
2. **`/my-focus`** — Modo focus: identifica item más prioritario, carga contexto relevante, elimina distracciones.
3. **`/my-learning`** — Detección de tech stack gaps: código del developer vs. best practices del proyecto.
4. **`/code-patterns`** — Catálogo de patterns del proyecto con ejemplos del propio código.

---

### Fase 11 — Tech Lead Intelligence (v0.48.0)

**Roles beneficiados:** Tech Lead, CEO/CTO

1. **`/tech-radar`** — Radar tecnológico: librerías, versiones, categorización adopt/trial/hold/retire.
2. **`/team-skills-matrix`** — Skills del equipo: quién sabe qué, bus factor por módulo, pair programming.
3. **`/arch-health`** — Salud arquitectónica: fitness functions, drift detection, coupling metrics.
4. **`/incident-postmortem`** — Template de postmortem: timeline, root cause, action items.

---

### Fase 12 — Product Owner Analytics (v0.49.0)

**Roles beneficiados:** Product Owner, CEO/CTO

1. **`/value-stream-map`** — Mapa de valor end-to-end: idea→producción, waste, cuellos de botella.
2. **`/feature-impact`** — Impacto de features: esfuerzo vs. valor, features con mejor ROI.
3. **`/stakeholder-report`** — Informe para stakeholders: progreso por epics, roadmap visual, riesgos.
4. **`/release-readiness`** — Checklist de release: features, tests, docs, compliance, deployment.

---

## Priorización

| Fase | Versión | Impacto | Esfuerzo | Prioridad |
|---|---|---|---|---|
| Informes Ejecutivos (CEO) | v0.45.0 | Alto | Medio | 🟢 Alta |
| Toolkit QA y Testing | v0.46.0 | Alto | Medio | 🟢 Alta |
| Developer Productivity | v0.47.0 | Medio | Medio | 🟡 Media |
| Tech Lead Intelligence | v0.48.0 | Medio | Alto | 🟡 Media |
| Product Owner Analytics | v0.49.0 | Medio | Alto | 🟠 Baja |

---

## Métricas de Éxito

1. **Tokens por sesión promedio**: Reducir un 20% sin pérdida de funcionalidad
2. **Comandos por sesión**: Mantener o aumentar (~8-10)
3. **Precisión de respuestas**: Medir con `/context-benchmark`
4. **Adopción por rol**: Cada rol usa ≥3 comandos específicos por sesión

---

*🦉 Esta hoja de ruta se revisará con cada release.*
