# Anexo: IaC — Patrones Multi-Cloud Detallados
# ── Comandos específicos por proveedor, ejemplos de configuración ─────────────

## Detección Automática de Infraestructura Existente

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

### Azure

| Recurso | Tier DEV | Tier PRO | Notas |
|---|---|---|---|
| App Service | F1 (Free) | B1 (Basic) | Free sin SSL custom |
| SQL Database | Basic (5 DTU) | S0 (10 DTU) | Evaluar serverless |
| Functions | Consumption | Consumption | Pago por ejecución |
| Storage | Standard_LRS | Standard_GRS | GRS para redundancia |
| Key Vault | Standard | Standard | No hay tier free |
| Container Apps | Consumption | Consumption | Pago por uso |
| AKS | Free tier | Standard | Free limita SLA |
| Redis Cache | Basic C0 | Standard C0 | Basic sin SLA |
| App Insights | Free (5GB/mes) | Pay-per-use | Alerta si > 5GB |

### AWS

| Recurso | Tier DEV | Tier PRO |
|---|---|---|
| EC2 | t3.micro | t3.small |
| RDS | db.t3.micro | db.t3.small |
| Lambda | On-demand | On-demand |
| S3 | Standard | Standard |
| ECS Fargate | 0.25 vCPU/0.5 GB | 0.5 vCPU/1 GB |
| ElastiCache | cache.t3.micro | cache.t3.small |

### GCP

| Recurso | Tier DEV | Tier PRO |
|---|---|---|
| Cloud Run | 0-1 instances, 256MB | 1-3 instances, 512MB |
| Cloud SQL | db-f1-micro | db-g1-small |
| GKE | Autopilot | Autopilot |
| Cloud Functions | Pay-per-use | Pay-per-use |
| Memorystore | Basic 1GB | Standard 1GB |

---

## Tags/Labels Obligatorios

```hcl
tags = {
  Project     = var.project_name
  Environment = var.environment
  ManagedBy   = "terraform"
  Team        = var.team_name
  CostCenter  = var.cost_center
  CreatedDate = timestamp()
  CreatedBy   = "infrastructure-agent"
}
```
