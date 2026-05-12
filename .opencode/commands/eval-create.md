---
name: eval-create
description: Create and configure evaluation criteria for outputs
---

---

# /eval-create — Crear evaluación personalizada

Define y configura una nueva evaluación personalizada con rubric propios.

## Comportamiento

1. Pide nombre de la evaluación (kebab-case)
2. Pide descripción: qué se evalúa y por qué
3. Pide definir rubric: 4-5 criterios con puntuaciones
4. Genera fichero de configuración
5. Almacena en `data/evals/{eval-name}/config.json`

## Estructura de Rubric

Cada evaluación necesita:
- **Nombre**: descripción del criterio
- **Peso**: porcentaje en score final (total = 100%)
- **Niveles**: 4 niveles (Excellent 90-100, Good 70-89, Fair 50-69, Poor <50)
- **Descripción**: qué significa cada nivel

## Output

Genera:
- Fichero config JSON con rubric definida
- Directorio `data/evals/{eval-name}/` con estructura
- Confirmación y sugerencia de ejecutar `/eval-run {eval-name}`

## Ejemplo

```
/eval-create
→ Nombre: code-documentation-quality
→ Descripción: Evalúa claridad y completitud de documentación de código
→ Criterios: [Completitud, Claridad, Ejemplos, Mantenibilidad]
→ Guardado en data/evals/code-documentation-quality/config.json
```
