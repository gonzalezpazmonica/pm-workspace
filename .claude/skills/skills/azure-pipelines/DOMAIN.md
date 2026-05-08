# Azure Pipelines — Dominio

## Por que existe esta skill

Los equipos necesitan visibilidad y control sobre sus pipelines de CI/CD sin salir del flujo de trabajo del PM. Esta skill centraliza la gestion de builds y releases de Azure Pipelines via MCP, permitiendo consultar estado, ejecutar pipelines y crear nuevas desde pm-workspace con las protecciones necesarias para evitar deploys accidentales.

## Conceptos de dominio

- **Pipeline**: definicion de CI/CD en Azure DevOps que ejecuta build, test y deploy de forma automatizada
- **Build**: ejecucion concreta de una pipeline con estado (succeeded, failed, inProgress, canceled)
- **Stage pattern**: secuencia multi-entorno Build, Test, DEV (auto), PRE (approval), PRO (approval)
- **Preview**: simulacion de lo que ejecutaria una pipeline sin ejecutarla realmente, util para validar cambios YAML
- **Gate de aprobacion**: punto de control humano obligatorio antes de deploy a entornos criticos (PRE, PRO)

## Reglas de negocio que implementa

- Nunca ejecutar pipeline sin confirmacion explicita del PM
- Siempre hacer preview antes de run para validar el YAML
- Deploys a PRO requieren doble confirmacion (PM + PO)
- Variables sensibles (secrets) nunca se muestran en logs
- Artefactos se guardan en output/artifacts/{proyecto}/{build-id}/

## Relacion con otras skills

- **Upstream**: spec-driven-development (specs implementadas generan commits que disparan pipelines)
- **Downstream**: verification-lattice (Layer 1 incluye CI passing como gate), sprint-management (estado de builds en sprint review)
- **Paralelo**: devops-validation (valida configuracion del proyecto en Azure DevOps)

## Decisiones clave

- MCP en vez de CLI directa para aprovechar la integracion nativa de Claude Code con Azure DevOps
- Preview obligatorio antes de ejecucion para evitar runs accidentales con YAML incorrecto
- Doble gate para PRO (PM + PO) en vez de solo uno, porque los deploys a produccion son irreversibles
