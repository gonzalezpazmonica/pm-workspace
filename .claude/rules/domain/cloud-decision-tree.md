# Infrastructure Agent: Cloud Decision Tree y Tier Recommendations

> Referencia extraída de `infrastructure-agent.md`. Contiene árboles de decisión multi-cloud, recomendaciones de tiers y patrones de coste.

## Protocolo de Inicio

### 1. Leer contexto del proyecto
- `CLAUDE.md` del proyecto | `.claude/rules/environment-config.md` | `.claude/rules/confidentiality-config.md`
- `.claude/rules/infrastructure-as-code.md` | `infrastructure/` si existe

### 2. Identificar el cloud provider
- Buscar en CLAUDE.md: `CLOUD_PROVIDER`
- Detectar por ficheros: `*.tf` (Terraform), `bicep` (Azure), `cloudformation` (AWS)
- Si no está definido → preguntar al architect

### 3. Detectar infraestructura existente
**Azure:** `az group show --name "rg-{proyecto}-{env}"` | `az resource list --resource-group "rg-{proyecto}-{env}"`
**AWS:** `aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values={proyecto} Key=Environment,Values={env}`
**GCP:** `gcloud asset search-all-resources --scope=projects/{proyecto}-{env}`
**Terraform:** `cd infrastructure/environments/{env} && terraform state list`

### 4. Documentar hallazgos antes de proponer cambios

## Proceso de Creación de Infraestructura

| Paso | Acción |
|---|---|
| 1 | Análisis: ¿Qué recursos? ¿Para qué entorno(s)? ¿Dependencias? |
| 2 | Detección: Verificar si cada recurso existe. Documentar estado actual. |
| 3 | Selección tier: DEV=Free/Basic, PRE=Mismo DEV, PRO=Mínimo SLA |
| 4 | IaC: Preferencia Terraform > CLI nativo > Bicep/CDK |
| 5 | Validación: terraform validate, tflint, tfsec, az deployment validate, aws cloudformation validate |
| 6 | Coste: `infracost breakdown --path=.` o estimar manualmente |
| 7 | Propuesta: Generar `INFRA-PROPOSAL.md` (solicitud, infra existente, recursos, coste, alternativas, escalado, ficheros) |

## Restricciones por Entorno

| Entorno | Crear | Apply automático | Tier máximo |
|---|---|---|---|
| DEV | ✅ Con confirmación | ✅ | Basic/Micro |
| PRE | ✅ Con confirmación | ❌ Requiere aprobación | Basic/Small |
| PRO | ✅ Con confirmación | ❌ SIEMPRE aprobación | NINGUNO |

## Convenciones de Naming por Proveedor

### Azure
```
rg-{proyecto}-{env}           # Resource Group
app-{proyecto}-{env}          # App Service
sql-{proyecto}-{env}          # SQL Server
db-{proyecto}-{env}           # Database
kv-{proyecto}-{env}           # Key Vault
st{proyecto}{env}             # Storage (sin guiones, max 24)
cr{proyecto}{env}             # Container Registry
```

### AWS
```
{proyecto}-{env}-{recurso}    # Nombre general
{proyecto}-{env}-{region}     # S3 buckets (globalmente únicos)
```

### GCP
```
{proyecto}-{env}              # Project ID
{proyecto}-{env}-{recurso}    # Nombres recursos
```

## Anti-patrones

- Crear recursos sin verificar si ya existen
- Usar tiers altos "por si acaso"
- Apply en PRO sin aprobación
- Secrets en código, .tfvars o variables sin cifrar
- Recursos sin tags (imposibilita control de costes)
- Infraestructura manual sin documentar — usar siempre IaC
- Un solo workspace Terraform para todos entornos
- Ignorar estimaciones de coste

## Outputs esperados

1. `INFRA-PROPOSAL.md` — Propuesta (solicitud, infra existente, recursos, coste, alternativas)
2. **Ficheros IaC** — Terraform/Bicep/CloudFormation listos para validar
3. **Validación** — terraform validate, tflint, tfsec
4. **Coste** — Tabla coste mensual por recurso y total
5. **Instrucciones apply** — Comandos exactos para humano ejecute
