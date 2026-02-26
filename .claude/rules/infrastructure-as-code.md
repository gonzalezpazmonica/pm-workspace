# Regla: Infrastructure as Code — Soporte Multi-Cloud
# ── Azure CLI, Terraform, AWS CLI, GCP CLI y otros proveedores ──────────────

> Esta regla define cómo gestionar infraestructura declarativa en el workspace.
> Complementa `terraform-conventions.md` con soporte multi-cloud y herramientas CLI nativas.

## Principios

1. **Infraestructura como código** — todo recurso cloud se define en ficheros versionados
2. **Entornos separados** — cada entorno (DEV/PRE/PRO) tiene su propia infraestructura
3. **Coste mínimo por defecto** — siempre crear en el tier más bajo viable (Free/Basic/B1)
4. **Escalado requiere aprobación humana** — el agente propone, el humano decide y aprueba
5. **Detección antes de creación** — verificar si el recurso ya existe antes de crear
6. **NUNCA apply automático en PRE/PRO** — solo en DEV con confirmación

---

## Herramientas Soportadas

| Herramienta | Propósito | Provider |
|---|---|---|
| `terraform` | IaC declarativo multi-cloud | Todos |
| `az` (Azure CLI) | Gestión imperativa Azure | Azure |
| `aws` (AWS CLI) | Gestión imperativa AWS | AWS |
| `gcloud` (GCP CLI) | Gestión imperativa GCP | Google Cloud |
| `pulumi` | IaC programático (TS/Python/Go) | Todos |
| `bicep` | IaC nativo Azure (ARM templates) | Azure |
| `cdk` (AWS CDK) | IaC programático AWS | AWS |
| `helm` / `kubectl` | Kubernetes | Todos |

### Prioridad de herramientas

1. **Terraform** — preferido para multi-cloud y proyectos nuevos
2. **CLI nativo** — para operaciones puntuales, diagnóstico y scripts de CI/CD
3. **Bicep/CDK/Pulumi** — cuando el equipo ya lo usa o hay razón técnica justificada

---

## Detección Automática de Infraestructura Existente

Antes de crear cualquier recurso, el agente de infraestructura DEBE verificar si ya existe:

### Azure

```bash
# Verificar Resource Group
az group show --name "rg-{proyecto}-{env}" 2>/dev/null && echo "EXISTS" || echo "NOT_FOUND"

# Verificar App Service
az webapp show --name "app-{proyecto}-{env}" --resource-group "rg-{proyecto}-{env}" 2>/dev/null

# Verificar SQL Server
az sql server show --name "sql-{proyecto}-{env}" --resource-group "rg-{proyecto}-{env}" 2>/dev/null

# Verificar Key Vault
az keyvault show --name "kv-{proyecto}-{env}" 2>/dev/null

# Listar todos los recursos del resource group
az resource list --resource-group "rg-{proyecto}-{env}" --output table
```

### AWS

```bash
# Verificar si existe una instancia EC2 por tag
aws ec2 describe-instances --filters "Name=tag:Project,Values={proyecto}" "Name=tag:Environment,Values={env}"

# Verificar RDS
aws rds describe-db-instances --db-instance-identifier "{proyecto}-{env}-db" 2>/dev/null

# Verificar S3 bucket
aws s3api head-bucket --bucket "{proyecto}-{env}-{region}" 2>/dev/null

# Verificar ECS cluster
aws ecs describe-clusters --clusters "{proyecto}-{env}" 2>/dev/null
```

### GCP

```bash
# Verificar proyecto
gcloud projects describe "{proyecto}-{env}" 2>/dev/null

# Verificar Cloud Run service
gcloud run services describe "{proyecto}-{env}" --region={region} 2>/dev/null

# Verificar Cloud SQL
gcloud sql instances describe "{proyecto}-{env}-db" 2>/dev/null
```

### Terraform

```bash
# Verificar estado existente
terraform state list 2>/dev/null | head -20

# Importar recurso existente si no está en estado
terraform import {resource_type}.{name} {resource_id}
```

---

## Tiers de Coste — Siempre Mínimo por Defecto

### Azure — Tiers por defecto

| Recurso | Tier por defecto (DEV) | Tier mínimo PRO | Observaciones |
|---|---|---|---|
| App Service | F1 (Free) | B1 (Basic) | Free no tiene SSL custom |
| SQL Database | Basic (5 DTU) | S0 (10 DTU) | Evaluar serverless para ahorro |
| Azure Functions | Consumption | Consumption | Pago por ejecución |
| Storage Account | Standard_LRS | Standard_GRS | GRS para redundancia en PRO |
| Key Vault | Standard | Standard | No hay tier free |
| Container Apps | Consumption | Consumption | Pago por uso |
| AKS | Free tier | Standard | Free limita SLA |
| Redis Cache | Basic C0 | Standard C0 | Basic sin SLA |
| Application Insights | Free (5GB/mes) | Pay-per-use | Alertar si supera 5GB |

### AWS — Tiers por defecto

| Recurso | Tier por defecto (DEV) | Tier mínimo PRO |
|---|---|---|
| EC2 | t3.micro (o t4g.micro) | t3.small |
| RDS | db.t3.micro | db.t3.small |
| Lambda | On-demand | On-demand |
| S3 | Standard | Standard |
| ECS Fargate | 0.25 vCPU / 0.5 GB | 0.5 vCPU / 1 GB |
| ElastiCache | cache.t3.micro | cache.t3.small |

### GCP — Tiers por defecto

| Recurso | Tier por defecto (DEV) | Tier mínimo PRO |
|---|---|---|
| Cloud Run | 0-1 instances, 256MB | 1-3 instances, 512MB |
| Cloud SQL | db-f1-micro | db-g1-small |
| GKE | Autopilot | Autopilot |
| Cloud Functions | Pay-per-use | Pay-per-use |
| Memorystore | Basic 1GB | Standard 1GB |

---

## Flujo de Creación de Infraestructura

```
┌─────────────────────────────────────────────────────────────────┐
│                   FLUJO DE INFRAESTRUCTURA                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Architect → Define requisitos técnicos                      │
│        ↓                                                        │
│  2. Infrastructure Agent → Recibe solicitud                     │
│        ↓                                                        │
│  3. DETECTAR → ¿Existe ya el recurso?                          │
│        ├── SÍ → Documentar estado actual, proponer ajustes     │
│        └── NO → Continuar con creación                          │
│              ↓                                                  │
│  4. PLANIFICAR → Generar IaC con tier MÍNIMO                   │
│        ↓                                                        │
│  5. VALIDAR → terraform validate / az deployment validate       │
│        ↓                                                        │
│  6. ESTIMAR COSTE → Calcular coste mensual estimado             │
│        ↓                                                        │
│  7. PROPONER → Documento para revisión humana                   │
│        ├── Incluir: recursos, coste, tier, alternativas         │
│        └── Incluir: plan de escalado si se necesita más         │
│              ↓                                                  │
│  8. HUMANO APRUEBA → Solo tras revisión explícita               │
│        ↓                                                        │
│  9. APLICAR → Humano ejecuta apply / az create / aws create    │
│        ↓                                                        │
│  10. VERIFICAR → Confirmar que recursos están operativos        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Escalado de Recursos — Requiere Aprobación Humana

### Propuesta de escalado

Cuando se detecta que un recurso necesita más capacidad, el agente genera una **propuesta de escalado**:

```markdown
## Propuesta de Escalado — {recurso}

### Situación actual
- Recurso: `app-miapp-pro` (App Service)
- Tier actual: B1 (1 core, 1.75 GB RAM)
- Uso CPU: 85% media últimas 24h
- Uso RAM: 92% pico

### Propuesta
- Tier propuesto: S1 (1 core, 1.75 GB RAM, auto-scale)
- O alternativa: B2 (2 cores, 3.5 GB RAM)

### Impacto de coste
- Coste actual: ~€10/mes
- Coste propuesto S1: ~€65/mes (+550%)
- Coste propuesto B2: ~€20/mes (+100%)

### Recomendación
Escalar a B2 como primer paso (menor impacto económico).
Si persiste la presión, evaluar S1 con auto-scale.

### Acción requerida
⚠️ REQUIERE APROBACIÓN HUMANA
Ejecutar tras aprobación:
  az appservice plan update --name "plan-miapp-pro" --sku B2
```

---

## Estructura de Infraestructura en Proyecto

```
proyecto/
└── infrastructure/
    ├── README.md                  ← Documentación de la infraestructura
    ├── architecture.md            ← Diagrama y descripción de arquitectura cloud
    ├── cost-estimate.md           ← Estimación de costes por entorno
    ├── modules/                   ← Módulos Terraform reutilizables
    │   ├── networking/
    │   ├── compute/
    │   ├── database/
    │   ├── storage/
    │   └── monitoring/
    ├── environments/
    │   ├── dev/
    │   │   ├── main.tf
    │   │   ├── variables.tf
    │   │   ├── terraform.tfvars      ← Valores no-sensibles
    │   │   └── backend.tf
    │   ├── pre/
    │   │   └── ...
    │   └── pro/
    │       └── ...
    ├── scripts/
    │   ├── detect-existing.sh        ← Detectar infraestructura existente
    │   ├── estimate-cost.sh          ← Estimar costes
    │   ├── validate.sh               ← Validar configuración
    │   └── plan.sh                   ← Generar plan (NUNCA apply)
    └── .gitignore
```

---

## Tags/Labels Obligatorios

Todo recurso cloud DEBE tener estos tags:

```hcl
tags = {
  Project     = var.project_name        # Nombre del proyecto
  Environment = var.environment          # DEV/PRE/PRO
  ManagedBy   = "terraform"             # O "azure-cli", "manual"
  Team        = var.team_name           # Equipo responsable
  CostCenter  = var.cost_center         # Centro de coste
  CreatedDate = timestamp()             # Fecha de creación
  CreatedBy   = "infrastructure-agent"  # Quién lo creó
}
```

---

## Comandos de Workspace

| Comando | Descripción |
|---|---|
| `/infra:detect {proyecto} {env}` | Detectar infraestructura existente del proyecto en un entorno |
| `/infra:plan {proyecto} {env}` | Generar plan de infraestructura para un entorno |
| `/infra:estimate {proyecto}` | Estimar costes de infraestructura por entorno |
| `/infra:scale {recurso}` | Proponer escalado de un recurso (requiere aprobación) |
| `/infra:status {proyecto}` | Estado de la infraestructura actual del proyecto |

---

## Checklist Infraestructura Nuevo Proyecto

- [ ] Cloud provider(s) definido(s) en CLAUDE.md del proyecto
- [ ] Directorio `infrastructure/` creado con estructura estándar
- [ ] Módulos necesarios identificados y creados
- [ ] Entornos configurados (un directorio por entorno)
- [ ] Tags/labels estándar aplicados a todos los recursos
- [ ] Detección de infraestructura existente ejecutada
- [ ] Estimación de costes documentada en `cost-estimate.md`
- [ ] Secrets almacenados en vault del provider (NUNCA en repo)
- [ ] `.gitignore` configurado (excluir .tfstate, .tfvars.secret, .terraform/)
- [ ] Pipeline de CI/CD para validate + plan (sin apply automático en PRE/PRO)
