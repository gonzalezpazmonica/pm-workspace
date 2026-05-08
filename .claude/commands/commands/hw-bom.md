---
name: hw-bom
description: >
  Gestiona la Lista de Materiales (BOM) del hardware con seguimiento de componentes,
  costos, proveedores y estados. Permite agregar, listar, calcular costos, exportar e
  importar componentes con análisis de revisiones y disponibilidad.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

## Descripción

Comando para administrar la Lista de Materiales (BOM) del hardware de los proyectos. Almacena datos en `projects/{proyecto}/hardware/bom.json` y realiza seguimiento de revisiones, costos y estados de componentes.

## Subcomandos

### add
Agrega un componente nuevo a la BOM.

```bash
hw-bom add <proyecto> --ref=R1 --name="Resistor 10k" --manufacturer=Vishay \
  --quantity=100 --unit-cost=0.05 --supplier=Digi-Key --footprint=0603 \
  --status=active
```

Campos obligatorios:
- ref: referencia del componente (R1, C1, U1, etc.)
- name: nombre/descripción
- manufacturer: fabricante
- quantity: cantidad
- unit_cost: costo unitario (USD)
- supplier: proveedor
- footprint: tamaño/tipo (0603, QFP100, etc.)
- status: active, obsolete, pending

### list
Lista componentes con filtros opcionales.

```bash
hw-bom list <proyecto>
hw-bom list <proyecto> --category=resistor --supplier="Digi-Key" --status=active
```

Muestra: referencia, nombre, fabricante, cantidad, costo unitario, proveedor, estado.

### cost
Calcula costos totales y por categoría.

```bash
hw-bom cost <proyecto>
```

Retorna:
- Costo total de la BOM
- Costo unitario (por unidad de producto)
- Desglose por categoría (resistores, capacitores, ICs, etc.)
- Componentes con costo crítico

### export
Exporta BOM a formato CSV o Excel.

```bash
hw-bom export <proyecto> --format=csv --output=bom.csv
hw-bom export <proyecto> --format=excel --output=bom.xlsx
```

### import
Importa componentes desde CSV.

```bash
hw-bom import <proyecto> --file=components.csv --update=false
```

Opción --update=true sobreescribe componentes existentes.

## Seguimiento

- Número de revisión: incrementa con cambios significativos
- Última actualización: timestamp automático
- Estado de componente: activo, obsoleto, pendiente
- Historial de cambios: quién, cuándo, qué modificó

## Estructura de Almacenamiento

```json
{
  "proyecto": "mi-proyecto",
  "revision": 1,
  "last_updated": "2026-03-06T10:30:00Z",
  "components": [
    {
      "ref": "R1",
      "name": "Resistor 10k",
      "category": "resistor",
      "manufacturer": "Vishay",
      "quantity": 100,
      "unit_cost": 0.05,
      "currency": "USD",
      "supplier": "Digi-Key",
      "footprint": "0603",
      "status": "active",
      "added_date": "2026-03-06T10:30:00Z"
    }
  ]
}
```

## Ejemplos

Ver BOM completa: `hw-bom list smart-meter`

Filtrar resistores activos: `hw-bom list smart-meter --category=resistor --status=active`

Calcular costos: `hw-bom cost smart-meter`

Exportar a CSV: `hw-bom export smart-meter --format=csv`
