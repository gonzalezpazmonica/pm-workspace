---
name: /incident-register
description: >
  Registro sistemático de incidentes de seguridad clínica. Clasifica por
  severidad y tipo, gestiona investigación de causas raíz, registra acciones
  correctivas. Cumple AEPD privacidad: sin datos identificadores de pacientes.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# /incident-register — Registro de Incidentes Clínicos

Gestiona el registro sistemático de incidentes de seguridad del paciente,
investigaciones y acciones correctivas.

## Sintaxis

```bash
/incident-register <subcommand> [opciones]
```

## Subcomandos

### classify
Registrar un nuevo incidente con clasificación.

```bash
/incident-register classify \
  --severity "moderado" \
  --type "medicación" \
  --fecha "2026-03-06" \
  --ubicacion "Quirófano 3" \
  --descripcion "Medicamento incorrecto preparado antes de intervención"
```

Genera: `projects/{proyecto}/quality/incidents/INC-NNN.yml`

Campos obligatorios:
- severity: grave|moderado|leve
- type: caída|medicación|infección|otro
- fecha: YYYY-MM-DD
- ubicacion: ubicación del incidente
- descripcion: descripción hechos observados

### investigate
Iniciar análisis de causa raíz.

```bash
/incident-register investigate --id INC-NNN --metodo "5-why"
```

Métodos soportados:
- 5-why — Análisis iterativo
- fishbone — Diagrama de Ishikawa
- timeline — Cronología de eventos

### action
Registrar acción correctiva o preventiva.

```bash
/incident-register action --id INC-NNN \
  --accion "Revisar protocolo de preparación de medicamentos" \
  --owner "Jefe Farmacia" \
  --deadline "2026-04-06"
```

### list
Listar incidentes con filtros.

```bash
/incident-register list \
  --severity "grave" \
  --type "medicación" \
  --estado "abierto" \
  --fecha-desde "2026-01-01" \
  --fecha-hasta "2026-03-06"
```

Columnas:
- ID, Tipo, Severidad, Fecha, Ubicación, Estado

### report
Generar informe de período.

```bash
/incident-register report --mes "2026-03"
```

Incluye:
- Total incidentes por tipo y severidad
- Tendencias (aumentando/estable/decrece)
- Acciones completadas vs. pendientes

## Almacenamiento

```
projects/{proyecto}/quality/incidents/
  INC-001.yml
  INC-002.yml
  ...
```

## Privacidad GDPR/AEPD

- NUNCA incluir nombres de pacientes
- NUNCA incluir números de historia clínica
- NUNCA incluir identificadores del paciente
- Usar: "paciente Z" o "usuario código ABC"
- Descripción focalizada en el incidente, no en la persona

## Tipos de incidente

- **caída**: Paciente se cayó en zona clínica
- **medicación**: Error en medicamento (dosis, tipo, vía)
- **infección**: Infección adquirida durante asistencia
- **otro**: Otro tipo de incidente de seguridad

## Severidades

- **grave**: Daño permanente o muerte
- **moderado**: Daño temporal significativo
- **leve**: Daño mínimo o sin daño
