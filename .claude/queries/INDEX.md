# Query Library — INDEX

Auto-generated. 12 queries. Regen: scripts/query-lib-index.sh. CI check: --check flag. SPEC-SE-031.

| ID | Lang | Tags | Description | File |
|---|---|---|---|---|
| active-sprint-items | wiql | azure-devops, sprint, status | Items del sprint activo con estado y asignación | [azure-devops/active-sprint-items.wiql](./azure-devops/active-sprint-items.wiql) |
| backlog-groom-open | wiql | azure-devops, backlog, grooming | Items abiertos candidatos a grooming (User Story, Feature, Bug no cerrados) orde | [azure-devops/backlog-groom-open.wiql](./azure-devops/backlog-groom-open.wiql) |
| blocked-issues-jira | jql | jira, blocked, sla | Issues bloqueados en Jira sprint actual | [jira/blocked-issues.jql](./jira/blocked-issues.jql) |
| blocked-pbis-over-3d | wiql | azure-devops, blocked, sla, sprint | PBIs bloqueados más de 3 días sin actualización en el sprint activo | [azure-devops/blocked-pbis-over-3d.wiql](./azure-devops/blocked-pbis-over-3d.wiql) |
| board-status-not-done | wiql | azure-devops, board, kanban, sprint | Items del board del sprint activo excluyendo Epic/Feature y estados terminales — | [azure-devops/board-status-not-done.wiql](./azure-devops/board-status-not-done.wiql) |
| bugs-open-by-severity | wiql | azure-devops, bugs, quality | Bugs abiertos agrupables por severidad | [azure-devops/bugs-open-by-severity.wiql](./azure-devops/bugs-open-by-severity.wiql) |
| my-open-issues-jira | jql | jira, owner, workload | Issues asignados al usuario actual, activos | [jira/my-open-issues.jql](./jira/my-open-issues.jql) |
| pbis-by-owner | wiql | azure-devops, owner, workload | PBIs asignados a un owner específico, activos o pendientes | [azure-devops/pbis-by-owner.wiql](./azure-devops/pbis-by-owner.wiql) |
| pending-reviews-savia | savia-flow | savia-flow, review, bottleneck | Items en estado Review esperando aprobación | [savia-flow/pending-reviews.yaml](./savia-flow/pending-reviews.yaml) |
| sprint-items-detailed | wiql | azure-devops, sprint, tracking, detailed | Items del sprint activo con trabajo completado, restante, story points y activit | [azure-devops/sprint-items-detailed.wiql](./azure-devops/sprint-items-detailed.wiql) |
| tasks-no-estimate | wiql | azure-devops, estimation, quality | Tasks del sprint sin OriginalEstimate (requieren estimación) | [azure-devops/tasks-no-estimate.wiql](./azure-devops/tasks-no-estimate.wiql) |
| velocity-last-3-sprints | savia-flow | savia-flow, velocity, planning | Velocity de los últimos 3 sprints cerrados para proyección | [savia-flow/velocity-last-3-sprints.yaml](./savia-flow/velocity-last-3-sprints.yaml) |
