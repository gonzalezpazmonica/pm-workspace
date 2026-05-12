# Plantillas de Generación de PBIs desde Diagrama

> Referencia para la skill `diagram-import`. Templates para crear PBIs automáticamente según el tipo de entidad detectada.

## Feature Template

```markdown
# Feature: {nombre_bounded_context}

## Descripción
Implementación del módulo {nombre} del sistema, que incluye {N} componentes:
{lista_componentes}.

**Origen:** Diagrama de arquitectura — {source_url_o_fichero}

## Componentes incluidos
{tabla_entidades_del_feature}

## Criterios de aceptación del Feature
- [ ] Todos los PBIs hijos completados y validados
- [ ] Tests de integración entre componentes del módulo
- [ ] Documentación de arquitectura actualizada
- [ ] Deploy funcional en entorno DEV
```

## PBI Templates por tipo de entidad

### Microservicio — Scaffolding

```markdown
**Título:** Scaffolding {nombre_servicio}

**Descripción:**
Crear la estructura base del microservicio {nombre}, incluyendo proyecto,
configuración, health checks y pipeline CI básico.

**Criterios de aceptación:**
- [ ] Proyecto creado con template estándar ({framework})
- [ ] Health check endpoint /health respondiendo
- [ ] Dockerfile funcional
- [ ] Pipeline CI: build + test
- [ ] Configuración de entorno (appsettings/env vars)
- [ ] Logging configurado (Serilog/equivalente)

**Tags:** diagram-import, microservice, scaffolding
**SP estimados:** 3-5
```

### Microservicio — Endpoint

```markdown
**Título:** Endpoint {verb} {path} en {nombre_servicio}

**Descripción:**
Implementar el endpoint {verb} {path} que {descripcion_funcional}.
Relación: {from} → {to} ({tipo_relacion}).

**Criterios de aceptación:**
- [ ] Endpoint implementado con validación de inputs
- [ ] Autenticación/autorización configurada
- [ ] Tests unitarios (≥80% cobertura)
- [ ] Swagger/OpenAPI documentado
- [ ] Manejo de errores estándar (ProblemDetails)

**Tags:** diagram-import, microservice, endpoint
**SP estimados:** 2-3
```

### Base de datos — Schema

```markdown
**Título:** Schema y migraciones {nombre_db}

**Descripción:**
Crear el esquema de base de datos {nombre} ({tecnologia}).
Incluye migraciones, seeders de datos de prueba y configuración de backup.

**Criterios de aceptación:**
- [ ] Schema creado según diseño de reglas de negocio
- [ ] Migraciones aplicables y reversibles
- [ ] Seeders de datos de prueba para DEV
- [ ] Índices para queries frecuentes
- [ ] Connection string configurada por entorno
- [ ] Política de backup documentada

**Tags:** diagram-import, database, schema
**SP estimados:** 2-3
```

### Cola/Bus — Productor

```markdown
**Título:** Productor de mensajes para {nombre_cola}

**Descripción:**
Implementar el productor de mensajes hacia {nombre_cola} desde {servicio_origen}.
Formato: {formato_mensaje}.

**Criterios de aceptación:**
- [ ] Productor implementado con serialización correcta
- [ ] Mensajes publicados en formato acordado
- [ ] Retry policy configurada
- [ ] Tests unitarios del productor
- [ ] Logging de mensajes enviados

**Tags:** diagram-import, queue, producer
**SP estimados:** 2
```

### Cola/Bus — Consumidor

```markdown
**Título:** Consumidor de mensajes de {nombre_cola}

**Descripción:**
Implementar el consumidor de mensajes de {nombre_cola} en {servicio_destino}.
Procesamiento: {descripcion_procesamiento}.

**Criterios de aceptación:**
- [ ] Consumidor implementado con deserialización
- [ ] Idempotencia garantizada
- [ ] Dead Letter Queue (DLQ) configurada
- [ ] Manejo de errores y reintentos
- [ ] Tests unitarios del consumidor
- [ ] Monitoring de cola (backlog, errors)

**Tags:** diagram-import, queue, consumer
**SP estimados:** 3
```

### Frontend — Vista/Página

```markdown
**Título:** Vista {nombre_vista} en {nombre_frontend}

**Descripción:**
Implementar la vista/página {nombre} que permite al usuario {funcionalidad}.
Integración con API: {endpoints_consumidos}.

**Criterios de aceptación:**
- [ ] Componente implementado según diseño
- [ ] Integración con API funcional
- [ ] Responsive design (mobile/tablet/desktop)
- [ ] Accesibilidad WCAG 2.1 AA
- [ ] Tests de componente
- [ ] Loading states y manejo de errores

**Tags:** diagram-import, frontend, view
**SP estimados:** 3-5
```

### Integración externa — Cliente

```markdown
**Título:** Cliente SDK para {nombre_servicio_externo}

**Descripción:**
Implementar cliente para integración con {proveedor} ({tipo_integracion}).
SLA esperado: {sla}.

**Criterios de aceptación:**
- [ ] Cliente implementado con interfaz abstraída
- [ ] Circuit breaker / retry configurado
- [ ] Fallback definido para indisponibilidad
- [ ] Credenciales gestionadas por config (no hardcoded)
- [ ] Tests con mock del servicio externo
- [ ] Logging de llamadas y tiempos de respuesta

**Tags:** diagram-import, integration, external
**SP estimados:** 3
```

## Tasks comunes (hijos de cada PBI)

| Task | Horas est. | Actividad |
|---|---|---|
| Scaffolding / Setup | 2h | Dev |
| Implementación core | 4-8h | Dev |
| Tests unitarios | 2-4h | Dev |
| Tests integración | 2-4h | Dev |
| Documentación API | 1-2h | Dev |
| Code review | 1h | Review |
| Config CI/CD | 1-2h | DevOps |
