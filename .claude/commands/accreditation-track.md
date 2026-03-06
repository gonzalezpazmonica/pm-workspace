---
name: /accreditation-track
description: >
  Seguimiento de acreditaciones sanitarias (JCI, EFQM, ISO 9001, ISO 15189).
  Mapea requisitos a evidencias, detecta gaps, genera reportes de cumplimiento.
  Prepara auditorías y evaluaciones de terceros.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# /accreditation-track — Seguimiento de Acreditaciones

Gestiona el cumplimiento de estándares de acreditación sanitaria.

## Sintaxis

```bash
/accreditation-track <subcommand> [opciones]
```

## Subcomandos

### standard
Definir un estándar de acreditación.

```bash
/accreditation-track standard \
  --nombre "JCI" \
  --version "6.3" \
  --sector "hospital" \
  --requisitos 280
```

Estándares soportados:
- JCI — Joint Commission International
- EFQM — European Foundation Quality Management
- ISO 9001 — Gestión de calidad
- ISO 15189 — Laboratorio clínico

### evidence
Vincular evidencia a requisito.

```bash
/accreditation-track evidence \
  --standard "JCI" \
  --requirement "ACC.1.1" \
  --documento "protocols/medication-safety.pdf" \
  --revisor "Jefe Calidad" \
  --fecha "2026-03-05"
```

Estados: aceptada|revisión|rechazada|vencida

### gap
Identificar requisitos sin evidencia.

```bash
/accreditation-track gap --standard "ISO 15189"
```

Muestra:
- Requisitos sin evidencia
- Evidencias vencidas (>12 meses)
- Documentos desactualizados

### status
Mostrar cumplimiento por estándar.

```bash
/accreditation-track status --standard "JCI"
```

Resumen:
- % Requisitos cubiertos
- % Evidencias vigentes
- % Conforme/No conforme
- Próxima auditoría

### export
Generar reporte de acreditación.

```bash
/accreditation-track export --standard "ISO 9001" --formato "pdf"
```

Incluye:
- Matriz de cumplimiento
- Hallazgos por requisito
- Plan de mejora
- Firma revisores

## Almacenamiento

```
projects/{proyecto}/quality/accreditation/
  jci-status.yml
  iso-15189-evidence/
  efqm-gaps.md
```

## Ciclo de auditoría

**Pre-auditoría** → audit-track gap → revisar evidencias
**Durante** → registrar findings
**Post** → crear acciones para no-conformidades

## Vigencia de evidencias

- Documentos: 12 meses
- Procedimientos: 24 meses
- Registros de cumplimiento: 12 meses
- Auditorías internas: 12 meses
