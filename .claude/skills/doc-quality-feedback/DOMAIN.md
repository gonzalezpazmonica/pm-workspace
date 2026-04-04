# Doc Quality Feedback — Dominio

## Por que existe esta skill

La documentacion del workspace (skills, reglas, agentes) puede degradarse con el
tiempo. Esta skill implementa un loop de auto-mejora donde los agentes puntuan la
documentacion que usan, y la agregacion mensual detecta docs de baja calidad.

## Conceptos de dominio

- **Rating**: puntuacion que un agente emite tras usar un skill/regla (clear, confusing, incomplete, outdated, wrong)
- **Score de doc**: porcentaje de ratings positivos (clear) vs negativos; threshold >30% negativo = flagged
- **Agregacion mensual**: consolidacion de todos los ratings para producir ranking de calidad
- **Emision voluntaria**: los agentes no estan obligados a puntuar siempre; solo cuando detectan friccion o fluidez

## Reglas de negocio que implementa

- Self-Improvement Loop (Rule #21): feedback de docs alimenta el ciclo de mejora continua
- Skill Lifecycle (skill-lifecycle.md): ratings influyen en la maduracion experimental > beta > stable
- Clara Philosophy (clara-philosophy.md): docs con rating bajo son candidatos a reescritura SKILL.md + DOMAIN.md

## Relacion con otras skills

- **Upstream**: cualquier agente que usa un skill o regla (emite rating como efecto secundario)
- **Downstream**: skill-optimize (prioriza docs con peor rating para reescritura)
- **Paralelo**: codebase-map (detecta huerfanos estructuralmente; doc-quality detecta docs confusos funcionalmente)

## Decisiones clave

- Ratings en JSONL publico (no gitignored): las puntuaciones son genericas, sin datos de proyecto
- Emision voluntaria con sampling (1/5 para clear): evitar saturar el log con confirmaciones positivas
- Cinco niveles de rating: granularidad suficiente para diagnosticar el tipo de problema
