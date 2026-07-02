---
name: qa-bug-triage
description: Triage asistido de bugs — clasificación, duplicados, asignación sugerida
developer_type: all
agent: none
context_cost: medium
tier: extended
---

# /qa-bug-triage

> 🦉 Savia te ayuda a clasificar y asignar bugs rápidamente.

---

## Cargar perfil de usuario

Grupo: **Quality & PRs** — cargar:

- `identity.md` — nombre, rol
- `projects.md` — proyecto target
- `tone.md` — alert_style

---

## Subcomandos

- `/qa-bug-triage` — triage de bugs sin clasificar del sprint
- `/qa-bug-triage {bug-id}` — triage de un bug específico
- `/qa-bug-triage --backlog` — triage de todo el backlog de bugs

---

## Flujo

### Paso 1 — Obtener bugs pendientes de triage

Filtrar work items tipo Bug con estado New o sin severidad asignada.

### Paso 2 — Clasificar severidad

Para cada bug, analizar:

| Factor | Peso | Criterio |
|---|---|---|
| Impacto usuario | 40% | ¿Afecta a funcionalidad core? ¿Bloquea uso? |
| Frecuencia | 25% | ¿Reproducible siempre? ¿Solo en condiciones específicas? |
| Workaround | 20% | ¿Existe alternativa viable? |
| Datos afectados | 15% | ¿Corrupción de datos? ¿Pérdida de información? |

Clasificación resultante: Critical / High / Medium / Low.

### Paso 3 — Detectar duplicados

Comparar título + descripción con bugs existentes:
- Similitud > 80% → marcar como posible duplicado
- Similitud > 60% → marcar como relacionado

### Paso 4 — Sugerir asignación

Basado en contexto del código afectado:
- ¿Quién tocó ese fichero recientemente? → sugerir
- ¿Quién tiene menos carga? → considerar
- ¿Quién tiene expertise en ese módulo? → priorizar

### Paso 5 — Mostrar resultado

```
🦉 Bug Triage — {proyecto} — {fecha}

📋 Bugs pendientes de triage: {N}

| Bug | Severidad | Duplicado? | Asignación sugerida |
|---|---|---|---|
| #1234 Login fails | 🔴 Critical | No | @dev-A (author) |
| #1235 UI glitch | 🟢 Low | ~#1201 | @dev-B (less load) |
| #1236 Timeout | 🟡 Medium | No | @dev-C (expert) |

💡 Resumen:
  {N} critical, {N} high, {N} medium, {N} low
  {N} posibles duplicados encontrados
```

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: qa_bug_triage
bugs_triaged: 5
critical: 1
high: 2
medium: 1
low: 1
duplicates_found: 1
```

---

## Restricciones

- **NUNCA** cerrar o modificar bugs automáticamente
- **NUNCA** asignar sin confirmación — solo sugerir
- Duplicados son sugerencias, no decisiones definitivas
