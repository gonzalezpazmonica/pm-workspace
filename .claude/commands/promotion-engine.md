---
name: promotion-engine
description: "Gestiona promociones: crear, activar, desactivar, evaluar, reportes"
section: "Retail/eCommerce"
category: "Marketing & Promotions"
keywords: ["promociones", "descuentos", "ofertas", "campañas"]
author: "Claude Code"
---

## Descripción

Comando para gestionar promociones y ofertas del proyecto de retail. Permite definir promociones con distintos tipos (descuentos, BOGO, bundling, cupones), activarlas, desactivarlas, evaluar su aplicabilidad a carritos y analizar el impacto en negocio.

Almacenamiento: `projects/{proyecto}/retail/promotions/`

## Subcomandos

### create
Define una nueva promoción con identificador PROMO-NNN.

```
savia promotion-engine create \
  --type "discount" \
  --name "Rebajas Primavera" \
  --value 20 \
  --conditions "category:Electrónica,min-purchase:100" \
  --start-date "2026-03-08" \
  --end-date "2026-03-22" \
  --max-uses 1000
```

**Tipos:**
- `discount`: Descuento porcentaje o cantidad
- `bogo`: Buy One Get One
- `bundle`: Paquete de productos
- `coupon`: Código cupón

**Parámetros:**
- `--type`: Tipo de promoción
- `--name`: Nombre descriptivo
- `--value`: Valor (% o cantidad según tipo)
- `--conditions`: Condiciones (format: clave:valor,...)
- `--start-date`: Inicio (YYYY-MM-DD)
- `--end-date`: Fin (YYYY-MM-DD)
- `--max-uses`: Uso máximo (opcional)

### activate
Pone una promoción en vivo.

```
savia promotion-engine activate \
  --promo PROMO-001 \
  --channels "web,mobile,tienda"
```

**Parámetros:**
- `--promo`: ID de promoción
- `--channels`: Canales (web/mobile/tienda/todos)

### deactivate
Detiene una promoción activa.

```
savia promotion-engine deactivate \
  --promo PROMO-001 \
  --reason "fin-temporada"
```

**Parámetros:**
- `--promo`: ID de promoción
- `--reason`: Motivo de desactivación

### evaluate
Evalúa si un carrito califica para promociones.

```
savia promotion-engine evaluate \
  --cart-items "SKU-0001:2,SKU-0045:1" \
  --cart-total 250 \
  --customer-segment "premium"
```

**Parámetros:**
- `--cart-items`: Productos en carrito (SKU:cant,...)
- `--cart-total`: Monto total carrito
- `--customer-segment`: Segmento cliente (opcional)

**Salida:** Promociones aplicables + ahorros

### report
Analiza performance de promociones activas.

```
savia promotion-engine report \
  --period "monthly" \
  --metrics "redemptions,revenue-impact,margin"
```

**Parámetros:**
- `--period`: (daily/weekly/monthly)
- `--metrics**: métricas a incluir (redemptions/revenue/margin/roi)

**Incluye:**
- Canjes totales
- Ingresos generados por promoción
- Impacto en margen de beneficio
- ROI estimado
