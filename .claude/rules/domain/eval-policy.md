# Política de Evaluaciones — Automatización y Alertas

Regla que define cuándo ejecutar evaluaciones, periodicidad, y políticas de regresión.

## Evaluaciones Post-Sprint

**Cuándo:** Sprint review (viernes fin de sprint)

**Evaluación requerida:** `estimation-accuracy`
- Compara SP predichos vs. SP reales completados
- Calcula desviación % por categoría de tarea
- Identifica tendencias de sub/sobre-estimación

## Evaluaciones Mensuales

**Cuándo:** Primer miércoles de cada mes

**Evaluaciones requeridas:**
- `pbi-quality` — Evalúa PBIs creados en el mes anterior
- `spec-quality` — Evalúa specs generadas en el mes anterior

Ambas se ejecutan en paralelo. Resultados se incluyen en `report-monthly`.

## Política de Regresión

**Alerta si:** Score baja > 10% respecto a la evaluación anterior del mismo tipo

**Acción:**
1. Alertar al PM en dashboard (banner rojo)
2. Generar informe automático "Regresión Detectada"
3. Mostrar en `/eval-report {eval-name}` con flag de regresión
4. Sugerir `/debug-regression {eval-name}` para análisis

**Threshold:** -10% es umbral crítico. Entre -5% y -10% = warning amarillo.

## Alertas de Regresión

Patrones a detectar automáticamente:
- Mismo criterio fallando 2+ sprints consecutivos
- Score global bajando consistentemente (3+ sprints)
- Nuevas evaluaciones puntuando < 50% (CRITICAL)

**Notificación:** Sugerir revisar process/capacitación/herramientas que causó la caída.

## Historiales

Se mantienen en `data/evals/{eval-name}/trends/{eval-name}-trends.json`:
- Lista de todas las evaluaciones con fecha, score, detalles
- Facilita análisis histórico y detección de patrones
- Base para /eval-report y análisis de regresión
