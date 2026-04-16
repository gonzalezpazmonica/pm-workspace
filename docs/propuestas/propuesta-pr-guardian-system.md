# Propuesta: PR Guardian System — Validación Automatizada de Pull Requests

**Fecha:** 2026-03-03
**Prioridad:** Alta — protege la integridad del proyecto ante contribuciones externas
**Alcance:** GitHub Actions + PR Template + Branch Protection

---

## 1. Estado actual (auditoría)

### Lo que YA tenemos (y funciona bien)

| Capa | Componente | Estado |
|---|---|---|
| **CI workflow** | `ci.yml` — JSON validation, secrets scan, test suite (≥93/96), file sizes ≤150 lines, frontmatter, required files | ✅ Sólido |
| **Auto-labeling** | `auto-label-pr.yml` — Branch prefix (feature/fix/docs...) + size labels (XS→XL) | ✅ Funcional |
| **PR template** | `pull_request_template.md` — Tipo, ficheros, test, checklist | ✅ Básico pero funcional |
| **CODEOWNERS** | Todo @gonzalezpazmonica (proyecto unipersonal de momento) | ✅ Correcto |
| **Hooks locales** | `agent-hook-premerge.sh` (secrets, TODOs, conflicts, 150-line limit), `pre-commit-review.sh` (debug, secrets, any, TODOs con cache) | ✅ Fuerte |
| **Releases** | `release.yml` — Automated release notes from tags | ✅ Funcional |
| **E2E** | `savia-e2e.yml` — End-to-end testing | ✅ Funcional |

### Lo que NOS FALTA (gaps críticos para contribuciones externas)

| Gap | Riesgo | Severidad |
|---|---|---|
| **Sin ShellCheck en CI** | PRs con bugs en shell scripts (.claude/hooks/, .claude/commands/) pasan CI | 🔴 ALTO |
| **Sin validación de CLAUDE.md** | Un PR podría inflar CLAUDE.md >150 líneas destruyendo gestión de contexto | 🔴 ALTO |
| **Sin Gitleaks/TruffleHog** | El scan de secrets actual es regex básico (52-char pattern). Gitleaks detecta 700+ patterns | 🟡 MEDIO |
| **Sin Conventional Commits** | Títulos de PR caóticos, CHANGELOG difícil de generar | 🟡 MEDIO |
| **Sin validación de PR description** | PRs con descripción vacía pueden pasar | 🟡 MEDIO |
| **Sin hook timeout validation** | Un hook con timeout excesivo podría bloquear Claude Code | 🟡 MEDIO |
| **Sin Dependabot** | Dependencias de GitHub Actions desactualizadas | 🟢 BAJO |
| **Sin branch protection rules** | No hay branch protection en main configurada vía repo settings | 🟡 MEDIO |

---

## 2. Diseño: PR Guardian Workflow

Un ÚNICO workflow nuevo (`pr-guardian.yml`) que centraliza TODAS las validaciones de PR. No modifica los workflows existentes — se suma a ellos.

### Arquitectura

```
PR abierto/actualizado
    │
    ├── ci.yml (existente) → JSON, test suite, file sizes, frontmatter
    ├── auto-label-pr.yml (existente) → Labels por branch y size
    │
    └── pr-guardian.yml (NUEVO) → 8 gates de validación
         │
         ├── Gate 1: PR Description Quality
         ├── Gate 2: Conventional Commits (título)
         ├── Gate 3: CLAUDE.md Context Guard
         ├── Gate 4: ShellCheck (hooks + commands)
         ├── Gate 5: Gitleaks Secret Scanning
         ├── Gate 6: Hook Safety Validator
         ├── Gate 7: Context Impact Analysis
         └── Gate 8: Dependency Review
```

### Gate 1: PR Description Quality

Valida que la PR no tenga descripción vacía y siga el template.

**Checks:**
- Descripción no vacía (>50 caracteres excluyendo template)
- Al menos un checkbox marcado en "Type of contribution"
- Sección "How to test" no vacía

**Acción en fallo:** ❌ Bloquea PR

### Gate 2: Conventional Commits

Valida el título del PR (para squash merge) contra conventional commits.

**Format:** `type(scope): description`
- Types: feat, fix, docs, style, refactor, perf, test, chore, ci
- Scope: opcional (commands, hooks, agents, rules, skills, docs, ci)

**Acción en fallo:** ❌ Bloquea PR

### Gate 3: CLAUDE.md Context Guard

**El gate más crítico para nosotros.** Protege la gestión de contexto purista.

**Checks:**
- CLAUDE.md ≤120 líneas (nuestro límite interno, más estricto que los 150 estándar)
- No se añaden nuevas reglas `@` sin eliminar otras (balance de contexto)
- No se duplican instrucciones ya presentes en `docs/rules/`
- Ficheros en `docs/rules/domain/` ≤150 líneas
- No se añaden imports innecesarios a CLAUDE.md (cada línea cuesta tokens)

**Acción en fallo:** ❌ Bloquea PR con explicación detallada del impacto en contexto

### Gate 4: ShellCheck Diferencial

Solo analiza scripts NUEVOS o MODIFICADOS en la PR. No arrastra deuda técnica preexistente.

**Alcance:**
- `.claude/hooks/*.sh`
- `.claude/commands/*.md` (extrae bloques bash)
- `scripts/*.sh`

**Severidad:** Solo bloquea en errores (SC error level). Warnings como anotaciones.

**Acción en fallo:** ❌ Bloquea en errores, ⚠️ warnings como anotaciones

### Gate 5: Gitleaks Secret Scanning

Reemplaza el regex básico actual con detección profesional.

**Patterns:** 700+ credential patterns (AWS, Azure, GCP, GitHub, SSH, JWT, database URLs...)

**Config personalizada:** Excluir mock data y ejemplos.

**Acción en fallo:** ❌ Bloquea PR (hard block, sin excepciones)

### Gate 6: Hook Safety Validator

Previene hooks que rompan la experiencia de Claude Code.

**Checks:**
- Timeout ≤30s para hooks síncronos (evita bloqueos)
- Hooks de logging/observabilidad DEBEN ser `async: true`
- No se permite `set -e` en hooks PreToolUse (puede bloquear Claude Code involuntariamente)
- No se permite `exit 1` o `exit 2` en hooks que deberían ser warning-only
- Cada hook nuevo DEBE tener un timeout explícito en settings.json
- No se permiten hooks que hagan llamadas de red síncronas (latencia)

**Acción en fallo:** ❌ Bloquea si hook puede romper flujo, ⚠️ Warning si es solo rendimiento

### Gate 7: Context Impact Analysis

Calcula el impacto total de la PR en la ventana de contexto de Claude Code.

**Checks:**
- Conteo total de líneas añadidas a ficheros que se cargan al inicio (CLAUDE.md, rules con `@`)
- Si el PR añade >50 líneas netas a ficheros de contexto → warning
- Si el PR añade >100 líneas netas → bloqueo
- Report automático: "Esta PR añade X tokens estimados al context window de arranque"

**Acción en fallo:** ❌ Bloquea >100 líneas netas, ⚠️ Warning >50 líneas

### Gate 8: Dependency Review

Para GitHub Actions y scripts con dependencias externas.

**Checks:**
- Actions pinneadas a SHA (no `@v4`, sí `@sha256:...` o al menos `@v4.x.x`)
- No se añaden dependencias npm/pip sin justificación
- `actions/dependency-review-action` para vulnerabilidades conocidas

**Acción en fallo:** ⚠️ Warning (no bloquea, pero flag)

---

## 3. PR Template actualizado

Refuerza el template actual con secciones de contexto:

```markdown
## What does this PR add or fix?

<!-- 2-3 sentence summary. Must be >50 characters. -->

## Type of contribution

- [ ] New slash command
- [ ] New agent
- [ ] New skill
- [ ] New hook
- [ ] New domain rule
- [ ] Bug fix
- [ ] Documentation improvement
- [ ] Test suite addition
- [ ] Refactor (no behaviour change)
- [ ] Other: ___

## Context impact

- [ ] This PR does NOT modify CLAUDE.md or files loaded at startup
- [ ] This PR modifies context files — estimated impact: ___ lines added/removed
- [ ] CLAUDE.md stays within 120 lines limit

## Hook safety (if applicable)

- [ ] Hook has explicit timeout ≤30s
- [ ] Observability/logging hooks are marked `async: true`
- [ ] No `set -e` in PreToolUse hooks
- [ ] No network calls in synchronous hooks

## Files added / modified

<!-- List key files and what each one does -->

## How to test this

<!-- Step-by-step instructions for the reviewer -->

1.
2.

## Test suite

- [ ] `./scripts/test-workspace.sh --mock` passes ≥ 93/96
- [ ] `shellcheck` passes on new/modified `.sh` files
- [ ] No secrets detected by gitleaks

## Checklist

- [ ] PR title follows conventional commits: `type(scope): description`
- [ ] Command/skill name follows conventions (kebab-case)
- [ ] Tested in a real Claude Code conversation
- [ ] No PATs, org URLs, project names, or client data
- [ ] Documentation sufficient for a PM to understand without reading this PR
- [ ] `CHANGELOG.md` updated under `[Unreleased]`

## Related issues

Closes #
```

---

## 4. Branch Protection Rules (GitHub Settings)

Configurar en Settings → Branches → Add rule para `main`:

- ✅ Require pull request before merging (1 approval)
- ✅ Dismiss stale reviews when new commits pushed
- ✅ Require review from Code Owners
- ✅ Require status checks to pass:
  - `validate` (de ci.yml)
  - `pr-guardian` (de pr-guardian.yml)
  - `lint-markdown` (de ci.yml)
- ✅ Require branches to be up to date before merging
- ❌ Allow force pushes → DISABLED
- ❌ Allow deletions → DISABLED
- ✅ Include administrators (nadie salta las reglas)

---

## 5. Gitleaks config personalizada

Fichero `.gitleaks.toml` en raíz del proyecto:

```toml
[allowlist]
description = "pm-workspace allowlist"
paths = [
  '''projects/sala-reservas/test-data/.*''',
  '''docs/examples/.*''',
  '''.*mock.*''',
  '''.*placeholder.*'''
]
regexTarget = "line"
```

---

## 6. Plan de implementación

| Fase | Entregable | Prioridad | Bloquea PR |
|---|---|---|---|
| 1 | `pr-guardian.yml` con Gates 1-5 | P0 | Sí |
| 2 | Gate 6 (Hook Safety) + Gate 7 (Context Impact) | P0 | Sí |
| 3 | PR Template actualizado | P1 | No |
| 4 | `.gitleaks.toml` configuración | P1 | No |
| 5 | Gate 8 (Dependency Review) | P2 | No |
| 6 | Branch Protection Rules en GitHub | P0 | N/A |
| 7 | Dependabot para GitHub Actions | P2 | No |

**Fase 1+2 pueden implementarse en un solo PR.** Son el core del sistema.

---

## 7. Métricas de éxito

- 0 secrets detectados en PRs mergeados (objetivo: 100% detection rate)
- 0 PRs que rompan la gestión de contexto (CLAUDE.md >120 líneas)
- 0 hooks introducidos sin timeout explícito
- 100% de PRs con título conventional commits
- <5% de false positives en Gitleaks (ajustar allowlist según necesidad)
- Tiempo medio de CI para pr-guardian: <2 minutos

---

## 8. Lo que NO hacemos (y por qué)

| Descartado | Razón |
|---|---|
| **Danger.js** | Overhead de Node.js innecesario; nuestras reglas caben en bash + GitHub Script |
| **Semgrep SAST** | Overkill para un proyecto de shell scripts y markdown |
| **Actions pinneadas a SHA** | Recomendable pero bajo riesgo en proyecto público; lo añadimos como warning |
| **Auto-merge** | Nunca. Todo PR requiere revisión humana, especialmente en contexto de gestión PM |
| **Bot reviewers** | No sustituimos el juicio humano de `/pr-review` con bots automáticos |
