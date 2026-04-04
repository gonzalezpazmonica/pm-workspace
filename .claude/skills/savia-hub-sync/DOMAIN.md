# savia-hub-sync — Dominio

## Por que existe esta skill

SaviaHub es el repositorio Git compartido de conocimiento organizacional (empresa, clientes, usuarios). Sin sincronizacion fiable, los datos de clientes divergen entre maquinas del equipo o se pierden al trabajar offline. Esta skill garantiza que SaviaHub funcione local-first con sync opcional, resolviendo conflictos sin perder datos de cliente.

## Conceptos de dominio

- **SaviaHub**: repositorio Git independiente de pm-workspace que almacena perfiles de empresa, clientes y usuarios en markdown
- **Flight mode**: modo offline que encola escrituras localmente y las drena al reconectar con el remote
- **Sync queue**: fichero JSONL append-only que registra cada escritura durante flight mode para posterior commit+push
- **Conflicto de cliente**: divergencia entre version local y remota de un fichero de datos de cliente, que NUNCA se auto-resuelve

## Reglas de negocio que implementa

- Principio foundacional #1: soberania del dato (.md es la verdad)
- Principio foundacional #5: el humano decide (conflictos siempre al PM)
- Regla N4 de confidencialidad: datos de clientes aislados por proyecto
- Regla de seguridad: PATs y secrets NUNCA en SaviaHub

## Relacion con otras skills

- **Upstream**: `client-profile-manager` (genera los datos que se sincronizan)
- **Upstream**: `company-messaging` (SaviaHub contiene perfiles de empresa)
- **Downstream**: `backlog-git-tracker` (snapshots de backlog viven en SaviaHub)
- **Paralelo**: `personal-vault` (vault personal vs hub compartido del equipo)

## Decisiones clave

- SaviaHub vive fuera del repo pm-workspace (~/.savia-hub/) para no contaminar el contexto de Claude Code
- Se eligio Git como backend porque garantiza versionado, rollback y auditoria sin dependencias externas
- Flight mode con cola JSONL en vez de branch separado, porque es mas simple y no requiere merge de ramas
- NUNCA auto-resolver conflictos en datos de clientes: el coste de perder un dato de cliente supera el coste de preguntar al PM
