---
description: Reglas centralizadas de code review automatizado
globs:
context: on-demand
---

# Code Review Rules

Reglas para el hook de code review pre-commit y `/pr-review`. Cada proyecto puede override en `projects/{proy}/code-review-rules.md`.

---

## Reglas REJECT (bloquean)

**REJECT** hardcoded secrets — passwords, API keys, tokens, connection strings en código fuente. Excepción: ficheros `.example` o `.template`.

**REJECT** merge conflict markers — `<<<<<<<`, `=======`, `>>>>>>>` en ficheros staged.

**REJECT** debugger statements en producción — `debugger;`, `binding.pry`, `import pdb`, `breakpoint()`. Excepción: ficheros de test.

---

## Reglas REQUIRE (obligatorias)

**REQUIRE** TODOs con ticket — todo `TODO`, `FIXME`, `HACK` debe referenciar un ticket: `TODO(AB#1234)` o `TODO(@usuario)`.

**REQUIRE** tipos en TypeScript — prohibido `any` excepto en `*.d.ts` o casteos explícitos documentados con `// eslint-disable-next-line`.

**REQUIRE** error handling — funciones async deben tener try/catch o propagación explícita. No `catch {}` vacíos.

**REQUIRE** test coverage — ficheros nuevos de lógica de negocio deben tener tests correspondientes (verificado por TDD gate).

---

## Reglas PREFER (sugerencias)

**PREFER** constantes sobre magic numbers — números literales en lógica de negocio deben ser constantes con nombre.

**PREFER** early return — favorecer `if (!condition) return` sobre bloques if/else profundos.

**PREFER** readonly/const — propiedades y variables que no se reasignan deben ser `readonly` (C#), `const` (JS/TS), `final` (Java/Dart).

**PREFER** descriptive names — evitar nombres de 1-2 caracteres excepto en lambdas y loops.

---

## Configuración por proyecto

Cada proyecto puede crear `projects/{proy}/code-review-rules.md` con reglas adicionales o overrides:

```yaml
override:
  reject_debug_statements: false
  require_todos_with_ticket: true
additional:
  - "REJECT any import from deprecated-module"
```

---

## Integración

- **Pre-commit hook**: `pre-commit-review.sh` aplica reglas REJECT automáticamente
- **`/pr-review`**: aplica todas las reglas (REJECT + REQUIRE + PREFER) con diff-only mode
- **Caché**: SHA256(contenido + reglas) — invalidación automática al cambiar este fichero
