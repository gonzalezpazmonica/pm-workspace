---
context_tier: L2
token_budget: 902
---

# Application Code Twin (ACT)
Spec: SPEC-190 — Gemelo markdown del código fuente. Lee bajo demanda. No sustituye al código — snapshot interpretativo para razonamiento de agentes.

## Definición

**ACT** = conjunto versionado de archivos markdown en `projects/{slug}/code-twin/` que describe la arquitectura viva de un proyecto: entidades, lógica, contratos API, DB schema y constraints de infraestructura.

## Componentes

| Artefacto | Descripción | Límite |
|-----------|-------------|--------|
| `code-twin/index.md` (CTI) | Índice maestro lazy-loading | ≤300 tokens |
| `code-twin/{layer}/{module}.md` (CTF) | Un módulo; Logic + Side effects + Edge cases | ≤600 tokens |
| `infrastructure/db/seeds/{table}.jsonl` | 5-10 filas representativas por tabla | ≥5 líneas |

## Layers válidos

`domain` · `application` · `infrastructure` · `api` · `frontend` · `cross-cutting`

## CTF frontmatter (8 campos obligatorios)

```yaml
module_id: AuthService
layer: application
version: "1.0.0"
last_sync: "2026-06-01T14:30:00Z"
token_budget: 600          # max 800
stale_after_days: 14
depends_on:
  - UserRepository
provides:
  - login
```

`status: STABLE` o `status: DRAFT`. DRAFT rechazado en lint de producción.

## CTI frontmatter (2 campos obligatorios)

```yaml
total_modules: 8
total_token_cost: 1980
last_full_sync: "2026-06-01T14:30:00Z"
```
Tabla requerida: `| module_id | layer | path | provides | tokens |`

## DB Seeds schema.md format

```markdown
## Table: users
| column | type | nullable |
|--------|------|----------|
| id | uuid | false |
| email | varchar | false |
| last_login_at | timestamp | true |
```

## Function entry format (CTF de capa application/infrastructure)

```markdown
#### login(email: string, password: string): LoginResult

**Logic**:
1. UserRepository.findByEmail(email) → null → THROW 401 INVALID_CREDENTIALS
2. bcrypt.compare(password, user.passwordHash) → false → THROW 401
3. JwtService.sign({sub: user.id}) → token: string

**Side effects**: DB WRITE users.last_login_at

**Edge cases**: disabled=true → THROW 403 USER_DISABLED
```

## Scripts

| Script | Propósito |
|--------|-----------|
| `code-twin-lint.sh` | Valida CTF/CTI/seeds: exit 0/2 |
| `code-twin-init.sh` | Scaffold `code-twin/` vacío |
| `code-twin-extract.sh` | Extractor AST-light: TS/C#/Python → CTF DRAFT |
| `code-twin-simulate.sh` | Simulación heurística con seeds; header NOT GROUND TRUTH |
| `code-twin-validate-spec.sh` | Valida spec nueva contra ACT; feasibility_score |
| `code-twin-load.sh` | Lazy loader con token budget SPEC-156 |
| `code-twin-sync-check.sh` | Detecta CTFs stale; exit 0/1 |
| `code-twin-anonymize.sh` | Anonimiza ACT antes de publicar |

## Reglas operativas

1. CTI siempre cargado; CTFs bajo demanda (lazy load).
2. `confidence` en simulate nunca llega a 1.0; toda salida de simulate lleva header `[SIMULATION — NOT GROUND TRUTH]`.
3. CTFs generados por extractor tienen `status: DRAFT` y NO pasan lint en producción. El humano revisa → cambia a STABLE.
4. `token_budget` hard-cap 800 por CTF; cap global via SPEC-156 enforcement.
5. Seeds nunca contienen datos reales de producción.
6. Usar `code-twin-anonymize.sh` antes de publicar cualquier ACT.

## Lint rápido

```bash
bash scripts/code-twin-lint.sh <ctf.md>
bash scripts/code-twin-lint.sh --index code-twin/index.md
bash scripts/code-twin-lint.sh --seeds code-twin/infrastructure/db/seeds
```

## Refs

- SPEC-190: `docs/propuestas/SPEC-190-application-code-twin.md`
- SPEC-169: Project Twin (convenciones base)
- SPEC-156: Token Budget frontmatter enforcement
