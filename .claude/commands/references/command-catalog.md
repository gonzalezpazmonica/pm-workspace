# Catálogo de Comandos PM-Workspace (84)

> Este fichero se carga bajo demanda (desde `/help` o consultas de catálogo).
> NO se auto-carga en el contexto.

## Sprint y Reporting (10)
`/sprint-status` · `/sprint-plan` · `/sprint-review` · `/sprint-retro` · `/report-hours` · `/report-executive` · `/report-capacity` · `/team-workload` · `/board-flow` · `/kpi-dashboard`

## PBI y Discovery (6)
`/pbi-decompose {id}` · `/pbi-decompose-batch {ids}` · `/pbi-assign {pbi_id}` · `/pbi-plan-sprint` · `/pbi-jtbd {id}` · `/pbi-prd {id}`

## SDD (5)
`/spec-generate {task_id}` · `/spec-implement {spec}` · `/spec-review {spec}` · `/spec-status` · `/agent-run {spec}`

## Calidad y PRs (4)
`/pr-review [PR]` · `/pr-pending [--project p]` · `/evaluate-repo [URL]` · `/changelog-update`

## Equipo (3)
`/team-privacy-notice {nombre} --project {p}` · `/team-onboarding {nombre} --project {p}` · `/team-evaluate {nombre} --project {p}`

## Infra (7)
`/infra-detect {proy} {env}` · `/infra-plan {proy} {env}` · `/infra-estimate {proy}` · `/infra-scale {recurso}` · `/infra-status {proy}` · `/env-setup {proy}` · `/env-promote {proy} {orig} {dest}`

## Diagramas (4)
`/diagram-generate {proy}` · `/diagram-import {source} --project {p}` · `/diagram-config --tool {t}` · `/diagram-status`

## Pipelines (5)
`/pipeline-status --project {p}` · `/pipeline-run --project {p} {pipeline}` · `/pipeline-logs --project {p} --build {id}` · `/pipeline-create --project {p} --name {n} --repo {r}` · `/pipeline-artifacts --project {p} --build {id}`

## Azure Repos (6)
`/repos-list --project {p}` · `/repos-branches --project {p} --repo {r}` · `/repos-pr-create --project {p} --repo {r}` · `/repos-pr-list --project {p}` · `/repos-pr-review --project {p} --pr {id}` · `/repos-search --project {p} {query}`

## Governance (5)
`/debt-track --project {p}` · `/kpi-dora --project {p}` · `/dependency-map --project {p}` · `/retro-actions --project {p}` · `/risk-log --project {p}`

## Legacy & Capture (3)
`/legacy-assess --project {p}` · `/backlog-capture --project {p} --source {tipo}` · `/sprint-release-notes --project {p}`

## Project Onboarding (5)
`/project-audit --project {p}` · `/project-release-plan --project {p}` · `/project-assign --project {p}` · `/project-roadmap --project {p}` · `/project-kickoff --project {p}`

## DevOps Extended (5)
`/wiki-publish {file} --project {p}` · `/wiki-sync --project {p}` · `/testplan-status --project {p}` · `/testplan-results --project {p} --run {id}` · `/security-alerts --project {p}`

## Mensajería e Inbox (6)
`/notify-whatsapp {contacto} {msg}` · `/whatsapp-search {query}` · `/notify-nctalk {sala} {msg}` · `/nctalk-search {query}` · `/inbox-check` · `/inbox-start --interval {min}`

## Conectores (12)
`/notify-slack {canal} {msg}` · `/slack-search {query}` · `/github-activity {repo}` · `/github-issues {repo}` · `/sentry-health --project {p}` · `/sentry-bugs --project {p}` · `/gdrive-upload {file} --project {p}` · `/linear-sync --project {p}` · `/jira-sync --project {p}` · `/confluence-publish {file} --project {p}` · `/notion-sync --project {p}` · `/figma-extract {url} --project {p}`

## DevOps Validation (1)
`/devops-validate --project {p} [--team {t}]`

## Utilidades (4)
`/context-load` · `/session-save` · `/help [filtro]` · `/help --setup`
