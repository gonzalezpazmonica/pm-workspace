---
name: eval-run
description: Execute evaluation against specified criteria
---

---

# /eval-run — Ejecutar evaluación

Corre una evaluación de calidad de outputs de agentes y guarda los resultados.

## Argumentos

`$ARGUMENTS` — Tipo de evaluación:
- `pbi-quality` — Calidad de descomposición de PBIs
- `spec-quality` — Calidad de especificaciones técnicas
- `estimation-accuracy` — Precisión de estimaciones post-sprint
- `review-quality` — Calidad de revisiones de código
- `assignment-quality` — Asignación de tareas a personas correctas

## Comportamiento

1. Valida que el tipo de evaluación es válido
2. Ejecuta la evaluación (corre agentes si es necesario)
3. Aplica rubric correspondiente
4. Guarda scores y feedback en `data/evals/{eval-name}/results/`
5. Genera informe con hallazgos y score global
6. Detecta regresiones (caída >10% vs. última evaluación)

## Output

- Informe de evaluación en `output/evals/YYYYMMDD-{eval-name}.md`
- Datos JSON en `data/evals/{eval-name}/results/YYYYMMDD.json`
- Alertas si hay regresión detectada

## Ejemplo

```
/eval-run pbi-quality
→ Evalúa 10 PBIs activos contra rubric de descomposición
  Score: 76/100 (Good)
  ↓ -5% desde última evaluación (fue 81)
```
