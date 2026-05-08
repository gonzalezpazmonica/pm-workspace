---
globs: [".claude/settings.json", ".opencode/hooks/**"]
---

# Intelligent Hooks — Prompt & Agent Hooks

> Evolución de Command hooks (1-3s) a Prompt hooks (2-5s, LLM) y Agent hooks (30-120s, subagentes).
> Fuente: aicodingpatterns.com — taxonomía de 3 tipos de hooks.

---

## Taxonomía de Hooks

| Tipo | Tiempo | Mecanismo | Ejemplo |
|---|---|---|---|
| Command | 1-3s | Script bash, determinista | validate-bash-global.sh |
| Prompt | 2-5s | LLM evalúa semánticamente | ¿El commit describe lo que cambió? |
| Agent | 30-120s | Subagente con acceso a ficheros | Security review pre-merge |

---

## Prompt Hooks

Usan un modelo rápido (Haiku) para validaciones semánticas.
No inspeccionan código — evalúan la coherencia del texto.

### Casos de uso

| Hook | Trigger | Pregunta al LLM |
|---|---|---|
| commit-semantic | Pre git commit | ¿El mensaje describe los cambios reales? |
| pr-description | Pre PR create | ¿La descripción cubre scope, testing, risks? |
| spec-coherence | Post spec write | ¿La spec es implementable sin ambigüedades? |

### Calibración gradual

1. **Fase 1 (warning)**: Hook informa pero no bloquea
2. **Fase 2 (soft-block)**: Hook bloquea con opción de override
3. **Fase 3 (hard-block)**: Hook bloquea sin override

Promover solo tras confirmar **cero falsos positivos** en fase anterior.

### Configuración

```bash
# Variables de control
PROMPT_HOOKS_ENABLED=true
PROMPT_HOOKS_MODE="warning"      # warning | soft-block | hard-block
PROMPT_HOOKS_MODEL="haiku"       # Modelo rápido para latencia baja
PROMPT_HOOKS_TIMEOUT=5            # Segundos máximo
```

---

## Agent Hooks

Usan subagentes con acceso a ficheros para verificaciones profundas.
Solo se ejecutan en eventos de alto impacto (pre-merge, pre-deploy).

### Casos de uso

| Hook | Trigger | Agente | Acción |
|---|---|---|---|
| security-scan | Pre merge | security-guardian | Scan OWASP staged files |
| dependency-check | Pre merge | test-engineer | Verify no broken deps |
| coverage-gate | Pre merge | test-runner | Verify coverage ≥ threshold |

### Restricciones

- **NUNCA** en PreToolUse (demasiado lento, crea loops)
- Solo en Stop o Pre-merge (eventos poco frecuentes)
- Timeout máximo: 120s
- Si timeout → warning, NUNCA bloquear silenciosamente

---

## Anti-Patterns

| Anti-pattern | Problema | Solución |
|---|---|---|
| Prompt hook en PreToolUse | Loop de reintentos | Solo en Stop/Pre-commit |
| Agent hook sin timeout | Bloquea sesión | Siempre timeout ≤ 120s |
| Hard-block desde el día 1 | Falsos positivos frustran | Empezar en warning |
| Hook sin logging | No se puede calibrar | Log resultado + tokens |

---

## Coste de Hooks

| Tipo | Tokens/invocación | Coste estimado |
|---|---|---|
| Command | 0 | $0 |
| Prompt (Haiku) | ~200 input + ~50 output | ~$0.0003 |
| Agent (Sonnet) | ~2000 input + ~500 output | ~$0.012 |

A 50 commits/día: Prompt ~$0.015/día, Agent ~$0.60/día.
