---
name: patterns-terraform
description: Patrones de arquitectura para Terraform (Infrastructure as Code)
context_cost: low
---

# Patrones — Terraform (IaC)

## 1. Service Stack Pattern (⭐ Recomendado)

Un stack por servicio y entorno → deploy independiente.

**Folder Structure**:
```
infrastructure/
├── modules/                → Módulos reutilizables
│   ├── networking/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── compute/
│   ├── database/
│   └── storage/
├── services/               → Un stack por servicio
│   ├── api/
│   │   ├── dev/
│   │   │   ├── main.tf
│   │   │   └── terraform.tfvars
│   │   ├── staging/
│   │   └── production/
│   └── worker/
└── shared/                 → Infra compartida (VPC, DNS)
```

**Detection Markers**:
- Separación por servicio + entorno
- `.tfvars` por entorno
- `backend.tf` con remote state (S3, Azure Storage, GCS)
- Módulos referenciados por path o registry

## 2. Three-Tier (Platform / Product / Shared)

**Folder Structure**:
```
terraform/
├── platform/             → Infra base (VPC, IAM, DNS) — DevOps team
├── products/             → Servicios de negocio — Product teams
│   └── service-a/
└── shared/               → Módulos y variables compartidas
```

**Detection Markers**:
- Separación platform/products
- Shared modules referenced cross-tier
- Different state files per tier

## 3. Monolithic (Terralith) — ⚠️ No recomendado

**Detection Markers**:
- Un solo `main.tf` con toda la infra
- Sin módulos o muy pocos
- Un solo state file para todo
- Riesgo: blast radius, slow plans, coupling

## 4. Module-Based (DRY)

**Detection Markers**:
- `modules/` con componentes reutilizables
- Cada módulo: `main.tf`, `variables.tf`, `outputs.tf`
- Llamadas: `module "vpc" { source = "./modules/networking" }`
- Versionado de módulos en registry

## 5. Workspace-Based

**Detection Markers**:
- `terraform workspace` commands
- Mismo código, diferentes workspaces (dev, staging, prod)
- `terraform.workspace` en conditionals
- ⚠️ Limitado para diferencias grandes entre entornos

## Terraform Best Practices

### Naming Conventions
- Resources: `resource_type_purpose` → `aws_s3_bucket_logs`
- Modules: `purpose` → `module "networking"`
- Variables: `descriptive_name` → `var.database_instance_class`

### State Management
- **Remote state**: S3+DynamoDB (AWS), Azure Storage (Azure), GCS (GCP)
- **State locking**: Evita cambios concurrentes
- **State encryption**: Cifrado at rest

### Security
- **No secrets en `.tf`**: Usar vault, SSM, o Key Vault
- **Least privilege**: IAM roles mínimos
- **Policy as Code**: Sentinel (HashiCorp), OPA (Open Policy Agent)

## Tools de Enforcement
- **Terragrunt**: DRY config, remote state management
- **TFLint**: Linting de Terraform files
- **Checkov**: Security scanning para IaC
- **Terraform-docs**: Auto-generación de documentación
- **Infracost**: Estimación de costes antes de apply
- **Terratest**: Tests de infraestructura en Go
- **Sentinel**: Policy as Code (Terraform Cloud/Enterprise)

## Anti-patterns comunes
- State file en git (debe ser remote)
- Hardcoded values (en lugar de variables)
- Sin módulos (copy-paste entre entornos)
- `terraform apply` sin `plan` previo
- Sin remote locking → conflictos de state
- Recursos nombrados con entorno hardcoded
