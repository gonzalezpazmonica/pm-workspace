# Hoja de Ruta para Madurez Empresarial — pm-workspace/Savia

## Resumen Ejecutivo

pm-workspace es un sistema de gestión de proyectos impulsado por IA que destaca en gestión de proyectos individuales para equipos de 5-30 personas. Sin embargo, las grandes consultorías (500-5,000 empleados, 50+ proyectos concurrentes) requieren capacidades empresariales que actualmente no existen.

Esta hoja de ruta define un camino de 15 eras (36-50) dividido en 4 fases para cerrar brechas críticas sin abandonar los principios fundamentales: código abierto, nativo de Git, impulsado por IA y amigable para desarrolladores.

**Visión**: Convertir pm-workspace en la plataforma de gestión de proyectos preferida para consultorías ágiles que valoran la transparencia, la automatización inteligente y la integración profunda con sus flujos de trabajo existentes.

---

## Puntuación Actual — Diagnóstico Empresarial

| Dimensión | Score | Nivel |
|-----------|-------|-------|
| RBAC / Control de Acceso | 1/10 | Crítico |
| Facturación / Invoicing | 0/10 | Crítico |
| Orquestación Multi-Equipo | 1/10 | Crítico |
| Gestión Centralizada de Usuarios | 0/10 | Crítico |
| Escalabilidad Horizontal | 0/10 | Crítico |
| Integraciones en Tiempo Real | 2/10 | Alto |
| Gestión Financiera / Costos | 0/10 | Crítico |
| Dashboard de Cumplimiento | 1/10 | Alto |
| Logging Centralizado | 0/10 | Medio |
| Identidad Empresarial (SSO/LDAP) | 0/10 | Crítico |
| Gestión de Cartera | 3/10 | Medio |
| Agregación de Riesgo Multi-Proyecto | 0/10 | Medio |
| Balanceo de Recursos Multi-Equipo | 1/10 | Medio |
| Características de Conocimiento Social | 0/10 | Bajo |

**Fortalezas Actuales**: 343 comandos, 27 agentes, 31 habilidades. Desarrollo impulsado por especificaciones (SDD), cumplimiento (AEPD, GDPR, EU AI Act), integraciones solidas (Azure DevOps, Jira, Linear), IaC multi-nube, excelente experiencia de desarrollador.

---

## Fase 1: Fundación (Eras 36-38) — Gobernanza Organizacional

### Era 36: Orquestación Multi-Equipo y Espacios de Trabajo

**Descripción**: Introducir departamentos virtuales, bordes de equipo y sincronización automática de dependencias. Permite que equipos independientes coordinen objetivos sin punto único de fallo.

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | `team-orchestration.rule`, `dept-sync.skill`, `boundary-manager.command` |
| Cambios | `core/agents`: agregar agente Orchestrator; `core/commands`: `savia team-link`, `savia dept-status` |
| Complejidad | **M** |
| Dependencias | Ninguna |

---

### Era 37: Gobernanza Centralizada y Audit Trail

**Descripción**: Sistema de permisos granular basado en roles, registro inmutable de todas las operaciones (quién, qué, cuándo). Cumplimiento GDPR/SOX.

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | `governance.rule`, `audit-logger.skill`, `permissions-map.rule` |
| Cambios | Almacenamiento: `teams/{team}/audit.jsonl` (append-only); CLI: `savia audit-log --filter=user:alice` |
| Complejidad | **M** |
| Dependencias | Era 36 |

---

### Era 38: Incorporación Empresarial a Escala

**Descripción**: API para importar usuarios desde CSV, provisionamiento automático de espacios de trabajo, plantillas de proyecto estándar.

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | `bulk-import.command`, `workspace-templates.rule`, `onboarding.skill` |
| Cambios | CLI: `savia import-users --file=users.csv --org=acme` |
| Complejidad | **S** |
| Dependencias | Era 37 |

---

## Fase 2: Inteligencia Financiera (Eras 39-41)

### Era 39: Pipeline de Facturación

**Descripción**: Integrar hojas de tiempo con facturación. Generar facturas por cliente, servicio, proyecto. Sincronización con SAP/NetSuite (inicial: exportar a CSV).

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | `timesheet-to-invoice.skill`, `billing-rules.rule`, `invoice-generator.command` |
| Cambios | Entrada: hojas de tiempo existentes; Salida: `teams/{team}/invoices/{client}_{period}.json` |
| Complejidad | **M** |
| Dependencias | Era 38 |

---

### Era 40: Gestión de Costos y Utilización

**Descripción**: Dashboard de utilización por recurso/proyecto/cliente. Análisis de rentabilidad. Alertas cuando proyectos superan presupuesto.

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | `cost-analyzer.skill`, `budget-alerts.rule`, `utilization-dashboard.command` |
| Cambios | Métricas: `teams/{team}/financials/costs.json`; Reporte: `savia cost-report --period=2026-Q1` |
| Complejidad | **M** |
| Dependencias | Era 39 |

---

### Era 41: Previsión y Planificación Financiera

**Descripción**: Modelos de ingresos futuros basados en cartera. Análisis de escenarios (qué pasa si perdemos cliente X).

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | `forecast-model.skill`, `scenario-planner.command` |
| Cambios | Archivos: `teams/{team}/financials/forecast_{year}.json` |
| Complejidad | **L** |
| Dependencias | Era 40 |

---

## Fase 3: Arquitectura de Escala (Eras 42-45) — Cambios Arquitectónicos

### Era 42: Capa API REST

**Descripción**: API HTTP para todas las operaciones de pm-workspace. Esquema OpenAPI. Autenticación token + RBAC.

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | `api/v1/openapi.yaml`, `api-server.js` (Node.js/Fastify) |
| Cambios | CLI sigue usando archivos; API es cliente alternativo |
| Complejidad | **L** |
| Dependencias | Era 41 |

---

### Era 43: Backend Opcional (PostgreSQL)

**Descripción**: Conexión a PostgreSQL opcional para consultas analíticas en tiempo real. Git sigue siendo fuente de verdad. La migración es opt-in.

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | `db/schema.sql`, `sync-layer.js`, `db-migrate.command` |
| Cambios | Nuevos agentes: QueryBuilder, AnalyticsEngine |
| Complejidad | **L** |
| Dependencias | Era 42 |

---

### Era 44: Control de Acceso Basado en Roles (RBAC)

**Descripción**: Roles predefinidos (Gerente, Ejecutor, Observador, Admin). Control granular a nivel de proyecto/fianza. Cumplimiento SOX.

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | `rbac.rule`, `role-enforcement.skill` |
| Cambios | Validación en todos los puntos de entrada (CLI, API) |
| Complejidad | **M** |
| Dependencias | Era 43 |

---

### Era 45: Identidad Empresarial (SSO/LDAP/Okta)

**Descripción**: Integración con Okta, Azure AD, LDAP. Aprovisionamiento automático de usuarios. Cumplimiento IdM.

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | `sso-adapter.skill`, `ldap-sync.skill` |
| Cambios | CLI: `savia sso-login --provider=okta` |
| Complejidad | **M** |
| Dependencias | Era 44 |

---

## Fase 4: Ecosistema Empresarial (Eras 46-50)

### Era 46: Conectores ServiceNow / SAP / Salesforce

**Descripción**: Sincronización bidireccional con soluciones ERP/CRM. pm-workspace es fuente de verdad para incidentes de proyecto.

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | `connectors/servicenow.skill`, `connectors/sap.skill`, `connectors/salesforce.skill` |
| Complejidad | **L** (por conector) |
| Dependencias | Era 42 |

---

### Era 47: Integración BI y Dashboards

**Descripción**: Conectar a Tableau, Power BI, Looker. Modelos de datos semánticos. Reportes empresariales en tiempo casi real.

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | `bi-adapter.skill`, `semantic-model.rule` |
| Complejidad | **M** |
| Dependencias | Era 43, Era 46 |

---

### Era 48: Streaming de Eventos en Tiempo Real

**Descripción**: Apache Kafka/AWS EventBridge para eventos de proyecto. Suscriptores internos y externos en tiempo real.

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | `event-stream.skill`, `event-schema.rule` |
| Complejidad | **L** |
| Dependencias | Era 42 |

---

### Era 49: Mercado de Plugins y Extensiones

**Descripción**: Comunidad crea extensiones certificadas. Marketplace verificado. Modelo de negocio para partners.

| Aspecto | Detalles |
|--------|---------|
| Archivos a Crear | `plugin-validator.skill`, `marketplace-manifest.rule` |
| Complejidad | **M** |
| Dependencias | Era 42 |

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

- **Código abierto**: Todos los códigos, incluida la Era 45+ (SSO, RBAC, API), permanecen bajo licencia de código abierto (MIT/Apache).
- **Git-first**: El repositorio Git sigue siendo la fuente de verdad. Las bases de datos son opcionales, de solo lectura, caches.
- **Especificaciones antes del código**: Cada Era requiere SDD antes de implementar. Los agentes evolucionan basándose en retroalimentación real.
- **Sin telemetría obligatoria**: El análisis de telemetría es local, nunca se envía a servidores de terceros sin consentimiento explícito.

---

## Apéndice: Comparativa con Competidores

| Capacidad | Savia | Jira | Azure DevOps | Linear | Monday.com |
|-----------|-------|------|--------------|--------|-----------|
| **Nativo Git** | ✓ | ✗ | ✓ | ✓ | ✗ |
| **Impulsado por IA** | ✓ | Limitado | Limitado | Limitado | ✗ |
| **Código Abierto** | ✓ | ✗ | Parcial | ✗ | ✗ |
| **Sin Vendor Lock-in** | ✓ | ✗ | ✗ | ✗ | ✗ |
| **RBAC** | Próx. (E44) | ✓ | ✓ | ✓ | ✓ |
| **Facturación Integrada** | Próx. (E39) | ✗ | ✗ | ✗ | ✓ |
| **Multi-Nube IaC** | ✓ | Limitado | ✓ | ✗ | ✗ |
| **Cumplimiento GDPR** | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Curva de Aprendizaje** | Baja | Alta | Alta | Media | Baja |
| **Coste para 500 usuarios** | ~$50k/año* | ~$150k/año | ~$180k/año | ~$100k/año | ~$120k/año |

*Estimado: autohospedado, soporte comunitario.

---

## Cronograma Estimado

- **Q2-Q3 2026**: Eras 36-38 (Gobernanza)
- **Q4 2026**: Eras 39-41 (Financiero)
- **Q1-Q2 2027**: Eras 42-45 (Escala)
- **Q3-Q4 2027**: Eras 46-50 (Ecosistema)

**Recursos Recomendados**: 2 arquitectos, 3 ingenieros de características, 1 especialista en cumplimiento.

---

**Documento Actualizado**: 6 de Marzo de 2026
**Propietario**: Equipo de Arquitectura pm-workspace
**Aprobado**: Pendiente de revisión ejecutiva
