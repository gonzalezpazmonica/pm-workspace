---
context_tier: L2
token_budget: 700
---

# Agent Hook Protocol — SE-202

## Qué es un agent hook

Un agent hook es un hook de tipo `agent` en `settings.json` cuyo ejecutor es un
agente LLM en lugar de un script bash. Permite razonamiento semántico sobre el
tool call antes de permitirlo o bloquearlo.

Runner: `scripts/agent-hook-runner.sh`

## Cuándo usar agent hook vs bash hook

| Criterio | Bash hook | Agent hook |
|---|---|---|
| Detección léxica (regex, patrones fijos) | Si | No |
| Razonamiento semántico sobre el intent | No | Si |
| Latencia aceptable | <100ms | 5-30s |
| Eventos de alta frecuencia (Bash, Edit) | Si | No recomendado |
| Eventos de alto impacto (PreCommit, PrePush) | Complementario | Si |

Regla: limitar agent hooks a eventos de alto impacto y baja frecuencia.
Nunca en `Read` o herramientas frecuentes — la latencia es inaceptable.

## Contrato de exit codes

| Exit code | Significado | Acción del runtime |
|---|---|---|
| `0` | allow | La tool call continua |
| `2` | deny | La tool call es bloqueada |
| `1` | error inesperado | Se aplica FAIL_OPEN policy |

Nota: exit code `2` es compatible con el sistema de hooks Claude Code/OpenCode.

## Formato del evento JSON

```json
{
  "tool": "Bash",
  "tool_input": "rm -rf /var/data",
  "session_id": "abc123",
  "context": "optional extra context"
}
```

Campos requeridos: `tool` (string), `tool_input` o `input` (string o objeto).
Campos opcionales: `session_id`, `context`.

## Respuesta del agente

El agente debe devolver JSON:

```json
{
  "decision": "allow",
  "reason": "safe read operation, no destructive side effects"
}
```

Valores válidos para `decision`: `"allow"` | `"deny"`.
El runner tolera ruido narrativo — extrae el primer objeto JSON con `decision`.

## Registro de decisiones

Cada decisión se registra en `output/agent-hook-decisions.jsonl`:

```json
{
  "timestamp": "2026-06-07T10:00:00Z",
  "agent": "security-guardian",
  "tool": "Bash",
  "decision": "deny",
  "reason": "destructive rm command detected",
  "duration_ms": 2400
}
```

## Configuración: fail-open vs fail-closed

```bash
SAVIA_AGENT_HOOK_FAIL_OPEN=true   # default: allow on agent failure/timeout
SAVIA_AGENT_HOOK_FAIL_OPEN=false  # strict: deny on agent failure/timeout
SAVIA_AGENT_HOOK_TIMEOUT=30       # seconds before timeout (default: 30)
```

Recomendación: `fail_open=true` para producción (evita bloqueos por latencia).
`fail_open=false` solo en entornos con SLA de latencia del agente garantizado.

## Cómo registrar un agent hook

En `.claude/settings.json`, sección `hooks.PreToolUse` (solo eventos de alto impacto):

```jsonc
// SE-202 example agent hook (uncomment to enable):
// { "type": "agent", "agent": "security-guardian", "event": "PreToolUse", "timeout": 30 }
```

Via script runner (invocación directa desde bash hook):

```bash
bash scripts/agent-hook-runner.sh \
  --agent security-guardian \
  --event '{"tool":"Bash","tool_input":"'"$COMMAND"'"}'
```

## Naming convention para agentes de hook

Usar agentes del catálogo `.opencode/agents/`. Los más adecuados:

- `security-guardian` — detecta credenciales, comandos destructivos, OWASP
- `commit-guardian` — valida semántica de commits
- `compliance-judge` — verifica PII y nivel de confidencialidad

No crear agentes ad-hoc solo para hooks — reutilizar el catálogo existente.
