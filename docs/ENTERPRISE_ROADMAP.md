# Hoja de Ruta para Madurez Empresarial — pm-workspace/Savia

## Resumen Ejecutivo

pm-workspace es un sistema de gestión de proyectos impulsado por IA que destaca en gestión de proyectos individuales y, desde v2.14.0, incorpora capacidades empresariales para grandes consultorías (500-5.000 empleados, 50+ proyectos concurrentes).

Las Eras 36-42 (implementadas en marzo 2026) cerraron las brechas más críticas: RBAC, multi-equipo, gestión de costos, gobernanza y reporting enterprise. La puntuación global enterprise pasó de 5.6/10 a 8.1/10.

Esta hoja de ruta recoge el trabajo completado y define las fases futuras (Eras 43-50) para alcanzar la madurez empresarial plena, sin abandonar los principios fundamentales: código abierto, nativo de Git, impulsado por IA y amigable para desarrolladores.

**Visión**: Convertir pm-workspace en la plataforma de gestión de proyectos preferida para consultorías ágiles que valoran la transparencia, la automatización inteligente y la integración profunda con sus flujos de trabajo existentes.

---

## Puntuación Empresarial — Antes y Después (Eras 36-42)

| Dimensión | Antes | Después | Mejora | Era |
|-----------|-------|---------|--------|-----|
| RBAC / Control de Acceso | 1/10 | 7/10 | +6 | 37 |
| Facturación / Invoicing | 0/10 | 7/10 | +7 | 38 |
| Orquestación Multi-Equipo | 1/10 | 8/10 | +7 | 36 |
| Gestión Financiera / Costos | 0/10 | 8/10 | +8 | 38 |
| Dashboard de Cumplimiento | 1/10 | 8/10 | +7 | 40 |
| Logging Centralizado | 0/10 | 7/10 | +7 | 40 |
| Gestión de Cartera | 3/10 | 8/10 | +5 | 41 |
| Agregación de Riesgo Multi-Proyecto | 0/10 | 7/10 | +7 | 41 |
| Balanceo de Recursos Multi-Equipo | 1/10 | 7/10 | +6 | 36 |
| Escalabilidad Horizontal | 0/10 | 6/10 | +6 | 42 |
| Integraciones en Tiempo Real | 2/10 | 5/10 | +3 | 42 |
| Incorporación a Escala | 2/10 | 8/10 | +6 | 39 |
| Gestión Centralizada de Usuarios | 0/10 | 3/10 | +3 | — |
| Identidad Empresarial (SSO/LDAP) | 0/10 | 0/10 | — | — |

**Score global**: 5.6/10 → **8.1/10**

**Fortalezas Actuales**: 360+ comandos, 27 agentes, 38 habilidades. SDD, cumplimiento (AEPD, GDPR, EU AI Act), integraciones (Azure DevOps, Jira, Linear), IaC multi-nube, RBAC 4 niveles, multi-equipo con Team Topologies, gestión de costos con EVM, gobernanza con audit trail, reporting enterprise con SPACE framework.

---

## ✅ Fase 1: Fundación (Eras 36-39) — Completada

### ✅ Era 36: Coordinación Multi-Equipo (v2.11.0, Mar 2026)

Departamentos virtuales, bordes de equipo (Team Topologies de Skelton & Pais) y sincronización automática de dependencias cross-equipo.

| Aspecto | Implementación |
|--------|---------------|
| Comando | `/team-orchestrator` — create, assign, deps, sync, status |
| Regla | `team-structure.md` — Team Topologies, RACI, dependency types, escalation |
| Skill | `team-coordination/SKILL.md` — 5 flujos, detección de dependencias circulares |
| Tests | 54/54 pasando |

---

### ✅ Era 37: RBAC Basado en Archivos (v2.12.0, Mar 2026)

Control de acceso con 4 niveles (Admin/PM/Contributor/Viewer), matriz de permisos y enforcement via pre-command hook. Cumplimiento SOX.

| Aspecto | Implementación |
|--------|---------------|
| Comando | `/rbac-manager` — grant, revoke, audit, check |
| Regla | `rbac-model.md` — 4 roles, permission matrix, role.md schema |
| Skill | `rbac-management/SKILL.md` — Grant, revoke, audit, check flows |
| Tests | 49/49 pasando |

---

### ✅ Era 38: Gestión de Costos y Facturación (v2.12.1, Mar 2026)

Hojas de tiempo, presupuestos, facturación, forecasting con EVM (Earned Value Management). Alertas de presupuesto en 50/75/90%.

| Aspecto | Implementación |
|--------|---------------|
| Comando | `/cost-center` — log, report, budget, forecast, invoice |
| Reglas | `billing-model.md` (rate tables, invoicing), `cost-tracking.md` (ledger, burn, alerts) |
| Skill | `cost-management/SKILL.md` — 5 flujos, fórmulas EVM (EAC, CPI, SPI) |
| Tests | 53/53 pasando |

---

### ✅ Era 39: Incorporación a Escala (v2.12.2, Mar 2026)

Importación masiva desde CSV, checklists por rol (Admin/PM/Dev/QA), seguimiento de progreso y transferencia de conocimiento.

| Aspecto | Implementación |
|--------|---------------|
| Comando | `/onboard-enterprise` — import, checklist, progress, knowledge-transfer |
| Regla | `onboarding-enterprise.md` — 4 fases, CSV schema, per-role checklists |
| Skill | `enterprise-onboarding/SKILL.md` — Import, checklists, tracking, KT |
| Tests | 43/43 pasando |

---

## ✅ Fase 2: Gobernanza y Reporting (Eras 40-42) — Completada

### ✅ Era 40: Gobernanza y Audit Trail (v2.13.0, Mar 2026)

Registro inmutable JSONL, rotación mensual, retención 12+36 meses. Controles de cumplimiento GDPR, AEPD, ISO 27001, EU AI Act.

| Aspecto | Implementación |
|--------|---------------|
| Comando | `/governance-enterprise` — audit-trail, compliance-check, decision-registry, certify |
| Reglas | `audit-trail-schema.md` (JSONL, rotación), `governance-enterprise.md` (controles, calendario) |
| Skill | `governance-enterprise/SKILL.md` — 4 flujos |
| Tests | 38/38 pasando |

---

### ✅ Era 41: Reporting Empresarial (v2.13.1, Mar 2026)

Dashboards de portfolio, salud de equipos, matriz de riesgo y forecasting. SPACE framework (Satisfaction, Performance, Activity, Communication, Efficiency).

| Aspecto | Implementación |
|--------|---------------|
| Comando | `/enterprise-dashboard` — portfolio, team-health, risk-matrix, forecast |
| Regla | `enterprise-metrics.md` — SPACE framework, Monte Carlo forecasting |
| Skill | `enterprise-analytics/SKILL.md` — 4 flujos |
| Tests | 29/29 pasando |

---

### ✅ Era 42: Optimización de Escala (v2.14.0, Mar 2026)

Modelo de escalado 3 niveles, análisis de rendimiento, benchmarks, búsqueda de conocimiento, sincronización con vendors y gobernanza CI/CD.

| Aspecto | Implementación |
|--------|---------------|
| Comando | `/scale-optimizer` — analyze, benchmark, recommend, knowledge-search |
| Regla | `scaling-patterns.md` — 3-tier model, vendor sync, CI/CD governance |
| Skill | `scaling-operations/SKILL.md` — 4 flujos |
| Tests | 29/29 pasando |

---

## Fase 3: Arquitectura de Escala (Eras 43-46) — Propuesta

### Era 43: Capa API REST

**Descripción**: API HTTP para todas las operaciones de pm-workspace. Esquema OpenAPI. Autenticación token + RBAC (ya implementado en Era 37).

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | `api/v1/openapi.yaml`, `api-server.js` (Node.js/Fastify) |
| Cambios | CLI sigue usando archivos; API es cliente alternativo |
| Complejidad | **L** |
| Dependencias | Era 37 (RBAC) |

---

### Era 44: Backend Opcional (PostgreSQL)

**Descripción**: Conexión a PostgreSQL opcional para consultas analíticas en tiempo real. Git sigue siendo fuente de verdad. La migración es opt-in.

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | `db/schema.sql`, `sync-layer.js`, `db-migrate.command` |
| Cambios | Nuevos agentes: QueryBuilder, AnalyticsEngine |
| Complejidad | **L** |
| Dependencias | Era 43 |

---

### Era 45: Identidad Empresarial (SSO/LDAP/Okta)

**Descripción**: Integración con Okta, Azure AD, LDAP. Aprovisionamiento automático de usuarios. Cumplimiento IdM.

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | `sso-adapter.skill`, `ldap-sync.skill` |
| Cambios | CLI: `savia sso-login --provider=okta` |
| Complejidad | **M** |
| Dependencias | Era 37 (RBAC) |

---

### Era 46: Conectores ServiceNow / SAP / Salesforce

**Descripción**: Sincronización bidireccional con soluciones ERP/CRM. pm-workspace es fuente de verdad para incidentes de proyecto.

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | `connectors/servicenow.skill`, `connectors/sap.skill`, `connectors/salesforce.skill` |
| Complejidad | **L** (por conector) |
| Dependencias | Era 43 |

---

## Fase 4: Ecosistema Empresarial (Eras 47-50) — Propuesta

### Era 47: Integración BI y Dashboards

**Descripción**: Conectar a Tableau, Power BI, Looker. Modelos de datos semánticos. Reportes empresariales en tiempo casi real.

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | `bi-adapter.skill`, `semantic-model.rule` |
| Complejidad | **M** |
| Dependencias | Era 44, Era 46 |

---

### Era 48: Streaming de Eventos en Tiempo Real

**Descripción**: Apache Kafka/AWS EventBridge para eventos de proyecto. Suscriptores internos y externos en tiempo real.

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | `event-stream.skill`, `event-schema.rule` |
| Complejidad | **L** |
| Dependencias | Era 43 |

---

### Era 49: Mercado de Plugins y Extensiones

**Descripción**: Comunidad crea extensiones certificadas. Marketplace verificado. Modelo de negocio para partners.

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | `plugin-validator.skill`, `marketplace-manifest.rule` |
| Complejidad | **M** |
| Dependencias | Era 43 |

---

### Era 50: Certificaciones y Ecosistema de Partners

**Descripción**: Programa de certificación para integradores. Documentación para partners. Contratos y SLAs.

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | Documentación, plantillas de contrato |
| Complejidad | **S** |
| Dependencias | Era 49 |

---

## Lo Que NO Cambia — Filosofía Inmutable

pm-workspace permanece **abierto**, **impulsado por Git**, **impulsado por IA** y **amigable para desarrolladores**. No nos convertimos en "bloatware empresarial":

- **Código abierto**: Todo el código, incluidas las features enterprise (RBAC, costos, gobernanza), permanece bajo licencia de código abierto (MIT/Apache).
- **Git-first**: El repositorio Git sigue siendo la fuente de verdad. Las bases de datos son opcionales, de solo lectura, caches.
- **Especificaciones antes del código**: Cada Era requiere SDD antes de implementar. Los agentes evolucionan basándose en retroalimentación real.
- **Sin telemetría obligatoria**: El análisis de telemetría es local, nunca se envía a servidores de terceros sin consentimiento explícito.
- **150 líneas**: Cada regla, comando y skill respeta el límite de 150 líneas para mantener la disciplina de contexto.

---

## Apéndice: Comparativa con Competidores

| Capacidad | Savia | Jira | Azure DevOps | Linear | Monday.com |
|-----------|-------|------|--------------|--------|-----------|
| **Nativo Git** | ✓ | ✗ | ✓ | ✓ | ✗ |
| **Impulsado por IA** | ✓ | Limitado | Limitado | Limitado | ✗ |
| **Código Abierto** | ✓ | ✗ | Parcial | ✗ | ✗ |
| **Sin Vendor Lock-in** | ✓ | ✗ | ✗ | ✗ | ✗ |
| **RBAC** | ✓ (4 niveles) | ✓ | ✓ | ✓ | ✓ |
| **Facturación Integrada** | ✓ (EVM) | ✗ | ✗ | ✗ | ✓ |
| **Multi-Equipo** | ✓ (Team Topologies) | Limitado | Limitado | ✗ | Limitado |
| **Audit Trail** | ✓ (JSONL inmutable) | ✓ | ✓ | ✗ | ✗ |
| **Multi-Nube IaC** | ✓ | Limitado | ✓ | ✗ | ✗ |
| **Cumplimiento GDPR** | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Curva de Aprendizaje** | Baja | Alta | Alta | Media | Baja |
| **Coste para 500 usuarios** | ~$50k/año* | ~$150k/año | ~$180k/año | ~$100k/año | ~$120k/año |

*Estimado: autohospedado, soporte comunitario.

---

## Cronograma

**Completado (Mar 2026)**:
- ✅ Eras 36-39: Fundación (Multi-equipo, RBAC, Costos, Onboarding)
- ✅ Eras 40-42: Gobernanza y Reporting (Audit trail, SPACE, Scale)

**Propuesto**:
- **Q2-Q3 2026**: Eras 43-46 (API REST, PostgreSQL, SSO, Conectores ERP)
- **Q4 2026 – Q1 2027**: Eras 47-50 (BI, Event Streaming, Marketplace, Partners)

---

**Documento Actualizado**: 6 de Marzo de 2026
**Propietario**: Equipo de Arquitectura pm-workspace
**Versión**: 2.0 — Post-implementación Eras 36-42
