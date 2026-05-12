---
name: banking-bian
description: Validar arquitectura contra estándar BIAN y generar diagramas ArchiMate
developer_type: all
agent: architect
context_cost: high
---

# /banking-bian [--project {nombre}] [--diagram] [--level 1-5]

> 🏦 Valida tu arquitectura contra el framework BIAN y genera vistas ArchiMate.

---

## Cargar perfil y skill

Grupo: **Architecture & Tech** — cargar `identity.md` + `projects.md` + `preferences.md`.
Skill: `@.claude/skills/banking-architecture/SKILL.md`
Reference: `@.claude/skills/banking-architecture/references/bian-framework.md`

## Parámetros

- `--project {nombre}` — Proyecto (default: activo)
- `--diagram` — Generar diagramas ArchiMate en Mermaid
- `--level {1-5}` — Profundidad de validación (1=naming, 5=governance)

## Flujo

### Paso 1 — Detectar microservicios

Escanear proyecto: Docker Compose, Kubernetes manifests, service directories.
Listar servicios encontrados con sus APIs expuestas.

### Paso 2 — Mapear a BIAN Service Domains

Para cada microservicio detectado, intentar mapeo a BIAN:
```
payment-service      → Payment Initiation / Payment Execution
account-service      → Current Account / Savings Account
settlement-engine    → Settlement
scoring-service      → Credit Administration (Credit Scoring)
fraud-detector       → Fraud Detection
kyc-service          → Party Authentication
notification-service → Customer Event History
```

Identificar servicios NO mapeables (posible gap o god service).

### Paso 3 — Validar adherencia por nivel

**Nivel 1 — Naming:** ¿Servicios siguen nomenclatura BIAN?
**Nivel 2 — Boundaries:** ¿Cada servicio respeta los límites del domain?
**Nivel 3 — APIs:** ¿Service operations siguen el patrón BIAN?
**Nivel 4 — Data:** ¿Business Objects siguen metamodelo BIAN?
**Nivel 5 — Governance:** ¿Architecture Board valida cambios?

### Paso 4 — Detectar anti-patterns

Buscar en el reference:
- **God Service** — Un servicio cubre múltiples BIAN domains
- **Fragmented Domain** — Un domain partido en demasiados servicios
- **Missing Gateway** — Acceso directo a BD sin API
- **Coupled Settlement** — Settlement acoplado a payments
- **Shadow IT** — Servicios no registrados

### Paso 5 — Generar diagrama ArchiMate (si `--diagram`)

Generar Mermaid con viewpoints:
- **Application Cooperation** — Cómo cooperan los servicios
- **Technology Usage** — Servicios → infraestructura (K8s, Kafka, DBs)
- **Business Process** — Flujo de negocio → BIAN domains

Guardar en `projects/{p}/diagrams/local/bian-archimate.mermaid`

### Paso 6 — Generar informe

```markdown
# 🏦 BIAN Validation — {proyecto}

**Nivel validado:** {1-5} | **Adherencia:** {Alta|Media|Baja}
**Servicios detectados:** {N} | **Mapeados a BIAN:** {M}/{N}

## Service Domain Mapping
| Microservicio | BIAN Domain | Status |
|---------------|-------------|--------|
| payment-svc | Payment Execution | ✅ Mapped |
| mega-service | ⚠️ Multiple domains | ❌ God Service |

## Anti-patterns Detectados
1. ⚠️ {pattern} — Severidad: {CRITICAL|WARNING|INFO}

## Diagrama ArchiMate
(Mermaid diagram inline)

## Recomendaciones
- {acción concreta para mejorar adherencia}
```

Output: `output/banking-bian-{proyecto}-{fecha}.md`

## Restricciones

- BIAN es una referencia, no una imposición — las desviaciones pueden ser intencionales
- **SIEMPRE** marcar recomendaciones como "sugerencia técnica"
- Integra con `/arch-detect` para vista complementaria
- Sugerir `/banking-eda-validate` para validar pipelines Kafka
