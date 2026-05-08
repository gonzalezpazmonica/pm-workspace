---
name: insurance-claim
description: >
  Gestiona reclamaciones de seguros: apertura, investigación, resolución, listado y reportes.
  Almacena en projects/{proyecto}/insurance/claims/ con identificadores CLM-NNN.
  Enlaza con pólizas e incluye notas de investigación y asignación de ajustador.
allowed-tools:
  - Read
  - Write
  - Glob
  - Bash
---

# /insurance-claim {proyecto} {subcomando} [opciones]

## Subcomandos

### open
```bash
/insurance-claim {proyecto} open \
  --policy POL-NNN \
  --date {YYYY-MM-DD} \
  --type {siniestro|accidente|robo|daño} \
  --description "Descripción del evento" \
  --estimated-amount {monto}
```
Registra CLM-NNN vinculado a póliza, estado ABIERTA.

### investigate
```bash
/insurance-claim {proyecto} investigate \
  --claim-id CLM-NNN \
  --notes "Notas de investigación" \
  --adjuster "Nombre ajustador"
```
Añade notas, asigna adjuster, estado INVESTIGACIÓN.

### resolve
```bash
/insurance-claim {proyecto} resolve \
  --claim-id CLM-NNN \
  --resolution {approved|denied|partial} \
  --payout {monto}
```
Cierra claim, registra resolución y monto pagado.

### list
```bash
/insurance-claim {proyecto} list \
  [--status {ABIERTA|INVESTIGACIÓN|RESUELTA}] \
  [--policy POL-NNN] \
  [--type {tipo}] \
  [--date-from] [--date-to]
```
Tabla: CLM-NNN, póliza, tipo, estado, fecha, monto estimado.

### report
```bash
/insurance-claim {proyecto} report
```
Resumen: frecuencia, severidad, ratio de pérdida por tipo.

## Estructura de datos

```yaml
id: CLM-NNN
policy_ref: POL-NNN
date_opened: YYYY-MM-DD
type: siniestro|accidente|robo|daño
description: Texto
estimated_amount: XXX.XX
status: ABIERTA|INVESTIGACIÓN|RESUELTA
investigation:
  notes: []
  adjuster: Nombre
  assigned_date: YYYY-MM-DD
resolution:
  resolution_type: approved|denied|partial
  payout_amount: XXX.XX
  date_resolved: YYYY-MM-DD
```

## Reglas

- CLM-NNN numeración secuencial (3 dígitos)
- Debe referenciar póliza existente
- Investigación requiere adjuster asignado
- Resolución cierra reclamación
- Frecuencia de reclamaciones afecta risk_profile en póliza
