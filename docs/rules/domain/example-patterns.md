---
name: example-patterns
description: Estándar para escribir ejemplos (few-shot) en commands y skills — el tipo de contexto más potente
auto_load: false
paths: []
---

# Regla: Example Patterns — Few-shot en Commands y Skills

> Fuente: AI Engineering Guidebook (2025) p.152-160 — "Examples are the most powerful type of context."

---

## Principio

Los ejemplos concretos de input→output reducen errores en tareas complejas.
Todo command o skill de uso frecuente debe incluir al menos 2 ejemplos:
uno positivo (comportamiento correcto) y uno negativo (qué NO hacer).

---

## Formato estándar

Añadir una sección `## Ejemplos` después de los parámetros, antes del flujo:

```markdown
## Ejemplos

**✅ Correcto:**
```
Entrada: /mi-comando --project alpha --focus security
Salida esperada: Informe en output/audits/20260305-security-alpha.md
  Score: 7.2/10 | 🔴 2 críticos | 🟡 3 mejorables
```

**❌ Incorrecto:**
```
Entrada: /mi-comando alpha
Salida incorrecta: Volcado de 200 líneas en la conversación sin guardar fichero
Por qué falla: Viola output-first (context-health.md regla 1)
```
```

---

## Reglas de escritura

1. **Mínimo 2 ejemplos** en commands con `context_cost: high/medium`
2. **Al menos 1 negativo** — muestra el error más frecuente y por qué falla
3. **Datos genéricos** — usar `alpha`, `test-org`, `alice` (regla PII-Free #20)
4. **Brevedad** — cada ejemplo ≤5 líneas, no repetir la spec del comando
5. **Representativos** — cubrir el caso de uso principal, no edge cases
6. **Opcionales** en commands `context_cost: low` (no justifica el coste en tokens)

---

## Ejemplos en Skills

Los skills también se benefician de ejemplos. Formato en SKILL.md:

```markdown
## Ejemplo de uso

Comando: `/mi-skill --input datos.csv`
Resultado: Análisis guardado en output/analytics/...
```

Un solo ejemplo basta para skills (se cargan bajo demanda, cada token cuenta).

---

## Coste en tokens

Cada ejemplo añade ~50-100 tokens. En commands frecuentes, el trade-off es
positivo: mejor output > más tokens. En commands raramente usados, priorizar
brevedad.

---

## Prioridad de adopción

Añadir ejemplos primero a los commands más impactantes:
1. `/project-audit` — genera informes complejos
2. `/sprint-plan` — cálculos de capacity
3. `/spec-generate` — specs técnicas
4. `/debt-track` — registro de deuda
5. `/risk-log` — registro de riesgos

Luego expandir a los 20 commands más usados progresivamente.
