---
title: "Incidentes de Red Telecomunicaciones"
description: "Gestión del ciclo de vida de incidentes de red con reporte, clasificación, escalado y resolución"
icon: "🚨"
category: "Telecomunicaciones"
---

# Incidentes de Red Telecomunicaciones

Administra el ciclo de vida completo de incidentes de red incluyendo reportes, clasificación por procesos eTOM, escalado entre niveles y resolución con análisis de cumplimiento SLA.

## Subcomandos

### report
Registra un nuevo incidente de red con identificador único (NI-NNNN).

**Uso:** `network-incident report [opciones]`

**Parámetros:**
- `--tipo` - Tipo de incidente: outage, degradation, maintenance (requerido)
- `--area-afectada` - Área geográfica o de red afectada (requerido)
- `--impacto` - Descripción del impacto en servicios (requerido)
- `--severidad` - Nivel de severidad: crítica, alta, media, baja (requerido)
- `--proyecto` - Identificador del proyecto (requerido)

**Ejemplo:**
```bash
network-incident report \
  --tipo outage \
  --area-afectada "Región Metropolitana - Zona Norte" \
  --impacto "Pérdida total de servicio de datos a 5000 clientes" \
  --severidad crítica \
  --proyecto mi-telco
```

**Resultado:** Crea archivo `projects/{proyecto}/telco/incidents/NI-NNNN.yaml` con datos del incidente registrado.

### classify
Categoriza un incidente según las áreas de proceso eTOM (Operaciones, Gestión y Mantenimiento).

**Uso:** `network-incident classify [opciones]`

**Parámetros:**
- `--incidente` - Identificador del incidente (requerido)
- `--area-etom` - Área eTOM de clasificación (requerido)
- `--causa-raiz` - Descripción preliminar de causa raíz (opcional)
- `--proyecto` - Identificador del proyecto (requerido)

**Ejemplo:**
```bash
network-incident classify \
  --incidente NI-0001 \
  --area-etom "Gestión de Infraestructura de Red" \
  --causa-raiz "Fallo de equipo de enrutamiento en nodo central" \
  --proyecto mi-telco
```

### escalate
Escala un incidente al siguiente nivel de soporte con notas técnicas.

**Uso:** `network-incident escalate [opciones]`

**Parámetros:**
- `--incidente` - Identificador del incidente (requerido)
- `--nivel` - Nivel de escalado: 1, 2, 3, especialista (requerido)
- `--notas` - Notas técnicas para el siguiente nivel (requerido)
- `--proyecto` - Identificador del proyecto (requerido)

**Ejemplo:**
```bash
network-incident escalate \
  --incidente NI-0001 \
  --nivel 3 \
  --notas "Se requiere intervención de especialista en enrutamiento. Verificar configuración BGP." \
  --proyecto mi-telco
```

### resolve
Cierra un incidente registrando la causa raíz y la resolución aplicada.

**Uso:** `network-incident resolve [opciones]`

**Parámetros:**
- `--incidente` - Identificador del incidente (requerido)
- `--causa-raiz` - Causa raíz identificada (requerido)
- `--resolucion` - Descripción de la resolución (requerido)
- `--duracion` - Duración total del incidente en minutos (opcional)
- `--proyecto` - Identificador del proyecto (requerido)

**Ejemplo:**
```bash
network-incident resolve \
  --incidente NI-0001 \
  --causa-raiz "Degradación de la interfaz de enrutamiento por sobrecarga" \
  --resolucion "Reemplazo del módulo de interfaz y reconfiguración de carga" \
  --duracion 180 \
  --proyecto mi-telco
```

### sla-check
Verifica el cumplimiento del acuerdo de nivel de servicio para un incidente.

**Uso:** `network-incident sla-check [opciones]`

**Parámetros:**
- `--incidente` - Identificador del incidente (requerido)
- `--severidad` - Severidad del incidente (requerido)
- `--proyecto` - Identificador del proyecto (requerido)

**Ejemplo:**
```bash
network-incident sla-check \
  --incidente NI-0001 \
  --severidad crítica \
  --proyecto mi-telco
```

**Resultado:** Muestra análisis de cumplimiento SLA con tiempos de respuesta, resolución y desviaciones.

## Almacenamiento

Todos los incidentes se guardan en `projects/{proyecto}/telco/incidents/` con estructura YAML incluyendo auditoría completa de cambios.

