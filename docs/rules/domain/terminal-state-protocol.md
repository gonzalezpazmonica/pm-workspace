---
context_tier: L2
token_budget: 680
spec: SPEC-TERMINAL-STATE-HANDOFF
---

# Terminal State Protocol

> Protocolo de handoff de estado final entre agentes/loops y el orquestador.
> Sin este protocolo el orquestador no puede distinguir un fin limpio de un crash
> y aplica políticas de reintento ciegas — coste: trabajo duplicado o silencio
> ante errores que requieren escalamiento humano.

## Enum de estados de terminación

```
termination_reason:
  completed           — tarea completada, DoD verificado
  user_abort          — usuario canceló explícitamente
  token_budget        — se agotó el presupuesto de tokens
  stop_hook           — hook de stop bloqueó la ejecución
  max_turns           — se alcanzó el límite de turnos configurado
  unrecoverable_error — error interno irrecuperable (crash, OOM)
```

## Definición de cada estado

### `completed`
La tarea terminó satisfactoriamente y los criterios de DoD (Definition of Done)
fueron verificados por el propio agente o por un juez.

- **Política de reintento**: no reintentar.
- **Acción del orquestador**: marcar loop como `DONE`, archivar artefactos.
- **Ejemplo**: `"3/3 tasks done, all tests green, PR created"`

### `user_abort`
El usuario interrumpió la ejecución explícitamente (Ctrl+C, signal SIGTERM
tramitado, o flag `--abort` pasado al loop).

- **Política de reintento**: no reintentar sin nueva instrucción explícita.
- **Acción del orquestador**: preservar estado parcial, notificar usuario.
- **Ejemplo**: `"SIGTERM received at task 2/5"`

### `token_budget`
El agente detectó que el presupuesto de tokens del modelo se agotó antes de
completar la tarea. El trabajo puede estar parcialmente hecho.

- **Política de reintento**: escalar modelo (haiku → sonnet → opus), reintentar
  con checkpoint del estado parcial si existe.
- **Acción del orquestador**: leer checkpoint, relanzar con modelo superior.
- **Ejemplo**: `"Context window at 95%, task 4/7 incomplete"`

### `stop_hook`
Un hook de stop (`PostToolUse`, `Stop`) bloqueó la ejecución antes de que el
agente terminara. Puede indicar violación de policy (seguridad, autonomy gate).

- **Política de reintento**: NO reintentar automáticamente.
- **Acción del orquestador**: identificar qué hook disparó, escalar a humano.
- **Ejemplo**: `"sycophancy-strip.sh blocked output at turn 8"`

### `max_turns`
El loop alcanzó el límite de turnos configurado (`AGENT_MAX_TURNS` o `--max-turns`)
sin completar la tarea.

- **Política de reintento**: si `retry_count < 3` reintentar con contexto comprimido;
  si `retry_count >= 3` escalar a humano.
- **Acción del orquestador**: leer `retry_count` del historial jsonl antes de decidir.
- **Ejemplo**: `"Reached max_turns=50, 5/8 tasks complete"`

### `unrecoverable_error`
Error interno que impide continuar: OOM, crash del proceso, corrupción de estado,
fallo irrecuperable de herramienta esencial.

- **Política de reintento**: NO reintentar automáticamente.
- **Acción del orquestador**: escalar a humano inmediatamente, adjuntar logs.
- **Ejemplo**: `"OOM at turn 12, process killed"`

## Almacenamiento

Cada emisión se apenda a:
```
output/loop-state/<loop>/terminal-state.jsonl
```

El orquestador lee siempre la **última línea** del fichero — permite auditar el
historial completo de ejecuciones del mismo loop.

## Herramientas

| Script | Rol |
|---|---|
| `scripts/terminal-state-emit.sh` | El agente emite su estado al terminar |
| `scripts/terminal-state-read.sh` | El orquestador lee el último estado y obtiene exit code |

## Exit code mapping

| reason | exit code |
|---|---|
| `completed` | 0 |
| `user_abort` | 0 |
| `token_budget` | 2 |
| `stop_hook` | 3 |
| `max_turns` | 4 |
| `unrecoverable_error` | 5 |
| razón desconocida | 1 |

## Integración con autonomous-safety.md

Este protocolo complementa `docs/rules/domain/autonomous-safety.md`:
- `AGENT_MAX_CONSECUTIVE_FAILURES` sigue siendo el gate de abort en caliente.
- `terminal-state-emit.sh` debe llamarse en el bloque `trap EXIT` del loop,
  garantizando emisión incluso ante señales.
- El estado `unrecoverable_error` activa siempre escalamiento humano,
  independientemente de `AGENT_MAX_CONSECUTIVE_FAILURES`.
