# Guía: pm-workspace/Savia para Grandes Consultoras Tecnológicas

## 1. ¿Para quién es esta guía?

Esta guía está diseñada para **grandes consultoras tecnológicas** con:

- **500–5.000 empleados**
- **20–50+ proyectos concurrentes**
- **Múltiples clientes** (banca, seguros, energía, retail, administración pública, sanidad)
- **Stacks mixtos**: SAP, .NET, Java, Kubernetes, serverless, etc.
- **Necesidad de soberanía tecnológica y cumplimiento normativo**

Si tu consultora es más pequeña (5–50 personas), comienza con [Guía de Inicio Rápido](./quick-start.md).

**Ver también**: [Análisis de Gaps — Gran Consultora](guide-enterprise-gap-analysis.md) — 10 problemas operativos comunes y cómo los resuelve pm-workspace.

---

## 2. Qué ofrece pm-workspace a cada perfil

| Rol | Valor Clave | Comandos Principales | Resultado |
|-----|-------------|----------------------|-----------|
| **CEO/CFO** | ROI claro, tiempo-a-valor, margen, costos | `/ceo-report`, `/enterprise-dashboard`, `/cost-center` | Dashboard ejecutivo: proyectos, riesgos, costes, forecasting EVM |
| **CTO** | Soberanía tecnológica, sin lock-in, RBAC | `/sovereignty-audit`, `/rbac-manager`, `/scale-optimizer` | Control total de datos, permisos y cumplimiento normativo |
| **Dir. Operaciones** | Multi-equipo, previsibilidad, escala | `/team-orchestrator`, `/enterprise-dashboard`, `/forecast` | Coordinación cross-equipo (Team Topologies), sin cuellos de botella |
| **PM/Scrum Master** | Automatización, visibilidad, menos overhead | `/sprint-sync`, `/backlog-ai`, `/risk-radar` | Sprints sin ceremonias manuales, alertas proactivas |
| **Tech Lead** | Especificaciones precisas, SDD, AI agents | `/spec-review`, `/arch-decision`, `/sdd-status` | Dev entiende qué hace antes de escribir código |
| **Developers** | Contexto claro, menos reuniones, menos emails | `/context`, `/next-action`, `/spec-check` | Flujo de trabajo enfocado, evita 3 reuniones/día |
| **QA** | Testing coordenado, trazabilidad, SLA | `/test-plan`, `/regression-matrix`, `/qa-sign-off` | Bugs evitados (no encontrados), metricas de calidad |
| **RRHH / Onboarding** | Incorporación masiva, checklists, KT | `/onboard-enterprise`, `/team-orchestrator` | Onboarding de 100+ personas con checklists por rol |
| **Compliance Officer** | GDPR, AEPD, EU AI Act, audit trail | `/governance-enterprise`, `/rbac-manager`, `/ai-audit` | Audit trail inmutable, controles automáticos, certificación |

---

## 3. Modelo de Adopción Progresiva

**No es big-bang.** Es iterativo. Cada fase toma 4–12 semanas.

### **Fase 0: Piloto (4 semanas)**

- **Equipo**: 1 squad de 6–8 personas (1 proyecto pequeño/mediano)
- **Scope**: Clone repo → Setup perfiles → First sprint with `/sprint-sync`
- **Éxito**: Sprint completado, métricas capturadas, equipo adopta `/daily-standup`
- **Riesgos**: Falta de formación en SDD, acceso a Azure DevOps/Jira
- **Instalación**: Claude Code + pm-workspace CLI en laptop cada dev

### **Fase 1: Expansión Vertical (8 semanas)**

- **Equipo**: 3–5 squads del mismo dominio (ej: banca retail)
- **Scope**: Consolidar lecciones del piloto, integración con Azure DevOps/Jira
- **Éxito**: `/portfolio-overview` funciona, CIO ve datos consolidados
- **Riesgos**: Fricciones en cultura (algunos devs prefieren email)
- **Instalación**: Git centralizado, SaviaHub como wiki, PR Guardian en CI/CD

### **Fase 2: Expansión Horizontal (12 semanas)**

- **Equipo**: 2–3 unidades de negocio (ej: banca + seguros)
- **Scope**: Gobierno multi-proyecto, aislamiento por cliente, reportes ejecutivos
- **Éxito**: `/ceo-report` se ejecuta weekly, `/sovereignty-audit` pasa
- **Riesgos**: Competencia entre unidades, datos sensibles, GDPR
- **Instalación**: Multi-tenant architecture, `clients/{slug}/` folders, Azure DevOps federation

### **Fase 3: Organización Completa (ongoing)**

- **Equipo**: Todos los devs, PMs, líderes técnicos
- **Scope**: Soberanía cognitiva, ROI medible, feedback loop
- **Éxito**: Reducción 25–40% en "reuniones de coordinación", eficiencia +35%
- **Riesgos**: Deuda técnica en docs, cambios de personal, mandatos de herramientas legacy
- **Instalación**: Enterprise RBAC (`/rbac-manager` — 4 niveles), gobernanza (`/governance-enterprise`), licencias Claude escaladas

---

## 4. Arquitectura para Grandes Consultoras

### Estrategia de Repositorios

**Multi-repo por cliente** es mejor que monorepo en consultoras:

```
github.com/consulting-org/
├── client-alpha-backend/        # Proyecto banca
│   ├── savia/                   # SDD specs
│   └── .claude/                 # Agentes y skills
├── client-beta-infra/           # Proyecto cloud
│   ├── savia/
│   └── terraform/
└── shared-libs/                 # Libs reutilizables, separadas
```

**Ventaja**: Cada cliente en su repo = isolamiento claro, sin accidentes de código.

### SaviaHub como Central de Conocimiento

- Una instancia de SaviaHub por consultora (o por unidad de negocio grande)
- Sindica specs desde todos los proyectos: `curl /api/sync --repos client-*`
- PMs y líderes buscan patrones: `/search-savia "API auth patterns"` → reaprovechar
- Cumplimiento: Auditoría centralizada de quién accede a qué

### Integración con Azure DevOps / Jira

```bash
# Sincronizar trabajo planificado en Azure DevOps con SDD specs
savia sync --source azure-devops --org "tu-org" --project "cliente-alpha"

# Resultado: cada user story → spec en savia/specs/
# PR Guardian bloquea merges si spec está out-of-sync
```

### CI/CD: PR Guardian

En cada merge a `main`:

```yaml
# .github/workflows/pr-guardian.yml
- run: savia audit-spec
  # Bloquea si spec está vago o incompleto
- run: savia compliance-check
  # AEPD, GDPR, EU AI Act
- run: savia sovereignty-audit
  # Sin datos encriptados, sin vendor lock-in
```

---

## 5. Soberanía Tecnológica y Cognitiva

### Por qué importa en consultoras

1. **Datos de clientes**: Bancarios, sanitarios, seguros — muy sensibles. Un vendor lock-in con AI = riesgo GDPR/AEPD.
2. **Conocimiento organizacional**: Si toda tu arquitectura está en Copilot/Cursor proprietary, ¿quién es el dueño?
3. **Regulación**: EU AI Act, GDPR. Auditoría de vendor AI = obligatoria en 2025.

### `/sovereignty-audit` — Cómo usarlo

```bash
savia sovereignty-audit --client client-alpha --output report.json

# Resultado:
# ✅ Todos los specs en Git/Markdown (portable)
# ✅ Agents reutilizables, open-source
# ✅ Datos cliente: nunca enviados a Anthropic sin consentimiento explícito
# ✅ Cumplimiento: AEPD, GDPR, EU AI Act
```

### Garantías de Portabilidad

- **Specs**: Plain Markdown en Git. Importable a Jira, Linear, Azure DevOps.
- **SDD**: Plain YAML. Ningún formato proprietary.
- **Agents/Skills**: Python + YAML. Funciona en Cursor, VS Code, Claude Code, offline.
- **Datos cliente**: Jamás almacenados en servers Anthropic. Solo en tu Git + Azure/AWS.

### Savia vs. Copilot 100%

| Aspecto | Savia | Copilot 100% |
|--------|-------|--------------|
| **Lock-in** | Ninguno. Todo es Git. | Altísimo. Código ⊂ GitHub/Copilot. |
| **Cumplimiento** | GDPR, AEPD, EU AI Act nativo | Requiere acuerdos legales extra |
| **Auditoría** | `/sovereignty-audit` automática | Manual, costosa |
| **Coste** | pm-workspace free + Claude | GitHub + Copilot ($) |
| **Offline** | Sí | No |
| **Control de datos** | Tuyo 100% | Microsoft 100% |

---

## 6. Gobernanza Multi-Proyecto

### Portfolio View

```bash
savia portfolio-overview --org tu-consultora --output dashboard.json

# Devuelve:
# - 47 proyectos activos
# - 23 en riesgo (delay >5 días)
# - 12 en compliance review
# - ROI acumulado: 2.3M€/year
```

### Cross-Project Search

```bash
savia search-savia "patrón de autenticación API" --across-clients

# Encuentra en 40 proyectos:
# - 12 implementaciones JWT (recomendado)
# - 5 implementaciones OAuth2 (legado)
# - 3 pendientes de upgrade

# Reutiliza spec ganadora, aplica a nuevos proyectos
```

### Reportes Ejecutivos

```bash
# Semanal para CFO/CEO
savia ceo-report --week 2026-03-06 --metrics deployment-freq,defect-density,sprint-velocity

# Mensual para CTO
savia org-metrics --month 2026-03 --focus tech-debt,sovereignty,ai-cost
```

### Auditoría y Compliance

```bash
# Audit trail inmutable con governance-enterprise (Era 40)
savia governance-enterprise audit-trail --period 2026-Q1
savia governance-enterprise compliance-check --standard aepd,gdpr,eu-ai-act

# RBAC: verificar permisos de un usuario (Era 37)
savia rbac-manager audit --user alice --output audit.md

# Genera:
# - Quién accede a datos de quién (audit trail JSONL)
# - Permisos por rol (Admin/PM/Contributor/Viewer)
# - Controles de cumplimiento GDPR, AEPD, ISO 27001, EU AI Act
# - Calendario de compliance con rotación mensual
```

---

## 7. ROI y Métricas de Éxito

### Métricas Clave

| Métrica | Sin pm-workspace | Con pm-workspace | Mejora |
|---------|------------------|------------------|--------|
| **Time-to-spec** | 5–7 días | 1–2 días | 75% ↓ |
| **Deployment freq** | 1/mes (enterprise) | 3–5/sem | 10x ↑ |
| **Defect density** | 15/10k LOC | 6/10k LOC | 60% ↓ |
| **Reuniones coord** | 8–12/sem | 2–3/sem | 70% ↓ |
| **Time in email/chat** | 40% día | 15% día | 62% ↓ |

### Comparación de Costes (100 devs, 25 proyectos)

| Concepto | Jira + Confluence | Linear + Notion | pm-workspace |
|----------|-------------------|-----------------|--------------|
| **Licencias/year** | 45.000€ | 28.000€ | 5.000€* |
| **Formación** | 8.000€ | 6.000€ | 2.000€ |
| **Admin overhead** | 2 FTE/year | 1 FTE/year | 0.2 FTE/year |
| **Total anual** | 61.000€ | 35.000€ | 7.000€ |

*Asumiendo 25 Claude users @ 200€/year. pm-workspace itself es gratis (open-source).

**Payback**: 6–8 meses en productividad + ROI acumulado.

---

## 8. Capacidades Enterprise Actuales y Roadmap

### Funciona Hoy ✅

- SDD: generación de código desde especificaciones, completamente funcional
- Azure DevOps / Jira sync con Savia Flow
- Compliance audits (AEPD, GDPR, EU AI Act)
- Git-native, offline, sovereign
- Specs + implementation + QA en flujo único
- **RBAC**: Control de acceso 4 niveles (Admin/PM/Contributor/Viewer) con `/rbac-manager`
- **Multi-equipo**: Coordinación cross-equipo con Team Topologies via `/team-orchestrator`
- **Gestión de costos**: Timesheets, presupuestos, facturación, EVM con `/cost-center`
- **Onboarding masivo**: Importación CSV, checklists por rol con `/onboard-enterprise`
- **Gobernanza**: Audit trail inmutable JSONL, compliance checks con `/governance-enterprise`
- **Reporting enterprise**: Portfolio, team-health, risk-matrix, SPACE con `/enterprise-dashboard`
- **Optimización de escala**: Análisis, benchmarks, recomendaciones con `/scale-optimizer`

### Roadmap Enterprise (pendiente) 🔄

- **API REST**: Capa HTTP con OpenAPI + autenticación RBAC
- **SSO/LDAP/Okta**: Integración de identidad empresarial
- **Conectores ERP**: ServiceNow, SAP, Salesforce bidireccional
- **BI nativo**: Conectores Tableau, Power BI, Looker
- **LLM flexibility**: Soportar Gemini, Llama, además de Claude

Ver [ENTERPRISE_ROADMAP.md](../ENTERPRISE_ROADMAP.md) para detalles.

---

## 9. Quick-Start para el Equipo Piloto

### Paso 1: Setup (10 min por persona)

```bash
# En laptop dev (macOS, Linux, Windows + WSL)
git clone https://github.com/pm-workspace/savia.git
cd savia
./install.sh --profile consultancy

# Resultado:
# - Claude Code + pm-workspace CLI listo
# - Perfiles de equipo generados (CEO, CTO, Dev, QA, etc.)
```

### Paso 2: Clone del Proyecto Piloto (5 min)

```bash
savia init --client "cliente-piloto" --team "squad-1" \
  --languages "python,typescript" \
  --cloud "azure" \
  --integrations "azure-devops"

# Genera structure:
# cliente-piloto/
# ├── savia/specs/  (vacío, listo para primer sprint)
# ├── .claude/      (agents, skills)
# └── .github/workflows/pr-guardian.yml
```

### Paso 3: Primer Sprint (1 semana)

**Day 1–2**: Setup y kickoff
- Todos ejecutan `/profile-setup` para registrarse
- CTO ejecuta `/arch-decision --scope "auth strategy"` → spec generada

**Day 3–5**: Desarrollo con SDD
- Devs implementan spec con `/spec-check` en cada commit
- `/daily-standup --team squad-1 --format slack` enviado a 9am

**Day 6–7**: Review y reportes
```bash
# Friday 4pm
savia sprint-summary --team squad-1 --week 1 --output summary.md
savia ceo-report --client cliente-piloto --focus velocity,burndown

# Resultado: ✅ Spec completada, 0 surpresas, ROI visible
```

### Paso 4: Métricas de Éxito (Week 2)

```bash
savia metrics --team squad-1 --compare baseline

# ✅ Criterios:
# - Spec review time < 4 horas
# - 0 PRs bloqueados por ambigüedad spec
# - Satisfaction score >= 7/10
# - Velocity estable o +10%
```

---

## Siguientes Pasos

1. **Pilotos en paralelo**: Si hay 2–3 clientes candidatos, comienza 2 pilotos simultáneamente (12 semanas, no 4).
2. **Entrenamiento**: Dedica 2–3 días a devs + PMs en SDD + comandos frecuentes.
3. **Integración**: Conecta Azure DevOps / Jira API antes de Fase 1.
4. **Governance**: Designa "SDD Champion" (PM senior) y "Sovereignty Officer" (CTO o Compliance).
5. **Feedback**: Ejecuta `/pulse-survey` cada 2 semanas durante primeros 3 meses.

---

**Versión**: 2.0 | **Última actualización**: 2026-03-06 | **Mantainer**: pm-workspace Community
