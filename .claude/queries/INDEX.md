# Query Library — INDEX

Auto-generated. 9 queries. Regen: scripts/query-lib-index.sh. CI check: --check flag. SPEC-SE-031.

| ID | Lang | Tags | Description | File |
|---|---|---|---|---|
| active-sprint-items | wiql | azure-devops, sprint, status | Items del sprint activo con estado y asignación | [azure-devops/active-sprint-items.wiql](./azure-devops/active-sprint-items.wiql) |
| blocked-issues-jira | jql | jira, blocked, sla | Issues bloqueados en Jira sprint actual | [jira/blocked-issues.jql](./jira/blocked-issues.jql) |
| blocked-pbis-over-3d | wiql | azure-devops, blocked, sla, sprint | PBIs bloqueados más de 3 días sin actualización en el sprint activo | [azure-devops/blocked-pbis-over-3d.wiql](./azure-devops/blocked-pbis-over-3d.wiql) |
| bugs-open-by-severity | wiql | azure-devops, bugs, quality | Bugs abiertos agrupables por severidad | [azure-devops/bugs-open-by-severity.wiql](./azure-devops/bugs-open-by-severity.wiql) |
| my-open-issues-jira | jql | jira, owner, workload | Issues asignados al usuario actual, activos | [jira/my-open-issues.jql](./jira/my-open-issues.jql) |
| pbis-by-owner | wiql | azure-devops, owner, workload | PBIs asignados a un owner específico, activos o pendientes | [azure-devops/pbis-by-owner.wiql](./azure-devops/pbis-by-owner.wiql) |
| pending-reviews-savia | savia-flow | savia-flow, review, bottleneck | Items en estado Review esperando aprobación | [savia-flow/pending-reviews.yaml](./savia-flow/pending-reviews.yaml) |
| tasks-no-estimate | wiql | azure-devops, estimation, quality | Tasks del sprint sin OriginalEstimate (requieren estimación) | [azure-devops/tasks-no-estimate.wiql](./azure-devops/tasks-no-estimate.wiql) |
| velocity-last-3-sprints | savia-flow | savia-flow, velocity, planning | Velocity de los últimos 3 sprints cerrados para proyección | [savia-flow/velocity-last-3-sprints.yaml](./savia-flow/velocity-last-3-sprints.yaml) |
