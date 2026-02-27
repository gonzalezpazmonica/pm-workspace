# Agent Teams para SDD Paralelo

> Coordinación de múltiples agentes Claude Code trabajando en paralelo en sprints SDD.
> Feature experimental: requiere `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (ya habilitado en settings.json).

---

## Concepto

Agent Teams permite que el PM (lead) coordine múltiples desarrolladores (teammates) trabajando simultáneamente en specs SDD diferentes. Cada teammate tiene su propio contexto y trabaja en un worktree aislado.

```
PM (Lead)
├── dotnet-developer  → Spec #1234 (worktree aislado)
├── python-developer  → Spec #1235 (worktree aislado)
├── test-engineer     → Tests para Spec #1234 (worktree aislado)
└── code-reviewer     → Review de Spec completada
```

## Cuándo Usar

**Usar Agent Teams cuando:**
- 3+ specs SDD pueden implementarse en paralelo
- Las specs tocan módulos independientes (sin conflictos de ficheros)
- El sprint tiene suficiente capacity para paralelizar

**NO usar cuando:**
- Las specs tienen dependencias secuenciales
- Modifican los mismos ficheros
- Una sola spec es suficientemente compleja para ocupar toda la sesión

## Ejemplo de Uso

```
Crea un equipo de agentes para implementar estas 3 specs en paralelo:
- Spec #1234: API de autenticación (dotnet-developer)
- Spec #1235: Servicio de notificaciones (python-developer)
- Spec #1236: Dashboard de métricas (frontend-developer)
Cada uno en su worktree. Requiere plan approval antes de implementar.
```

## Flujo Recomendado

1. **PM genera specs** con `/spec-generate` para cada PBI
2. **PM revisa specs** con `/spec-review`
3. **PM crea Agent Team** asignando cada spec a un developer
4. **Developers planifican** (plan mode — requiere aprobación del PM)
5. **PM aprueba planes** y developers implementan
6. **Test engineer** ejecuta tests en cada worktree
7. **Code reviewer** revisa cada implementación
8. **PM integra** los worktrees al branch principal

## Quality Gates con Hooks

Los hooks `TeammateIdle` y `TaskCompleted` se pueden usar para asegurar calidad:

```json
{
  "hooks": {
    "TaskCompleted": [{
      "hooks": [{
        "type": "command",
        "command": ".claude/hooks/stop-quality-gate.sh"
      }]
    }]
  }
}
```

## Limitaciones Actuales

- No resume sessions con teammates in-process
- Un team por sesión
- No nested teams (teammates no pueden crear sub-teams)
- Split panes requiere tmux o iTerm2
- El lead es fijo durante toda la sesión
