---
name: human-code-map
description: "Genera y mantiene mapas narrativos de componentes (.hcm) para luchar activamente contra la deuda cognitiva. Usar PROACTIVELY cuando: se incorpora un dev nuevo, se toca un módulo sin mapa, debt-score > 6, o se detecta que alguien re-lee el mismo código repetidamente."
summary: |
  Pipeline de 4 fases: cargar .acm del componente → analizar código real →
  generar borrador narrativo → ciclo de validación humana.
  Output: fichero .hcm con story, modelo mental, gotchas, decisiones y debt-score.
maturity: experimental
context: fork
category: "quality"
tags: ["comprehension", "cognitive-debt", "documentation", "onboarding", "mental-model"]
priority: "high"
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash]
model: sonnet
context_cost: medium
---

# Human Code Map — Skill

## Por qué existe este skill

La deuda cognitiva es el coste invisible de los sistemas de software. Los .acm
resuelven la comprensión para los agentes de IA. Los .hcm resuelven la comprensión
para los desarrolladores humanos. Sin .hcm, el conocimiento de un módulo muere
con la persona que lo escribió.

Referencia: https://addyosmani.com/blog/comprehension-debt/

---

## Regla del skill

Ver `.claude/rules/domain/hcm-maps.md` — formato, lifecycle, debt score, relación con .acm.

---

## Fase 1 — Cargar contexto del componente

**Input**: path de componente o nombre de servicio

1. Leer `.agent-maps/INDEX.acm` para localizar la capa/sección relevante
2. Leer el `.acm` de la capa correspondiente (entities/services/infrastructure/api)
3. Leer los ficheros principales del componente (máx 5, los más relevantes)
4. Si existe un `.hcm` previo, leerlo para preservar gotchas y decisiones históricas

**Output**: contexto suficiente para generar narración precisa sin inventar.

---

## Fase 2 — Análisis de deuda

Calcular el estado actual antes de generar:

```bash
# Días desde último paseo
LAST_WALK=$(grep 'last-walk:' .human-maps/${path}.hcm | head -1 | grep -oP '\d{4}-\d{2}-\d{2}')
DAYS_STALE=$(( ($(date +%s) - $(date -d "$LAST_WALK" +%s)) / 86400 ))

# Complejidad del componente (proxy: líneas + número de dependencias)
LINES=$(wc -l < ${main_file})
DEPS=$(grep -c "^import\|^using\|^require" ${main_file} 2>/dev/null || echo 0)

# Score
STALENESS_PENALTY=$(( DAYS_STALE / 30 * 2 ))  # max 4
COMPLEXITY=$([ $LINES -gt 200 ] && echo 3 || [ $LINES -gt 80 ] && echo 2 || echo 1)
DEBT_SCORE=$(( STALENESS_PENALTY + COMPLEXITY ))
```

Si `DEBT_SCORE > 7` → avisar al PM antes de generar.

---

## Fase 3 — Generar borrador narrativo

Generar cada sección del .hcm con instrucciones específicas:

### La historia (1 párrafo)
No describir ficheros — describir el *problema que resuelve* y *cómo lo piensa el sistema*.
Usar el tiempo presente. Evitar jerga técnica innecesaria.

Ejemplo correcto: "El pipeline SDD transforma un PBI vago en código deployable pasando por
5 agentes en secuencia, donde cada agente valida el trabajo del anterior antes de continuar."

Ejemplo incorrecto: "El skill spec-driven-development contiene los ficheros SKILL.md y
DOMAIN.md que definen el proceso..."

### El modelo mental
Identificar la abstracción central del componente. Una analogía si ayuda.
¿Qué concepto del mundo real modela? ¿Qué invariante mantiene siempre?

### Puntos de entrada
Para cada operación común, dar la ruta exacta de inicio: fichero, función, línea.
Basado en los `Public API` del .acm correspondiente.

### Gotchas
Buscar en el código:
- Comentarios `// HACK`, `// TODO`, `// NOTE`, `// WARNING`
- Condiciones con nombres no obvios
- Efectos secundarios en funciones con nombres inocentes
- Orden de operaciones que no es obvio

Si existe un .hcm previo, preservar los gotchas validados por humanos.

### Por qué está construido así
Buscar en:
- `adrs/` si existe
- `decision-log.md` si existe
- Mensajes de commit relevantes: `git log --oneline -- {fichero} | head -20`
- Comentarios de diseño en el código

### Indicadores de deuda
- Complexity metrics (lines, deps, nesting)
- Coverage gaps (si existe test-coverage report)
- Áreas marcadas con TODO/FIXME
- Código que el análisis detecta pero ningún test cubre

---

## Fase 4 — Ciclo de validación

El borrador generado NO es el .hcm final. Requiere validación humana.

Output al usuario:
```
📝 Borrador .hcm generado: .human-maps/{path}.hcm
   debt-score estimado: {N}/10

   ⚠️ ACCIÓN REQUERIDA antes de marcar como válido:
   [ ] Leer la sección "La historia" — ¿describe el problema correcto?
   [ ] Leer "Gotchas" — ¿hay algo que falta o que está incorrecto?
   [ ] Leer "Por qué está construido así" — ¿captura las decisiones reales?
   [ ] Actualizar last-walk: con la fecha de hoy tras validar

   El .hcm no protege contra deuda cognitiva hasta que un humano lo haya leído.
```

El campo `last-walk:` solo se actualiza cuando el humano confirma la validación.
Un .hcm con `last-walk:` = fecha de generación automática sin validación = no es fiable.

---

## Integración con .acm

| Evento | .acm | .hcm |
|--------|------|------|
| Código cambia | Hash inválido → regenerar | Stale automático si .acm stale |
| Nuevo componente | Añadir sección | Crear borrador .hcm |
| Componente eliminado | Eliminar sección | Archivar en `.human-maps/_archived/` |
| Dev nuevo llega | — | Cargar .hcm del módulo que va a tocar |

---

## Cuándo NO generar .hcm

- Componentes con < 50 líneas de código (overhead mayor que beneficio)
- Ficheros de configuración pura (el .hcm sería solo repetición del .acm)
- Código generado automáticamente (migrations, scaffolding)
- Scripts de un solo uso (no hay deuda cognitiva a gestionar)

---

## Output esperado

Fichero: `.human-maps/{capa}/{componente}.hcm`
Secciones obligatorias: header, La historia, El modelo mental, Puntos de entrada, Gotchas
Secciones opcionales: Por qué está construido así, Indicadores de deuda
Límite: 150 líneas
