# Guide: Start a project from scratch with Savia

> For PMs who want to configure a complete project: client, team, architecture, business rules, specs and tests. Applies to Azure DevOps, Jira or Savia Flow.

---

## Step 1 — Define the client

> "Savia, create a client profile for Acme Corp"

Savia executes `/client-profile create` and asks for basic information. It is stored in SaviaHub:

```
clients/acme-corp/
├── profile.md      ← Name, industry, size, primary contact
├── contacts.md     ← Key client people (PO, sponsor, IT)
├── rules.md        ← Client rules (schedules, compliance, restrictions)
└── projects/       ← Projects associated with this client
```

**Example of `profile.md`:**

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

## Step 2 — Create the project

```bash
mkdir -p projects/acme-tienda/specs projects/acme-tienda/sprints
```

Create `projects/acme-tienda/CLAUDE.md` — it is the central file. Adapt it to the PM tool:

| Section | Azure DevOps | Jira | Savia Flow |
|---------|-------------|------|------------|
| Identity | `PROJECT_AZDO_NAME = "AcmeTienda"` | `JIRA_PROJECT_KEY = "ACM"` | `PROJECT_NAME = "acme-tienda"` |
| Sprint | `ITERATION_PATH_ROOT = "AcmeTienda\\Sprints"` | `JIRA_BOARD_ID = "42"` | `/savia-sprint start` |
| Repo | `REPO_URL = "https://dev.azure.com/..."` | `REPO_URL = "https://github.com/..."` | Same Git repo |

**Minimal example of project CLAUDE.md:**

```
# Acme Tienda — E-commerce Backend

## CONSTANTS
PROJECT_NAME        = "acme-tienda"
SPRINT_ACTUAL       = "Sprint 2026-05"
SPRINT_GOAL         = "API de catálogo + carrito de compras"

## Stack
BACKEND             = ".NET 8 / ASP.NET Core"
DATABASE            = "PostgreSQL 16"
ARCH_PATTERN        = "Clean Architecture"
TEST_FRAMEWORK      = "xUnit"
test_coverage_min   = 80

## Team: see equipo.md
## Business rules: see reglas-negocio.md
```

---

## Step 3 — Define the team

Create `projects/acme-tienda/equipo.md`:

```markdown
# Team — Acme Tienda

| Role | Person | Sprint Capacity | Hours/day |
|-----|---------|-----------------|-----------|
| PM / Scrum Master | Ana García | 80h | 8h |
| Tech Lead | Pedro Ruiz | 60h | 6h (2h coordination) |
| Backend Developer | Laura Díaz | 70h | 7h |
| Frontend Developer | Marc Soler | 70h | 7h |
| QA Engineer | Sara López | 40h | 4h (part-time) |
| Claude Agent Team | dev:agent | unlimited | — |

Total sprint capacity (2 weeks): 320h
```

> "Savia, add the acme-tienda team"

In **Azure DevOps**: they are mapped to the Team on the Board. In **Jira**: they are assigned as Project Members. In **Savia Flow**: they are created as company repo users.

---

## Step 4 — Document business rules and domain

Create `projects/acme-tienda/reglas-negocio.md`. Recommended structure:

```markdown
# Business Rules — Acme Tienda

## Domain: Product Catalog

### RN-PROD-01: Unique SKU
Each product has a unique alphanumeric SKU (8-20 characters).
- Error: `DuplicateSkuException` · HTTP: 409

### RN-PROD-02: Price > 0
The selling price must be greater than zero.
- Error: `ValidationException` · HTTP: 400

### RN-PROD-03: Non-negative stock
Stock cannot be negative. Attempting to sell without stock → error.
- Error: `InsufficientStockException` · HTTP: 409

## Domain: Shopping Cart

### RN-CART-01: Maximum 50 lines
A cart cannot have more than 50 different lines.

### RN-CART-02: Minimum quantity 1
Each cart line must have quantity ≥ 1.

### RN-CART-03: Price fixed when added
An item's price is captured at the moment it is added to the cart (does not change if the catalog is updated later).

## Glossary

| Term | Definition |
|------|-----------|
| SKU | Stock Keeping Unit — unique product identifier |
| Cart | Temporary collection of products before payment |
| Line | A product + quantity within the cart |
```

**Key**: each rule has ID (`RN-XXX-NN`), description, expected error and HTTP code. This allows tracing requirement → spec → test.

---

## Step 5 — Create PBIs and plan sprint

| Azure DevOps | Jira | Savia Flow |
|-------------|------|------------|
| `/sprint-plan acme-tienda` | `/jira-sync pull` → `/sprint-plan` | `/savia-pbi create "API Catálogo" --project acme-tienda` |
| Savia decomposes PBIs and syncs with Azure DevOps | Savia syncs with Jira and plans | Everything in Git, no external tool |

**Universal example (works in all 3):**

> "Savia, decompose the PBI 'Product Catalog API' into tasks"

Savia executes `/pbi-decompose` and generates tasks by layer:

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

## Step 6 — Write specs (SDD)

> "Savia, generate a spec for task 2.1 CreateProductHandler"

Savia executes `/spec-generate` and creates `specs/sprint-2026-05/ACM-B2-create-product-handler.spec.md`:

```markdown
# Spec: CreateProductHandler

## Requirements
- RF-01: Create product with name, SKU, price, stock
- RF-02: Validate RN-PROD-01 (unique SKU), RN-PROD-02 (price > 0)

## Files
- CREATE: src/Application/Products/Commands/CreateProductHandler.cs
- CREATE: src/Application/Products/Commands/CreateProductRequest.cs

## Tests that must pass
- CreateProduct_ValidData_ReturnsProductId
- CreateProduct_DuplicateSku_Returns409
- CreateProduct_NegativePrice_Returns400

## Acceptance criteria
- [ ] Handler receives CreateProductRequest and returns ProductId
- [ ] Validates unique SKU against repository
- [ ] Validates price > 0 with FluentValidation
- [ ] Saves product via IProductRepository
```

---

## Step 7 — Define testing requirements

Savia follows the rule: **minimum 80% coverage**, Code Review E1 always human.

**Test types by layer:**

| Layer | Type | Who | Example |
|------|------|-------|---------|
| Domain | Unit (entity + domain service) | Human | `Product_InvalidSku_ThrowsException` |
| Application | Unit (handlers + validators) | Agent | `CreateProduct_DuplicateSku_Returns409` |
| Infrastructure | Integration (repo + EF) | Human | `ProductRepo_Save_PersistsToDb` |
| API | Integration (controllers) | Agent | `POST /products → 201 Created` |
| E2E | Acceptance | QA (human) | Complete flow login→catalog→cart |

In the spec, the "Tests that must pass" section defines exactly what assertions are expected. The `test-engineer` agent generates the test code from the spec.

---

## Step 8 — Implement with Dev Session Protocol

> "Savia, analyze the spec and divide into slices"

```
/spec-slice specs/sprint-2026-05/ACM-B2-create-product-handler.spec.md
```

Then:

```
/dev-session start specs/sprint-2026-05/ACM-B2-create-product-handler.spec.md
/dev-session next    ← implements slice 1 (subagent), validates, persists
/compact             ← mandatory between slices
/dev-session next    ← slice 2
/compact
/dev-session review  ← final code review + consensus
```

---

## Summary: complete flow

```
1. /client-profile create       → Define client
2. mkdir projects/{nombre}       → Create structure
3. Create project CLAUDE.md      → Configure constants
4. Create equipo.md              → Define team + capacity
5. Create reglas-negocio.md      → Document domain (RN-XXX-NN)
6. /pbi-decompose                → Decompose PBIs into tasks
7. /spec-generate                → Generate SDD specs per task
8. /spec-slice + /dev-session    → Implement with optimized context
9. Code Review E1 (human)        → Approve
```

Works the same in Azure DevOps, Jira or Savia Flow — the sync commands change, not the method.
