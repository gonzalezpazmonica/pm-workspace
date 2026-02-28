---
name: regulatory-compliance
description: Marco regulatorio cross-sector para validación de compliance en código fuente
developer_type: all
context_cost: medium
paths:
  - ".claude/commands/compliance-*.md"
---

# Regulatory Compliance — Regla de Dominio

## Sectores regulados

12 sectores con regulaciones informáticas específicas. Un proyecto puede pertenecer a múltiples sectores.

| Sector | Regulaciones clave | Entidades típicas |
|--------|--------------------|-------------------|
| Healthcare | HIPAA, HL7/FHIR, GDPR salud, EU MDR | Patient, MedicalRecord, Diagnosis |
| Finance | PCI-DSS, PSD2, SOX, MiFID II | Transaction, Account, Payment |
| Food/Agriculture | FSMA 204, FDA 21 CFR 11, EU 178/2002 | Product, Batch, Supplier, Allergen |
| Justice/Legal | Protección datos judiciales, cadena custodia | Case, Evidence, Ruling, Party |
| Public Admin | ENS, eIDAS, WCAG 2.1, EIF | Citizen, Procedure, Document |
| Insurance | Solvency II, IDD | Policy, Claim, Risk, Premium |
| Pharma | GxP, 21 CFR Part 11, EU Annex 11 | Drug, ClinicalTrial, Batch |
| Energy | NERC CIP, NIS2 | Grid, Meter, Asset, SCADA |
| Telecom | ePrivacy, GDPR telecom | Subscriber, Call, Message |
| Education | FERPA, COPPA, CIPA | Student, Grade, Course |
| Defense | ITAR, NIST 800-171, CUI | Asset, Classification, Clearance |
| Transport/Auto | UNECE R155/R156, ISO 21434 | Vehicle, ECU, Firmware |

## Algoritmo de detección (5 fases, pesos calibrados)

```
Fase 1 — Domain Models (35%): modelos, DTOs, interfaces, enums del sector
Fase 2 — Naming & Routes (25%): APIs, controllers, servicios, carpetas, namespaces
Fase 3 — Dependencies (15%): paquetes NuGet/npm/pip sectoriales
Fase 4 — Configuration (15%): env, config keys, connection strings sectoriales
Fase 5 — Infra & Docs (10%): README, docs, CI/CD, terraform — menciones a regulaciones

score ≥ 55% → AUTO (proceder sin preguntar)
score 25-54% → ASK (mostrar top 3 sectores al usuario)
score < 25% → UNDETECTED (ofrecer "No regulado" para saltar)
```

Pesos calibrados tras testing real sobre 12 sectores (.NET 10, 2026-02-28).

## Patrones comunes cross-sector

### Cifrado (aplica a todos)
- **CRITICAL**: Datos PII sin cifrar at-rest → AES-256 mínimo
- **CRITICAL**: Transmisión sin TLS → TLS 1.2+ obligatorio
- **HIGH**: Sin gestión de claves → Implementar key rotation

### Audit Trails (aplica a 10 de 12 sectores)
- **CRITICAL**: Sin logging de acceso a datos sensibles
- **HIGH**: Logs editables (no append-only)
- **MEDIUM**: Sin retención definida

### Control de Acceso (aplica a todos)
- **CRITICAL**: Sin autenticación en endpoints sensibles
- **HIGH**: Sin RBAC/ABAC
- **MEDIUM**: Sin MFA en operaciones críticas

### Trazabilidad (aplica a food, pharma, justice, defense)
- **CRITICAL**: Sin cadena de custodia en datos regulados
- **HIGH**: Sin versionado de registros regulados
- **MEDIUM**: Sin capacidad de recall

### Consentimiento (aplica a healthcare, education, telecom)
- **CRITICAL**: Procesamiento sin base legal/consentimiento
- **HIGH**: Sin mecanismo de revocación
- **MEDIUM**: Sin minimización de datos

### Accesibilidad (aplica a public admin)
- **HIGH**: Sin WCAG 2.1 AA en servicios públicos digitales
- **MEDIUM**: Sin ARIA labels en formularios
- **LOW**: Sin testing automatizado de accesibilidad

## Matriz de severidad

| Tipo de violación | Healthcare | Finance | Food | Justice | Public | Pharma |
|---|---|---|---|---|---|---|
| Sin cifrado | CRITICAL | CRITICAL | HIGH | CRITICAL | HIGH | CRITICAL |
| Sin audit trail | CRITICAL | CRITICAL | HIGH | CRITICAL | HIGH | CRITICAL |
| Sin RBAC | HIGH | HIGH | MEDIUM | HIGH | HIGH | HIGH |
| Sin trazabilidad | HIGH | MEDIUM | CRITICAL | CRITICAL | MEDIUM | CRITICAL |
| Sin consentimiento | CRITICAL | HIGH | LOW | HIGH | MEDIUM | HIGH |
| Sin accesibilidad | LOW | LOW | LOW | LOW | CRITICAL | LOW |

## Integración con ai-governance

Esta regla complementa `ai-governance.md` añadiendo:
- Regulaciones sectoriales sobre las genéricas de IA (EU AI Act)
- Compliance checks específicos además de model cards y risk assessment
- Audit trails regulatorios más estrictos que los genéricos de observabilidad

## Regulaciones genéricas (aplican siempre)

Independientemente del sector, todo software en la UE debe cumplir:
- **GDPR/LOPDGDD**: Protección de datos personales
- **EU AI Act**: Si usa modelos de IA (ver `ai-governance` rule)
- **NIS2**: Si es operador esencial o importante
- **Directiva de Accesibilidad 2025**: Productos y servicios digitales
