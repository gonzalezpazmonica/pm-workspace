---
name: governance-enterprise
description: "Enterprise governance matrix (GDPR, AEPD, ISO 27001, EU AI Act), compliance controls, decision registry"
auto_load: false
paths: [".opencode/commands/governance-enterprise*", ".opencode/skills/governance-enterprise/*"]
---

# Regla: Gobernanza Empresarial

> Basado en: NIST AI RMF, EU AI Act (2024/1689), AEPD Orientaciones (Feb 2026)
> Complementa: @.opencode/skills/regulatory-compliance/references/aepd-framework.md, @docs/rules/domain/audit-trail-schema.md

**Principio fundamental**: Gobierno visible, auditables y evolucionables de sistemas de IA agéntica.

## Matriz de controles

### GDPR (2018/679) — 9 controles

| ID | Control | Frecuencia | Owner | Evidencia |
|---|---|---|---|---|
| GDPR-1 | Data minimization audit | Quarterly | DPO | audit-trail + report |
| GDPR-2 | Consent registry | Continuous | PM | consent-log.jsonl |
| GDPR-3 | Breach notification test | Annual | Security | test-report |
| GDPR-4 | DPIA para nuevos agentes | Pre-deploy | DPO | dpia.md |
| GDPR-5 | Art. 17 (right to be forgotten) testing | Annual | DPO | test-results |
| GDPR-6 | International transfer compliance | Annual | Legal | policy-review |
| GDPR-7 | Third-party data processor agreements | Annual | Procurement | signed-docs |
| GDPR-8 | Data inventory audit | Quarterly | DPO | inventory-report |
| GDPR-9 | Retention policy enforcement | Quarterly | Ops | retention-check |

### ISO 27001 — 6 controles

| ID | Control | Frecuencia | Owner | Evidencia |
|---|---|---|---|---|
| ISO-1 | Access control review | Quarterly | Security | iam-audit |
| ISO-2 | Encryption enforcement (at-rest, in-transit) | Monthly | Ops | encryption-report |
| ISO-3 | Incident response drills | Quarterly | Security | drill-report |
| ISO-4 | Vulnerability scanning | Weekly | Security | scan-results |
| ISO-5 | Backup restore testing | Quarterly | Ops | restore-test |
| ISO-6 | Security awareness training | Annual | HR | completion-report |

### EU AI Act (2024/1689) — 8 controles

| ID | Control | Frecuencia | Owner | Evidencia |
|---|---|---|---|---|
| AI-1 | High-risk classification audit | Quarterly | CTO | risk-assessment |
| AI-2 | Transparency register compliance | Continuous | PM | transparency-log |
| AI-3 | Training data documentation | Pre-deploy | Architect | dataset-card.md |
| AI-4 | Bias testing (counterfactual audit) | Pre-deploy | ML Lead | bias-report.md |
| AI-5 | Human oversight mechanism verification | Monthly | PM | oversight-check |
| AI-6 | Performance monitoring (drift detection) | Weekly | ML Lead | drift-report |
| AI-7 | Consumer complaint handling | Continuous | Customer Service | complaint-log |
| AI-8 | Compliance gap remediation | Continuous | Compliance | remediation-plan |

### AEPD (IA Agéntica) — 5 controles

| ID | Control | Frecuencia | Owner | Evidencia |
|---|---|---|---|---|
| AEPD-1 | Agente autonomy boundary review | Quarterly | CTO | scope-guard-audit |
| AEPD-2 | Human-in-the-loop enforcement | Monthly | PM | hiloop-logs |
| AEPD-3 | Spanish data localization verification | Quarterly | Infra | data-residency-check |
| AEPD-4 | Minor data protection (COPPA-like) | Quarterly | Legal | minor-check |
| AEPD-5 | AI governance audit | Annual | DPO | aepd-audit-report |

## Calendario de cumplimiento

```
QUARTERLY (cada 3 meses a 1º del mes)
  - GDPR-1: Auditoría de minimización de datos
  - GDPR-8: Auditoría de inventario
  - ISO-1: Revisión de control de acceso
  - ISO-5: Test de restauración de backups
  - AI-1: Auditoría de clasificación de riesgo
  - AEPD-1, AEPD-2, AEPD-3, AEPD-4: Revisiones trimestrales

MONTHLY
  - ISO-2: Enforcement de cifrado
  - AI-5, AEPD-2: Verificación de mecanismos de supervisión

WEEKLY
  - ISO-4: Vulnerability scanning
  - AI-6: Drift detection

ANNUAL (Enero)
  - GDPR-3: Test de notificación de brecha
  - GDPR-5, GDPR-6, GDPR-7, ISO-6: Auditorías anuales
  - AEPD-5: Auditoría completa de gobernanza de IA

CONTINUOUS
  - GDPR-2: Registry de consentimiento
  - AI-2, AI-7, AI-8: Logs y tracking
```

## Decision Registry

Cada decisión significativa se registra:

```yaml
---
id: "DEC-2026-015"
date: "2026-03-05"
decision: "Autorizar uso de modelo Sonnet 4.6 para scoring de clientes"
rationale: "Evaluación GDPR+AEPD completada; bias testing passed; human oversight implementado"
participants: ["cto@empresa.com", "dpo@empresa.com", "pm@empresa.com"]
status: "active"      # active | superseded | revoked
evidence:
  - "bias-report-20260303.md"
  - "dpia-customer-scoring.md"
  - "governance-audit-20260301.md"
---
```

**Almacenamiento**: `decision-registry.md` (registro único, append-only)

## Certificación

**Flujo**:
1. **Assess**: Ejecutar `/governance-enterprise compliance-check` → scores por control
2. **Remediate**: Si score < 80%, crear remediation plan
3. **Certify**: Si todos los controles ≥ 80%, generar `/governance-enterprise certify`
4. **Monitor**: Continuous monitoring; si score cae, alertar

**Output certificación**: `compliance-cert-YYYYMM.pdf` + decision-registry entry

## Integración

| Comando | Uso |
|---|---|
| `/governance-enterprise audit-trail` | Leer/queryar trail de acciones |
| `/governance-enterprise compliance-check` | Verificar controles |
| `/governance-enterprise decision-registry` | Log de decisiones |
| `/governance-enterprise certify` | Generar certificación de cumplimiento |
