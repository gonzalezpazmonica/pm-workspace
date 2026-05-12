---
name: workload-balance
description: Equilibrado objetivo de carga de trabajo respetando especialidades del equipo
developer_type: all
agent: task
context_cost: medium
---

# /workload-balance — Equilibrado de Carga Objetiva

Detecta desequilibrios de carga y propone redistribuciones respetando especialidades, skills y preferencias de cada miembro.

## Sintaxis

```bash
/workload-balance [--show] [--suggest] [--redistribute] [--lang es|en]
```

## Opciones

- **--show**: Visualizar carga actual por persona (defecto)
- **--suggest**: Proponer redistribución sin aplicar
- **--redistribute**: Aplicar cambios propuestos (requiere confirmación)
- **--lang**: Idioma de salida

## Métricas Analizadas

1. **WIP por persona** — Work in progress actual
2. **Cycle time individual** — Tiempo promedio de tarea de cada miembro
3. **Complejidad asignada** — Story points o peso de tareas
4. **Especialidades** — Áreas de expertise (backend, QA, devops, etc.)
5. **Capacidad** — Disponibilidad declared y observada
6. **Preferencias** — Roles o tipos de trabajo preferidos

## Output

Tabla:
| Miembro | Carga Actual | Carga Óptima | Diferencia | Acción |
|---------|-------------|-------------|----------|--------|
| Maria | 8 SP | 6 SP | +2 | Transferir 2-4 SP |
| Carlos | 4 SP | 6 SP | -2 | Recibir 2-4 SP |

## Restricciones

- No reasignar especialidades críticas (ej: DBA, infra)
- Respetar preferencias declaradas en perfil del equipo
- Minimizar context switching

## Ejemplo

```bash
/workload-balance --suggest
```

Propone nuevas asignaciones sin cambiar el sistema.

🦉 **Savia te recuerda**: El equilibrio no es perfección, sino justicia sostenible.
