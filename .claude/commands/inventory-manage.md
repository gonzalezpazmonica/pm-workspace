---
title: "Gestión de Inventario"
description: "Gestiona inventario: stock, reordenes, transferencias, conteos, alertas"
section: "Retail/eCommerce"
category: "Inventory Management"
keywords: ["inventario", "stock", "almacén", "reorden"]
author: "Claude Code"
---

## Descripción

Comando para gestionar el inventario del proyecto de retail. Permite consultar niveles de stock, generar órdenes de compra automáticas, registrar transferencias entre ubicaciones, realizar conteos físicos y monitorizar alertas de stock.

Almacenamiento: `projects/{proyecto}/retail/inventory/`

## Subcomandos

### stock
Muestra niveles de stock actuales por producto o almacén.

```
savia inventory-manage stock \
  --product SKU-0001 \
  --warehouse "Almacén Central" \
  --group-by "location"
```

**Parámetros:**
- `--product`: SKU específico (opcional)
- `--warehouse`: Almacén específico (opcional)
- `--group-by`: (product/location/category)

### reorder
Genera órdenes de compra automáticas cuando stock está bajo reorden.

```
savia inventory-manage reorder \
  --threshold-percent 30 \
  --auto-generate true \
  --output PO-20260306.md
```

**Parámetros:**
- `--threshold-percent`: Porcentaje para generar orden
- `--auto-generate`: (true/false)
- `--output`: Nombre fichero de salida

### transfer
Registra transferencia de inventario entre ubicaciones.

```
savia inventory-manage transfer \
  --sku SKU-0001 \
  --quantity 50 \
  --from "Almacén Central" \
  --to "Almacén Regional" \
  --reference TRF-20260306-001
```

**Parámetros:**
- `--sku`: Producto a transferir
- `--quantity`: Cantidad
- `--from`: Ubicación origen
- `--to`: Ubicación destino
- `--reference`: ID de transferencia

### count
Registra recuento físico de inventario con varianzas.

```
savia inventory-manage count \
  --location "Almacén Central" \
  --type "cycle-count" \
  --variance-report true
```

**Parámetros:**
- `--location`: Almacén a contar
- `--type`: (full-count/cycle-count)
- `--variance-report`: Generar informe de varianzas

### alert
Muestra alertas de inventario activas.

```
savia inventory-manage alert \
  --type "low-stock" \
  --severity "critical" \
  --warehouse "Almacén Central"
```

**Tipos de alerta:**
- `low-stock`: Stock bajo reorden
- `overstock`: Exceso de inventario
- `dead-stock`: Producto sin movimiento >90 días
- `expiry-soon`: Vencimiento próximo
