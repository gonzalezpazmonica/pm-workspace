# Savia → Savia Enterprise — Migración estratégica

> **Fecha:** 2026-04-11
> **Autora:** la usuaria González Paz
> **Contexto:** Informe estratégico profesional Q1-Q2 2026
> **Licencia objetivo:** MIT (core + enterprise modules)
> **Principio no negociable:** Agnosticismo total, zero vendor lock-in

---

## 1. Tesis

Savia Enterprise **no es un fork ni un producto cerrado**. Es una extensión
modular sobre Savia Core (MIT) que añade capacidades exigidas por organizaciones
reguladas —multi-tenancy, compliance, SSO, observabilidad federada, despliegue
soberano— **sin romper ninguno de los 7 principios fundacionales** ni crear
dependencia con ningún proveedor.

La apuesta no es convertir Savia en SaaS. Es convertirla en la **referencia
open-source de arquitectura agentic soberana** que las empresas pueden desplegar
on-premise, auditar línea a línea y mantener sin nosotros si así lo deciden.

El informe estratégico identifica tres ejes de mercado donde Savia ya está del
lado correcto: **agentic AI + soberanía + criterio humano**. Enterprise es la
capa que hace esa posición legible desde fuera.

---

## 2. Principios inmutables (NUNCA se tocan)

Los 7 principios de `savia-foundational-principles.md` se preservan íntegros.
Cualquier módulo Enterprise que los viole se rechaza en code review, sin
excepción, sin override, sin "solo por este cliente".

| # | Principio | Implicación Enterprise |
|---|-----------|------------------------|
| 1 | Soberanía del dato: `.md` es la verdad | NUNCA migrar fuente de verdad a DB propietaria |
| 2 | Independencia del proveedor | Adaptadores, nunca acoplamientos |
| 3 | Honestidad radical | Benchmarks públicos, fallos documentados |
| 4 | Privacidad absoluta | N4 nunca sale del cliente; modo air-gap ready |
| 5 | El humano decide | Gates humanos en merge, deploy, compliance |
| 6 | Igualdad (Equality Shield) | Aplicado también en onboarding enterprise |
| 7 | Protección de identidad | Savia sigue siendo Savia bajo cualquier marca |

---

## 3. Arquitectura de capas

```
┌─────────────────────────────────────────────────────┐
│  Savia Enterprise (MIT, opt-in modules)             │
│  ├── multi-tenant, RBAC, SSO, SAML                  │
│  ├── governance pack (AI Act, NIS2, DORA)           │
│  ├── observability stack (OTel federado)            │
│  ├── sovereign deployment (air-gap, Ollama)         │
│  └── enterprise dashboard                           │
├─────────────────────────────────────────────────────┤
│  Savia Core (MIT) — INTOCABLE                       │
│  ├── 46 agents, 82 skills, 496 commands             │
│  ├── Spec-Driven Development                        │
│  ├── Savia Shield (data sovereignty)                │
│  ├── Equality Shield                                │
│  └── Radical Honesty                                │
├─────────────────────────────────────────────────────┤
│  Adapter layer (agnóstico)                          │
│  ├── MCP servers (Azure DevOps, Jira, GitHub)       │
│  ├── Agent runtimes (MS Agent FW, LangGraph, SK)    │
│  ├── Model providers (Anthropic, OpenAI, Ollama)    │
│  └── Storage (local .md, opt-in vector DB)          │
└─────────────────────────────────────────────────────┘
```

**Regla:** ningún módulo Enterprise puede contener lógica que Core necesite.
Core funciona sin Enterprise. Enterprise no funciona sin Core. Dependencia
unidireccional.

---

## 4. Las 34 specs de migración

### 4.1 Core Platform (SE-001..SE-006)

Fundamentos de la plataforma enterprise: contratos de capas, aislamiento multi-tenant, catálogo MCP, interoperabilidad de agentes, despliegue soberano y gobernanza.

| Spec | Título | Descripción |
|------|--------|-------------|
| [SE-001](SPEC-SE-001-foundations.md) | Foundations & Layer Contract | Contrato de capas Core/Enterprise, dependencia unidireccional y estructura de módulos |
| [SE-002](SPEC-SE-002-multi-tenant.md) | Multi-Tenant & RBAC | Aislamiento por tenant con control de acceso basado en roles |
| [SE-003](SPEC-SE-003-mcp-catalog.md) | MCP Server Catalog | Catálogo de MCP servers para integración con herramientas enterprise |
| [SE-004](SPEC-SE-004-agent-framework-interop.md) | Agent Framework Interop | Interoperabilidad con MS Agent Framework, LangGraph, Semantic Kernel |
| [SE-005](SPEC-SE-005-sovereign-deployment.md) | Sovereign Deployment | Despliegue soberano air-gap ready con Ollama y modelos locales |
| [SE-006](SPEC-SE-006-governance-compliance.md) | Governance & Compliance Pack | Pack de gobernanza para AI Act, NIS2, DORA con audit trail en git |

### 4.2 Business Operations (SE-007..SE-011)

Operaciones de negocio: onboarding a escala, licenciamiento, observabilidad, migración y documentación.

| Spec | Título | Descripción |
|------|--------|-------------|
| [SE-007](SPEC-SE-007-enterprise-onboarding.md) | Enterprise Onboarding & Scale | Onboarding batch de equipos grandes con perfiles y configuración a escala |
| [SE-008](SPEC-SE-008-licensing-distribution.md) | Licensing & Distribution Strategy | Estrategia de licenciamiento MIT y distribución del producto |
| [SE-009](SPEC-SE-009-observability.md) | Observability Stack | Stack de observabilidad con OpenTelemetry federado |
| [SE-010](SPEC-SE-010-migration-path.md) | Migration Path & Backward Compat | Ruta de migración desde Savia Core con compatibilidad retroactiva |
| [SE-011](SPEC-SE-011-docs-restructuring.md) | Documentation Restructuring & Narrative | Reestructuración de documentación y narrativa del producto |

### 4.3 Project Lifecycle (SE-012..SE-020)

Ciclo de vida completo del proyecto: desde la reducción de ruido en CI hasta dependencias cross-project, pasando por estimación, releases, prospección, valoración, definición contractual, facturación y evaluación post-entrega.

| Spec | Título | Descripción |
|------|--------|-------------|
| [SE-012](SPEC-SE-012-signal-noise-reduction.md) | Signal/Noise Reduction | Reducción del ruido en hooks, CI y cola de PRs para mejorar la eficiencia |
| [SE-013](SPEC-SE-013-dual-estimation.md) | Dual Estimation Rule | Estimación dual humano/agente con claim empírico de 10x throughput |
| [SE-014](SPEC-SE-014-release-orchestration.md) | Release Orchestration | Orquestación de releases multi-tenant, auditable, rollback-safe y air-gap ready |
| [SE-015](SPEC-SE-015-project-prospect.md) | Project Prospect (Pipeline-as-Code) | Pipeline de oportunidades como código con scoring BANT/MEDDIC y reutilización de propuestas |
| [SE-016](SPEC-SE-016-project-valuation.md) | Project Valuation (Business-Case-as-Code) | Business case vivo vinculado a datos de entrega con ROI ajustado por riesgo |
| [SE-017](SPEC-SE-017-project-definition.md) | Project Definition (SOW-as-Code) | Statement of Work como código con trazabilidad contractual end-to-end |
| [SE-018](SPEC-SE-018-project-billing.md) | Project Billing (Revenue-as-Code) | Motor de facturación aislado por tenant con reconocimiento de ingresos IFRS 15 |
| [SE-019](SPEC-SE-019-project-evaluation.md) | Project Evaluation (Lessons-as-Code) | Evaluación post-entrega con métricas CMMI, lecciones reutilizables y feedback al pipeline |
| [SE-020](SPEC-SE-020-cross-project-deps.md) | Cross-Project Dependencies (Portfolio-as-Graph) | Grafo de dependencias inter-proyecto con camino crítico y detección de contención de recursos |

### 4.4 Quality & Security (SE-021..SE-028)

Calidad y seguridad: code review multi-juez, gestión de bench, federación de conocimiento, salud de clientes, analytics de workforce, evidencia de compliance, entrenamiento de SLMs y protección contra prompt injection.

| Spec | Título | Descripción |
|------|--------|-------------|
| [SE-021](SPEC-SE-021-code-review-court.md) | Code Review Court | Tribunal de code review con 5 jueces especializados en paralelo para escalar la revisión de código AI |
| [SE-022](SPEC-SE-022-resource-bench.md) | Resource & Bench Management | Gestión soberana de recursos y bench con optimización de utilización y skills matching |
| [SE-023](SPEC-SE-023-knowledge-federation.md) | Knowledge Federation | Federación de conocimiento cross-project con minería de patrones anonimizados |
| [SE-024](SPEC-SE-024-client-health.md) | Client Health Intelligence | Scoring de salud de cuentas con señales de retención y mapeo de relaciones |
| [SE-025](SPEC-SE-025-agentic-workforce-analytics.md) | Agentic Workforce Analytics | Medición transparente de productividad humano-agente con contabilidad de costes |
| [SE-026](SPEC-SE-026-compliance-evidence.md) | Compliance Evidence Automation | Generación automática de evidencias para ISO 9001, CMMI, SOC 2, SOX, DORA, NIS2, AI Act |
| [SE-027](SPEC-SE-027-slm-training.md) | SLM Training Pipeline | Pipeline de fine-tuning local de Small Language Models con zero egress de datos |
| [SE-028](SPEC-SE-028-prompt-injection-guard.md) | Prompt Injection Guard | Escaneo de ficheros de contexto contra inyecciones de prompt en archivos .md |

### 4.5 Intelligence & Optimization (SE-029..SE-034)

Inteligencia y optimización: compresión iterativa de contexto, auto-mejora de skills, enforcement de delegación, lecciones cross-project, rotación de contexto y planificación diaria de activación de agentes.

| Spec | Título | Descripción |
|------|--------|-------------|
| [SE-029](SPEC-SE-029-iterative-compression.md) | Iterative Context Compression | Compresión iterativa de contexto que preserva semántica entre compactaciones |
| [SE-030](SPEC-SE-030-skill-self-improvement.md) | Skill Self-Improvement Pipeline | Pipeline automático de mejora de skills basado en métricas de invocación y feedback |
| [SE-031](SPEC-SE-031-delegation-toolset-enforcement.md) | Delegation Toolset Enforcement | Enforcement de toolsets restringidos al delegar tareas a subagentes |
| [SE-032](SPEC-SE-032-cross-project-lessons.md) | Cross-Project Lessons Pipeline | Pipeline de lecciones aprendidas cross-project con anonimización y propagación |
| [SE-033](SPEC-SE-033-context-rotation.md) | Context Rotation Strategy | Rotación temporal de contexto con archivado de sesiones y reset periódico |
| [SE-034](SPEC-SE-034-agent-activation-plan.md) | Daily Agent Activation Plan | Plan diario de activación de agentes con pre-carga de contexto por rol |

---

## 5. Alineación con el informe estratégico

| Apuesta del informe | Spec(s) que la ejecutan |
|---------------------|--------------------------|
| 5.2 Reposicionamiento AI Solutions Architect | SE-003, SE-004, SE-008 |
| 5.3 Savia como portfolio ejecutable | SE-001, SE-008, SE-010, SE-015..SE-020 |
| 5.4 Microsoft Agent Framework 1.0 | SE-004 |
| 5.6 MCP server público en .NET | SE-003 |
| Soberanía digital / IPCEI-AI | SE-005, SE-006, SE-027 |
| AI Act / NIS2 / DORA | SE-006, SE-026, SE-028 |
| Profundidad multi-stack | SE-003, SE-004 |
| Ciclo de vida consultivo end-to-end | SE-015, SE-016, SE-017, SE-018, SE-019 |
| Workforce analytics y ROI agéntico | SE-013, SE-022, SE-025 |
| Calidad de código a escala | SE-012, SE-021 |
| Inteligencia cross-project | SE-020, SE-023, SE-032 |
| Optimización de contexto y agentes | SE-029, SE-033, SE-034 |

---

## 6. Decisión sobre licenciamiento

**Todo MIT.** Sin dual-license. Sin "open core + commercial enterprise".
Los módulos Enterprise son MIT como Core. Lo que se monetiza (si procede) es
**soporte profesional, implantación y formación** — nunca el código.

Justificación: cualquier cosa distinta crea incentivos contra los principios 1
y 2 (soberanía + independencia del proveedor). Ver SE-008.

---

## 7. Lo que NO es Savia Enterprise

- No es un SaaS alojado por nosotros
- No es un fork cerrado
- No es un producto con módulos premium
- No es una plataforma que requiere Anthropic/OpenAI/Azure
- No es un sistema que encierre los datos del cliente
- No es un vehículo para telemetría ni tracking
- No es opinionated sobre runtime de agentes, modelo LLM o cloud

Savia Enterprise es **la misma Savia, con los tornillos que una organización
grande necesita para poder usarla en serio sin renunciar a su soberanía**.

---

## 8. Siguiente paso

1. Revisar las 34 specs en este directorio
2. Aprobar/ajustar prioridades (P0 → P3)
3. Crear PBIs en Azure DevOps con `/pbi-from-rules` a partir de specs aprobadas
4. Arrancar SE-001 + SE-008 en paralelo (fundamentos + licencia)
5. SE-003 y SE-005 son las dos palancas comerciales; arrancar segundas
6. SE-012..SE-020 cubren el ciclo de vida completo del proyecto consultivo
7. SE-021..SE-028 refuerzan calidad, seguridad y compliance a escala
8. SE-029..SE-034 optimizan la inteligencia interna y el uso de contexto
9. El resto se encadena según DAG en `/dag-plan`
