---
title: "Seguimiento de Pedidos"
description: "Gestiona pedidos: crear, actualizar estado, cumplir, procesar devoluciones y reportes"
section: "Retail/eCommerce"
category: "Order Management"
keywords: ["pedidos", "seguimiento", "entregas", "devoluciones"]
author: "Claude Code"
---

## Descripción

Comando para gestionar el ciclo completo de pedidos. Permite crear nuevos pedidos, actualizar estados, registrar cumplimiento con seguimiento, procesar devoluciones y generar análisis de rendimiento.

Almacenamiento: `projects/{proyecto}/retail/orders/`

## Subcomandos

### create
Registra un nuevo pedido con identificador ORD-NNNN.

```
savia order-track create \
  --customer-ref CUST-0523 \
  --items "SKU-0001,SKU-0045" \
  --quantities "2,1" \
  --total 249.97 \
  --payment-method "credit-card"
```

**Parámetros:**
- `--customer-ref`: Referencia del cliente
- `--items`: SKUs de productos (separados por comas)
- `--quantities`: Cantidades respectivas (separadas por comas)
- `--total`: Monto total del pedido
- `--payment-method`: Método de pago (credit-card/debit/transfer/cash)

### status
Actualiza el estado del pedido en el flujo de procesamiento.

```
savia order-track status \
  --order ORD-0001 \
  --state delivered
```

**Estados válidos:**
- `pending`: Pendiente de confirmación
- `confirmed`: Confirmado
- `processing`: En procesamiento
- `shipped`: Enviado
- `delivered`: Entregado
- `cancelled`: Cancelado

### fulfill
Marca el pedido como cumplido registrando información de seguimiento.

```
savia order-track fulfill \
  --order ORD-0001 \
  --carrier "DHL" \
  --tracking-number "1Z999AA10123456784"
```

**Parámetros:**
- `--order`: Número de pedido
- `--carrier`: Proveedor de envío
- `--tracking-number`: Número de seguimiento

### return
Procesa una devolución registrando razón y monto de reembolso.

```
savia order-track return \
  --order ORD-0001 \
  --reason "defective" \
  --refund-amount 249.97
```

**Parámetros:**
- `--order`: Número de pedido
- `--reason`: Motivo (defective/wrong-item/not-needed/damaged)
- `--refund-amount`: Monto a reembolsar

### report
Genera análisis de pedidos: volumen, ingresos, valor promedio, tasa de devolución.

```
savia order-track report \
  --period "monthly" \
  --start-date "2026-02-01" \
  --end-date "2026-03-06"
```

**Parámetros:**
- `--period`: (daily/weekly/monthly/yearly)
- `--start-date`: Fecha inicial (YYYY-MM-DD)
- `--end-date`: Fecha final (YYYY-MM-DD)
