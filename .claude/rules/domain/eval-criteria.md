---
name: eval-criteria
description: Criterios base G-Eval por tipo de output — usados por /eval-output
auto_load: false
paths: []
---

# Criterios de Evaluación G-Eval

> Fuente: AI Engineering Guidebook (2025) p.331-340 — G-Eval scoring framework.

---

## Criterios por tipo de output

### Tipo: report (informes, audits, análisis)

| Criterio | Peso | Descripción |
|----------|------|-------------|
| Completitud | 25% | ¿Cubre todas las dimensiones relevantes? |
| Claridad | 20% | ¿Se entiende sin ambigüedad? ¿Estructura lógica? |
| Accionabilidad | 25% | ¿Las recomendaciones son concretas y ejecutables? |
| Precisión | 15% | ¿Los datos y scores son verificables y coherentes? |
| Formato | 15% | ¿Sigue el template esperado? ¿Output-first? |

### Tipo: spec (especificaciones técnicas)

| Criterio | Peso | Descripción |
|----------|------|-------------|
| Completitud | 20% | ¿Cubre requisitos funcionales y no funcionales? |
| Testabilidad | 25% | ¿Los criterios de aceptación son medibles? |
| Implementabilidad | 25% | ¿Un developer puede implementar sin preguntas? |
| Coherencia | 15% | ¿Sin contradicciones internas? |
| Seguridad | 15% | ¿Considera OWASP y validaciones? |

### Tipo: code (código fuente, scripts)

| Criterio | Peso | Descripción |
|----------|------|-------------|
| Corrección | 30% | ¿Hace lo que dice que hace? ¿Sin bugs obvios? |
| Legibilidad | 20% | ¿Nombres claros, estructura lógica, comentarios? |
| Robustez | 20% | ¿Manejo de errores, edge cases, validaciones? |
| Convenciones | 15% | ¿Sigue las convenciones del lenguaje (rules/)? |
| Tests | 15% | ¿Incluye o facilita testing? |

### Tipo: plan (planes de sprint, release, proyecto)

| Criterio | Peso | Descripción |
|----------|------|-------------|
| Viabilidad | 25% | ¿Es realista con los recursos disponibles? |
| Completitud | 20% | ¿Cubre scope, riesgos, dependencias, timeline? |
| Priorización | 25% | ¿Los items están ordenados por valor/urgencia? |
| Claridad | 15% | ¿Roles y responsabilidades explícitos? |
| Métricas | 15% | ¿Define cómo medir éxito? |

---

## Criterios genéricos (fallback)

Si no se especifica `--type`, usar:

| Criterio | Peso | Descripción |
|----------|------|-------------|
| Claridad | 33% | ¿Se entiende sin ambigüedad? |
| Completitud | 34% | ¿Cubre lo que prometió cubrir? |
| Accionabilidad | 33% | ¿El lector sabe qué hacer después? |

---

## Escala de scoring

| Score | Significado |
|-------|-------------|
| 9-10 | Excelente — listo para producción sin cambios |
| 7-8 | Bueno — mejoras menores opcionales |
| 5-6 | Aceptable — necesita revisión en áreas específicas |
| 3-4 | Insuficiente — requiere reescritura parcial |
| 1-2 | Inaceptable — rehacer desde cero |

---

## Modo Arena (comparación A/B)

Para comparaciones, evaluar AMBOS outputs con los mismos criterios,
luego determinar ganador con formato:

```
| Criterio | Output A | Output B | Ganador |
|----------|----------|----------|---------|
```

Veredicto: "Output {X} es superior porque..." (2-3 frases).
Empate si la diferencia global es < 0.5 puntos.
