---
name: testplan-generate
description: Generación de plan de pruebas desde specs SDD o PBIs
developer_type: all
agent: task
context_cost: high
---

# /testplan-generate

> 🦉 Savia genera un plan de pruebas completo desde tus specs o PBIs.

---

## Cargar perfil de usuario

Grupo: **Quality & PRs** — cargar:

- `identity.md` — nombre, rol
- `workflow.md` — reviews_agent_code
- `projects.md` — proyecto target

---

## Subcomandos

- `/testplan-generate {spec-file}` — plan desde una spec SDD
- `/testplan-generate --pbi {id}` — plan desde un PBI
- `/testplan-generate --sprint` — plan para todo el sprint actual

---

## Flujo

### Paso 1 — Leer fuente

Si spec SDD: extraer scenarios Given/When/Then y acceptance criteria.
Si PBI: extraer acceptance criteria y description.
Si sprint: agregar todos los PBIs del sprint.

### Paso 2 — Generar test cases

Para cada scenario o criterio:

1. Caso positivo (happy path)
2. Caso negativo (error esperado)
3. Caso límite (edge case)
4. Caso de datos (valores nulos, vacíos, máximos)

### Paso 3 — Clasificar tests

| Tipo | Descripción |
|---|---|
| Unit | Lógica interna, sin dependencias externas |
| Integration | Interacción entre módulos o servicios |
| E2E | Flujo completo de usuario |
| Performance | Tiempos de respuesta, carga |
| Security | Autenticación, autorización, inyección |

### Paso 4 — Estimar esfuerzo

| Complejidad | Tiempo estimado |
|---|---|
| Simple (1 assertion) | 15 min |
| Medium (3-5 assertions) | 30 min |
| Complex (mocks, fixtures) | 1h |
| E2E (multi-step) | 2h |

### Paso 5 — Generar plan

Guardar en `output/testplans/{spec-id}-testplan-{fecha}.md`:

```
# Test Plan — {spec/PBI}
## Summary
  Total test cases: {N}
  Estimated effort: {N}h
  Coverage: {unit: N, integration: N, e2e: N}

## Test Cases
### TC-001: {nombre}
  Type: Unit | Priority: High
  Given: {precondición}
  When: {acción}
  Then: {resultado esperado}
  Edge cases: {lista}
```

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: testplan_generate
source: spec
test_cases: 24
unit: 14
integration: 6
e2e: 4
estimated_hours: 12
output_file: output/testplans/PBI-1234-testplan-2026-03-01.md
```

---

## Restricciones

- **NUNCA** escribir tests — solo planificar
- **NUNCA** omitir casos negativos o edge cases
- Cada test case debe ser verificable y reproducible
- Respetar la spec: no añadir requisitos no definidos
