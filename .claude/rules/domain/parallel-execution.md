---
name: parallel-execution
context: global
---

# Regla: Ejecución paralela de agentes

Governa la ejecución simultánea de múltiples agentes durante el pipeline SDD con DAG scheduling. Define límites, aislamiento, prevención de conflictos, timeouts y recuperación.

---

## Límites de concurrencia

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| SDD_MAX_PARALLEL_AGENTS | 5 (default) | Máximo de agentes simultáneos en una cohorte |
| SDD_DEFAULT_TIMEOUT_MIN | 30 | Timeout por agente (minutos) |
| SDD_WORKER_ISOLATION | worktree | Modo de aislamiento |

---

## Aislamiento: Worktree

Cada agente ejecuta en su propia copia:
- git worktree add /tmp/worker-{uuid}
- Cambios locales NO afectan a main branch
- Si falla: worktree se descarta, sin cambios en main
- Al completar: cambios se pullan a main de forma atómica

**Beneficios:**
- Sin race conditions de I/O
- Rollback automático si falla
- Paralelo seguro sin locks

---

## Prevención de conflictos de escritura

**CRÍTICO:** Ningún fichero puede ser escrito por dos agentes en la misma cohorte.

Verificación pre-cohorte:
```
for agente in cohorte:
  ficheros_output = agente.expected_files()
for fichero in ficheros_output:
  if count(agente que escribe) > 1:
    ERROR: Conflict detected
```

Si conflicto: mover uno de los agentes a cohorte siguiente

---

## Timeout y escalada

| Escenario | Timeout | Acción |
|-----------|---------|--------|
| Agente completa antes de T | — | ✅ Continuar |
| Agente excede T | 30 min | ❌ Terminar |
| Cohorte incompleta | 30 min | ❌ DETENER |

---

## Recuperación

**Si un agente falla:**
1. Registrar error y output
2. Reintentar **UNA VEZ** con contexto fresco
3. Si reintento falla: detener cohorte
4. Reportar al humano con error, output, sugerencias

**Si cohorte falla:** DETENER pipeline

---

## Validación post-cohorte

Tras completar cohorte:
1. Verificar ficheros esperados
2. Ejecutar tests si aplica
3. Si tests fallan: investigar
4. Mergear outputs solo si validación pasa

---

## Configuración

```yaml
# En CLAUDE.md
SDD_MAX_PARALLEL_AGENTS: 5
SDD_DEFAULT_TIMEOUT_MIN: 30
SDD_WORKER_ISOLATION: worktree
SDD_RETRY_FAILED_AGENTS: 1
SDD_VALIDATE_POST_COHORTE: true
```

---

## Referencia

- Skill: .claude/skills/dag-scheduling/SKILL.md
- Comandos: /dag-plan, /dag-execute
- Ver: .claude/skills/spec-driven-development/SKILL.md
