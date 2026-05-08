---
name: /training-compliance
description: >
  Seguimiento de cumplimiento formativo en profesionales sanitarios. Identifica
  formación obligatoria vencida/próxima a vencer, planifica planes de formación,
  registra certificados. Alertas sobre riesgos de incumplimiento.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# /training-compliance — Cumplimiento Formativo

Gestiona formación obligatoria y certificaciones profesionales.

## Sintaxis

```bash
/training-compliance <subcommand> [opciones]
```

## Subcomandos

### status
Ver estado de cumplimiento.

```bash
/training-compliance status --profesional "Dr. García" | --equipo "Quirófano"
```

Muestra:
- Certificaciones vigentes
- Certificaciones próximas a vencer (<30 días)
- Formación completada este año

### expired
Listar formación vencida o próxima a vencer.

```bash
/training-compliance expired --dias-limite 30
```

Alertas:
- 🔴 Crítico: ya vencido
- 🟡 Alerta: <30 días para expiración

### plan
Crear plan de formación para profesional.

```bash
/training-compliance plan --profesional "Enfermera Pérez" \
  --cursos "RCP,Higiene,Privacidad" \
  --deadline "2026-06-30"
```

Cursos obligatorios:
- RCP (Reanimación Cardiopulmonar)
- Fire Safety (Seguridad incendios)
- Hygiene (Higiene y bioseguridad)
- Privacy (Protección de datos)
- Specialty-specific (según especialidad)

### register
Registrar formación completada.

```bash
/training-compliance register --profesional "Médico López" \
  --curso "RCP Básico" \
  --fecha "2026-03-06" \
  --horas 4 \
  --certificado "cert-2026-rcp.pdf"
```

### report
Generar informe de cumplimiento.

```bash
/training-compliance report --departamento "Quirófanos" --mes "2026-03"
```

Incluye:
- % Profesionales con formación al día
- Gaps por especialidad
- Próximos vencimientos

## Almacenamiento

```
projects/{proyecto}/quality/training/
  profesionales.yml
  planes-formacion/
  certificados/
```

## Alertas

| Condición | Umbral |
|-----------|--------|
| 🔴 Crítico | Vencido |
| 🟡 Alerta | <30 días al vencimiento |
| 🟢 OK | >30 días |

## Formación obligatoria

La formación varía por puesto. Ejemplos:
- Médicos: RCP, especialidad, privacidad
- Enfermeros: RCP, higiene, privacidad, manejo medicamentos
- Técnicos: Bioseguridad, equipamiento, privacidad
- Administrativos: Privacidad, RGPD
