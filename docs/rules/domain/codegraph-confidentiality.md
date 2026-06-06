---
context_tier: L2
token_budget: 538
---

# Regla: CodeGraph — Confidencialidad y gitignore obligatorio

> **REGLA INMUTABLE** — Complementa Rule #20 (PII-Free) y zero-project-leakage.md.
> Aplica a cualquier proyecto donde se active el MCP `codegraph`.

## Principio

CodeGraph genera `.codegraph/codegraph.db`, una base SQLite que contiene
símbolos, edges y (en algunos modos) snippets de código fuente extraídos
con tree-sitter. **El fichero es una proyección parseable del código del
proyecto** — si el proyecto es N4 o N4b, el índice también lo es.

## Reglas

```
SIEMPRE  → Añadir `.codegraph/` al `.gitignore` del proyecto ANTES del primer `codegraph init`
SIEMPRE  → Verificar el gitignore antes de invocar `codegraph index` en proyectos N4/N4b
NUNCA    → Commitear `.codegraph/codegraph.db` al repo público (`pm-workspace`)
NUNCA    → Compartir el `.db` por canales no cifrados (mail, Slack, etc.)
NUNCA    → Activar el MCP codegraph en scope N4b (PM-Only) — el índice mezclaría
           datos de uno-a-uno y evaluaciones con código operativo
```

## Verificación automática

El skill `agent-code-map` ejecuta antes de invocar `codegraph index`:

```bash
if [[ ! "$(cat .gitignore 2>/dev/null)" =~ \.codegraph/ ]]; then
  echo "ERROR: .codegraph/ no está gitignored — abortando"
  exit 1
fi
```

## Niveles de confidencialidad

| Nivel | Activación CodeGraph |
|---|---|
| N1 (público — pm-workspace) | Permitida, sin restricciones |
| N2 (empresa) | Permitida, `.gitignore` obligatorio |
| N3 (usuario) | Permitida, `.gitignore` obligatorio |
| N4 (proyecto cliente) | Permitida con gitignore + auditoría manual del `.db` antes de cualquier movimiento |
| N4b (PM-Only) | **PROHIBIDA** — el índice mezclaría datos sensibles |

## Auditoría

`scripts/savia-shield-status.sh` debe reportar la presencia de `.codegraph/`
en cada proyecto activo y advertir si no está en `.gitignore`.

## Referencias

- Skill `codegraph` — activación opt-in del motor.
- Skill `agent-code-map` — proyección Markdown del índice.
- Regla `docs/rules/domain/zero-project-leakage.md` (#N1).
- Regla `docs/rules/domain/data-sovereignty.md` (Savia Shield).
