# Skill: Diagram Import — Parsing, Validación y Generación de Work Items

## Propósito

Importar diagramas de arquitectura (Draw.io, Miro, Mermaid local), extraer entidades y relaciones, validar que existan reglas de negocio suficientes y generar Features/PBIs/Tasks en Azure DevOps.

**Principio fundamental:** NO se crean PBIs si falta información de reglas de negocio. Se solicita al PM.

---

## Triggers

- Comando `/diagram-import` — Importación completa
- Petición directa: "importa el diagrama y crea los PBIs"

---

## Contexto Requerido (Progressive Disclosure)

1. `CLAUDE.md` (raíz) — Contexto global, conexión Azure DevOps
2. `projects/{proyecto}/CLAUDE.md` — Stack, arquitectura, repos
3. `projects/{proyecto}/reglas-negocio.md` — **CRÍTICO**: reglas de dominio
4. `projects/{proyecto}/equipo.md` — Perfiles para asignación posterior
5. `.claude/rules/diagram-config.md` — Constantes y checklist de validación
6. `.claude/rules/pm-config.md` — Credenciales MCP y Azure DevOps
7. `docs/politica-estimacion.md` — Para estimar PBIs generados

---

## Fase 1: Obtener y Parsear el Diagrama

### 1.1 Fuentes soportadas

| Fuente | Detección | Método de lectura |
|---|---|---|
| URL Draw.io | `draw.io/`, `.drawio.com` en URL | MCP `draw-io` → leer diagrama XML |
| URL Miro | `miro.com/app/board/` en URL | MCP `miro` → leer items del board |
| Fichero local `.drawio` / `.xml` | Extensión `.drawio`, `.xml` | Leer XML directamente |
| Fichero local `.mermaid` | Extensión `.mermaid`, `.md` con bloques mermaid | Parsear sintaxis Mermaid |
| Meta existente | ID de `diagrams/*.meta.json` | Leer meta → obtener source |

### 1.2 Parsing → Modelo normalizado

Independiente del formato de origen, producir un modelo interno:

```json
{
  "entities": [
    {
      "id": "svc-users",
      "name": "User Service",
      "type": "microservice",
      "description": "Gestión de usuarios y autenticación",
      "metadata": { "framework": ".NET 8", "db": "PostgreSQL" }
    }
  ],
  "relationships": [
    {
      "from": "api-gateway",
      "to": "svc-users",
      "type": "http-sync",
      "label": "POST /api/users"
    }
  ]
}
```

### 1.3 Reconocimiento de entidades

Usar `references/diagram-to-domain-mapping.md` para clasificar shapes:
- Rectángulos → servicios/APIs
- Cilindros → bases de datos
- Hexágonos → colas/buses
- Rombos → decisiones o caches
- Rectángulos redondeados → frontends
- Rectángulos grises/dashed → servicios externos
- Flechas sólidas → sync, discontinuas → async

---

## Fase 2: Validación Arquitectónica

Invocar agente `diagram-architect` para:
1. Detectar dependencias circulares
2. Validar layering correcto
3. Identificar antipatrones (DB compartida, god service)
4. Evaluar completitud de cada entidad

Si hay problemas ❌ bloqueantes → informar al PM y recomendar corregir el diagrama.

---

## Fase 3: Validación de Reglas de Negocio ⚠️ CRÍTICO

### 3.1 Cargar reglas de negocio

Leer `projects/{proyecto}/reglas-negocio.md`. Si no existe:
```
❌ No existe el fichero de reglas de negocio.

Para importar un diagrama y generar work items, necesito que el proyecto
tenga reglas de negocio documentadas en:
  → projects/{proyecto}/reglas-negocio.md

Este fichero debe contener las reglas de dominio, restricciones funcionales
y requisitos de cada componente del sistema.

¿Quieres que genere una plantilla para que la completes?
```

### 3.2 Verificar por cada entidad

Para cada entidad del diagrama, verificar checklist según tipo (ver `references/business-rules-validation.md`):

| Tipo | Campos obligatorios |
|---|---|
| Microservicio | Interfaz/contrato definido, esquema DB, entorno deploy, escalado |
| API/Endpoint | Método HTTP, path, autenticación, rate limit, validaciones |
| Base de datos | Tecnología, esquema, política backup, plan escalado, retención |
| UI/Frontend | User stories vinculadas, requisitos accesibilidad, responsive |
| Cola/Mensajería | Formato mensaje, política reintentos, DLQ, orden garantizado |
| Integración ext. | Proveedor, SLA, fallback, credenciales, formato datos |

### 3.3 Generar informe de información faltante

Si hay entidades con campos faltantes:

```
⚠️ Reglas de Negocio Incompletas

Se han detectado {N} entidades en el diagrama.
{M} entidades tienen reglas de negocio completas.
{N-M} entidades necesitan información adicional:

┌─────────────────────┬──────────────┬───────────────────────────────────┐
│ Entidad             │ Tipo         │ Información faltante              │
├─────────────────────┼──────────────┼───────────────────────────────────┤
│ Payment Service     │ Microservice │ Entorno deploy, proveedor pagos   │
│ Orders DB           │ Database     │ Política backup, plan escalado    │
│ Notification Queue  │ Queue        │ Formato mensaje, política DLQ     │
└─────────────────────┴──────────────┴───────────────────────────────────┘

❌ NO se crearán PBIs hasta completar esta información.

Opciones:
  [1] Proporciona la información ahora (interactivo)
  [2] Actualiza reglas-negocio.md y vuelve a ejecutar
  [3] Genera solo las entidades completas (parcial)
  [4] Genera todo como Draft (requiere revisión humana)
```

### 3.4 Opciones del PM

- **Opción 1**: Preguntar interactivamente campo por campo
- **Opción 2**: Esperar a que el PM actualice el fichero
- **Opción 3**: Generar solo Features/PBIs de entidades completas, marcar resto como pendiente
- **Opción 4**: Generar todo con tag `draft` y estado `New` (no `Committed`)

---

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

## Referencias

- `references/diagram-to-domain-mapping.md` — Reconocimiento de entidades
- `references/pbi-generation-templates.md` — Plantillas de PBIs
- `references/business-rules-validation.md` — Checklist de validación
- `references/missing-info-request-template.md` — Solicitud de info al PM
