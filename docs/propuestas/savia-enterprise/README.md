# Savia → Savia Enterprise — Migración estratégica

> **Fecha:** 2026-04-11
> **Autora:** Mónica González Paz
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

## 4. Las 11 specs de migración

| Spec | Título | Prioridad | Estima |
|------|--------|-----------|--------|
| [SE-001](SPEC-SE-001-foundations.md) | Foundations & Layer Contract | P0 | 3d |
| [SE-002](SPEC-SE-002-multi-tenant.md) | Multi-Tenant & RBAC | P0 | 5d |
| [SE-003](SPEC-SE-003-mcp-catalog.md) | MCP Server Catalog | P0 | 8d |
| [SE-004](SPEC-SE-004-agent-framework-interop.md) | Agent Framework Interop | P1 | 10d |
| [SE-005](SPEC-SE-005-sovereign-deployment.md) | Sovereign Deployment | P0 | 6d |
| [SE-006](SPEC-SE-006-governance-compliance.md) | Governance & Compliance Pack | P1 | 8d |
| [SE-007](SPEC-SE-007-enterprise-onboarding.md) | Enterprise Onboarding & Scale | P2 | 5d |
| [SE-008](SPEC-SE-008-licensing-distribution.md) | Licensing & Distribution Strategy | P0 | 2d |
| [SE-009](SPEC-SE-009-observability.md) | Observability Stack | P1 | 5d |
| [SE-010](SPEC-SE-010-migration-path.md) | Migration Path & Backward Compat | P0 | 4d |
| [SE-011](SPEC-SE-011-docs-restructuring.md) | Documentation Restructuring & Narrative | P0 | 6d |

Total estimado: ~62 días agente (≈ 2 sprints de dev-orchestrator con paralelismo).

---

## 5. Alineación con el informe estratégico

| Apuesta del informe | Spec(s) que la ejecutan |
|---------------------|--------------------------|
| 5.2 Reposicionamiento AI Solutions Architect | SE-003, SE-004, SE-008 |
| 5.3 Savia como portfolio ejecutable | SE-001, SE-008, SE-010 |
| 5.4 Microsoft Agent Framework 1.0 | SE-004 |
| 5.6 MCP server público en .NET | SE-003 |
| Soberanía digital / IPCEI-AI | SE-005, SE-006 |
| AI Act / NIS2 / DORA | SE-006 |
| Profundidad multi-stack | SE-003, SE-004 |

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

1. Revisar las 10 specs en este directorio
2. Aprobar/ajustar prioridades (P0 → P2)
3. Crear PBIs en Azure DevOps con `/pbi-from-rules` a partir de specs aprobadas
4. Arrancar SE-001 + SE-008 en paralelo (fundamentos + licencia)
5. SE-003 y SE-005 son las dos palancas comerciales; arrancar segundas
6. El resto se encadena según DAG en `/dag-plan`
