# Plantilla de Solicitud de Información al PM

> Referencia para la skill `diagram-import`. Templates para solicitar al PM la información faltante de reglas de negocio.

## Informe general de información faltante

```markdown
# ⚠️ Información faltante para importar diagrama — {proyecto}

**Fuente del diagrama:** {source}
**Entidades detectadas:** {total}
**Completas:** {complete} ✅
**Incompletas:** {incomplete} ⚠️
**Sin reglas:** {missing} ❌

## Detalle por entidad

{tabla_detalle}

## Acciones requeridas

Para completar la importación, necesito que proporciones la información
marcada como faltante. Puedes:

1. **Actualizar `projects/{proyecto}/reglas-negocio.md`** con la información
   y volver a ejecutar `/diagram:import`
2. **Proporcionar la información aquí** y la añado al fichero
3. **Generar solo las entidades completas** (parcial)

---
Generado por PM-Workspace — /diagram:import
```

## Solicitud por entidad (para modo interactivo)

### Microservicio

```
📋 {nombre_servicio} (Microservicio)

Necesito la siguiente información:

1. **Interfaz/Contrato**: ¿Qué endpoints expone este servicio?
   Formato: [VERB] /path → descripción
   Ejemplo: [POST] /api/users → Crear usuario

2. **Base de datos**: ¿Qué tecnología y entidades principales?
   Ejemplo: PostgreSQL — tablas: users, roles, sessions

3. **Entorno de deploy**: ¿Dónde se desplegará?
   Ejemplo: Azure AKS, namespace: users-service

4. **Autenticación**: ¿Cómo se autentican las llamadas?
   Ejemplo: JWT Bearer token, roles: admin, user
```

### Base de datos

```
📋 {nombre_db} (Base de datos)

Necesito la siguiente información:

1. **Tecnología**: ¿Qué motor de base de datos?
   Opciones: PostgreSQL, SQL Server, MongoDB, MySQL, DynamoDB, CosmosDB...

2. **Esquema principal**: ¿Cuáles son las entidades/tablas principales?
   Formato: tabla (campo1, campo2, ...) → relaciones

3. **Política de backup**: ¿Frecuencia y retención?
   Ejemplo: Backup diario, retención 30 días, RPO 1h, RTO 4h
```

### Cola / Bus

```
📋 {nombre_cola} (Cola/Mensajería)

Necesito la siguiente información:

1. **Formato de mensaje**: ¿Qué estructura tiene el mensaje?
   Ejemplo: JSON { "eventType": "...", "payload": { ... } }

2. **Política de reintentos**: ¿Cuántos reintentos y estrategia?
   Ejemplo: 3 reintentos, exponential backoff (1s, 5s, 30s)

3. **Dead Letter Queue**: ¿Se usa DLQ? ¿Cómo se revisan?
   Ejemplo: Sí, revisión manual diaria + alerta automática
```

### Integración externa

```
📋 {nombre_integracion} (Servicio externo)

Necesito la siguiente información:

1. **Proveedor**: ¿Qué servicio externo es?
   Ejemplo: Stripe Payment API v2

2. **SLA esperado**: ¿Qué uptime y latencia aceptamos?
   Ejemplo: 99.9% uptime, <500ms p95

3. **Fallback**: ¿Qué hacer si el servicio no responde?
   Ejemplo: Cola de reintentos + notificación al usuario
```

## Plantilla para reglas-negocio.md (nueva)

Si el fichero no existe, generar esta plantilla:

```markdown
# Reglas de Negocio — {proyecto}

> Documentar aquí las reglas de dominio, restricciones funcionales y
> requisitos de cada componente del sistema. Esta información es necesaria
> para generar PBIs de calidad desde diagramas de arquitectura.

## {Componente 1}

**Tipo:** Microservicio | Database | Cola | Frontend | Externo
**Descripción:** ...

### Interfaz / Contrato
...

### Reglas de dominio
...

### Restricciones
...

---

## {Componente 2}
...
```
