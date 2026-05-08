# Validación de Reglas de Negocio para Importación de Diagramas

> Referencia para la skill `diagram-import`. Checklist de campos obligatorios por tipo de entidad antes de poder generar PBIs.

## Principio

**No se crean PBIs sin reglas de negocio suficientes.** Cada entidad del diagrama debe tener información funcional mínima documentada en `projects/{proyecto}/reglas-negocio.md` para poder generar work items de calidad.

---

## Checklist por tipo de entidad

### Microservicio / API Service

| Campo | Obligatorio | Descripción |
|---|---|---|
| Interfaz / Contrato | ✅ Sí | Endpoints expuestos, request/response schemas |
| Base de datos propia | ✅ Sí | Tecnología y entidades principales del schema |
| Entorno de deploy | ✅ Sí | Cloud provider, servicio (AKS, App Service, ECS) |
| Autenticación | ✅ Sí | JWT, API Key, OAuth, mTLS |
| Escalado | ⚠️ Recom. | Horizontal/vertical, métricas de auto-scale |
| Observabilidad | ⚠️ Recom. | Logging, tracing, métricas, alertas |

### API Endpoint (individual)

| Campo | Obligatorio | Descripción |
|---|---|---|
| Método HTTP + Path | ✅ Sí | GET /api/v1/users/{id} |
| Request schema | ✅ Sí | Body, query params, headers requeridos |
| Response schema | ✅ Sí | Códigos HTTP, body de respuesta |
| Autenticación | ✅ Sí | Anónimo, autenticado, rol requerido |
| Rate limiting | ⚠️ Recom. | Límites por usuario/IP/global |
| Validaciones | ⚠️ Recom. | Reglas de validación de inputs |

### Base de datos

| Campo | Obligatorio | Descripción |
|---|---|---|
| Tecnología | ✅ Sí | PostgreSQL, SQL Server, MongoDB, etc. |
| Esquema / Entidades | ✅ Sí | Tablas/colecciones principales y relaciones |
| Política de backup | ✅ Sí | Frecuencia, retención, RPO/RTO |
| Plan de escalado | ⚠️ Recom. | Read replicas, sharding, partitioning |
| Retención de datos | ⚠️ Recom. | RGPD, política de borrado |

### UI / Frontend

| Campo | Obligatorio | Descripción |
|---|---|---|
| User stories vinculadas | ✅ Sí | Qué funcionalidad ve/usa el usuario |
| Requisitos accesibilidad | ✅ Sí | Nivel WCAG (AA mínimo) |
| Responsive | ⚠️ Recom. | Breakpoints, mobile-first |
| Framework / tecnología | ⚠️ Recom. | Angular, React, Vue, etc. |

### Cola / Bus de mensajería

| Campo | Obligatorio | Descripción |
|---|---|---|
| Formato de mensaje | ✅ Sí | JSON schema, Avro, Protobuf |
| Política de reintentos | ✅ Sí | Max retries, backoff strategy |
| Dead Letter Queue | ✅ Sí | Sí/No, política de revisión |
| Orden garantizado | ⚠️ Recom. | FIFO requerido o no |
| Tecnología | ⚠️ Recom. | Azure Service Bus, RabbitMQ, Kafka |

### Integración con servicio externo

| Campo | Obligatorio | Descripción |
|---|---|---|
| Proveedor | ✅ Sí | Nombre del servicio (Stripe, Twilio, etc.) |
| SLA esperado | ✅ Sí | Uptime, latencia máxima aceptable |
| Estrategia de fallback | ✅ Sí | Qué hacer si el servicio no responde |
| Formato de datos | ⚠️ Recom. | REST, GraphQL, SOAP, webhooks |
| Credenciales | ⚠️ Recom. | Tipo (API Key, OAuth), gestión (Key Vault) |

---

## Algoritmo de validación

```
Para cada entidad E del diagrama:
  1. Buscar E.name en reglas-negocio.md (match por nombre o alias)
  2. Si no encontrada → marcar como "sin reglas" (❌)
  3. Si encontrada:
     a. Obtener tipo de E (microservice, database, etc.)
     b. Cargar checklist del tipo
     c. Verificar cada campo ✅ obligatorio
     d. Si todos ✅ presentes → status = "complete"
     e. Si falta algún ✅ → status = "incomplete", listar missing_fields
     f. Campos ⚠️ ausentes → warning (no bloquea)

Resultado:
  - complete_count: entidades con toda la info obligatoria
  - incomplete_count: entidades con info faltante
  - missing_entities: entidades no encontradas en reglas-negocio.md
```

## Niveles de bloqueo

| Estado | Acción |
|---|---|
| Todas completas | ✅ Proceder a generar Features/PBIs/Tasks |
| Algunas incompletas | ⚠️ Ofrecer opciones (parcial, draft, esperar) |
| Ninguna encontrada | ❌ No generar nada. Solicitar reglas-negocio.md al PM |
| Fichero no existe | ❌ No generar nada. Crear plantilla para el PM |
