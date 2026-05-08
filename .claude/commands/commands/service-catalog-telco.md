---
name: service-catalog-telco
description: "Gestión del catálogo de servicios de telecom con definiciones, configuración y precios"
icon: "📋"
category: "Telecomunicaciones"
---

# Catálogo de Servicios Telecomunicaciones

Administra el catálogo completo de servicios de telecomunicaciones incluyendo definiciones, listados, configuración personalizada, cálculo de precios y empaquetamiento de servicios.

## Subcomandos

### define
Crea una nueva definición de servicio de telecomunicaciones con identificador único (SVC-NNN).

**Uso:** `service-catalog-telco define [opciones]`

**Parámetros:**
- `--nombre` - Nombre del servicio (requerido)
- `--tipo` - Tipo de servicio: voz, datos, fibra, tv, convergente (requerido)
- `--velocidad` - Velocidad o capacidad del servicio (requerido)
- `--sla` - Acuerdo de nivel de servicio (requerido)
- `--proyecto` - Identificador del proyecto (requerido)

**Ejemplo:**
```bash
service-catalog-telco define \
  --nombre "Fibra Óptica 300Mbps" \
  --tipo fibra \
  --velocidad "300 Mbps" \
  --sla "99.5%" \
  --proyecto mi-telco
```

**Resultado:** Crea archivo `projects/{proyecto}/telco/services/SVC-NNN.yaml` con la definición completa.

### list
Muestra todos los servicios del catálogo con opciones de filtrado.

**Uso:** `service-catalog-telco list [opciones]`

**Parámetros:**
- `--proyecto` - Identificador del proyecto (requerido)
- `--tipo` - Filtrar por tipo de servicio (opcional)
- `--activos` - Mostrar solo servicios activos (opcional)
- `--formato` - Formato de salida: tabla, json, yaml (default: tabla)

**Ejemplo:**
```bash
service-catalog-telco list \
  --proyecto mi-telco \
  --tipo fibra \
  --activos
```

### configure
Personaliza los parámetros de un servicio para un perfil específico de cliente.

**Uso:** `service-catalog-telco configure [opciones]`

**Parámetros:**
- `--servicio` - Identificador del servicio (requerido)
- `--perfil` - Perfil de cliente (requerido)
- `--parametro` - Parámetro a personalizar (requerido)
- `--valor` - Valor del parámetro (requerido)
- `--proyecto` - Identificador del proyecto (requerido)

**Ejemplo:**
```bash
service-catalog-telco configure \
  --servicio SVC-001 \
  --perfil corporativo \
  --parametro velocidad \
  --valor "500 Mbps" \
  --proyecto mi-telco
```

### price
Calcula el precio de un servicio basado en su configuración actual.

**Uso:** `service-catalog-telco price [opciones]`

**Parámetros:**
- `--servicio` - Identificador del servicio (requerido)
- `--perfil` - Perfil de cliente (opcional)
- `--cantidad` - Cantidad de unidades (opcional)
- `--moneda` - Moneda de cálculo (default: USD)
- `--proyecto` - Identificador del proyecto (requerido)

**Ejemplo:**
```bash
service-catalog-telco price \
  --servicio SVC-001 \
  --perfil corporativo \
  --cantidad 10 \
  --moneda EUR \
  --proyecto mi-telco
```

### bundle
Combina múltiples servicios en paquetes con descuentos aplicables.

**Uso:** `service-catalog-telco bundle [opciones]`

**Parámetros:**
- `--nombre` - Nombre del paquete (requerido)
- `--servicios` - Lista de servicios a agrupar (requerido)
- `--descuento` - Descuento aplicable al paquete (requerido)
- `--proyecto` - Identificador del proyecto (requerido)

**Ejemplo:**
```bash
service-catalog-telco bundle \
  --nombre "Pack Convergente Hogar" \
  --servicios "SVC-001,SVC-002,SVC-003" \
  --descuento "15%" \
  --proyecto mi-telco
```

**Resultado:** Crea archivo `projects/{proyecto}/telco/services/BUNDLE-NNN.yaml` con la definición del paquete y cálculos de precio final.

## Almacenamiento

Todos los datos se guardan en `projects/{proyecto}/telco/services/` con estructura YAML.

