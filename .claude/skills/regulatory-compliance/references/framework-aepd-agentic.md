---
name: AEPD Agentic AI Framework
description: Orientaciones AEPD sobre IA agéntica — requisitos específicos españoles
context_cost: low
---

# AEPD — IA Agéntica y Protección de Datos

## Applicable Regulations

- **RGPD (Reglamento General de Protección de Datos)**
- **LOPDGDD (Ley Orgánica de Protección de Datos)**
- **EU AI Act (Reglamento Europeo de IA)**
- **Orientaciones AEPD sobre IA Agéntica (2026)**

## Detection Markers

### Packages
- anthropic, openai, google-generativeai, langchain, autogen
- claude-agent-sdk, semantic-kernel, crewai

### Entities
- Agent, Tool, Prompt, Model, Pipeline, Chain, Memory
- ActionLog, AuditTrail, GovernancePolicy, RiskAssessment

### APIs
- /api/agents, /api/workflows, /api/actions
- /api/governance, /api/audit, /api/compliance

### Configuration
- ANTHROPIC_API_KEY, OPENAI_API_KEY, AGENT_MODE
- GOVERNANCE_POLICY_*, AI_RISK_LEVEL_*
- AEPD_COMPLIANCE_*, RGPD_MODE_*

### Middleware & Services
- AgentOrchestrator, GovernanceMiddleware, AuditLogger
- ScopeGuard, PlanGate, SecurityGuardian

### Database & Schema
- agent_actions, audit_logs, governance_policies
- risk_assessments, consent_records, data_processing

### Folder & Namespace Patterns
- Agents/, Governance/, Compliance/, AI/, Orchestration/

### Documentation & CI/CD
- AEPD, RGPD, LOPDGDD, IA agéntica, agentes autónomos
- evaluación de impacto, privacy by design

## Compliance Checklist

- [ ] EIPD (Evaluación de Impacto) documentada por agente
- [ ] Base jurídica identificada para cada tratamiento
- [ ] Transparencia: usuario sabe que interactúa con IA
- [ ] Minimización: agente solo accede a datos necesarios
- [ ] Scope guard: agente no actúa fuera de su alcance
- [ ] Audit trail: todas las acciones registradas
- [ ] Supervisión humana para acciones de riesgo alto
- [ ] Protocolo notificación brechas (72h AEPD)
- [ ] Derecho de oposición: usuario puede detener agente
- [ ] Revisión trimestral de cumplimiento

## Common Violations

- Agente accede a datos sin base jurídica documentada
- Sin EIPD antes de desplegar agente autónomo
- Agente actúa fuera de scope sin control
- Datos personales en logs sin anonimizar
- Sin mecanismo de parada (kill switch)
- Ausencia de supervisión humana en decisiones críticas

## Risk Assessment

**Severity**: Critical (multas RGPD hasta 4% facturación)
**Scope**: Todos los agentes que procesan datos personales
**Impact**: Sanciones AEPD, pérdida de confianza, litigios
