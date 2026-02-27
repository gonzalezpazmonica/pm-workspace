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

## Regla de Serialización de Scope

**ANTES de lanzar Agent Teams**, el PM DEBE verificar que los scopes no se solapan:

1. Para cada spec asignada, leer la sección "Ficheros a Crear/Modificar"
2. Generar la lista completa de ficheros que cada spec tocará
3. Si dos o más specs tocan los mismos ficheros → **serializar** (una después de otra) o asignar al mismo agente
4. Si los scopes son disjuntos → proceder con paralelo

```
# Ejemplo de verificación:
Spec #1234 → src/Auth/LoginHandler.cs, src/Auth/TokenService.cs
Spec #1235 → src/Notifications/EmailService.cs, src/Notifications/SmsService.cs
Spec #1236 → src/Auth/LoginHandler.cs, src/Dashboard/MetricsController.cs
                   ^^^^^^^^^^^^^^^^^^^^
# Conflicto: Spec #1234 y #1236 tocan LoginHandler.cs → SERIALIZAR
# Spec #1235 es independiente → puede ir en paralelo con cualquiera
```

**Riesgo**: Sin esta verificación, dos agentes pueden modificar el mismo fichero en worktrees separados. Ambos cambios serán internamente coherentes pero mutuamente contradictorios. El merge será limpio (sin conflictos git) pero el comportamiento será incorrecto.

El hook `scope-guard.sh` (Stop) detecta ficheros modificados fuera del scope de la spec, proporcionando una segunda línea de defensa.

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
