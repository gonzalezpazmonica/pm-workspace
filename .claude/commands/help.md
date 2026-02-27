---
name: help
description: Catálogo de comandos y primeros pasos pendientes.
---

Filtro: $ARGUMENTS

Aplica siempre @.claude/rules/command-ux-feedback.md

Muestra la ayuda de PM-Workspace. Pasos:

## 1. Banner de inicio

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 /help — Catálogo y estado del workspace
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 2. Primeros pasos (siempre, o si $ARGUMENTS = --setup)

Comprobar configuración y mostrar estado de cada check:

```
Verificando configuración del workspace...
```

Checks (mostrar ✅ o ❌ por cada uno):
- PAT: `test -f $HOME/.azure/devops-pat`
- Org: AZURE_DEVOPS_ORG_URL no contiene "MI-ORGANIZACION"
- PM: AZURE_DEVOPS_PM_USER no es placeholder
- Proyecto: existe `projects/*/CLAUDE.md`
- Equipo: existe `projects/*/equipo.md`
- Test: existe `output/test-workspace-*.md`

### Si hay ❌ → Modo interactivo

Para CADA check fallido, seguir este flujo:

1. Explicar qué es y por qué es necesario
2. Preguntar si quiere configurarlo ahora
3. Si dice sí → pedir el dato y guardarlo en el fichero correcto
4. Confirmar que se guardó

**PAT faltante:**
- Explicar: "El Personal Access Token permite a pm-workspace conectarse a Azure DevOps"
- Pedir: "Pega tu PAT de Azure DevOps (dev.azure.com → User Settings → Personal Access Tokens)"
- Guardar en: `$HOME/.azure/devops-pat` (sin salto de línea final)
- Verificar: longitud > 20 chars, sin espacios

**Org placeholder:**
- Explicar: "La URL de tu organización es necesaria para las llamadas a la API"
- Pedir: "¿Cuál es tu URL? Ejemplo: https://dev.azure.com/mi-empresa"
- Guardar en: CLAUDE.md → reemplazar "MI-ORGANIZACION" por el valor real

**PM user placeholder:**
- Explicar: "Tu email en Azure DevOps identifica tus items asignados"
- Pedir: "¿Cuál es tu email en Azure DevOps?"
- Guardar en: CLAUDE.md → reemplazar placeholder en AZURE_DEVOPS_PM_USER

**Proyecto faltante:**
- Explicar: "Cada proyecto necesita su propio CLAUDE.md con la configuración específica"
- Preguntar: "¿Cómo se llama tu proyecto en Azure DevOps?"
- Crear: `projects/{nombre}/CLAUDE.md` desde plantilla
- Mostrar: contenido creado para que el PM lo revise

**Equipo faltante:**
- Explicar: "equipo.md contiene los miembros y sus competencias"
- Preguntar: "¿Quieres crear el fichero de equipo ahora?"
- Si sí: pedir nombre, email y rol de cada miembro (loop hasta que diga "fin")
- Guardar: `projects/{nombre}/equipo.md`

**Test no ejecutado:**
- Explicar: "El test del workspace verifica que todo funciona"
- Preguntar: "¿Quieres ejecutar el test ahora? (puede tardar ~2 min)"
- Si sí: ejecutar `bash scripts/test-workspace.sh --mock`

### Después de resolver todos los ❌

Mostrar de nuevo el resumen actualizado:
```
✅ Verificación completada — 6/6 checks OK
```

Si todo estaba OK desde el principio:
```
✅ Workspace configurado correctamente
```

## 3. Catálogo (si $ARGUMENTS no es --setup, o después del setup)

Mostrar los comandos por categoría (nombre, params, descripción breve):

**Sprint y Reporting (10):** sprint:status, sprint:plan, sprint:review, sprint:retro, report:hours, report:executive, report:capacity, team:workload, board:flow, kpi:dashboard
**PBI y Discovery (6):** pbi:decompose {id}, pbi:decompose-batch {ids}, pbi:assign {pbi_id}, pbi:plan-sprint, pbi:jtbd {id}, pbi:prd {id}
**SDD (5):** spec:generate {task_id}, spec:implement {spec}, spec:review {spec}, spec:status, agent:run {spec}
**Calidad y PRs (4):** pr:review [PR], pr:pending [--project p], evaluate:repo [URL], changelog:update
**Equipo (3):** team:privacy-notice {nombre} --project {p}, team:onboarding {nombre} --project {p}, team:evaluate {nombre} --project {p}
**Infra (7):** infra:detect {proy} {env}, infra:plan {proy} {env}, infra:estimate {proy}, infra:scale {recurso}, infra:status {proy}, env:setup {proy}, env:promote {proy} {orig} {dest}
**Diagramas (4):** diagram:generate {proy}, diagram:import {source} --project {p}, diagram:config --tool {t}, diagram:status
**Pipelines (5):** pipeline:status --project {p}, pipeline:run --project {p} {pipeline}, pipeline:logs --project {p} --build {id}, pipeline:create --project {p} --name {n} --repo {r}, pipeline:artifacts --project {p} --build {id}
**Azure Repos (6):** repos:list --project {p}, repos:branches --project {p} --repo {r}, repos:pr-create --project {p} --repo {r}, repos:pr-list --project {p}, repos:pr-review --project {p} --pr {id}, repos:search --project {p} {query}
**Governance (5):** debt:track --project {p}, kpi:dora --project {p}, dependency:map --project {p}, retro:actions --project {p}, risk:log --project {p}
**Legacy & Capture (3):** legacy:assess --project {p}, backlog:capture --project {p} --source {tipo}, sprint:release-notes --project {p}
**Project Onboarding (5):** project:audit --project {p}, project:release-plan --project {p}, project:assign --project {p}, project:roadmap --project {p}, project:kickoff --project {p}
**DevOps Extended (5):** wiki:publish {file} --project {p}, wiki:sync --project {p}, testplan:status --project {p}, testplan:results --project {p} --run {id}, security:alerts --project {p}
**Mensajería e Inbox (6):** notify:whatsapp {contacto} {msg}, whatsapp:search {query}, notify:nctalk {sala} {msg}, nctalk:search {query}, inbox:check, inbox:start --interval {min}
**Conectores (12):** notify:slack {canal} {msg}, slack:search {query}, github:activity {repo}, github:issues {repo}, sentry:health --project {p}, sentry:bugs --project {p}, gdrive:upload {file} --project {p}, linear:sync --project {p}, jira:sync --project {p}, confluence:publish {file} --project {p}, notion:sync --project {p}, figma:extract {url} --project {p}
**Utilidades (2):** context:load, help [filtro]

Si $ARGUMENTS filtra (sprint, pbi, sdd, pr, team, infra, diagram, pipeline, repos, governance, debt, dora, risk, dependency, retro, legacy, capture, backlog, release-notes, onboarding, audit, roadmap, kickoff, wiki, testplan, security, devops, whatsapp, nctalk, nextcloud, inbox, messaging, voice, slack, github, sentry, gdrive, linear, jira, confluence, atlassian, notion, figma, connectors, --setup), mostrar solo esa sección.

## 4. Banner de fin

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /help — Fin del catálogo (81 comandos, 13 skills, 24 agentes)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 5. Restricciones

- Solo lectura (salvo modo interactivo de --setup)
- No mostrar secrets (PAT, tokens)
- El modo interactivo SOLO modifica ficheros de configuración, nunca código
