---
name: underwriting-rule
description: >
  Gestiona reglas de underwriting para decisiones de asunción de riesgo.
  Almacena en projects/{proyecto}/insurance/underwriting/ con definición,
  evaluación y auditoría de cambios y overrides.
allowed-tools:
  - Read
  - Write
  - Glob
  - Bash
---

# /underwriting-rule {proyecto} {subcomando} [opciones]

## Subcomandos

### define
```bash
/underwriting-rule {proyecto} define \
  --name "Nombre regla" \
  --product {vida|auto|hogar|salud|responsabilidad} \
  --criteria "Criterio 1; Criterio 2" \
  --risk-factors "Factor1:límite; Factor2:límite" \
  --auto-approve "condiciones de aprobación automática"
```
Crea regla de underwriting. Cada regla tiene ID secuencial.

### evaluate
```bash
/underwriting-rule {proyecto} evaluate \
  --case-data "{json o fichero}" \
  --product {tipo}
```
Ejecuta caso contra reglas activas del producto.
Resultado: ACCEPT | REFER (revisión manual) | DECLINE.

Muestra:
- Reglas aplicadas
- Factores encontrados
- Decisión y justificación
- Confianza (%)

### list
```bash
/underwriting-rule {proyecto} list \
  [--product {tipo}] \
  [--status {active|inactive}]
```
Tabla: ID, nombre, producto, criterios, estado, creada, actualizada.

### audit
```bash
/underwriting-rule {proyecto} audit \
  [--rule-id UW-NNN]
```
Historial: cambios en regla, quién modificó, cuándo.
Frecuencia overrides por regla.

## Estructura de datos

```yaml
id: UW-NNN
name: Nombre
product: vida|auto|hogar|salud|responsabilidad
criteria:
  - descripción
risk_factors:
  factor1: límite_max
  factor2: límite_max
auto_approve_conditions: descripción
status: active|inactive
created: YYYY-MM-DD
updated: YYYY-MM-DD
change_history:
  - date: YYYY-MM-DD
    change: descripción
override_count: N
```

## Reglas

- UW-NNN numeración secuencial (3 dígitos)
- Producto determina reglas aplicables
- Evaluación es determinística (misma entrada → mismo resultado)
- Overrides se registran para auditoría
- Cambios a reglas no afectan decisiones previas
