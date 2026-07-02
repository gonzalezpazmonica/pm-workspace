---
name: arch-health
description: Salud arquitectónica — fitness functions, drift detection, coupling metrics
developer_type: all
agent: task
context_cost: high
tier: extended
---

# /arch-health

> 🦉 Savia mide la salud de tu arquitectura con métricas objetivas.

---

## Cargar perfil de usuario

Grupo: **Architecture & Debt** — cargar:

- `identity.md` — nombre, rol
- `projects.md` — proyecto target
- `preferences.md` — detail_level

---

## Subcomandos

- `/arch-health` — informe completo de salud arquitectónica
- `/arch-health --drift` — solo detección de drift
- `/arch-health --coupling` — solo métricas de acoplamiento

---

## Flujo

### Paso 1 — Ejecutar fitness functions

Ejecutar las reglas definidas por `/arch-fitness` (si existen):

| Fitness Function | Qué mide |
|---|---|
| Layer independence | ¿Las capas respetan sus dependencias? |
| No circular deps | ¿Hay dependencias circulares? |
| Naming conventions | ¿Los nombres siguen las convenciones? |
| File size limits | ¿Hay ficheros excesivamente grandes? |
| Import limits | ¿Hay ficheros con demasiados imports? |

### Paso 2 — Detectar drift arquitectónico

Comparar estado actual vs. ADRs activos:

1. ¿Se están respetando las decisiones documentadas?
2. ¿Hay nuevos patrones no documentados emergiendo?
3. ¿Hay violaciones de las convenciones del lenguaje?

### Paso 3 — Calcular métricas de acoplamiento

| Métrica | Cálculo |
|---|---|
| Afferent Coupling (Ca) | Módulos que dependen de este |
| Efferent Coupling (Ce) | Módulos de los que este depende |
| Instability | Ce / (Ca + Ce) — 0=estable, 1=inestable |
| Abstractness | Interfaces / Total clases |
| Distance | \|A + I - 1\| — 0=zona óptima |

### Paso 4 — Generar informe

```
🦉 Architecture Health — {proyecto}

📊 Health Score: {N}/100 {🟢|🟡|🔴}

✅ Fitness Functions: {passed}/{total} PASS
  🟢 Layer independence — PASS
  🔴 No circular deps — FAIL (A→B→C→A)
  🟢 Naming conventions — PASS

🔄 Drift Detection:
  ⚠️ ADR-003 (Use Repository Pattern): 2 violaciones
  ✅ ADR-005 (CQRS): Respetado

📐 Coupling:
  Top acoplados: {módulo} (Ce=12), {módulo} (Ce=9)
  Inestables: {módulo} (I=0.9), {módulo} (I=0.8)

💡 Recomendaciones:
  1. Romper dependencia circular A→B→C→A
  2. Reducir coupling de {módulo} extrayendo interfaz
```

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: arch_health
health_score: 68
fitness_passed: 4
fitness_total: 5
drift_violations: 2
circular_deps: 1
top_coupling: 12
```

---

## Restricciones

- **NUNCA** modificar código automáticamente
- **NUNCA** eliminar ADRs sin confirmación
- Métricas objetivas — sin juicios subjetivos
