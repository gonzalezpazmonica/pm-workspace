---
name: governance-report
description: Reporte de gobernanza IA para management — cumplimiento normativo, uso responsable
developer_type: all
agent: task
context_cost: medium
---

# /governance-report

> 🦉 Informe ejecutivo de gobernanza para dirección.

Compila datos de auditoría, mapea a marcos regulatorios, presenta cumplimiento normativo.

---

## Flujo

1. **Paso 1** — Ejecutar `/governance-audit` (o leer reporte anterior)
2. **Paso 2** — Compilar datos de gobernanza:
   - Score de cumplimiento global
   - Hallazgos críticos
   - Acciones correctivas
3. **Paso 3** — Mapear a marcos:
   - **EU AI Act**: requisitos por nivel de riesgo
   - **NIST AI RMF**: cinco funciones (Govern, Map, Measure, Manage, Monitor)
   - **ISO/IEC 42001**: gestión de sistemas de IA
4. **Paso 4** — Presentar executive summary
5. **Paso 5** — Recomendar mejoras y siguiente review

---

## Secciones del Reporte

### Executive Summary (1 página)
- Score de cumplimiento global (%)
- Top 3 riesgos
- Top 3 mejoras implementadas
- Próximas acciones

### Detalle por Marco
- **EU AI Act**: Mapeo de acciones a prohibidas/alto riesgo/general
- **NIST**: Madurez en Govern/Map/Measure/Manage
- **ISO 42001**: Cobertura de requisitos de sistemas de IA
- **AEPD**: Score 4 fases (tecnología, cumplimiento, vulnerabilidades, medidas)

### Conformidad Regulatoria
- Documentación de governance (✓/✗)
- Auditoría completada (✓/✗)
- Aprobaciones registradas (✓/✗)
- Incidentes reportados (✓/✗)

### Métricas de Uso Responsable
- % acciones de BAJO riesgo (esperado >70%)
- % excepciones documentadas (esperado <10%)
- Tiempo medio de aprobación (ALTO/CRÍTICO)
- Incumplimientos sin resolver

---

## Output

Fichero: `output/governance-YYYYMMDD-report.md`

**Destinatario**: CEO/CTO/Legal
**Frecuencia**: Mensual o bajo demanda
**Integración**: Input para `/governance-certify` (roadmap de certificación)

---

## Marcos Soportados

- ✅ **EU AI Act** (EN 2024)
- ✅ **NIST AI RMF** (v1.0)
- ✅ **ISO/IEC 42001** (DIS)
- ✅ **SOC 2 Type II** (AI control mapping)
- ✅ **AEPD IA Agéntica** (2026) — Orientaciones españolas para agentes autónomos
