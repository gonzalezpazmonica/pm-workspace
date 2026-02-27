# Métricas y KPIs

| KPI | Descripción | Umbral OK |
|-----|-------------|-----------|
| Velocity | Story Points completados por sprint | > media últimos 5 sprints |
| Burndown | Progreso vs plan del sprint | Dentro del rango ±15% |
| Cycle Time | Días desde "Active" hasta "Done" | < 5 días (P75) |
| Lead Time | Días desde "New" hasta "Done" | < 12 días (P75) |
| Capacity Utilization | % de capacity usada | 70-90% (🟢), >95% (🔴) |
| Sprint Goal Hit Rate | % de sprints que cumplen el objetivo | > 75% |
| Bug Escape Rate | Bugs en producción / total completado | < 5% |
| SDD Agentización | % de tasks técnicas implementadas por agente | Objetivo: > 60% |

---

## Reglas Críticas

### Gestión de proyectos
1. **El PAT nunca se hardcodea** — siempre `$(cat $AZURE_DEVOPS_PAT_FILE)`
2. **Filtrar siempre por IterationPath** en queries WIQL, salvo petición explícita
3. **Confirmar antes de escribir** en Azure DevOps — Claude pregunta antes de modificar datos
4. **Leer el CLAUDE.md del proyecto** antes de actuar sobre él
5. **La Spec es el contrato** — no se implementa sin spec aprobada (ni humanos ni agentes)
6. **El Code Review (E1) es siempre humano** — sin excepciones, nunca a un agente
7. **"Si el agente falla, la Spec no era suficientemente buena"** — mejorar la spec, no saltarse el proceso

### Calidad de código (ver `.claude/rules/{lang}-conventions.md`)
8. **Verificar siempre**: build + test del lenguaje del proyecto antes de dar una tarea por hecha
9. **Secrets**: NUNCA connection strings, API keys o passwords en el repositorio — usar vault o `config.local/` (git-ignorado)
10. **Infraestructura**: NUNCA `terraform apply` en PRE/PRO sin aprobación humana; siempre tier mínimo; detectar antes de crear

### Buenas prácticas Claude Code (ver `docs/best-practices-claude-code.md`)
11. **Explorar → Planificar → Implementar → Commit** — usar `/plan` para separar investigación de ejecución
12. **Gestión activa del contexto** — `/compact` al 50%, `/clear` entre tareas no relacionadas
13. **Si Claude corrige el mismo error 2+ veces** — `/clear` y reformular el prompt
14. **README actualizado** — reflejar cambios estructurales o de herramientas antes del commit

### Git workflow (ver `.claude/rules/github-flow.md`)
15. **Nunca commit directo en `main`** — todo cambio pasa por rama + Pull Request + revisión

---

## Roadmap de Adopción

| Semanas | Fase | Objetivo |
|---------|------|----------|
| 1-2 | Configuración | Conectar con Azure DevOps, probar `/sprint-status` |
| 3-4 | Gestión básica | Iterar con `/sprint-plan`, `/team-workload`, ajustar constantes |
| 5-6 | Reporting | Activar `/report-hours` y `/report-executive` con datos reales |
| 7-8 | SDD piloto | Generar primeras specs, probar agente con 1-2 tasks de Application Layer |
| 9+ | SDD a escala | Objetivo: 60%+ de tasks técnicas repetitivas implementadas por agentes |

---
