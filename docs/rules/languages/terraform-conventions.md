---
paths:
  - "**/*.tf"
  - "**/*.tfvars"
  - "**/*.hcl"
---

# Regla: Convenciones y Prácticas Terraform / Infrastructure as Code
# ── Aplica a todos los proyectos Terraform en este workspace ───────────────────

## Verificación obligatoria en cada tarea

Antes de dar una tarea por terminada, ejecutar siempre en este orden:

```bash
terraform validate                             # 1. ¿Sintaxis correcta?
terraform fmt --check --recursive .            # 2. ¿Formato estándar?
tflint --init && tflint                        # 3. ¿Sin errores de linting?
tfsec .                                        # 4. ¿Auditoría de seguridad?
terratest [test_dir]                           # 5. ¿Pasan los tests de infraestructura?
```

**CRÍTICO:** `terraform apply` siempre requiere revisión y confirmación **humana**.
Nunca automatizar `apply` sin aprobación explícita.

## Convenciones de código Terraform

- **Naming:** `snake_case` para variables, recursos, outputs, locals
- **Archivos:** `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `versions.tf`
- **Módulos:** Directorios bajo `modules/` con su propio `main.tf`, `variables.tf`, `outputs.tf`
- **Workspaces:** Separar ambientes (dev, staging, prod) con `terraform workspace` o directorios separados
- **Estado remoto:** Siempre usar backend remoto (S3, Azure Blob, Terraform Cloud) en producción — NUNCA local
- **Versionado:** Especificar versiones de provider explícitamente; no usar `~>` dinámicas en producción
- **Descripción:** Todos los variables y outputs con descripción clara
- **Sensitive values:** Marcar con `sensitive = true` credenciales, passwords, tokens
- **Locals:** Usar para valores derivados, constantes reutilizables
- **Meta-arguments:** `for_each` preferido sobre `count` (readability); `depends_on` solo cuando explícito sea necesario

## Estructura de repositorio Terraform

```
terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf                 ← configuración específica de dev
│   │   ├── terraform.tfvars        ← variables para dev
│   │   ├── provider.tf             ← configuración de provider con vars
│   │   ├── state/
│   │   │   └── backend.tf          ← backend remoto
│   │   └── .terraform.lock.hcl    ← lock file (siempre commitear)
│   ├── staging/
│   │   ├── main.tf
│   │   ├── terraform.tfvars
│   │   └── ...
│   └── prod/
│       ├── main.tf
│       ├── terraform.tfvars
│       └── ...
├── modules/                        ← módulos reutilizables
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   ├── compute/
│   │   └── ...
│   └── database/
│       └── ...
├── docs/                          ← documentación
│   ├── architecture.md
│   └── MODULES.md
├── tests/                         ← tests de infraestructura (Terratest)
│   ├── vpc_test.go
│   └── ...
├── scripts/
│   ├── init-backend.sh           ← inicializar backend remoto
│   ├── plan.sh                   ← generar plan (no aplicar)
│   └── apply.sh                  ← aplicar cambios (requiere confirmación)
├── .gitignore                    ← excluir .tfvars, .tfstate, .terraform/
└── README.md
```

## Variables y Outputs

```hcl
# variables.tf — tipado y con descripción
variable "environment" {
  description = "Ambiente de deployment (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment debe ser dev, staging o prod."
  }
}

variable "db_password" {
  description = "Contraseña de la base de datos"
  type        = string
  sensitive   = true  # CRÍTICO: no mostra en logs
  
  validation {
    condition     = length(var.db_password) >= 12
    error_message = "Password debe tener al menos 12 caracteres."
  }
}

# outputs.tf — exportar valores para consumidores
output "vpc_id" {
  description = "ID de la VPC creada"
  value       = aws_vpc.main.id
}

output "database_endpoint" {
  description = "Endpoint de la base de datos"
  value       = aws_db_instance.main.endpoint
  sensitive   = true  # no mostrar en outputs
}
```

## Módulos

```hcl
# modules/vpc/main.tf
variable "cidr_block" {
  description = "CIDR block de la VPC"
  type        = string
}

variable "environment" {
  description = "Ambiente"
  type        = string
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true

  tags = {
    Name        = "vpc-${var.environment}"
    Environment = var.environment
  }
}

output "vpc_id" {
  value       = aws_vpc.this.id
  description = "VPC ID"
}

# modules/vpc/variables.tf
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

Usar módulo:
```hcl
module "vpc_dev" {
  source     = "./modules/vpc"
  cidr_block = "10.0.0.0/16"
  environment = "dev"
}
```

## State Management

**CRÍTICO:** El estado es la fuente de verdad de tu infraestructura.

```hcl
# backend.tf — backend remoto (NUNCA local en producción)
terraform {
  backend "s3" {
    bucket         = "terraform-state-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true                      # CRÍTICO: cifrar estado
    dynamodb_table = "terraform-locks"         # CRÍTICO: locks distribuidos
  }
}
```

```bash
# Inicializar backend remoto
terraform init -backend-config="bucket=terraform-state-prod"

# Ver estado
terraform state list
terraform state show aws_instance.main

# State file local (NUNCA en producción)
terraform apply -state=local.tfstate          # NO usar en prod
```

**Nunca** editar `.tfstate` manualmente. Si hay error usar `terraform state mv`, `terraform state rm`:
```bash
terraform state mv aws_instance.old aws_instance.new
terraform state rm aws_instance.to_delete
```

## Plan, Review, Apply

**Flujo recomendado:**

```bash
# 1. Generar plan (sin aplicar)
terraform plan -out=plan.tfplan -var-file=environments/prod/terraform.tfvars

# 2. Revisar plan en detalle
terraform show plan.tfplan

# 3. REVISIÓN HUMANA OBLIGATORIA — leer cada `+`, `~`, `-` en el plan
# Preguntas críticas:
#   - ¿Creará/modificará/destruirá lo esperado?
#   - ¿Hay secrets expuestos en el plan?
#   - ¿Hay recursos que dependen uno de otro (orden)?
#   - ¿Causará downtime?

# 4. Si todo bien, aplicar (requiere confirmación interactiva)
terraform apply plan.tfplan

# 5. Commitear el lock file (pero NO el tfstate ni tfvars con secrets)
git add .terraform.lock.hcl
git commit -m "terraform: update dependencies"
```

**NUNCA hacer:**
```bash
terraform apply -auto-approve  # No usar en producción
```

## Linting y Validación

```bash
# Validar sintaxis
terraform validate

# Formato estándar (auto-fix)
terraform fmt --recursive .

# TFLint — mejores prácticas
terraform init
tflint --init
tflint --format=default

# Seguridad — tfsec
tfsec . --format=json --out=tfsec-report.json
```

Configurar en `.tflint.hcl`:
```hcl
plugin "aws" {
  enabled = true
  version = "0.29.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rule "aws_instance_invalid_type" {
  enabled = true
}

rule "aws_s3_bucket_public_access_block" {
  enabled = true
}
```

## Tests de Infraestructura — Terratest

```go
// tests/vpc_test.go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestVPC(t *testing.T) {
    terraformOptions := &terraform.Options{
        TerraformDir: "../environments/dev",
    }

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    vpcId := terraform.Output(t, terraformOptions, "vpc_id")
    assert.NotEmpty(t, vpcId)
    assert.Contains(t, vpcId, "vpc-")
}
```

Ejecutar:
```bash
cd tests
go test -timeout 30m -v ./...
```

## Secrets Management

**NUNCA** commitear credenciales en `.tfvars` o `terraform.tfvars`.

```hcl
# variables.tf
variable "db_password" {
  type      = string
  sensitive = true
  # No default — se pasa en tiempo de apply
}

# Pasar en apply:
terraform apply -var="db_password=$(aws secretsmanager get-secret-value --secret-id prod/db-password --query SecretString --output text)"

# O con environment variable:
export TF_VAR_db_password="..."
terraform apply

# O archivo separado (git-ignorado):
# terraform.tfvars.secret (en .gitignore)
terraform apply -var-file=terraform.tfvars -var-file=terraform.tfvars.secret
```

## Workflows recomendados

```bash
# 1. Desarrollo local con dev environment
cd environments/dev
terraform plan

# 2. Testing en staging
cd environments/staging
terraform plan -var-file=terraform.tfvars

# 3. Production — máxima precaución
cd environments/prod
terraform plan -out=prod.plan
# REVISAR PLAN MANUALMENTE
terraform show prod.plan
# Tras OK: terraform apply prod.plan

# 4. Rollback (si es necesario)
terraform plan -destroy -out=destroy.plan
terraform apply destroy.plan
```

## Versionado de Terraform

```hcl
# versions.tf — definir versiones de provider
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"   # ~> permite patches, no minors
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.50"
    }
  }
}
```

Actualizar providers:
```bash
terraform init -upgrade
git add .terraform.lock.hcl
```

## Hooks recomendados para proyectos Terraform

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "run": "cd $(git rev-parse --show-toplevel) && terraform validate 2>&1 | head -20"
    }],
    "PreToolUse": [{
      "matcher": "Bash(git commit*)",
      "run": "cd $(git rev-parse --show-toplevel) && terraform fmt --check --recursive . && tflint 2>&1 | head -20"
    }]
  }
}
```

## Documentación obligatoria

Cada módulo debe tener `README.md`:
```markdown
# Módulo VPC

Crea una VPC con subnets públicas y privadas.

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| cidr_block | CIDR block | string | |
| environment | Environment | string | dev |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | ID de la VPC |

## Usage

```hcl
module "vpc" {
  source = "./modules/vpc"
  cidr_block = "10.0.0.0/16"
}
```
```

**Usar `terraform-docs` para auto-generar:**
```bash
terraform-docs markdown . > README.md
```

---

## Reglas de Análisis Estático

> Equivalente a análisis TFLint/TFSec para Terraform. Aplica en code review y pre-commit.

### Vulnerabilities (Blocker)

#### TERRAFORM-SEC-01 — Hardcoded values en variables
**Severidad**: Blocker
```hcl
# ❌ Noncompliant
resource "aws_db_instance" "main" {
  allocated_storage    = 20
  storage_type        = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "mydb"
  username             = "admin"
  password             = "SuperSecret123"  # hardcoded
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
}

# ✅ Compliant
resource "aws_db_instance" "main" {
  allocated_storage    = var.allocated_storage
  storage_type        = var.storage_type
  engine               = var.engine
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  name                 = var.database_name
  username             = var.db_username
  password             = var.db_password  # usar variable con sensitive = true
  parameter_group_name = aws_db_parameter_group.main.name
  skip_final_snapshot  = var.skip_final_snapshot
}
```

#### TERRAFORM-SEC-02 — Falta de lifecycle blocks
**Severidad**: Blocker
```hcl
# ❌ Noncompliant - Recurso destruible sin restricción
resource "aws_s3_bucket" "main" {
  bucket = "my-important-bucket"
}

# ✅ Compliant - Proteger recurso crítico
resource "aws_s3_bucket" "main" {
  bucket = "my-important-bucket"

  lifecycle {
    prevent_destroy = true
  }
}
```

### Bugs (Major)

#### TERRAFORM-BUG-01 — Versiones dinámicas de provider
**Severidad**: Major
```hcl
# ❌ Noncompliant
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"  # acepta cualquier versión >= 5.0
    }
  }
}

# ✅ Compliant
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.15"  # permite 5.15, 5.16, ... pero no 6.0
    }
  }
}
```

#### TERRAFORM-BUG-02 — Missing tags en recursos
**Severidad**: Major
```hcl
# ❌ Noncompliant
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  # sin tags para tracking
}

# ✅ Compliant
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  tags = {
    Name        = "web-server-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
    CreatedAt   = timestamp()
  }
}
```

### Code Smells (Critical)

#### TERRAFORM-SMELL-01 — Módulo > 50 líneas
**Severidad**: Critical
Módulos de más de 50 líneas deben dividirse en módulos más pequeños.

#### TERRAFORM-SMELL-02 — Complejidad de variables
**Severidad**: Critical
Variables con lógica compleja deben extraerse a locals.

### Arquitectura

#### TERRAFORM-ARCH-01 — Mezcla de recursos en main.tf
**Severidad**: Critical
Código Terraform no debe contener todo en un único main.tf. Usar módulos.
```hcl
# ❌ Noncompliant - Todo mezclado
resource "aws_vpc" "main" { ... }
resource "aws_subnet" "public" { ... }
resource "aws_db_instance" "main" { ... }
resource "aws_elb" "main" { ... }
resource "aws_autoscaling_group" "main" { ... }

# ✅ Compliant - Modularizado
module "vpc" {
  source = "./modules/vpc"
  cidr   = var.vpc_cidr
}

module "database" {
  source = "./modules/database"
  vpc_id = module.vpc.vpc_id
}

module "compute" {
  source = "./modules/compute"
  vpc_id = module.vpc.vpc_id
}
```


