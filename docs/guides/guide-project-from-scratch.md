# Guía: Arrancar un proyecto desde cero con Savia

> Para PMs que quieren configurar un proyecto completo: cliente, equipo, arquitectura, reglas de negocio, specs y tests. Aplica a Azure DevOps, Jira o Savia Flow.

---

## Paso 1 — Definir al cliente

> "Savia, crea un perfil de cliente para Acme Corp"

Savia ejecuta `/client-profile create` y te pide datos básicos. Se almacena en SaviaHub:

```
clients/acme-corp/
├── profile.md      ← Nombre, sector, tamaño, contacto principal
├── contacts.md     ← Personas clave del cliente (PO, sponsor, TI)
├── rules.md        ← Reglas del cliente (horarios, compliance, restricciones)
└── projects/       ← Proyectos asociados a este cliente
```

**Ejemplo de `profile.md`:**

```yaml
nombre: Acme Corp
sector: Retail
tamaño: 200 empleados
contrato: T&M (Time & Materials)
presupuesto_horas: 800
contacto_principal: María López (maria.lopez@acme.com)
compliance: RGPD, PCI-DSS (acepta pagos)
```

---

## Paso 2 — Crear el proyecto

```bash
mkdir -p projects/acme-tienda/specs projects/acme-tienda/sprints
```

Crea `projects/acme-tienda/CLAUDE.md` — es el fichero central. Adaptarlo al PM tool:

| Sección | Azure DevOps | Jira | Savia Flow |
|---------|-------------|------|------------|
| Identidad | `PROJECT_AZDO_NAME = "AcmeTienda"` | `JIRA_PROJECT_KEY = "ACM"` | `PROJECT_NAME = "acme-tienda"` |
| Sprint | `ITERATION_PATH_ROOT = "AcmeTienda\\Sprints"` | `JIRA_BOARD_ID = "42"` | `/savia-sprint start` |
| Repo | `REPO_URL = "https://dev.azure.com/..."` | `REPO_URL = "https://github.com/..."` | Mismo repo Git |

**Ejemplo mínimo de CLAUDE.md del proyecto:**

```
# Acme Tienda — E-commerce Backend

## CONSTANTES
PROJECT_NAME        = "acme-tienda"
SPRINT_ACTUAL       = "Sprint 2026-05"
SPRINT_GOAL         = "API de catálogo + carrito de compras"

## Stack
BACKEND             = ".NET 8 / ASP.NET Core"
DATABASE            = "PostgreSQL 16"
ARCH_PATTERN        = "Clean Architecture"
TEST_FRAMEWORK      = "xUnit"
test_coverage_min   = 80

## Equipo: ver equipo.md
## Reglas de negocio: ver reglas-negocio.md
```

---

## Paso 3 — Definir el equipo

Crea `projects/acme-tienda/equipo.md`:

```markdown
# Equipo — Acme Tienda

| Rol | Persona | Capacidad sprint | Horas/día |
|-----|---------|-----------------|-----------|
| PM / Scrum Master | Ana García | 80h | 8h |
| Tech Lead | Pedro Ruiz | 60h | 6h (2h coordinación) |
| Developer Backend | Laura Díaz | 70h | 7h |
| Developer Frontend | Marc Soler | 70h | 7h |
| QA Engineer | Sara López | 40h | 4h (media jornada) |
| Claude Agent Team | dev:agent | ilimitada | — |

Capacity total sprint (2 semanas): 320h
```

> "Savia, incorpora al equipo de acme-tienda"

En **Azure DevOps**: se mapean al Team en el Board. En **Jira**: se asignan como Members del Project. En **Savia Flow**: se crean como usuarios del company repo.

---

## Paso 4 — Documentar reglas de negocio y dominio

Crea `projects/acme-tienda/reglas-negocio.md`. Estructura recomendada:

```markdown
# Reglas de Negocio — Acme Tienda

## Dominio: Catálogo de Productos

### RN-PROD-01: SKU único
Cada producto tiene un SKU único alfanumérico (8-20 caracteres).
- Error: `DuplicateSkuException` · HTTP: 409

### RN-PROD-02: Precio > 0
El precio de venta debe ser mayor que cero.
- Error: `ValidationException` · HTTP: 400

### RN-PROD-03: Stock no negativo
El stock no puede ser negativo. Intentar vender sin stock → error.
- Error: `InsufficientStockException` · HTTP: 409

## Dominio: Carrito de Compras

### RN-CART-01: Máximo 50 líneas
Un carrito no puede tener más de 50 líneas distintas.

### RN-CART-02: Cantidad mínima 1
Cada línea del carrito debe tener cantidad ≥ 1.

### RN-CART-03: Precio se fija al añadir
El precio de un item se captura al momento de añadirlo al carrito (no cambia si el catálogo actualiza después).

## Glosario

| Término | Definición |
|---------|-----------|
| SKU | Stock Keeping Unit — identificador único de producto |
| Carrito | Colección temporal de productos antes de pagar |
| Línea | Un producto + cantidad dentro del carrito |
```

**Clave**: cada regla tiene ID (`RN-XXX-NN`), descripción, error esperado y código HTTP. Esto permite trazar requisito → spec → test.

---

## Paso 5 — Generar PBIs desde reglas de negocio

> "Savia, mapea las reglas de negocio de acme-tienda a PBIs"

Savia ejecuta `/pbi-from-rules acme-tienda` y analiza cada regla (RN-XXX-NN) para:
1. Comprobar qué reglas ya están cubiertas por PBIs existentes
2. Identificar brechas (reglas sin cobertura)
3. Proponer nuevos PBIs con trazabilidad directa regla → PBI

```
Resumen de Trazabilidad — acme-tienda

Total RNs: 6
RNs con cobertura completa: 2 (33%)   ← RN-PROD-01, RN-CART-03
RNs con cobertura parcial: 1 (17%)    ← RN-PROD-03
RNs sin cobertura: 3 (50%)            ← RN-PROD-02, RN-CART-01, RN-CART-02

PBIs propuestos: 3
  - 3 simple rules → PBIs directas (validación precio, límite carrito, cantidad mínima)
```

Savia te pregunta si crear los PBIs propuestos. Si confirmas:
- En **Azure DevOps**: los crea vía API con tags RN-XXX-NN
- En **Jira**: los sincroniza como Stories
- En **Savia Flow**: los crea como ficheros en `projects/acme-tienda/pbis/`

Para ver el reporte completo después: `/pbi-from-rules-report acme-tienda`

> **Tip:** Usa `--dry-run` para solo ver propuestas sin crear nada: `/pbi-from-rules acme-tienda --dry-run`

---

## Paso 6 — Descomponer PBIs en tasks y planificar sprint

| Azure DevOps | Jira | Savia Flow |
|-------------|------|------------|
| `/sprint-plan acme-tienda` | `/jira-sync pull` → `/sprint-plan` | `/savia-pbi create "API Catálogo" --project acme-tienda` |
| Savia descompone PBIs y sincroniza con Azure DevOps | Savia sincroniza con Jira y planifica | Todo en Git, sin herramienta externa |

**Ejemplo universal (funciona en las 3):**

> "Savia, descompone el PBI 'API de Catálogo de Productos' en tasks"

Savia ejecuta `/pbi-decompose` y genera tasks por capa:

```
PBI: API de Catálogo de Productos (5 SP)
├── 1.1 [Domain] Entidad Product + Value Object SKU (2h, human)
├── 2.1 [Application] CreateProductHandler (2h, agent)
├── 2.2 [Application] GetProductsQueryHandler (1h, agent)
├── 3.1 [Infrastructure] ProductRepository + EF Config (2h, agent)
├── 4.1 [API] ProductsController (2h, agent)
├── 4.2 [Tests] Unit tests Application (3h, agent)
└── 5.1 [Review] Code Review E1 (2h, human)
```

---

## Paso 7 — Escribir specs (SDD)

> "Savia, genera un spec para la task 2.1 CreateProductHandler"

Savia ejecuta `/spec-generate` y crea `specs/sprint-2026-05/ACM-B2-create-product-handler.spec.md`:

```markdown
# Spec: CreateProductHandler

## Requisitos
- RF-01: Crear producto con nombre, SKU, precio, stock
- RF-02: Validar RN-PROD-01 (SKU único), RN-PROD-02 (precio > 0)

## Ficheros
- CREAR: src/Application/Products/Commands/CreateProductHandler.cs
- CREAR: src/Application/Products/Commands/CreateProductRequest.cs

## Tests que deben pasar
- CreateProduct_ValidData_ReturnsProductId
- CreateProduct_DuplicateSku_Returns409
- CreateProduct_NegativePrice_Returns400

## Criterios de aceptación
- [ ] Handler recibe CreateProductRequest y devuelve ProductId
- [ ] Valida SKU único contra repositorio
- [ ] Valida precio > 0 con FluentValidation
- [ ] Guarda producto vía IProductRepository
```

---

## Paso 8 — Definir requisitos de pruebas

Savia sigue la regla: **cobertura mínima 80%**, Code Review E1 siempre humano.

**Tipos de test por capa:**

| Capa | Tipo | Quién | Ejemplo |
|------|------|-------|---------|
| Domain | Unit (entidad + domain service) | Human | `Product_InvalidSku_ThrowsException` |
| Application | Unit (handlers + validators) | Agent | `CreateProduct_DuplicateSku_Returns409` |
| Infrastructure | Integration (repo + EF) | Human | `ProductRepo_Save_PersistsToDb` |
| API | Integration (controllers) | Agent | `POST /products → 201 Created` |
| E2E | Acceptance | QA (human) | Flujo completo login→catálogo→carrito |

En el spec, la sección "Tests que deben pasar" define exactamente qué assertions se esperan. El `test-engineer` agent genera el código de test a partir del spec.

---

## Paso 9 — Implementar con Dev Session Protocol

> "Savia, analiza el spec y divide en slices"

```
/spec-slice specs/sprint-2026-05/ACM-B2-create-product-handler.spec.md
```

Luego:

```
/dev-session start specs/sprint-2026-05/ACM-B2-create-product-handler.spec.md
/dev-session next    ← implementa slice 1 (subagent), valida, persiste
/compact             ← obligatorio entre slices
/dev-session next    ← slice 2
/compact
/dev-session review  ← code review final + consensus
```

---

## Resumen: flujo completo

```
 1. /client-profile create       → Definir cliente
 2. mkdir projects/{nombre}       → Crear estructura
 3. Crear CLAUDE.md del proyecto  → Configurar constantes
 4. Crear equipo.md               → Definir team + capacidad
 5. Crear reglas-negocio.md       → Documentar dominio (RN-XXX-NN)
 6. /pbi-from-rules               → Mapear reglas → PBIs con trazabilidad
 7. /pbi-decompose                → Descomponer PBIs en tasks
 8. /spec-generate                → Generar specs SDD por task
 9. /spec-slice + /dev-session    → Implementar con contexto optimizado
10. Code Review E1 (humano)       → Aprobar
```

El paso 6 (`/pbi-from-rules`) es la pieza clave que conecta las reglas de negocio documentadas con PBIs concretos. Sin él, las reglas quedan como documentación pasiva; con él, cada regla tiene trazabilidad directa hasta su implementación.

Funciona igual en Azure DevOps, Jira o Savia Flow — cambian los comandos de sincronización, no el método.
