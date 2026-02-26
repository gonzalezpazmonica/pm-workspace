---
name: help
description: Catálogo de comandos y primeros pasos pendientes.
---

Filtro: $ARGUMENTS

Muestra la ayuda de PM-Workspace. Pasos:

1. **Primeros pasos** — comprueba si falta configuración:
   - PAT: `test -f $HOME/.azure/devops-pat`
   - Org: AZURE_DEVOPS_ORG_URL no contiene "MI-ORGANIZACION"
   - PM: AZURE_DEVOPS_PM_USER no es placeholder
   - Proyecto: existe `projects/*/CLAUDE.md`
   - Equipo: existe `projects/*/equipo.md`
   - Test: existe `output/test-workspace-*.md`
   Si hay pendientes, listarlos con ⬜/✅. Si todo OK → "✅ Workspace configurado".

2. **Catálogo** — muestra los comandos por categoría (nombre, params, descripción breve):

   **Sprint y Reporting (10):** sprint:status, sprint:plan, sprint:review, sprint:retro, report:hours, report:executive, report:capacity, team:workload, board:flow, kpi:dashboard
   **PBI y Discovery (6):** pbi:decompose {id}, pbi:decompose-batch {ids}, pbi:assign {pbi_id}, pbi:plan-sprint, pbi:jtbd {id}, pbi:prd {id}
   **SDD (5):** spec:generate {task_id}, spec:implement {spec}, spec:review {spec}, spec:status, agent:run {spec}
   **Calidad y PRs (4):** pr:review [PR], pr:pending [--project p], evaluate:repo [URL], changelog:update
   **Equipo (3):** team:privacy-notice {nombre} --project {p}, team:onboarding {nombre} --project {p}, team:evaluate {nombre} --project {p}
   **Infra (7):** infra:detect {proy} {env}, infra:plan {proy} {env}, infra:estimate {proy}, infra:scale {recurso}, infra:status {proy}, env:setup {proy}, env:promote {proy} {orig} {dest}
   **Diagramas (4):** diagram:generate {proy}, diagram:import {source} --project {p}, diagram:config --tool {t}, diagram:status
   **Utilidades (2):** context:load, help [filtro]

   Si $ARGUMENTS filtra (sprint, pbi, sdd, pr, team, infra, diagram, --setup), mostrar solo esa sección.

3. **Solo lectura** — no modificar ficheros. No mostrar secrets.
