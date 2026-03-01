---
name: my-learning
description: Detección de tech stack gaps — código del developer vs best practices del proyecto
developer_type: all
agent: task
context_cost: high
---

# /my-learning

> 🦉 Savia detecta áreas de mejora analizando tu código vs. las mejores prácticas del proyecto.

---

## Cargar perfil de usuario

Grupo: **Quality & PRs** — cargar:

- `identity.md` — nombre, rol
- `workflow.md` — reviews_agent_code
- `tools.md` — ide, git_mode

---

## Subcomandos

- `/my-learning` — análisis completo de oportunidades de mejora
- `/my-learning --quick` — solo top 3 áreas
- `/my-learning --topic {tema}` — profundizar en un tema específico

---

## Flujo

### Paso 1 — Analizar código del developer

Revisar los últimos 20-30 commits del usuario:

1. Patrones de código más frecuentes
2. Librerías y frameworks utilizados
3. Estilo de testing
4. Manejo de errores
5. Patrones de arquitectura aplicados

### Paso 2 — Comparar con best practices del proyecto

Para cada área detectada:

| Área | Fuente de best practices |
|---|---|
| Lenguaje | `.claude/rules/languages/{lang}-conventions.md` |
| Arquitectura | ADRs del proyecto, `/arch-detect` |
| Testing | Patterns del test-engineer, TDD gate |
| Seguridad | Code review rules, security-guardian |
| Performance | Performance patterns del proyecto |

### Paso 3 — Identificar gaps

Clasificar gaps por impacto y frecuencia:

| Nivel | Criterio |
|---|---|
| 🔴 Frecuente | Aparece en >50% de los commits |
| 🟡 Ocasional | Aparece en 20-50% de los commits |
| 🟢 Raro | Aparece en <20% de los commits |

### Paso 4 — Generar plan de aprendizaje

```
🦉 Learning Opportunities — {nombre}

📊 Análisis de últimos {N} commits

🎯 Top oportunidades de mejora:

1. 🔴 {Área}: {descripción}
   Ejemplo en tu código: {snippet corto}
   Best practice: {lo que sugiere la convención}
   Recurso: {link o referencia}

2. 🟡 {Área}: {descripción}
   ...

3. 🟢 {Área}: {descripción}
   ...

✅ Lo que haces bien:
   - {patrón positivo 1}
   - {patrón positivo 2}

💡 Sugerencia: Enfócate en el gap #1 esta semana.
```

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: my_learning
commits_analyzed: 25
gaps_found: 5
frequent: 1
occasional: 2
rare: 2
top_area: "Error handling"
strengths: ["Clean naming", "Good test coverage"]
```

---

## Restricciones

- **NUNCA** compartir resultados con otros miembros del equipo
- **NUNCA** usar tono negativo — enfoque constructivo
- Siempre incluir lo que el developer hace bien
- Análisis privado y personal — sin ranking ni comparación
