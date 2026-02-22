# Política de Estimación

> Define cómo el equipo estima el esfuerzo de los work items y cómo se mapean Story Points a horas para el reporting económico.
>
> **Nota:** La skill `pbi-decomposition` (Fase 3) usa la tabla de calibración SP→horas de este documento para validar que la suma de horas de las tasks es coherente con los Story Points del PBI. Si la desviación supera el 30% del rango esperado, el agente alertará antes de proponer la descomposición.

## Constantes de Estimación

```
METODO_ESTIMACION     = "Story Points (Fibonacci)"
ESCALA_FIBONACCI      = [1, 2, 3, 5, 8, 13, 21, ?]   # ? = no estimable sin más info
SP_MAX_POR_SPRINT     = 40                             # máximo absoluto de SP por sprint (equipo de 4)
TASK_MAX_HORAS        = 8                              # una task no puede superar 8h; si supera → descomponer
PBI_MAX_SP            = 13                             # un PBI > 13 SP debe descomponerse
FACTOR_FOCO           = 0.75                           # 75% del tiempo es productivo (reuniones, overhead)
HORAS_POR_DIA         = 8                              # jornada laboral
```

---

## 1. Escala de Story Points

| SP | Complejidad | Referencia de calibración | Horas aprox. |
|----|-------------|--------------------------|--------------|
| 1 | Trivial | Cambio de texto/etiqueta, ajuste CSS mínimo | 1-2h |
| 2 | Muy pequeño | Bug simple sin impacto arquitectural, CRUD básico | 2-4h |
| 3 | Pequeño | Funcionalidad simple, endpoint REST sencillo | 4-8h |
| 5 | Mediano | Funcionalidad con lógica de negocio, integración simple | 1-2 días |
| 8 | Grande | Funcionalidad compleja, múltiples componentes, integración compleja | 2-4 días |
| 13 | Muy grande | Épica pequeña, requiere investigación previa | 4-8 días |
| 21 | Épica | Demasiado grande → descomponer obligatoriamente | > 1 sprint |
| ? | Incompleto | No hay suficiente información para estimar → refinar primero | — |

> ⚠️ Los Story Points miden **complejidad y riesgo**, no horas exactas. La tabla de horas es orientativa para el planning inicial.

---

## 2. Ejemplos de Calibración (Reales del Equipo)

Mantener esta sección actualizada con ejemplos reales del proyecto para anclar el equipo:

| Item real | SP asignados | Horas reales | Notas |
|-----------|-------------|--------------|-------|
| Endpoint GET /api/users con paginación | 3 | 6h | incluye tests |
| Formulario de login con validación | 5 | 12h | UX + backend + tests |
| Integración con proveedor de pagos | 13 | 32h | docs, mock, tests E2E |
| Migración de base de datos (schema simple) | 2 | 3h | script + rollback |
| Dashboard con 3 gráficos (Chart.js) | 8 | 20h | incluye endpoints de datos |

> Añadir nuevos ejemplos después de cada sprint completado.

---

## 3. Proceso de Estimación — Planning Poker

### Reglas del juego:
1. El PO lee la historia de usuario en voz alta
2. El equipo hace preguntas de clarificación (máx. 5 minutos por item)
3. Cada persona elige una carta de la escala Fibonacci (en privado)
4. Se revelan todas las cartas a la vez
5. Si hay consenso (o diferencia ≤ 1 nivel): se acepta
6. Si hay divergencia: las personas con la carta más alta y más baja explican su razonamiento (máx. 3 min) → segunda votación
7. Máximo 3 rondas; si no hay consenso → escalar al Tech Lead o marcar como `?`

### Velocidad del refinement:
- Objetivo: estimar 10-15 items por sesión de 2h
- Si un item consume > 10 min → marcar como `?` y buscar más información

---

## 4. Descomposición de Work Items

### Cuándo descomponer un PBI:
- Story Points > 13 → **obligatorio** descomponer
- No se puede completar en un sprint → descomponer
- Más de una persona trabajaría en paralelo → descomponer en tasks independientes
- Implica tecnologías muy distintas (ej: frontend + backend + BD) → descomponer

### Reglas de descomposición de Tasks:
- Máximo **8 horas por task** (si supera → dividir)
- Cada task debe ser completamente independiente (sin bloqueos entre tasks del mismo PBI)
- Nomenclatura: `[AB#XXXX] Descripción del PBI > Descripción de la task`
- Asignar actividad (`Development`, `Testing`, `Documentation`) a cada task desde el inicio
- Total de horas de tasks ≥ StoryPoints * horas_referencia (sin reducción por factor de foco, que ya se aplica a la capacity)

---

## 5. Capacity Planning — Fórmula Oficial

```
Capacity por persona (h) = días_hábiles_sprint × horas_por_día × factor_foco

Donde:
  días_hábiles_sprint = días_laborables_del_sprint - días_off_personales - festivos_equipo
  horas_por_día       = 8 (o lo configurado en Azure DevOps para esa persona)
  factor_foco         = 0.75 (25% de overhead: reuniones, slack, interrupciones)

Ejemplo:
  Sprint 2 semanas = 10 días laborables
  Sin vacaciones ni festivos
  Capacity = 10 × 8 × 0.75 = 60 horas por persona
```

### Regla de sobre-compromiso:
- Nunca planificar más del **85% de la capacity total** del equipo
- El 15% restante es colchón para bugs urgentes, imprevistos y ceremonias extra

---

## 6. Mapping Story Points → Horas (para reporting económico)

Cuando el cliente o dirección pide un presupuesto o seguimiento económico en horas:

```
Horas estimadas por SP = velocity_media_horas / velocity_media_sp

Ejemplo:
  Media últimos 5 sprints:
    - Velocity media: 32 SP/sprint
    - Horas imputadas media: 520h/sprint (equipo de 4, sin festivos)
  Ratio: 520 / 32 = 16.25 h/SP

  Para un PBI de 5 SP → estimación económica: 5 × 16.25 = ~81 horas
```

> Este ratio debe recalcularse cada 5 sprints. Guardarlo en `projects/<proyecto>/CLAUDE.md`.

---

## 7. Re-estimación durante el Sprint

- **Permitido:** Ajustar `RemainingWork` de tasks en curso (es la estimación de lo que falta, no lo que se lleva)
- **No permitido:** Cambiar los Story Points de un PBI una vez que el sprint ha comenzado (distorsiona la velocity)
- **Excepción:** Si se descubre que la complejidad real es radicalmente diferente (factor > 2x), documentar la discrepancia en el work item y proponer re-estimación en la retro

---

## 8. Bugs — Estimación especial

- Los bugs se estiman en horas (no en SP) salvo que sean tan complejos que merezcan tratamiento de PBI
- Los bugs P1 entran al sprint sin pasar por Planning Poker; se estiman a posteriori
- Los bugs P2/P3 pasan por refinement normal antes de entrar al sprint
- Tiempo máximo de resolución por severidad:
  - P1 (Crítico): < 4 horas en producción
  - P2 (Alto): < 1 sprint
  - P3 (Medio/Bajo): puede acumularse en el backlog
