---
name: governance-policy
description: Definir política de uso de IA de la empresa — clasificación de riesgo, aprobaciones
developer_type: all
agent: none
context_cost: low
---

# /governance-policy

> 🦉 Crear o actualizar la política de gobernanza de IA de tu empresa.

Basado en **NIST AI RMF** (Govern, Map, Measure, Manage) e **ISO/IEC 42001**.

---

## Flujo

1. **Paso 1** — Leer `company/policies.md` (crear si no existe)
2. **Paso 2** — Presentar guía interactiva de política
3. **Paso 3** — Clasificación de riesgo por tipo de acción
4. **Paso 4** — Matriz de aprobaciones (quién autoriza qué)
5. **Paso 5** — Guardar en `company/policies.md` con timestamp

---

## Secciones de Política

### 1. Clasificación de Riesgo

| Nivel | Descripción | Ejemplos |
|---|---|---|
| **BAJO** | Lectura de datos públicos, análisis no críticos | `/sprint-status`, `/team-workload` |
| **MEDIO** | Creación de PBIs, recomendaciones de asignación | `/backlog-prioritize`, `/adoption-plan` |
| **ALTO** | Modificación de configuración, acceso a secretos | Crear infraestructura, cambiar permisos |
| **CRÍTICO** | Infraestructura en PRO, rotación de secrets, eliminaciones | Deploy a producción, rotación de PAT |

### 2. Aprobadores por Riesgo

Definir roles autorizados:
- **BAJO**: Savia (sin aprobación)
- **MEDIO**: PM/Tech Lead aprueba
- **ALTO**: PM + Tech Lead aprueban
- **CRÍTICO**: PM + CTO + Legal aprueban

### 3. Auditoría y Cumplimiento

Documentar:
- Quién ejecutó cada acción
- Cuándo y con qué autorización
- Resultado y conformidad normativa

---

## Marco de Referencia

**NIST AI RMF**:
- Govern: Esta política
- Map: `/governance-audit` mapea acciones vs permitidas
- Measure: `/governance-report` mide cumplimiento
- Manage: `/governance-certify` valida certificaciones

**ISO/IEC 42001**: Gestión de sistemas de IA

---

## Salida

Fichero: `company/policies.md` con secciones:
- Clasificación de riesgos (personalizada para tu industria)
- Matriz de aprobaciones
- Escalation path
- Revisión anual (recordatorio)

**Integración**: `/governance-audit` y `/governance-report` leen esta política.
