# Backlog Git Tracker — Dominio

## Por que existe esta skill

Los backlogs cambian silenciosamente: se anaden items, se re-estiman, se eliminan sin registro. Sin snapshots periodicos es imposible detectar scope creep o medir la estabilidad del backlog entre sprints. Esta skill captura el estado del backlog como markdown versionado en SaviaHub, permitiendo comparar versiones, detectar desviaciones y generar informes de tendencia.

## Conceptos de dominio

- **Snapshot**: captura inmutable del backlog en un momento dado, almacenada como markdown con frontmatter YAML y tabla de items
- **Scope creep**: crecimiento no planificado del backlog medido como porcentaje de items anadidos entre snapshots
- **Diff**: comparacion entre dos snapshots que identifica items anadidos, eliminados y modificados con campos cambiados
- **Deviation report**: informe de tendencia sobre la serie temporal de snapshots con metricas acumuladas
- **Rollback report**: informe (nunca ejecucion) de las acciones necesarias para restaurar el backlog a un estado anterior

## Reglas de negocio que implementa

- Los snapshots son inmutables (append-only): nunca modificar uno existente
- El rollback solo genera informe, nunca ejecuta cambios en el PM tool
- Soporta 5 fuentes de datos: Azure DevOps, Jira, GitLab, Savia Flow y modo manual
- Frecuencia recomendada: minimo 1 snapshot por sprint (planning + review)

## Relacion con otras skills

- **Upstream**: savia-hub-sync (gestiona push al remote), client-profile-manager (proporciona cliente y proyecto)
- **Downstream**: sprint-management (datos de scope creep alimentan retrospectivas), enterprise-analytics (tendencias de backlog)
- **Paralelo**: backlog-patterns (detecta duplicados, complementa con analisis cualitativo)

## Decisiones clave

- Markdown en vez de base de datos para que los snapshots sean legibles, versionables con git y portables sin infraestructura
- Append-only en vez de mutable para garantizar trazabilidad completa y evitar manipulacion del historico
- Multi-fuente con deteccion automatica en vez de acoplarse a un solo PM tool, para soportar equipos heterogeneos
