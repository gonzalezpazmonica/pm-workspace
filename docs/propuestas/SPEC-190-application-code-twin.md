---
spec_id: SPEC-190
title: "Application Code Twin — Gemelo Inteligente de Código"
status: APPROVED
tier: 1A
effort: 28-35h
era: 199
origin: user-request-2026-06-05
version_draft: 3
score_last: 96/100
blocking_deps:
  - SPEC-169 (Project Twin — establece convenciones twin: frontmatter, stale_after_days, token_budget)
  - SPEC-156 (Token Budget frontmatter — enforcement de token_budget en CTFs)
related_specs:
  - SPEC-162 (Knowledge Graph — CTFs como nodos tipados)
  - SPEC-165 (World Model — ACT como snapshot de estado de código)
  - SPEC-158 (Decide Architecture gate — feasibility_score como input)
  - SPEC-169 (Project Twin — convenciones base reutilizadas)
---

# SPEC-190 — Application Code Twin (ACT)
## Gemelo Inteligente de Código

> Estado: PROPOSED · Tier 1A · Estimación 28-35 h · Era 199
> Origen: petición directa 2026-06-05 — evolución natural de SPEC-169
> Dependencias bloqueantes: SPEC-169 (convenciones twin), SPEC-156 (token_budget)

---

## Objetivo

Representar el comportamiento completo de una aplicación software (backend +
frontend + base de datos) como una colección de archivos markdown versionados
("Code Twin Files" o CTFs), particionados por capa y módulo para carga lazy.
Un motor de simulación heurístico permite: (a) trazar flujos de datos entrada→
salida sin compilar, (b) validar specs nuevas detectando conflictos con lógica
existente, (c) servir como base de conocimiento estructurada para agentes de
arquitectura, depuración e implementación.

**Objetivo de negocio medible**: un agente cargado con el ACT implementa un
requisito de negocio en un solo intento (spec + código + PR sin retrabajo
posterior) el 80% de las veces, frente al ~40% actual sin ACT. Métrica de
referencia: AC abiertos post-PR en el primer sprint tras despliegue del ACT.

**Trade-off explícito**: el ACT es un snapshot. Puede estar desfasado respecto
al código real. `stale_after_days` + `code-twin-sync-check.sh` mitigan el
drift, pero no lo eliminan. Nunca usar el ACT como sustituto del código real
en decisiones de producción — solo como base para spec y planificación.

---

## Principios afectados

- **#3 Transparencia** — El ACT hace explícita la lógica oculta del código.
  Todo CTF es legible y versionado en git.
- **#5 Humans decide** — La simulación produce `confidence` y el header
  `[SIMULATION — NOT GROUND TRUTH]`. El humano decide si el resultado es
  suficiente para proceder. Nunca eliminar este header.
- **#9 Supervised execution** — El agente `code-twin-agent` no puede hacer
  merge ni commit directo. Genera spec; el humano aprueba.
- **#11 Context efficiency** — Lazy loading: solo se cargan los CTFs
  necesarios. El índice (CTI) garantiza que el agente nunca necesita leer
  código fuente real para orientarse.

---

## Diseño

### Visión general

```
Business Requirement
        │
        ▼
  code-twin-agent
        │  carga lazy (CTI + ≤6 CTFs, ≤12K tokens total)
        ▼
  Application Code Twin (ACT)
  ├── index.md (CTI — siempre cargado)
  ├── meta/        ← tech stack, architecture, constraints
  ├── domain/      ← entidades, VOs, reglas de negocio
  ├── application/ ← use cases, commands, queries
  ├── infrastructure/ ← DB schema, repos, seeds JSONL, external APIs
  ├── api/         ← routes, auth matrix, DTOs, error catalog
  ├── frontend/    ← component tree, store, routing, API calls
  └── cross-cutting/ ← logging, events, coverage map
        │
        ├─► code-twin-simulate.sh → trace datos sin compilar
        │                         → {result, side_effects, db_trace, confidence}
        │
        └─► code-twin-validate-spec.sh → validar spec nueva
                                       → {feasibility_score, conflicts, impact_map}
        │
        ▼
  Spec SDD (implementable, feasibility_score ≥ 80)
        │
        ▼
  PR en repo real
```

### Componentes

| Nombre | Tipo | Propósito |
|--------|------|-----------|
| `code-twin/index.md` (CTI) | Artefacto | Índice maestro lazy ≤300 tokens |
| `code-twin/{layer}/{module}.md` (CTF) | Artefacto | Un módulo/capa; ≤600 tokens |
| `infrastructure/db/seeds/{table}.jsonl` | Artefacto | 5-10 filas representativas por tabla |
| `scripts/code-twin-init.sh` | Script | Scaffold estructura vacía de ACT para un proyecto |
| `scripts/code-twin-lint.sh` | Script | Valida CTFs, CTI y seeds contra schema; exit 0/2 |
| `scripts/code-twin-simulate.sh` | Script | Motor de simulación heurístico; exit 0/1 |
| `scripts/code-twin-validate-spec.sh` | Script | Valida spec nueva contra ACT; exit 0/1 |
| `scripts/code-twin-extract.sh` | Script | Extractor AST-light: TS + C# + Python → CTFs |
| `scripts/code-twin-load.sh` | Script | Lazy loader con token budget SPEC-156 |
| `scripts/code-twin-sync-check.sh` | Script | Detecta CTFs stale; integrable como pre-commit |
| `scripts/code-twin-anonymize.sh` | Script | Genera twin anonimizado (zero-project-leakage) |
| `.opencode/agents/code-twin-agent.md` | Agente | Agente para implementar requisitos con ACT |
| `docs/rules/domain/application-code-twin.md` | Regla | Doc canónica ≤150 líneas |

### Estructura de archivos CTF

```
projects/{slug}/code-twin/
├── index.md                        # CTI ≤300 tokens (SIEMPRE cargado)
├── meta/
│   ├── tech-stack.md               # Lenguajes, frameworks, versiones, patrones
│   ├── architecture.md             # Patrón + layer map + namespace→layer mapping
│   └── dev-constraints.md          # SLAs perf, seguridad, coding standards, CI
├── domain/
│   ├── entities.md                 # Entidades: fields, tipos, invariants, relaciones
│   ├── value-objects.md            # VOs: formato, validaciones, ejemplos
│   └── business-rules.md           # Reglas de negocio como assertions programáticas
├── application/
│   ├── use-cases.md                # UC: actor, pasos numerados, excepciones, output
│   ├── commands.md                 # Commands: input → handler steps → side effects
│   └── queries.md                  # Queries: input → SQL/ORM → output shape
├── infrastructure/
│   ├── db/
│   │   ├── schema.md               # Tablas, columnas, tipos, constraints, índices
│   │   └── seeds/
│   │       └── {table}.jsonl       # 5-10 filas representativas, JSON por línea
│   ├── repos/
│   │   └── {aggregate}-repo.md     # Métodos: firma + pseudoSQL + side effects
│   ├── external/
│   │   └── {service}-client.md     # APIs externas: base_url, endpoints, auth, errores
│   └── config.md                   # Env vars, feature flags, defaults, validación
├── api/
│   ├── routes.md                   # Endpoints: METHOD /path auth guard req→res
│   ├── auth.md                     # Strategies, guards, role matrix
│   ├── dtos.md                     # DTOs: fields, tipos, reglas de validación
│   └── errors.md                   # Catálogo: code, message, HTTP status, retry-safe
├── frontend/
│   ├── components/
│   │   ├── index.md                # Árbol componentes (cargado junto con CTI)
│   │   └── {feature}.md            # Props, state, eventos, API calls, side effects
│   ├── routing.md                  # Rutas página, guards, navegación, lazy chunks
│   ├── store.md                    # State slices: shape, selectors, mutations, effects
│   └── api-contracts.md            # Mapa de llamadas API del frontend con tipos
└── cross-cutting/
    ├── logging.md                  # Log events: level, payload, PII excluidos
    ├── events.md                   # Message queue: topics, schemas, producers
    └── tests.md                    # Coverage map: módulos cubiertos, tipos de test
```

### Contratos

#### Frontmatter obligatorio por CTF

```yaml
---
module_id: AuthService           # Identificador único en el twin
layer: application               # domain|application|infrastructure|api|frontend|cross-cutting
version: 1.0.0                   # Versión semántica del módulo en código real
last_sync: 2026-06-05            # Fecha última sincronización con código real
token_budget: 580                # Tokens aproximados de este CTF (≤600; ≤800 con excepción)
depends_on:                      # module_ids de los que depende (deben existir en CTI)
  - UserRepository
  - JwtService
  - ConfigService
provides:                        # Lista de funciones/métodos públicos expuestos
  - login
  - logout
  - refresh
  - validateToken
stale_after_days: 7              # Días antes de marcar como STALE
---
```

#### Formato function entry en CTF (capa application/infrastructure)

```markdown
#### login(email: string, password: string): LoginResult

**Logic**:
1. UserRepository.findByEmail(email) → null → THROW 401 code=INVALID_CREDENTIALS msg="Invalid email or password"
2. bcrypt.compare(password, user.passwordHash) → false → THROW 401 code=INVALID_CREDENTIALS
3. JwtService.sign({sub: user.id, roles: user.roles}, {expiresIn: "7d"}) → token: string
4. UserRepository.updateLastLogin(user.id, now) → side-effect: DB WRITE
5. RETURN {token: string, user: {id: uuid, email: string, roles: string[]}}

**Side effects**:
- DB WRITE: `UPDATE users SET last_login_at = NOW() WHERE id = :user_id`
- LOG: INFO `auth.login` `{userId, email, ip}` — never log password or token

**Edge cases**:
- email not found → same 401 as password mismatch (prevent user enumeration)
- user.disabled = true → THROW 403 code=USER_DISABLED before password check
- rate_limit exceeded → THROW 429 code=TOO_MANY_REQUESTS

**DB reads**: `SELECT id, email, password_hash, roles, disabled FROM users WHERE email = :email LIMIT 1`
```

#### Ejemplo completo de CTI index.md

```markdown
---
project: proyecto-alpha
twin_version: 1.0.0
last_sync: 2026-06-05
total_modules: 14
total_token_cost: 6800
---

# Code Twin Index — proyecto-alpha

| module_id | layer | path | provides | tokens |
|---|---|---|---|---|
| AuthService | application | application/auth-service.md | login,logout,refresh,validateToken | 580 |
| UserRepository | infrastructure | infrastructure/repos/user-repo.md | findByEmail,updateLastLogin,findById | 420 |
| UserEntity | domain | domain/entities.md | - | 150 |
| POST /auth/login | api | api/routes.md | - | 80 |
| JwtService | application | application/jwt-service.md | sign,verify,decode | 340 |
| DB:users | infrastructure | infrastructure/db/schema.md | - | 200 |
| LoginDTO | api | api/dtos.md | - | 120 |
| LoginResult | api | api/dtos.md | - | 90 |
```

#### Ejemplo de seeds/users.jsonl (5 filas, todos los campos non-nullable)

```jsonl
{"id":"uuid-alice","email":"alice@test.com","password_hash":"$2b$10$abcdefghijklmnopqrstuuABCDEFGHIJKLMNOPQRSTUVWXYZ012345","roles":["user"],"disabled":false,"last_login_at":null,"created_at":"2026-01-15T10:00:00Z"}
{"id":"uuid-bob","email":"bob@test.com","password_hash":"$2b$10$zyxwvutsrqponmlkjihgfeZYXWVUTSRQPONMLKJIHGFEDCBA987654","roles":["admin","user"],"disabled":false,"last_login_at":"2026-06-01T09:30:00Z","created_at":"2026-02-20T14:00:00Z"}
{"id":"uuid-charlie","email":"charlie@test.com","password_hash":"$2b$10$mnbvcxzlkjhgfdsapoiuytMNBVCXZLKJHGFDSAPOIUYTREWQ098765","roles":["user"],"disabled":true,"last_login_at":"2026-03-10T11:00:00Z","created_at":"2026-03-01T08:00:00Z"}
{"id":"uuid-diana","email":"diana@test.com","password_hash":"$2b$10$qwertyuiopasdfghjklzxcQWERTYUIOPASDFGHJKLZXCVBNM123456","roles":["user","moderator"],"disabled":false,"last_login_at":"2026-05-30T16:45:00Z","created_at":"2026-04-10T12:00:00Z"}
{"id":"uuid-eve","email":"eve@test.com","password_hash":"$2b$10$1234567890abcdefghijkl1234567890ABCDEFGHIJKLMNOPQRSTU","roles":["user"],"disabled":false,"last_login_at":null,"created_at":"2026-06-04T17:00:00Z"}
```

> Los `password_hash` son bcrypt ficticios. Seeds nunca contienen datos reales de producción (AC-14).

#### Ejemplo de sesión end-to-end con code-twin-agent

```
USER:  "Añadir funcionalidad para que los administradores puedan
        desactivar una cuenta de usuario desde el panel de admin.
        El usuario desactivado no puede hacer login."

AGENT (paso 2-3): Carga CTI + meta/tech-stack + meta/architecture
                  → Extrae: entidades=["User"], acción="disable", capas=["domain","api","application"]

AGENT (paso 4-5): Carga CTFs → UserEntity (domain), AuthService (application),
                               UserRepository (infrastructure), POST /auth/login (api)

AGENT (paso 6):   Ejecuta code-twin-validate-spec.sh sobre borrador:
                  → borrador: POST /admin/users/{id}/disable + campo disabled en UserEntity
                  → validate output: {feasibility_score: 92, conflicts: [],
                                       impact_map: {AuthService: ["UserEntity"]}}

AGENT (paso 7):   Genera spec SDD con:
  - Objective: "endpoint POST /admin/users/{id}/disable para role=admin"
  - Design.Components: DisableUserCommand, UserRepository.disable(id), POST /admin/users/{id}/disable
  - Contracts: request={id: uuid}, response={success: boolean}, errors=[404 USER_NOT_FOUND, 403]
  - AC-1: POST /admin/users/{id}/disable con role=admin → 200 {success:true}, user.disabled=true
  - AC-2: Login de usuario disabled → 403 code=USER_DISABLED (ya cubierto en AuthService edge cases)
  - AC-3: POST /admin/users/{id}/disable con role=user → 403 FORBIDDEN
  - Impact Map: AuthService (step 1 añade check disabled), UserRepository (+method disable),
                api/routes.md (+1 endpoint), api/auth.md (+AdminGuard en nuevo endpoint)
```



```json
{
  "_meta": "[SIMULATION — NOT GROUND TRUTH] confidence=0.88",
  "result": {
    "token": "eyJ...<simulated>",
    "user": {"id": "uuid-alice", "email": "alice@test.com", "roles": ["user"]}
  },
  "side_effects": [
    {"type": "DB_WRITE", "table": "users", "op": "UPDATE last_login_at", "where": "id=uuid-alice"}
  ],
  "db_trace": [
    {"op": "READ", "table": "users", "where": "email='alice@test.com'", "rows_returned": 1},
    {"op": "WRITE", "table": "users", "field": "last_login_at", "rows_affected": 1}
  ],
  "confidence": 0.88,
  "warnings": []
}
```

#### Salida de validate-spec.sh (JSON a stdout)

```json
{
  "feasibility_score": 75,
  "conflicts": [
    {"type": "route_duplicate", "endpoint": "POST /auth/login", "existing_in": "api/routes.md:12"}
  ],
  "missing_modules": [],
  "warnings": [
    {"type": "unknown_guard", "guard": "AdminGuard", "note": "not found in api/auth.md"}
  ],
  "impact_map": {
    "AuthService": ["UserRepository", "JwtService"],
    "api/routes.md": ["LoginDTO"]
  }
}
```

### Algoritmos

#### Simulation Engine

```
FUNCTION simulate(module_id, function_name, args_json, seeds_dir):
  1. Load CTI → resolve module_id → CTF path
     → exit 1 if module_id not in index
  2. Load CTF → extract function_entry for function_name
     → exit 1 if function not in provides[]
  3. Init: result=null, side_effects=[], db_trace=[], confidence=1.0, warnings=[]
  4. FOR each step N in function_entry.Logic (numbered 1..N):
     a. If step matches "THROW {status} code={code}":
        → evaluate precondition from prior DB reads
        → if precondition met: RETURN {error:{code,status}, side_effects, db_trace, confidence}
     b. If step matches "{ModuleX}.{method}({args})":
        → if ModuleX CTF exists in index: recurse simulate(ModuleX, method, resolved_args, seeds_dir)
        → else: append WARNING "CTF missing: {ModuleX}", confidence -= 0.2
     c. If step matches "DB READ / SELECT ... WHERE ...":
        → parse table name and WHERE clause
        → scan {seeds_dir}/{table}.jsonl for matching rows (exact match on = conditions)
        → confidence -= 0.1 if WHERE has LIKE, >, <, BETWEEN
        → append to db_trace
     d. If step matches "DB WRITE / UPDATE/INSERT ...":
        → append to side_effects and db_trace
        → update in-memory seed state
     e. If step matches "RETURN {shape}":
        → populate result from RETURN type and resolved values
  5. FOR each edge_case in function_entry.Edge cases:
        → if any arg_json value matches edge_case pattern → confidence -= 0.15
  6. Prepend to stdout: "[SIMULATION — NOT GROUND TRUTH] confidence={confidence}"
  7. OUTPUT JSON: {result, side_effects, db_trace, confidence, warnings}
  8. Exit 0 if result produced, exit 1 if unresolvable
```

#### Spec Validator

```
FUNCTION validate_spec(spec_md, code_twin_dir):
  1. Parse spec_md:
     - new_entities[]: H2/H3 headings with "Entity" or names matching CamelCase near "model/entity/tabla"
     - new_endpoints[]: strings matching (GET|POST|PUT|DELETE|PATCH) /[a-z/{}]+ in AC or API sections
     - modified_entities[]: existing entity names co-occurring with "new field", "add column", "modificar"
     - new_business_rules[]: AC items containing "must", "never", "always", "prohibit", "require"
  2. conflicts = [], missing = [], warnings = []
  3. For each new_entity in new_entities:
     - grep domain/entities.md for entity name → CONFLICT {type: entity_duplicate} if found
     - extract referenced VOs → grep domain/value-objects.md → MISSING if not found
  4. For each new_endpoint in new_endpoints:
     - grep api/routes.md for METHOD + path → CONFLICT {type: route_duplicate} if found
     - extract guard name → grep api/auth.md → WARN {type: unknown_guard} if not found
  5. For each new_business_rule in new_business_rules:
     - extract subject + predicate (NLP: noun phrase + verb phrase)
     - grep business-rules.md for same subject → check if new rule negates existing
       (heuristic: "never X" vs "must X" on same subject = contradiction)
     - CONFLICT {type: rule_contradiction} if contradiction found
  6. impact_map: for each affected module_id, reverse-lookup CTI depends_on graph
  7. feasibility_score = max(0, 100 - conflicts.len*20 - missing.len*10 - warnings.len*5)
  8. OUTPUT JSON: {feasibility_score, conflicts, missing_modules, warnings, impact_map}
  9. Exit 0 if feasibility_score ≥ 70, exit 1 if < 70
```

### Configuración

| Variable/Clave | Default | Propósito |
|---|---|---|
| `CODE_TWIN_DIR` | `projects/{slug}/code-twin` | Ruta raíz del ACT |
| `CODE_TWIN_SEEDS_DIR` | `{CODE_TWIN_DIR}/infrastructure/db/seeds` | Ruta de seeds JSONL |
| `CODE_TWIN_STALE_DAYS` | (del CTF `stale_after_days`) | Días antes de STALE |
| `CODE_TWIN_MAX_LOAD` | `6` | Máx CTFs en una sesión lazy (≈12K tokens) |
| `CODE_TWIN_TOKEN_LIMIT` | `800` | Máx tokens por CTF (configurable con excepción) |
| `CODE_TWIN_CONFIDENCE_WARN` | `0.7` | Threshold bajo el que se emite WARNING |

---

## Acceptance criteria

- **AC-1**: `code-twin/index.md` contiene frontmatter con `total_modules` y `total_token_cost`; contiene tabla con columnas `module_id, layer, path, provides, tokens`; `code-twin-lint.sh --index` exit 0 para CTI válido, exit 2 si tabla falta o columna ausente; token count del archivo ≤ 300.

- **AC-2**: Cada CTF tiene frontmatter con los 8 campos obligatorios (module_id, layer, version, last_sync, token_budget, depends_on, provides, stale_after_days); `code-twin-lint.sh {file}` exit 2 si cualquier campo falta, si token_budget > 800, o si layer no es uno de los 6 valores válidos.

- **AC-3**: `bash scripts/code-twin-simulate.sh AuthService login '{"email":"alice@test.com","password":"correct"}' tests/fixtures/code-twin/seeds` con seeds que contienen usuario alice (password_hash=bcrypt("correct")) produce: (a) primera línea stdout = `[SIMULATION — NOT GROUND TRUTH] confidence=0.88`; (b) JSON con `result.token` string no vacío; (c) `db_trace` exactamente 2 operaciones (1 READ tabla users, 1 WRITE last_login_at); (d) `confidence ≥ 0.85`; (e) tiempo total < 3s.

- **AC-4**: Mismo comando con `email: "notexist@test.com"` produce: (a) primera línea `[SIMULATION — NOT GROUND TRUTH]`; (b) `error.code = "INVALID_CREDENTIALS"`; (c) `error.status = 401`; (d) `db_trace` con 1 READ y 0 WRITE; (e) `side_effects = []`.

- **AC-5**: `bash scripts/code-twin-validate-spec.sh tests/fixtures/spec-with-duplicate-route.md tests/fixtures/code-twin` produce JSON con `conflicts[0].type = "route_duplicate"` y `feasibility_score ≤ 80`; exit 1.

- **AC-6**: `bash scripts/code-twin-validate-spec.sh docs/propuestas/SPEC-169-project-twin.md projects/proyecto-alpha/code-twin` (retrospectivo, si twin piloto existe) produce `conflicts = []` y `feasibility_score ≥ 90`; tiempo < 10s.

- **AC-7**: `bash scripts/code-twin-extract.sh --lang typescript --src tests/fixtures/ts-sample --out /tmp/twin-ts` con fixture ts-sample (≥3 clases @Injectable, @Controller, @Component) produce: (a) CTFs para exactamente esas clases; (b) cada CTF con frontmatter completo; (c) layer inferido: @Injectable→application, @Controller→api, @Component→frontend; (d) ≥3 function entries por CTF.

- **AC-8**: `bash scripts/code-twin-extract.sh --lang csharp --src tests/fixtures/cs-sample --out /tmp/twin-cs` con fixture cs-sample (namespace Project.Domain, Project.Application, Project.Api) produce CTFs con layer=domain, application, api respectivamente; namespace mapping override configurable en `meta/architecture.md` bajo clave `namespace_to_layer`.

- **AC-9**: Cada `infrastructure/db/seeds/{table}.jsonl` contiene ≥ 5 líneas; cada línea es JSON válido (`jq empty` exit 0); cada línea contiene todos los campos non-nullable de `schema.md` para esa tabla; `code-twin-lint.sh --seeds {dir}` exit 0 si válido, exit 2 con mensaje indicando línea y campo faltante.

- **AC-10**: `bash scripts/code-twin-load.sh AuthService` con variable `CODE_TWIN_CONTEXT_USED` simulada a 82% del límite SPEC-156 emite a stderr exactamente `[WARN] token budget 82% — loading CTF summary mode` y carga solo frontmatter + function signatures del CTF (sin bloques **Logic**), reduciendo tokens en ≥ 50%.

- **AC-11**: `bash scripts/code-twin-validate-spec.sh tests/fixtures/spec-get-user-profile.md tests/fixtures/code-twin` sobre fixture spec-get-user-profile.md (spec válido con 1 nuevo endpoint GET /users/{id}/profile, 1 nuevo DTO, sin conflictos) produce `feasibility_score ≥ 85` y `conflicts = []`; fixture spec se incluye en `tests/fixtures/`. Test BATS aserta `feasibility_score` extraído via `jq`.

- **AC-12**: `bash scripts/code-twin-sync-check.sh projects/{slug}/code-twin` lista todos los CTFs con `last_sync` anterior a `(today - stale_after_days)`; exit 0 si 0 stale, exit 1 si ≥ 1 stale con lista en stdout; `-q` flag suprime output pero mantiene exit code.

- **AC-13**: Twin piloto del proyecto real tiene ≥ 8 CTFs: index.md + meta/tech-stack.md + domain/entities.md + api/routes.md + infrastructure/db/schema.md + ≥ 3 seeds/{table}.jsonl; todos pasan `code-twin-lint.sh`; `total_token_cost` en CTI ≤ 8000.

- **AC-14**: `bash scripts/code-twin-anonymize.sh projects/{slug}/code-twin /tmp/anon-twin` produce directorio con CTFs donde: (a) ningún `module_id` contiene nombre real del proyecto (regex de exclusión en `.claude/rules/twin-anon-projects.local.txt`); (b) rutas absolutas reemplazadas por `{project_path}`; (c) todos los CTFs anonimizados pasan `code-twin-lint.sh`.

- **AC-V1**: Sobre el twin piloto real, `code-twin-simulate.sh {module} {function} {sample_input}` produce output con `confidence ≥ 0.7`; el JSON de output se guarda en `output/code-twin-pilot-sim-result.json` y se adjunta al PR como evidencia; diff entre `result` simulado y comportamiento documentado en la spec del proyecto tiene ≤ 2 discrepancias documentadas.

- **AC-V2**: `code-twin-validate-spec.sh docs/propuestas/SPEC-169-project-twin.md projects/{piloto}/code-twin` produce `feasibility_score ≥ 90` y `conflicts = []`; resultado guardado en `output/code-twin-retro-spec169.json` adjunto al PR.

---

## Estimación por slice

| # | Slice | Descripción | Horas | Buffer |
|---|-------|-------------|-------|--------|
| 1 | Schema + lint | CTF schema, CTI format, `code-twin-lint.sh`, `code-twin-init.sh`, doc canónica | 3h | +0.5h |
| 2 | Domain + Application CTFs | Templates + function entry format para domain/entities, application/use-cases, commands, queries | 2h | +0.5h |
| 3 | Infrastructure CTFs | DB schema.md, seeds JSONL validator, repos CTF, external-client, config formats | 3h | +0.5h |
| 4 | API + Frontend CTFs | routes, auth, dtos, errors; components/index, store, routing, api-contracts | 3h | +0.5h |
| 5 | Simulation engine | `code-twin-simulate.sh` Python: parser Logic, DB seed resolver, tracer, confidence | 5h | +1h |
| 6 | Spec validator | `code-twin-validate-spec.sh` Python: NLP extractor, conflict detector, feasibility | 4h | +1h |
| 7 | Extractor AST-light | `code-twin-extract.sh`: TypeScript (ts-morph), C# (Roslyn/dotnet-script), Python (ast) | 5h | +2h |
| 8 | Lazy loader + agente | `code-twin-load.sh`, `code-twin-sync-check.sh`, agente `.opencode/agents/code-twin-agent.md` | 2h | +0.5h |
| 9 | Piloto real + BATS | Twin completo sobre proyecto real; 5 suites BATS; AC-V1 + AC-V2 | 5h | +1h |

**Total estimado**: 32h + 7.5h buffer = **39.5h techo**; rango publicado 28-35h (p50).

> Buffer explícito en Slice 7: el extractor AST-light para 3 lenguajes tiene riesgo alto de subestimación. Si supera 7h, se reduce alcance a 2 lenguajes (TS + C#) y Python se difiere a v2.

---

## Dependencias

### Bloqueantes
| Spec/Tool | Razón |
|---|---|
| **SPEC-169** | Convenciones twin: frontmatter, `stale_after_days`, `token_budget`, `twin-linter.sh` patterns. ACT hereda sin reimplementar. |
| **SPEC-156** | `token_budget` enforcement en loader (AC-10). Sin SPEC-156, el loader no puede aplicar el cap. |

### Suaves (no bloqueantes; integración opcional)
| Spec | Integración |
|---|---|
| **SPEC-162** (Knowledge Graph) | CTFs registrables como nodos con relaciones `depends_on` y `provides`. |
| **SPEC-165** (World Model) | ACT como snapshot de estado de código; World Model consume CTFs para razonamiento cross-spec. |
| **SPEC-158** (Architecture gate) | `feasibility_score` del spec validator puede alimentar el gate `/decide-architecture`. |

### Herramientas externas (Slice 7 — solo extractor)
| Herramienta | Versión mínima | Licencia | Uso |
|---|---|---|---|
| **ts-morph** (npm) | v21.0 | MIT | AST TypeScript/JavaScript |
| **dotnet-script** (nuget) | v1.5 | Apache-2 | Roslyn C# analysis. Alternativa: `dotnet` CLI + NuGet Roslyn API |
| **python ast** | Python stdlib 3.9+ | PSF | AST Python. Sin deps externas. |
| **jq** | v1.6+ | MIT | Parsing JSON en BATS tests + extracción de campos en AC-11 y AC-V2 (ya presente en workspace) |

---

## Riesgos

| # | Riesgo | Severidad | Mitigación |
|---|--------|-----------|-----------|
| 1 | Drift CTF ↔ código real | Alta | `stale_after_days` + `code-twin-sync-check.sh` pre-commit opcional + extractor incremental (solo módulos modificados vía `git diff`) |
| 2 | Simulation usada como ground truth — confidence inflado genera falsa seguridad | Alta | Header `[SIMULATION — NOT GROUND TRUTH]` obligatorio en toda salida; AC-3 aserta este header; `confidence` nunca llega a 1.0 en el algoritmo; AC threshold: confidence < 0.7 bloquea uso en spec automático |
| 3 | Extractor AST-light genera CTFs incompletos o incorrectos | Alta | CTFs de extractor marcados `status: DRAFT`; `code-twin-lint.sh` rechaza DRAFT en validaciones de producción; humano aprueba → STABLE antes de usar en agente |
| 4 | Spec validator falsos positivos (conflictos inexistentes por NLP débil) | Media | Flag `--lenient` reduce umbral de conflicto; output incluye razón textual del conflicto; el humano tiene última palabra; rate de FP documentado en BATS como regression test |
| 5 | CTF sobrepasa token_budget (módulos complejos) | Media | Linter exit 2 si > 800 tokens; extractor parte módulos > 600 tokens en `{module}-part1.md`, `{module}-part2.md` con cross-reference en frontmatter |
| 6 | Exposición de lógica propietaria en CTF público | Media | `code-twin-anonymize.sh` obligatorio antes de publicar; seeds nunca contienen datos reales de producción; AC-14 valida anonimización |

---

## Verificación

```bash
bats tests/test-spec-190-code-twin-lint.bats        # AC-1, AC-2, AC-9, AC-12, AC-13, AC-14
bats tests/test-spec-190-code-twin-simulate.bats    # AC-3, AC-4, AC-10
bats tests/test-spec-190-code-twin-validate.bats    # AC-5, AC-6, AC-11, AC-V2
bats tests/test-spec-190-code-twin-extract.bats     # AC-7, AC-8
bats tests/test-spec-190-code-twin-pilot.bats       # AC-13, AC-V1, AC-V2
```

Score target: 97/100 en `python3 scripts/test-auditor-engine.py tests/test-spec-190-*.bats`.

---

## Agente code-twin-agent

### Flujo de 7 pasos

```
1. RECEIVE: requisito de negocio en lenguaje natural + project_slug
2. LOAD: CTI (index.md) + meta/tech-stack.md + meta/architecture.md [≤650 tokens total]
3. EXTRACT: del requisito → entidades mencionadas, verbos de acción, capas afectadas
4. RESOLVE: CTI lookup por provides[] y module_id → lista CTFs candidatos (máx 6)
5. LOAD LAZY: CTFs relevantes en orden domain→application→api→frontend [≤600 tok cada uno]
6. VALIDATE: generar propuesta preliminary → ejecutar code-twin-validate-spec.sh
   - feasibility_score ≥ 80: continuar a paso 7
   - feasibility_score < 80: analizar conflicts → ajustar propuesta → retry (máx 3 veces)
   - Si tras 3 retries < 80: escalar a humano con impact_map
7. GENERATE: spec SDD completo con secciones Objective, Design.Components, Contracts,
             AC (≥5 verificables), Slices (con horas), Impact Map del twin
```

### System prompt template

```
You are code-twin-agent for project {project_slug}.
Your knowledge base is the Application Code Twin (ACT) at:
  {code_twin_dir}

Loaded context:
  CTI index: {cti_summary}  (total_modules={n}, total_tokens={t})
  Loaded CTFs: {loaded_ctf_list}

Rules:
1. Never read real source code files directly. Use only CTFs.
2. Before generating a spec, run: code-twin-validate-spec.sh <your_draft> {code_twin_dir}
3. Do not proceed with spec if feasibility_score < 80 (max 3 retries).
4. Never assert confidence > 0.9 from simulation output.
5. Every spec you generate must include an "Impact Map" section referencing affected CTFs.
6. Simulation output starts with [SIMULATION — NOT GROUND TRUTH]. Never omit this.

Available tools:
  code-twin-load.sh {module_id}        → load a specific CTF
  code-twin-simulate.sh {m} {f} {args} → simulate function call
  code-twin-validate-spec.sh {spec}    → validate your spec draft
```

---

## OpenCode Implementation Plan

### Clasificación
- **Type**: Infraestructura de ingeniería — base de conocimiento para agentes
- **Autonomy**: L3 (agentes implementan slices individuales; humano revisa PR por slice)
- **Reversibility**: Alta (CTFs son texto puro en `projects/{slug}/code-twin/`, eliminables sin efecto en código real)

### Agent assignments por slice

| Slice | Agente | Herramientas principales |
|-------|--------|--------------------------|
| 1 | `python-developer` | Bash (lint script), Write (schema doc, init scaffold) |
| 2-4 | `python-developer` | Write (CTF templates), Read (specs existentes) |
| 5 | `python-developer` | Python (simulate.sh), Write (BATS fixtures), Bash |
| 6 | `python-developer` | Python (validate-spec.sh), Write (BATS fixtures) |
| 7 | `typescript-developer` + `python-developer` | Bash (ts-morph CLI), Python (ast), Write (BATS fixtures) |
| 8 | `python-developer` | Write (agente .md, loader script), Bash |
| 9 | `test-architect` + `python-developer` | Bash (BATS suites), Read (proyecto real), Write (CTFs piloto) |

### Gate de calidad por slice
Cada slice tiene PR propio. Gate mínimo: BATS del slice ≥ 80/100 en `test-auditor-engine.py`.
Slices 5 y 6 requieren score ≥ 85/100 (mayor riesgo de regresión).

---

## Out of scope permanente

- Compilación o ejecución real de código
- Generación automática de tests desde CTF (futuro SPEC-195)
- Twin de infraestructura cloud: VMs, containers, DNS (SPEC diferente)
- Twin de personas/equipos (prohibido — SPEC-169 principio)
- Sync en tiempo real (CTF es snapshot versionado, no live)
- Análisis RBAC/seguridad desde CTF (futuro, después de validar piloto)
- Lenguajes distintos a TypeScript, C# y Python en el extractor v1
- Frontend frameworks distintos a Angular/React en el extractor v1

---

## Referencias

- `docs/propuestas/SPEC-169-project-twin.md` — convenciones twin (reutilizadas)
- `docs/propuestas/SPEC-156-token-budget-frontmatter.md` — token_budget enforcement
- `docs/propuestas/SPEC-162-self-evolving-tools-research.md` — Knowledge Graph nodos
- `docs/propuestas/SPEC-165-world-model-simulation.md` — World Model integration
- `docs/rules/domain/project-twin-as-code.md` — regla canónica SPEC-169
- `docs/rules/domain/zero-project-leakage.md` — privacidad CTFs
- `scripts/twin-linter.sh` — linter base (patrones reutilizables en code-twin-lint.sh)
- `.opencode/skills/ast-comprehension/SKILL.md` — AST skills disponibles
- `docs/rules/domain/context-placement-confirmation.md` — niveles N1-N4b
- `docs/rules/domain/spec-opencode-implementation-plan.md` — sección OpenCode Plan obligatoria
