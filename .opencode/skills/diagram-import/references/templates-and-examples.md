# Diagram Import: Templates, Examples y Patrones Detallados

## Fase 4: Generación de Jerarquía Work Items

### 4.1 Reglas de generación

| Diagrama → | Azure DevOps Work Item |
|---|---|
| Bounded context / Módulo mayor | **Feature** |
| Funcionalidad / Endpoint / User Story | **PBI** |
| Tarea técnica (migración, test, CI/CD) | **Task** (hijo de PBI) |

### 4.2 Agrupación en Features

Agrupar entidades en Features por:
1. **Bounded context** — Si el diagrama tiene subgraphs/containers, cada uno es un Feature
2. **Dominio funcional** — Entidades del mismo dominio (users, orders, payments)
3. **Independencia de deploy** — Componentes que se despliegan juntos
4. Si no hay agrupación clara → 1 Feature = 1 entidad principal (microservicio/módulo)

### 4.3 Generación de PBIs por entidad

Para cada entidad, generar PBIs usando `references/pbi-generation-templates.md`:

- **Microservicio**: PBI de scaffolding + PBI por endpoint principal + PBI de tests + PBI de deploy
- **Base de datos**: PBI de schema/migración + PBI de seeders + PBI de backup config
- **Cola**: PBI de productor + PBI de consumidor + PBI de DLQ handling
- **Frontend**: PBI por vista/página + PBI de integración API + PBI de accesibilidad
- **Integración**: PBI de cliente SDK + PBI de fallback + PBI de monitoring

### 4.4 Estimación preliminar

Usar rangos estándar de `docs/politica-estimacion.md`:
- Scaffolding microservicio: 3-5 SP
- Endpoint CRUD: 2-3 SP
- Schema + migraciones: 2-3 SP
- Tests unitarios: 1-2 SP
- Tests integración: 2-3 SP
- Pipeline CI/CD: 1-2 SP

---

## Fase 5: Presentar Propuesta

```
📋 Importación de Diagrama — {proyecto}

Fuente: {url_o_fichero}
Entidades detectadas: {N}
Reglas de negocio: ✅ {M}/{N} completas

Jerarquía propuesta:

Feature 1: {nombre} ({X} SP estimados)
├── PBI 1.1: {título} ({Y} SP)
│   ├── Task: Scaffolding
│   ├── Task: Implementación
│   └── Task: Tests
├── PBI 1.2: {título} ({Y} SP)
...

Feature 2: {nombre} ({X} SP estimados)
├── PBI 2.1: {título} ({Y} SP)
...

Total: {F} Features, {P} PBIs, {T} Tasks, ~{SP} SP

¿Creo estos work items en Azure DevOps? ¿Quieres ajustar algo?
```

---

## Fase 6: Crear en Azure DevOps

Tras confirmación del PM:

1. Crear Features con descripción + link al diagrama source
2. Crear PBIs como hijos de Features, con:
   - Título descriptivo
   - Descripción generada desde template
   - Criterios de aceptación derivados de reglas de negocio
   - Tags: `diagram-import`, `{tipo-entidad}`
   - Link al diagrama source en campo Description
3. Crear Tasks como hijos de PBIs (scaffolding, implementación, tests)
4. Actualizar metadata: `diagrams/{tool}/{tipo}.meta.json` con IDs generados
5. Comentario en cada Feature: "Generado desde diagrama: {source}"

---

## Fase 7: Resumen Final

```
✅ Work items creados en Azure DevOps

Features: {F} creados (IDs: ...)
PBIs:     {P} creados
Tasks:    {T} creadas
SP total: ~{SP}

📊 Metadata actualizada: projects/{p}/diagrams/{tool}/{tipo}.meta.json

Siguiente paso recomendado:
  → /pbi-decompose-batch {ids} para refinar estimaciones y asignaciones
  → /sprint-plan para planificar el sprint con los nuevos PBIs
```

---

## Validación de Reglas de Negocio — Checklist Detallado

Para cada entidad, verificar campos según tipo:

### Microservicio
- [ ] Interfaz/contrato definido (API endpoints, gRPC, eventos)
- [ ] Esquema DB documentado (si usa BD)
- [ ] Entorno deploy definido (on-prem, cloud, container)
- [ ] Escalado definido (horizontal/vertical, auto-scaling)
- [ ] Dependencies identificadas (otras APIs, DBs, servicios externos)

### API/Endpoint
- [ ] Método HTTP definido (GET, POST, PUT, DELETE, PATCH)
- [ ] Path exacto definido (/api/v1/users/{id})
- [ ] Autenticación especificada (OAuth, JWT, API Key, None)
- [ ] Rate limit definido o justificado (unlimited)
- [ ] Validaciones de input listadas

### Base de datos
- [ ] Tecnología especificada (PostgreSQL, MySQL, MongoDB, etc.)
- [ ] Esquema definido (tablas principales, relaciones)
- [ ] Política backup definida (diaria, semanal, real-time)
- [ ] Plan escalado documentado (cuando escalar, cómo)
- [ ] Retención de datos definida (cuánto tiempo guardar)

### UI/Frontend
- [ ] User stories vinculadas (quién, qué, para qué)
- [ ] Requisitos accesibilidad definidos (WCAG 2.1 Level A/AA)
- [ ] Responsive definido (móvil, tablet, desktop)
- [ ] Integraciones de APIs especificadas (endpoints requeridos)

### Cola/Mensajería
- [ ] Formato mensaje definido (JSON schema, Protocol Buffers)
- [ ] Política reintentos definida (exponential backoff, max attempts)
- [ ] Dead Letter Queue (DLQ) configurado
- [ ] Orden garantizado o justificado (ordered, unordered)
- [ ] Garantía de entrega (at-most-once, at-least-once, exactly-once)

### Integración externa
- [ ] Proveedor especificado (API.io, MercadoPago, Stripe, etc.)
- [ ] SLA definido (uptime %, latencia máxima)
- [ ] Fallback definido (qué hacer si el servicio cae)
- [ ] Credenciales y autenticación documentadas (NUNCA en repo)
- [ ] Formato datos definido (request/response payloads)

---

## Manejo de Información Faltante

### Opción 1: Interactivo (recomendado)
```
❌ Falta información para Payment Service:
   - Entorno deploy
   - Proveedor pagos (Stripe / MercadoPago / PayPal)

   → ¿Cuál es el proveedor? > Stripe
   → ¿Dónde se despliega? > AWS Lambda

   ✅ Información guardada. Continuando...
```

### Opción 2: Actualizar fichero y reintentar
Esperar a que el PM complete `reglas-negocio.md` manualmente.

### Opción 3: Generar solo entidades completas
Crear Features/PBIs solo de entidades con información completa.
Marcar resto como pendiente en comentarios.

### Opción 4: Generar todo como Draft
Crear todo con tag `draft` y estado `New` (no `Committed`).
Requiere revisión humana antes de trabajar.

---

## Ejemplo Completo: Diagrama de E-commerce

```
📋 Diagrama: E-commerce Platform
Entidades: 7 (Product, User, Order, Payment, Inventory, Notification, Analytics)
Reglas: ✅ 6/7 completas (falta SLA de Notification Service)

Feature 1: User Management (15 SP)
├── PBI 1.1: Autenticación y registro de usuarios (5 SP)
│   ├── Task: Scaffolding del módulo User
│   ├── Task: Implementar login/registro con OAuth
│   ├── Task: Tests autenticación
├── PBI 1.2: Gestión de perfiles de usuario (3 SP)
├── PBI 1.3: Rol y permisos (7 SP)

Feature 2: Product Catalog (18 SP)
├── PBI 2.1: CRUD de productos (5 SP)
├── PBI 2.2: Búsqueda y filtrado (5 SP)
├── PBI 2.3: Categorías y atributos (8 SP)

Feature 3: Órdenes de Compra (22 SP)
├── PBI 3.1: Crear órdenes (6 SP)
├── PBI 3.2: Estado de órdenes (4 SP)
├── PBI 3.3: Historial de órdenes (3 SP)
├── PBI 3.4: Cancelación y devoluciones (9 SP)

Feature 4: Pagos (18 SP)
├── PBI 4.1: Integración Stripe (8 SP)
├── PBI 4.2: Webhooks de pagos (5 SP)
├── PBI 4.3: Reconciliación (5 SP)

Feature 5: Inventario (12 SP)
├── PBI 5.1: Stock management (5 SP)
├── PBI 5.2: Sincronización con órdenes (7 SP)

Feature 6: Notificaciones (10 SP) ⚠️ Falta SLA
├── PBI 6.1: Envío de emails (5 SP)
├── PBI 6.2: Notificaciones SMS (5 SP)
│   → Preguntar al PM: ¿Qué proveedor SMS? ¿Cuál es el SLA esperado?

Total: 6 Features, 15 PBIs, ~100 SP
```

---

## Troubleshooting Común

### Problema: Diagrama con ciclos de dependencias
**Solución**: Documentar ciclo en comentario de Feature, marcar como riesgo arquitectónico.
Sugerir: A → B → C (serializar o desacoplar).

### Problema: Entidad sin información de negocio
**Solución**: Opción 3 (generar solo completas) o Opción 4 (Draft).
No forzar generación sin info.

### Problema: Múltiples tecnologías en un servicio
**Solución**: Crear múltiples PBIs si son tecnologías ortogonales.
Ej: "B1: Backend Node.js" + "C1: Frontend React" (dos PBIs, mismo Feature).

### Problema: Entidad genérica sin especificidad
**Solución**: Pedir clarificación: ¿cuál es el endpoint principal?
¿Cuál es la responsabilidad primaria?
Agrupar bajo esa responsabilidad.
