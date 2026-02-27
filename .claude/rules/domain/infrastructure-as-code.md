---
paths:
  - "**/*.tf"
  - "**/*.tfvars"
  - "**/*.bicep"
  - "**/Dockerfile"
  - "**/docker-compose*.yml"
  - "**/*.cdktf.*"
---

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

## Detección Automática — Referencias Completas

Antes de crear cualquier recurso, verificar si ya existe. Para comandos específicos
por proveedor, tiers de coste por entorno y tags obligatorios, ver:
**→ `iac-cloud-patterns.md`**

---

## Flujo de Creación de Infraestructura

1. **DETECTAR** — ¿Existe ya el recurso? (ver `iac-cloud-patterns.md`)
2. **PLANIFICAR** — Generar IaC con tier MÍNIMO
3. **VALIDAR** — `terraform validate` / `az deployment validate`
4. **ESTIMAR COSTE** — Coste mensual por tier
5. **PROPONER** — Documento para revisión: recursos + coste + alternativas
6. **APROBACIÓN HUMANA** — Revisión explícita requerida
7. **APLICAR** — Humano ejecuta apply / create
8. **VERIFICAR** — Confirmar recursos operativos

---

## Escalado de Recursos — Requiere Aprobación Humana

Cuando se detecta que un recurso necesita más capacidad:

1. **Diagnosticar** — Recopilar métricas (CPU, RAM, latencia)
2. **Proponer** — 2-3 opciones con impacto de coste
3. **Recomendar** — Opción de menor impacto económico
4. **Aguardar aprobación humana** — NUNCA ejecutar automáticamente
5. **Ejecutar tras aprobación** — Humano verifica y ejecuta comando

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

## Comandos de Workspace

| Comando | Descripción |
|---|---|
| `/infra-detect {proyecto} {env}` | Detectar infraestructura existente del proyecto en un entorno |
| `/infra-plan {proyecto} {env}` | Generar plan de infraestructura para un entorno |
| `/infra-estimate {proyecto}` | Estimar costes de infraestructura por entorno |
| `/infra-scale {recurso}` | Proponer escalado de un recurso (requiere aprobación) |
| `/infra-status {proyecto}` | Estado de la infraestructura actual del proyecto |

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
