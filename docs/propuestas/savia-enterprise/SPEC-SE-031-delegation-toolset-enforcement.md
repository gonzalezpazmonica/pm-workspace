---
status: PROPOSED
---

# SPEC-SE-031: Delegation Toolset Enforcement

> **Estado**: Draft
> **Prioridad**: P1 (Seguridad de agentes)
> **Dependencias**: agent-permission-levels.md (existente)
> **Era**: 231
> **Inspiración**: Hermes Agent delegation tool restricted toolsets

---

## Problema

Cuando pm-workspace delega tareas a subagentes via `Task`, cada agente
recibe acceso completo a todas las herramientas de su nivel de permisos.
No hay mecanismo para que el orquestador restrinja las herramientas
disponibles para una delegación específica.

Hermes Agent resuelve esto con un parámetro `toolsets` en cada
delegación: el padre especifica exactamente qué herramientas puede
usar el hijo. Herramientas peligrosas (delegation recursiva, memory
write, messaging) están bloqueadas por defecto en hijos.

## Solución

Hook `PreToolUse` (matcher: Agent) que valida que cada invocación de
subagente incluye restricciones de toolset apropiadas, y bloquea
herramientas peligrosas en delegaciones anidadas.

## Reglas de restricción

### Herramientas bloqueadas en subagentes (por defecto)

| Herramienta | Motivo |
|---|---|
| Agent/Task (recursivo) | Prevenir delegation bombs |
| SendMessage | Subagente no debe comunicar externamente |
| Write a auto-memory | Subagente no debe persistir sin supervisión |
| git push/merge | Decisiones irreversibles requieren humano |
| RemoteTrigger | No llamadas externas desde subagente |

### Profundidad máxima de delegación

```
Nivel 0: Conversación principal (Savia)
Nivel 1: Subagente directo (ej: dotnet-developer)
Nivel 2: PROHIBIDO — no hay nietos
```

El hook detecta si el contexto ya está en nivel 1 (variable
`SAVIA_DELEGATION_DEPTH`) y bloquea Agent/Task si depth >= 1.

## Implementación

### Hook: `.claude/hooks/delegation-guard.sh`

```
Trigger: PreToolUse (matcher: Agent)
Tier: standard (activo en standard, strict, ci)
Acción:
  1. Leer prompt del agente a invocar
  2. Verificar que no contiene instrucciones de delegación recursiva
  3. Inyectar SAVIA_DELEGATION_DEPTH=1 en el entorno del hijo
  4. Registrar delegación en trace log
Exit 2: BLOCK (delegación prohibida)
Exit 0: ALLOW
```

### Variable de entorno

```bash
# En la conversación principal
SAVIA_DELEGATION_DEPTH=0  # (default, no set)

# El hook inyecta al delegar
SAVIA_DELEGATION_DEPTH=1  # Subagente nivel 1

# Si un subagente intenta delegar con DEPTH=1 → BLOCK
```

### Validación en agent-dispatch-validate.sh

Extender el hook existente `agent-dispatch-validate.sh` para verificar:
- Si `SAVIA_DELEGATION_DEPTH >= 1` → bloquear Agent/Task en prompt
- Si el prompt del subagente contiene "delegate" o "spawn" → warn

## Tests BATS (mínimo 10)

1. Hook existe y es ejecutable
2. Delegación normal (depth 0 → 1) pasa
3. Delegación recursiva (depth 1 → 2) bloqueada
4. Subagente sin DEPTH variable pasa (backwards compatible)
5. Trace log registra cada delegación
6. Prompt con "delegate_task" en depth 1 → BLOCK
7. Prompt sin delegación en depth 1 → ALLOW
8. Variable DEPTH se propaga correctamente
9. Hook no bloquea en perfil minimal
10. Delegación con toolsets explícitos se registra en trace

## Prohibido

```
NUNCA → Permitir delegación recursiva sin límite de profundidad
NUNCA → Permitir que subagentes envíen mensajes externos
NUNCA → Permitir que subagentes persistan en auto-memory
NUNCA → Ignorar la profundidad de delegación en el trace log
```
