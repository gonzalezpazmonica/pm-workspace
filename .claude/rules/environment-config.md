# Regla: Configuración Multi-Entorno
# ── Soporte para entornos DEV / PRE / PRO (configurable) ────────────────────

> Esta regla define cómo gestionar entornos múltiples en cualquier proyecto del workspace.
> Los valores reales (connection strings, secrets) van en ficheros protegidos (ver `confidentiality-config.md`).

## Principios

1. **Todo proyecto tiene al menos un entorno** — por defecto DEV
2. **Los nombres y cantidad de entornos son configurables** por proyecto
3. **Cada entorno tiene su propia configuración** — nunca compartir secrets entre entornos
4. **La configuración sensible NUNCA va al repositorio** — usar ficheros gitignore o servicios de secrets

---

## Configuración de Entornos por Proyecto

En el `CLAUDE.md` de cada proyecto, declarar la sección de entornos:

```
# ── Entornos ────────────────────────────────────────────────────────────────
ENVIRONMENTS_COUNT          = 3
ENVIRONMENTS                = ["DEV", "PRE", "PRO"]

# Cada entorno se define con nombre completo, diminutivo y propósito:
ENV_1_NAME                  = "Development"
ENV_1_SHORT                 = "DEV"
ENV_1_PURPOSE               = "Desarrollo y pruebas locales"
ENV_1_AUTO_DEPLOY           = true

ENV_2_NAME                  = "Pre-production"
ENV_2_SHORT                 = "PRE"
ENV_2_PURPOSE               = "Staging, pruebas de integración y UAT"
ENV_2_AUTO_DEPLOY           = false

ENV_3_NAME                  = "Production"
ENV_3_SHORT                 = "PRO"
ENV_3_PURPOSE               = "Producción — solo deploy con aprobación humana"
ENV_3_AUTO_DEPLOY           = false
```

### Variantes comunes

**2 entornos (proyectos pequeños):**
```
ENVIRONMENTS = ["DEV", "PRO"]
```

**4 entornos (proyectos enterprise):**
```
ENVIRONMENTS = ["DEV", "INT", "PRE", "PRO"]
# INT = Integration (pruebas de integración entre servicios)
```

**5 entornos (regulación estricta):**
```
ENVIRONMENTS = ["DEV", "INT", "QA", "PRE", "PRO"]
# QA = Quality Assurance (validación formal)
```

**Nombres personalizados:**
```
ENVIRONMENTS = ["LOCAL", "STAGING", "PRODUCTION"]
# O cualquier nombre que use la organización
```

---

## Estructura de Ficheros por Entorno

```
proyecto/
├── src/                           ← Código fuente (compartido)
├── config/
│   ├── appsettings.json           ← Config común (sin secrets)
│   ├── appsettings.DEV.json       ← Config específica DEV (sin secrets)
│   ├── appsettings.PRE.json       ← Config específica PRE (sin secrets)
│   └── appsettings.PRO.json       ← Config específica PRO (sin secrets)
├── config.local/                  ← 🔒 git-ignorado
│   ├── .env.DEV                   ← Secrets DEV (connection strings, API keys)
│   ├── .env.PRE                   ← Secrets PRE
│   └── .env.PRO                   ← Secrets PRO
├── infrastructure/
│   ├── environments/
│   │   ├── dev/
│   │   │   ├── main.tf
│   │   │   └── terraform.tfvars   ← Variables no-sensibles
│   │   ├── pre/
│   │   │   └── ...
│   │   └── pro/
│   │       └── ...
│   └── modules/                   ← Módulos IaC compartidos
├── deploy/
│   ├── pipelines/
│   │   ├── azure-pipelines.DEV.yml
│   │   ├── azure-pipelines.PRE.yml
│   │   └── azure-pipelines.PRO.yml
│   └── scripts/
│       ├── deploy-DEV.sh
│       ├── deploy-PRE.sh
│       └── deploy-PRO.sh
└── .gitignore                     ← Incluye config.local/, *.tfvars.secret, .env.*
```

---

## Convenciones de Naming por Entorno

| Recurso | Patrón | Ejemplo DEV | Ejemplo PRO |
|---|---|---|---|
| Resource Group (Azure) | `rg-{proyecto}-{env}` | `rg-miapp-dev` | `rg-miapp-pro` |
| App Service | `app-{proyecto}-{env}` | `app-miapp-dev` | `app-miapp-pro` |
| SQL Server | `sql-{proyecto}-{env}` | `sql-miapp-dev` | `sql-miapp-pro` |
| Base de datos | `db-{proyecto}-{env}` | `db-miapp-dev` | `db-miapp-pro` |
| Key Vault | `kv-{proyecto}-{env}` | `kv-miapp-dev` | `kv-miapp-pro` |
| Storage Account | `st{proyecto}{env}` | `stmiappdev` | `stmiapppro` |
| AWS S3 Bucket | `{proyecto}-{env}-{region}` | `miapp-dev-eu-west-1` | `miapp-pro-eu-west-1` |
| GCP Project | `{proyecto}-{env}` | `miapp-dev` | `miapp-pro` |

---

## Reglas de Promoción entre Entornos

```
DEV ──(CI automático)──► PRE ──(aprobación humana)──► PRO
```

1. **DEV → PRE**: Automático si pasan todos los quality gates (build + test + lint + security)
2. **PRE → PRO**: SIEMPRE requiere aprobación humana explícita
3. **PRO → Rollback**: Plan de rollback documentado antes de cada deploy a PRO
4. **Hotfix**: rama `hotfix/` → PRE → PRO (bypass DEV solo en emergencia documentada)

---

## Variables de Entorno Estándar

Cada proyecto debe definir estas variables mínimas por entorno:

```bash
# Identificación
APP_ENVIRONMENT=DEV           # Nombre del entorno actual
APP_VERSION=1.2.3             # Versión desplegada

# Conexiones (SIEMPRE en fichero protegido, NUNCA en repo)
DATABASE_CONNECTION_STRING=   # Connection string BD
REDIS_CONNECTION_STRING=      # Cache
MESSAGE_BUS_CONNECTION=       # Service Bus / RabbitMQ

# Servicios externos
API_BASE_URL=                 # URL del API del entorno
AUTH_AUTHORITY=               # URL del proveedor de autenticación
AUTH_CLIENT_ID=               # Client ID (puede ir en repo si no es secret)
AUTH_CLIENT_SECRET=           # Client secret (NUNCA en repo)

# Observabilidad
LOG_LEVEL=Information         # DEV=Debug, PRE=Information, PRO=Warning
TELEMETRY_KEY=                # Application Insights / Datadog key
```

---

## Detección Automática de Entorno

Al cargar un proyecto (`/context:load`), detectar entornos por:

| Señal | Interpretación |
|---|---|
| `appsettings.{ENV}.json` | .NET multi-entorno |
| `.env.{ENV}` o `config.local/.env.{ENV}` | Entornos con dotenv |
| `infrastructure/environments/{env}/` | Terraform multi-entorno |
| `deploy/pipelines/*{ENV}*` | Pipelines por entorno |
| `docker-compose.{env}.yml` | Docker multi-entorno |
| Sección `ENVIRONMENTS` en CLAUDE.md | Declaración explícita |

---

## Checklist Nuevo Entorno

- [ ] Nombre, diminutivo y propósito definidos en CLAUDE.md del proyecto
- [ ] Fichero de configuración no-sensible creado (`appsettings.{ENV}.json` o equivalente)
- [ ] Fichero de secrets creado en `config.local/.env.{ENV}` (git-ignorado)
- [ ] Infraestructura definida en `infrastructure/environments/{env}/`
- [ ] Pipeline de deploy creado o actualizado
- [ ] Naming de recursos cloud siguiendo convención `{recurso}-{proyecto}-{env}`
- [ ] Variables de entorno documentadas en README del proyecto
- [ ] Plan de rollback documentado (obligatorio para PRE y PRO)
