---
name: context-benchmark
description: Benchmark de posicionamiento de información en el contexto
developer_type: all
agent: none
context_cost: high
tier: extended
---

# /context-benchmark

> 🦉 Savia mide si la posición de la información afecta a la calidad de sus respuestas.

---

## Cargar perfil de usuario

Grupo: **Memory & Context** — cargar:

- `identity.md` — slug

---

## Concepto

El paper "Lost in the Middle" (Liu et al., 2024) demostró que los LLMs tienen un sesgo
en forma de U: recuerdan mejor la información al principio y al final del contexto.

Este benchmark mide empíricamente si pm-workspace posiciona bien su información crítica
(CLAUDE.md al inicio, perfil al final, reglas bajo demanda en medio).

---

## Flujo

### Paso 1 — Seleccionar suite de test

Usar 5 preguntas de verificación que requieren datos de diferentes fuentes:

1. **Pregunta de configuración** — ¿Cuál es la API version de Azure DevOps? (CLAUDE.md)
2. **Pregunta de perfil** — ¿Cómo se llama el usuario activo? (identity.md)
3. **Pregunta de workflow** — ¿Cuál es la duración del sprint? (CLAUDE.md + workflow.md)
4. **Pregunta de regla** — ¿Cuántas líneas máximas por fichero? (CLAUDE.md reglas)
5. **Pregunta de agente** — ¿Cuántos subagentes hay configurados? (CLAUDE.md estructura)

### Paso 2 — Ejecutar tests

Para cada pregunta:

1. Formular la pregunta como si fuera un usuario
2. Verificar si la respuesta es correcta comparando con el valor real
3. Registrar: pregunta, fuente, posición estimada, acierto (sí/no)

### Paso 3 — Analizar resultados

```
🦉 Context Benchmark — Posicionamiento
  Aciertos: {N}/5

  Inicio del contexto (CLAUDE.md): {aciertos}/{total}
  Medio del contexto (reglas @): {aciertos}/{total}
  Final del contexto (perfil): {aciertos}/{total}

  Conclusión: {recomendación}
```

### Paso 4 — Recomendar

Si hay posiciones débiles:

- Sugerir mover información crítica a posiciones más fuertes
- Sugerir duplicar datos críticos en CLAUDE.md si se pierden en el medio
- Registrar resultados para tracking histórico

---

## Subcomandos

- `/context-benchmark` — ejecutar benchmark completo (5 preguntas)
- `/context-benchmark quick` — solo 2 preguntas rápidas
- `/context-benchmark history` — ver resultados anteriores

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: context_benchmark
total: 5
correct: 4
accuracy: 80
positions:
  start: { correct: 2, total: 2 }
  middle: { correct: 1, total: 1 }
  end: { correct: 1, total: 2 }
recommendation: "Profile data at end has 50% accuracy — consider duplicating name in CLAUDE.md"
```

---

## Restricciones

- **NUNCA** modificar ficheros durante el benchmark
- **NUNCA** ejecutar benchmark en modo agente automático (consume tokens)
- Resultados son orientativos — no tomar decisiones solo con un benchmark
- Ejecutar máximo 1 vez por semana para no desperdiciar tokens
