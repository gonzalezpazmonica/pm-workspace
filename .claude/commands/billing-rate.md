---
name: billing-rate
description: >
  Gestiona tarifas y facturas de servicios legales.
  Subcomandos: set (definir tarifa), calculate (calcular honorarios),
  invoice (generar factura), report (análisis), list (listar tarifas).
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# Gestor de Tarifas y Facturación

Controla tarifas horarias, honorarios fijos y cálculo de facturas.

## Uso

```
billing-rate set <profesional> <tipo> <cantidad> [moneda]
billing-rate calculate <entrada-tiempo>
billing-rate invoice <caso> [periodo]
billing-rate report [filtros]
billing-rate list
```

## Subcomandos

### set
Define tarifa de profesional.
- `profesional`: nombre abogado, paralegal, pasante
- `tipo`: hourly | fixed_fee | contingency | mixed
- `cantidad`: tarifa por hora o cantidad fija
- `moneda`: EUR (default) | USD | GBP

Almacena en: `projects/{proyecto}/legal/billing/rates.json`

### calculate
Calcula honorarios desde entradas de tiempo.
- Input: fichero `.csv` con horas por profesional/materia
- Aplica tarifa configurable
- Output: desglose por profesional y materia
- Soporta descuentos por volumen o relación

### invoice
Genera factura en base a tiempo registrado.
- `caso`: referencia del caso
- `periodo`: MM-YYYY (default: mes actual)
- Incluye: descripción servicios, profesionales, horas, tarifas, total
- Formato: PDF + XML para compliance contable

### report
Análisis de facturación.
- `filtros`: por-lawyer | por-materia | por-cliente | por-periodo
- Muestra: ingresos, promedio por hora, rentabilidad por materia
- Tendencias: comparación trimestral, anual

### list
Muestra todas las tarifas activas.
- Tabla: profesional, tipo, cantidad, moneda, activo desde

## Tipos de Facturación

### hourly
Tarifa por hora. Requiere registro tiempo.
Ejemplo: 150 EUR/h

### fixed_fee
Honorario fijo por materia/caso.
Ejemplo: 2.500 EUR por contestación

### contingency
Sin pago hasta resultado. % sobre cantidad recuperada.
Ejemplo: 25% de lo recuperado

### mixed
Combinación (retainer + horas excedentes).
Ejemplo: 1.000 EUR base + 100 EUR/h horas extra

## Almacenamiento

```json
{
  "rates": [
    {
      "id": "rate-001",
      "lawyer": "abogado-1",
      "type": "hourly",
      "amount": 150,
      "currency": "EUR",
      "active_since": "2026-01-01",
      "active_until": null
    }
  ],
  "invoices": [
    {
      "id": "inv-2026-001",
      "case": "C-2024-001",
      "period": "2026-03",
      "total_hours": 24.5,
      "gross_amount": 3675,
      "discounts": 0,
      "net_amount": 3675,
      "status": "draft|issued|paid",
      "issued": "2026-03-06"
    }
  ]
}
```

## Compliance

- Registros de tiempo auditable
- Facturación transparente (desglose detallado)
- Retención de documentación (7 años)
- Cumplimiento normativa IVA/contable
