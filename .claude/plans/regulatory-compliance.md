# Plan: Regulatory Compliance Intelligence (v0.33.0)

## Resumen

Sistema de validación de marcos regulatorios por sector. Detecta automáticamente el sector del software, carga las regulaciones aplicables, escanea el código fuente contra cada requisito y ofrece corrección automática o generación de tareas manuales.

---

## Fase 1: Fundación (Skill + Domain Rule + 12 ficheros de sector)

### 1.1 Skill: `regulatory-compliance/SKILL.md` (~145 líneas)
- Algoritmo de detección de sector en 4 fases (misma estructura que `arch-detect`):
  - Fase 1 (40%): Patrones de ficheros (modelos, schemas, migraciones)
  - Fase 2 (30%): Dependencias (imports, packages)
  - Fase 3 (20%): Nomenclatura (entidades, variables, rutas API)
  - Fase 4 (10%): Configuración (env vars, config files)
- Umbral: ≥60% = auto-detectado, 30-59% = preguntar usuario, <30% = no detectado (opción "no regulado")
- Framework de compliance checks (estructura checklist por regulación)
- Clasificación de severidad: CRITICAL / HIGH / MEDIUM / LOW
- Plantillas de auto-fix por categoría

### 1.2 Domain Rule: `regulatory-compliance.md` (~140 líneas)
- Árbol de decisión para clasificación de sector
- Patrones comunes cross-sector (cifrado, audit trails, control acceso, retención)
- Matriz de severidad
- Integración con regla `ai-governance` existente

### 1.3 Ficheros de sector en `references/` (12 ficheros, ~140 líneas cada uno)

Cada fichero con estructura idéntica:
- Leyes aplicables con artículos concretos
- Markers de detección (packages, entidades, APIs, config)
- Checklist de compliance por regulación
- Violaciones comunes y patrones de auto-fix
- Clasificación de severidad por tipo

| # | Fichero | Regulaciones principales |
|---|---------|------------------------|
| 1 | `sector-healthcare.md` | HIPAA, HL7/FHIR, GDPR salud, EU MDR |
| 2 | `sector-finance.md` | PCI-DSS, PSD2, SOX, Basel III/IV, MiFID II |
| 3 | `sector-food-agriculture.md` | FSMA 204, FDA 21 CFR Part 11, EU 178/2002 |
| 4 | `sector-justice-legal.md` | Protección datos judiciales, cadena custodia |
| 5 | `sector-public-admin.md` | ENS, eIDAS, WCAG 2.1 AA, Marco Interoperabilidad |
| 6 | `sector-insurance.md` | Solvency II, IDD |
| 7 | `sector-pharma.md` | GxP, 21 CFR Part 11, EU Annex 11 |
| 8 | `sector-energy-utilities.md` | NERC CIP, NIS2 |
| 9 | `sector-telecom.md` | ePrivacy, GDPR telecom, neutralidad de red |
| 10 | `sector-education.md` | FERPA, COPPA, CIPA |
| 11 | `sector-defense-military.md` | ITAR, NIST SP 800-171, CUI |
| 12 | `sector-transport-automotive.md` | UNECE R155/R156, ISO 21434 |

Nota: Pharma y Food comparten FDA 21 CFR Part 11 → referencia cruzada.

---

## Fase 2: Comandos (3 comandos)

### 2.1 `/compliance-scan {path}` (~148 líneas)
Comando principal. Flujo de 7 pasos:
1. Verificar proyecto accesible
2. Detectar sector (algoritmo 4 fases)
3. Si ambiguo → preguntar usuario (con opción "No regulado → saltar")
4. Cargar regulaciones del sector desde `references/sector-{name}.md`
5. Escanear código contra checklist regulatorio
6. Clasificar hallazgos por severidad
7. Generar informe con acciones: `/compliance-fix ID-XXX` (auto) o Task (manual)

Parámetros: `{path}`, `--sector` (forzar), `--strict` (incluir MEDIUM/LOW)
Output: `output/compliance/{proyecto}-scan-{fecha}.md`

### 2.2 `/compliance-fix {issue-id}` (~130 líneas)
Aplica corrección automática y re-verifica:
1. Leer informe de scan
2. Localizar issue por ID
3. Aplicar plantilla de fix (código/config)
4. Mostrar changeset
5. Re-ejecutar verificación específica
6. Reportar PASS/FAIL

Parámetros: `{issue-id}`, `--dry-run` (preview sin aplicar)

### 2.3 `/compliance-report {path}` (~130 líneas)
Genera informe ejecutivo completo:
1. Cargar scan actual
2. Comparar con scans previos (si `--compare`)
3. Generar: resumen ejecutivo, hallazgos por sector, tendencia, roadmap de remediación
4. Exportar a markdown o docx

Parámetros: `{path}`, `--format md|docx`, `--compare`
Output: `output/compliance/{proyecto}-report-{fecha}.{ext}`

---

## Fase 3: Documentación

- `CHANGELOG.md` — Entrada v0.33.0
- `README.md` / `README.en.md` — Sección Regulatory Compliance, contadores actualizados
- `CLAUDE.md` — Skills +1 (17 total), comandos +3 (128 total)
- `docs/readme/12-comandos-agentes.md` / `docs/readme_en/12-commands-agents.md` — Nueva sección Compliance

---

## Resumen de entregables

| Tipo | Ficheros | Líneas estimadas |
|------|----------|-----------------|
| Skill (SKILL.md) | 1 | ~145 |
| Domain rule | 1 | ~140 |
| Sector references | 12 | ~1,680 (~140 cada uno) |
| Commands | 3 | ~408 |
| Docs updates | 6 | ~+60 líneas |
| **Total** | **23 ficheros** | **~2,433 líneas** |

Todos los ficheros ≤150 líneas.

---

## Flujo de usuario (ejemplo)

```
> /compliance-scan ./mi-app-salud

[1/7] Analizando proyecto...
[2/7] Detectando sector... Healthcare (87% confianza)
[3/7] Cargando regulaciones: HIPAA, HL7/FHIR, GDPR salud, EU MDR
[4/7] Escaneando código fuente...
[5/7] Verificando 34 requisitos regulatorios...
[6/7] Clasificando hallazgos...
[7/7] Generando informe...

━━ Compliance Scan — mi-app-salud ━━
Sector: Healthcare (87%) · Fecha: 2026-02-28
Score: 72% · CRITICAL: 2 · HIGH: 3 · MEDIUM: 5

Hallazgos críticos:
  ID-001 [CRITICAL] HIPAA §164.312(a) — Datos de paciente sin cifrado AES-256
    → /compliance-fix ID-001 (auto-fix disponible)
  ID-002 [CRITICAL] HIPAA §164.312(b) — Sin audit trail en acceso a historiales
    → /compliance-fix ID-002 (auto-fix disponible)

Informe: output/compliance/mi-app-salud-scan-20260228.md
```
