---
name: product-catalog
description: "Gestiona el catálogo de productos: añadir, actualizar, listar, buscar y exportar"
section: "Retail/eCommerce"
category: "Inventory Management"
keywords: ["productos", "catálogo", "SKU", "categorías"]
author: "Claude Code"
---

## Descripción

Comando para gestionar el catálogo de productos del proyecto de retail. Permite agregar nuevos productos, actualizar información existente, listar con filtros, buscar por atributos y exportar datos.

Almacenamiento: `projects/{proyecto}/retail/catalog/`

## Subcomandos

### add
Añade un nuevo producto al catálogo con identificador SKU-NNNN.

```
savia product-catalog add \
  --sku SKU-0001 \
  --name "Nombre Producto" \
  --category "Electrónica" \
  --price 99.99 \
  --cost 45.00 \
  --stock 150 \
  --description "Descripción detallada" \
  --attributes "Color:Azul,Tamaño:M" \
  --images "img-ref-001,img-ref-002"
```

**Parámetros:**
- `--sku`: Identificador único (SKU-NNNN)
- `--name`: Nombre del producto
- `--category`: Categoría
- `--price`: Precio de venta
- `--cost`: Precio de costo
- `--stock`: Stock inicial
- `--description`: Descripción
- `--attributes`: Atributos (Color, Tamaño, etc.)
- `--images`: Referencias de imágenes

### update
Modifica campos específicos de un producto existente.

```
savia product-catalog update \
  --sku SKU-0001 \
  --price 89.99 \
  --stock 120 \
  --status "active"
```

**Parámetros:**
- `--sku`: SKU del producto a actualizar
- `--price`: Nuevo precio (opcional)
- `--stock`: Nuevo stock (opcional)
- `--status`: Estado (active/inactive/discontinued)

### list
Lista productos con opciones de filtrado.

```
savia product-catalog list \
  --category "Electrónica" \
  --price-min 50 \
  --price-max 150 \
  --stock-level high
```

**Parámetros:**
- `--category`: Filtrar por categoría
- `--price-min`: Precio mínimo
- `--price-max`: Precio máximo
- `--stock-level`: (low/medium/high)

### search
Busca productos por palabra clave, categoría o atributos.

```
savia product-catalog search \
  --keyword "laptop" \
  --category "Electrónica" \
  --attribute "Marca:Dell"
```

**Parámetros:**
- `--keyword`: Palabra clave de búsqueda
- `--category`: Categoría específica
- `--attribute`: Atributo y valor (formato: Clave:Valor)

### export
Exporta el catálogo a CSV o JSON.

```
savia product-catalog export \
  --format json \
  --output catalog-20260306.json
```

**Parámetros:**
- `--format`: (csv/json)
- `--output`: Nombre del archivo de salida
