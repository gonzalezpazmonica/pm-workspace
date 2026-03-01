# /team-workload

Muestra la carga de trabajo por persona: items asignados, horas remaining y balance de equipo.

## 1. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Team & Workload** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/projects.md`
   - `profiles/users/{slug}/tone.md`
3. Adaptar output según `tone.alert_style` (calibrar alertas de sobrecarga)
4. Si no hay perfil → continuar con comportamiento por defecto

## 2. Uso
```
/team-workload [proyecto]
```

## 3. Pasos de Ejecución

1. Ejecutar WIQL para obtener todos los items activos del sprint actual asignados a cada persona
2. Para cada persona del equipo (leer de `projects/<proyecto>/equipo.md`):
   a. Items en estado Active o In Progress
   b. Items en estado New (pendientes de iniciar)
   c. Items en estado Resolved/Done (completados)
   d. Sum(RemainingWork) = carga pendiente total
   e. Count(Active items) = WIP actual
3. Comparar WIP con WIP_LIMIT_PER_PERSON
4. Detectar items sin asignar (unassigned) en el sprint
5. Mostrar distribución visual de la carga

## Formato de Salida

```
## Team Workload — [Proyecto] — [Sprint] — [Hoy]

| Persona | New | Active (WIP) | Done | Remaining (h) | Alerta |
|---------|-----|-------------|------|---------------|--------|
| Juan García | 3 | 2 ✅ | 5 | 18h | OK |
| Ana López | 1 | 3 ⚠️ | 4 | 24h | WIP alto |
| Pedro Ruiz | 0 | 1 ✅ | 8 | 4h | OK |

**WIP Limit configurado:** 2 items por persona

### 📋 Items Sin Asignar (en sprint)
| ID | Título | Tipo | SP |
|----|---------|----|-----|
| AB#XXXX | ... | Task | — |

### 📊 Distribución de Carga (Remaining Work)
Juan García  ████████████████ 18h
Ana López    ████████████████████████ 24h
Pedro Ruiz   ████ 4h

**Recomendación:** Redistribuir X task de Ana López a Pedro Ruiz (4h disponibles).
```
