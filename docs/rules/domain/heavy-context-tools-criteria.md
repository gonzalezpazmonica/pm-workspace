# Regla: Heavy Context Tools Criteria — When to use ACM / HCM / Graphify

> SPEC-HEAVY-CONTEXT-CRITERIA — derivada del informe "Context vs Tokens"
> (2026-05, n=108). Las celdas `heavy` son tentativas hasta acumular
> >=10 sesiones reales con `model_tier='heavy'`.

## Principio

Los heavy context tools (**Agent Code Map**, **Human Code Map**, **Graphify**)
anaden 5-15K tokens al prompt para dar contexto estructural. Solo amortizan
ese coste (CAC) en escenarios concretos. Fuera de ellos, **baseline gana**.

## Matriz canonica

| task_scope ↓ / model_tier → | fast (Haiku) | mid (Sonnet / V3 / V4-pro) | heavy (Opus / V4-pro) |
|---|---|---|---|
| **systemic** (cross-cutting refactor, impact analysis) | neutral | **recommend** | **recommend** `(tentative, N<10)` |
| **cross-module** (touches 3+ modules) | avoid | **recommend** | **recommend** `(tentative, N<10)` |
| **single-file** (one file, <500 LOC) | avoid | avoid | neutral `(tentative, N<10)` |
| **lookup** (find symbol, read docstring) | avoid | avoid | avoid `(tentative, N<10)` |

### Definiciones de scope

- **systemic**: cambio que afecta arquitectura global, contracts, o convenciones
  cross-cutting (logging, auth, error handling).
- **cross-module**: cambio que toca 3+ modulos pero NO redefine arquitectura.
- **single-file**: edicion confinada a 1 fichero (<500 LOC).
- **lookup**: consulta de simbolo, firma, docstring (sin escritura).

### Definiciones de tier

Resolucion via `~/.savia/preferences.yaml`:

- **fast**: alias `model_fast` (latencia <2s, coste bajo).
- **mid**: alias `model_mid` (balanceado).
- **heavy**: alias `model_heavy` (deep reasoning).

## Comando de apoyo

```bash
/heavy-context-recommend <scope> <tier>
```

Devuelve `recommend | neutral | avoid` + razon de 1-2 frases. En modo
activo (prereqs cumplidos) registra la decision en
`heavy_context_invocations` con `outcome='unknown'`.

## Cuando NO usar (resumen)

- **Single-file <500 LOC**: baseline gana 2/3 segun informe (n=108).
- **Lookups simples**: usa `Read`/`Grep`; el CAC de 5-15K tokens es
  injustificado.
- **Modelos fast**: CAC no se amortiza salvo `systemic` y con mejora marginal.
- **Cache hit rate del proyecto <50%**: anadir contexto agrava el problema
  (ver `/cache-analytics`).

## Limitaciones

1. **Fila `heavy` tentativa**: Opus no fue testeado en el informe origen.
   Las celdas llevan `(tentative, N<10)` hasta acumular >=10 invocaciones
   reales con `model_tier='heavy'`.
2. **Matriz estatica**: no se recalibra automaticamente. Refinamiento
   retroactivo previsto en futura `SPEC-CONTEXT-METRICS-DASHBOARD`.
3. **`outcome='unknown'`**: las decisiones se loguean sin medir resultado.
   La correlacion con cache hit rate posterior queda fuera de esta spec.
4. **Tier resolution generica**: alias `model_fast/mid/heavy` no garantizan
   capacidades equivalentes entre proveedores; la matriz es orientativa.

## Referencias

- Spec: `docs/specs/SPEC-HEAVY-CONTEXT-CRITERIA.spec.md`
- Skills: `.opencode/skills/{agent-code-map,human-code-map,knowledge-graph}/SKILL.md`
- Comando: `.opencode/commands/heavy-context-recommend.md`
- Informe origen: "Context vs Tokens" (2026-05, n=108).
