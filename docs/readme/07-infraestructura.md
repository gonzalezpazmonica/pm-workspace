# Definición de Infraestructura del Proyecto

El workspace permite al PM definir la infraestructura que necesita el proyecto directamente en el `CLAUDE.md` del proyecto. El `infrastructure-agent` interpreta estas preferencias y genera el código IaC correspondiente al **tier más bajo posible**, requiriendo aprobación humana para cualquier escalado.

## Cómo definir la infraestructura deseada

En el `CLAUDE.md` de cada proyecto, añade una sección `infrastructure_config`:

```yaml
# En projects/{proyecto}/CLAUDE.md

# ── Infraestructura ──────────────────────────────────────────
CLOUD_PROVIDER          = "azure"              # azure | aws | gcp | multi-cloud
CLOUD_REGION            = "westeurope"         # Región principal
CLOUD_REGION_SECONDARY  = "northeurope"        # Región secundaria (DR)

infrastructure_config:
  # ── Compute (dónde se ejecuta la aplicación) ──────────────────
  compute:
    type: "container-apps"          # Opciones disponibles abajo
    instances_min: 1                # Mínimo de instancias
    instances_max: 3                # Máximo de instancias (auto-scale)
    cpu: "0.5"                      # vCPU por instancia
    memory: "1Gi"                   # RAM por instancia

  # ── Base de datos ─────────────────────────────────────────────
  database:
    type: "sql-server"              # Opciones disponibles abajo
    version: "latest"
    high_availability: false        # true solo en PRO con aprobación
    backup_retention_days: 7

  # ── Cache ─────────────────────────────────────────────────────
  cache:
    enabled: true
    type: "redis"                   # redis | memcached | in-memory
    size: "250MB"

  # ── API Gateway / Load Balancer ───────────────────────────────
  api_gateway:
    enabled: true
    type: "application-gateway"     # Opciones disponibles abajo
    ssl: true
    waf: false                      # WAF solo en PRO con aprobación

  # ── Messaging / Event Bus ─────────────────────────────────────
  messaging:
    enabled: false
    type: "service-bus"             # service-bus | rabbitmq | kafka | sqs

  # ── Storage ───────────────────────────────────────────────────
  storage:
    enabled: true
    type: "blob"                    # blob | s3 | gcs | file-share

  # ── Monitoring ────────────────────────────────────────────────
  monitoring:
    enabled: true
    type: "application-insights"    # application-insights | cloudwatch | datadog

  # ── Container Registry ────────────────────────────────────────
  registry:
    enabled: true
    type: "acr"                     # acr | ecr | gcr | docker-hub
```

## Opciones de Compute disponibles

| Opción | Cloud | Cuándo usarla | Tier mínimo |
|---|---|---|---|
| `app-service` | Azure | Web apps y APIs tradicionales | F1 (Free) |
| `container-apps` | Azure | Microservicios contenedorizados | Consumption (pago por uso) |
| `aks` | Azure | Kubernetes full (equipo con experiencia K8s) | Free tier |
| `functions` | Azure | Event-driven, serverless | Consumption |
| `ecs-fargate` | AWS | Contenedores sin gestión de servidores | 0.25 vCPU |
| `eks` | AWS | Kubernetes en AWS | — |
| `lambda` | AWS | Serverless AWS | On-demand |
| `ec2` | AWS | Máquinas virtuales | t3.micro |
| `cloud-run` | GCP | Contenedores serverless | 0-1 instances |
| `gke` | GCP | Kubernetes en GCP | Autopilot |
| `cloud-functions` | GCP | Serverless GCP | On-demand |

## Opciones de Base de Datos

| Opción | Cloud | Tipo | Tier mínimo |
|---|---|---|---|
| `sql-server` | Azure | Relacional (SQL Server) | Basic (5 DTU) |
| `postgresql-azure` | Azure | Relacional (PostgreSQL Flexible) | Burstable B1ms |
| `cosmos-db` | Azure | NoSQL (documentos, grafos) | Serverless |
| `rds-postgres` | AWS | Relacional (PostgreSQL) | db.t3.micro |
| `rds-mysql` | AWS | Relacional (MySQL) | db.t3.micro |
| `dynamodb` | AWS | NoSQL (key-value) | On-demand |
| `aurora` | AWS | Relacional (MySQL/PostgreSQL compatible) | Serverless v2 |
| `cloud-sql-postgres` | GCP | Relacional (PostgreSQL) | db-f1-micro |
| `firestore` | GCP | NoSQL (documentos) | Free tier |
| `mongodb-atlas` | Multi | NoSQL (documentos) | M0 (Free) |

## Opciones de API Gateway / Load Balancer

| Opción | Cloud | Cuándo usarla |
|---|---|---|
| `application-gateway` | Azure | API Gateway con WAF, SSL, routing avanzado |
| `front-door` | Azure | CDN + routing global + WAF |
| `traefik` | Cualquiera | Reverse proxy para contenedores (Kubernetes, Docker) |
| `nginx-ingress` | Cualquiera | Ingress controller para Kubernetes |
| `api-management` | Azure | API Gateway empresarial con portal de desarrollador |
| `api-gateway` | AWS | API Gateway serverless |
| `alb` | AWS | Application Load Balancer |
| `cloud-load-balancing` | GCP | Load balancer global |

## Ejemplo completo: proyecto Java/Spring Boot en AWS

```yaml
# projects/microservicio-pagos/CLAUDE.md

CLOUD_PROVIDER = "aws"
CLOUD_REGION   = "eu-west-1"
LANGUAGE_PACK  = "java"

infrastructure_config:
  compute:
    type: "ecs-fargate"
    instances_min: 2
    instances_max: 5
    cpu: "0.5"
    memory: "1Gi"

  database:
    type: "rds-postgres"
    version: "16"
    high_availability: false
    backup_retention_days: 14

  cache:
    enabled: true
    type: "redis"
    size: "500MB"

  api_gateway:
    enabled: true
    type: "api-gateway"
    ssl: true
    waf: true

  messaging:
    enabled: true
    type: "sqs"

  monitoring:
    enabled: true
    type: "cloudwatch"
```

El `infrastructure-agent` leerá esta configuración y generará los ficheros Terraform correspondientes con el tier más bajo para cada recurso en DEV. Para PRE y PRO, propondrá un plan de escalado que requiere aprobación humana.

---
