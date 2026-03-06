---
name: insurance-policy
description: >
  Gestiona pólizas de seguros: creación, renovación, cancelación, listado y comparación.
  Almacena en projects/{proyecto}/insurance/policies/ con identificadores POL-NNN.
  Rastrea endorsos, reclamaciones y perfil de riesgo.
allowed-tools:
  - Read
  - Write
  - Glob
  - Bash
---

# /insurance-policy {proyecto} {subcomando} [opciones]

## Subcomandos

### create
```bash
/insurance-policy {proyecto} create \
  --holder "Titular" \
  --type {vida|auto|hogar|salud|responsabilidad} \
  --coverage "Descripción" \
  --premium {monto} \
  --start {YYYY-MM-DD} \
  --end {YYYY-MM-DD} \
  --beneficiaries "Nombre1, Nombre2"
```
Crea POL-NNN con timestamp, estado ACTIVA.

### renew
```bash
/insurance-policy {proyecto} renew \
  --policy-id POL-NNN \
  --new-end {YYYY-MM-DD} \
  --new-premium {monto}
```
Extiende vigencia, crea endorsement record.

### cancel
```bash
/insurance-policy {proyecto} cancel \
  --policy-id POL-NNN \
  --reason {texto} \
  --date {YYYY-MM-DD}
```
Marca como CANCELADA, registra motivo y fecha.

### list
```bash
/insurance-policy {proyecto} list \
  [--type {tipo}] \
  [--status {ACTIVA|CANCELADA|VENCIDA}] \
  [--expiring-days N]
```
Tabla: POL-NNN, titular, tipo, estado, fecha fin, prima.

### compare
```bash
/insurance-policy {proyecto} compare \
  --policy-1 POL-NNN \
  --policy-2 POL-MMM
```
Matriz de diferencias: cobertura, prima, beneficiarios.

## Estructura de datos

```yaml
id: POL-NNN
holder: Nombre
type: vida|auto|hogar|salud|responsabilidad
coverage: Descripción
premium:
  amount: XXX.XX
  currency: EUR
period:
  start: YYYY-MM-DD
  end: YYYY-MM-DD
beneficiaries:
  - name: Nombre
    relationship: relación
status: ACTIVA|CANCELADA|VENCIDA
endorsements:
  - date: YYYY-MM-DD
    change: descripción
claims_count: N
risk_profile: bajo|medio|alto
```

## Reglas

- POL-NNN numeración secuencial (3 dígitos)
- Premium positivo en EUR
- Start date ≤ end date
- Cambios en póliza activa generan endorsement
- Cancelaciones requieren motivo explícito
- Risk profile se calcula desde frecuencia de reclamaciones
