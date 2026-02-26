# Project Infrastructure Definition

The workspace allows the PM to define the infrastructure needs for the project directly in the project's `CLAUDE.md`. The `infrastructure-agent` interprets these preferences and generates Infrastructure as Code (Terraform, CloudFormation, Bicep) at the **lowest possible tier**, requiring human approval for any scaling.

## How to define the desired infrastructure

In each project's `CLAUDE.md`, add an `infrastructure_config` section:

```yaml
# In projects/{project}/CLAUDE.md

# ── Infrastructure ──────────────────────────────────────────
CLOUD_PROVIDER          = "azure"              # azure | aws | gcp | multi-cloud
CLOUD_REGION            = "westeurope"         # Primary region
CLOUD_REGION_SECONDARY  = "northeurope"        # Secondary region (DR)

infrastructure_config:
  # ── Compute (where the application runs) ──────────────────
  compute:
    type: "container-apps"          # Available options below
    instances_min: 1                # Minimum instances
    instances_max: 3                # Maximum instances (auto-scale)
    cpu: "0.5"                      # vCPU per instance
    memory: "1Gi"                   # RAM per instance

  # ── Database ─────────────────────────────────────────────
  database:
    type: "sql-server"              # Available options below
    version: "latest"
    high_availability: false        # true only in PRO with approval
    backup_retention_days: 7

  # ── Cache ─────────────────────────────────────────────────
  cache:
    enabled: true
    type: "redis"                   # redis | memcached | in-memory
    size: "250MB"

  # ── API Gateway / Load Balancer ───────────────────────────
  api_gateway:
    enabled: true
    type: "application-gateway"     # Available options below
    ssl: true
    waf: false                      # WAF only in PRO with approval

  # ── Messaging / Event Bus ─────────────────────────────────
  messaging:
    enabled: false
    type: "service-bus"             # service-bus | rabbitmq | kafka | sqs

  # ── Storage ───────────────────────────────────────────────
  storage:
    enabled: true
    type: "blob"                    # blob | s3 | gcs | file-share

  # ── Monitoring ────────────────────────────────────────────
  monitoring:
    enabled: true
    type: "application-insights"    # application-insights | cloudwatch | datadog

  # ── Container Registry ────────────────────────────────────
  registry:
    enabled: true
    type: "acr"                     # acr | ecr | gcr | docker-hub
```

## Available compute options

| Option | Cloud | Use case | Minimum tier |
|---|---|---|---|
| `app-service` | Azure | Traditional web apps and APIs | F1 (Free) |
| `container-apps` | Azure | Containerized microservices | Consumption (pay per use) |
| `aks` | Azure | Kubernetes (requires K8s expertise) | Free tier |
| `functions` | Azure | Event-driven, serverless | Consumption |
| `ecs-fargate` | AWS | Containers without server management | 0.25 vCPU |
| `eks` | AWS | Kubernetes on AWS | — |
| `lambda` | AWS | Serverless AWS | On-demand |
| `ec2` | AWS | Virtual machines | t3.micro |
| `cloud-run` | GCP | Serverless containers | 0-1 instances |
| `gke` | GCP | Kubernetes on GCP | Autopilot |
| `cloud-functions` | GCP | Serverless GCP | On-demand |

## Available database options

| Option | Cloud | Type | Minimum tier |
|---|---|---|---|
| `sql-server` | Azure | Relational (SQL Server) | Basic (5 DTU) |
| `postgresql-azure` | Azure | Relational (PostgreSQL Flexible) | Burstable B1ms |
| `cosmos-db` | Azure | NoSQL (documents, graphs) | Serverless |
| `rds-postgres` | AWS | Relational (PostgreSQL) | db.t3.micro |
| `rds-mysql` | AWS | Relational (MySQL) | db.t3.micro |
| `dynamodb` | AWS | NoSQL (key-value) | On-demand |
| `aurora` | AWS | Relational (MySQL/PostgreSQL compatible) | Serverless v2 |
| `cloud-sql-postgres` | GCP | Relational (PostgreSQL) | db-f1-micro |
| `firestore` | GCP | NoSQL (documents) | Free tier |
| `mongodb-atlas` | Multi | NoSQL (documents) | M0 (Free) |

The `infrastructure-agent` will read this configuration and generate Terraform files with the lowest tier for each resource in DEV. For PRE and PRO, it will propose a scaling plan requiring human approval.
