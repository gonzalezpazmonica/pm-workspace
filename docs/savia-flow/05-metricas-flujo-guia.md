# Métricas de Flujo: Guía Práctica
## DORA Metrics para Equipos de IA

**Autor:** Mónica González Paz, pm-workspace
**Fecha:** Marzo 2026
**Versión:** 1.0

---

## Por Qué Velocity Falla en Equipos de IA

### El Problema de Story Points

Velocity (puntos completados por sprint) asume:
1. Puntos son consistentes (un "5 point" siempre es igual esfuerzo)
2. Predicción es posible (historial predice futuro)
3. Esfuerzo correlaciona con valor (más puntos = más valor)

**Realidad con IA:**

```
Semana 1: Team completa 35 points
├─ "Agregar campo de búsqueda": 5 points (AI en 1 hora)
├─ "Refactor authentication": 8 points (AI en 2 horas)
├─ "Build reporting dashboard": 22 points (AI en 4 horas)

Semana 2: Team completa 12 points
├─ "Optimize database query": 5 points (6 horas de debugging manual)
├─ "Fix race condition": 7 points (2 hours finding, 1 hour fix)

Problem: 35 vs 12 no es comparable.
En Semana 1: IA fue muy útil (70%+ time saved)
En Semana 2: IA fue inútil (manual work was critical)

Velocity es opaco. No predice nada. Es un número que inspira confianza falsa.
```

### La Crisis de Gameabilidad

```
Un equipo "optimiza" velocity:
├─ Infla puntos ("que sea 13 en lugar de 8")
├─ Elige features fáciles (evita complejas)
├─ Declara "completo" aunque necesita rework
└─ Velocity crece, pero valor no

Stakeholders ven: "Velocity = 50! Somos 2x más rápido que hace 6 meses!"
Realidad: "Somos igual de rápido, pero gaming la métrica"

Con IA, es aún más fácil:
├─ IA genera 1000 líneas de código
├─ "Debe ser al menos 20 points!"
├─ Pero 60% requiere reescritura
└─ Game es obvio a expertos, pero no a gestión no-técnica
```

### Por Qué DORA Metrics son Superiores

DORA metrics miden **resultado**, no **esfuerzo**:

| Métrica | Qué Mide | Gameable? |
|---------|----------|-----------|
| Story Points | Esfuerzo percibido | Sí (muy) |
| Cycle Time | Días a producción | No (es un hecho) |
| Lead Time | Días idea → producción | No (es un hecho) |
| Throughput | Items entregados | No (es un hecho) |
| CFR | % de deploys problemáticos | Difícil (requiere esconder bugs) |

---

## Las 4 Métricas Primarias Explicadas

### 1. Cycle Time

**Definición:** Días desde que trabajo **comienza** hasta que está en **producción**

```
Timeline:
Monday 9am: "Ok, vamos a construir Feature X" → Comienza building
Friday 5pm: Feature X está en producción
Cycle Time = 5 días

Incluye:
✓ Implementación (coding, testing)
✓ Quality gates (CI/CD checks)
✓ Human review (si existe)
✗ Waiting for requirements (no, porque spec debe estar ready)
✗ Waiting in queue (no, porque capacidad es limitada)
```

**Cómo Medir:**

```sql
SELECT
  feature_id,
  DATE(completed_at) - DATE(started_at) as cycle_days
FROM features
WHERE status = 'deployed'
ORDER BY completed_at DESC
LIMIT 100;

-- Calculate average:
SELECT AVG(cycle_days) FROM (...)
```

**Target para Savia Flow:** 3-7 días
**Elite DORA performers:** <1 día

**Por qué importa:**
- Feedback más rápido = correcciones más rápidas
- Usuarios ven features antes
- Risk es menor (cambios pequeños)
- Team morale mejora (trabajo visible rápido)

### 2. Lead Time

**Definición:** Días desde que idea es **propuesta** hasta que está en **producción**

```
Timeline:
Monday semana 1 9am: PM propone "Feature X"
Friday semana 2 5pm: Feature X está en producción
Lead Time = 8 días

Incluye:
✓ Exploration (descubrir qué construir)
✓ Specification (escribir spec)
✓ Implementation (building)
✓ Quality gates
✓ Any waiting time
✗ Waiting for prioritization (no, asumimos prioritization es instantáneo)
```

**Cómo Medir:**

```sql
SELECT
  feature_id,
  DATE(deployed_at) - DATE(proposed_at) as lead_days
FROM features
WHERE status = 'deployed'
ORDER BY deployed_at DESC;

SELECT AVG(lead_days) FROM (...);
```

**Target para Savia Flow:** 7-14 días
**Elite DORA performers:** <1 día

**Por qué importa:**
- Muestra velocidad real (idea a impacto)
- Identifica cuellos de botella
- Lead time largo = feedback loop lento = mala toma de decisiones

**Lead Time vs Cycle Time:**

```
Lead Time = Idea → Producción (todo)
Cycle Time = Build → Producción (no exploration, no spec)

Lead Time = Exploration time + Spec time + Cycle Time

Si Lead Time es 8 días y Cycle Time es 4 días:
Exploration + Spec time = 4 días

Si Lead Time es 14 días y Cycle Time es 4 días:
Exploration + Spec time = 10 días ← Problema! Spec es lenta
```

### 3. Throughput

**Definición:** Número de features completados (deployed) por unidad de tiempo

```
Medición (semanal):
Week 1: 8 features deployed
Week 2: 9 features deployed
Week 3: 7 features deployed
Week 4: 10 features deployed

Throughput promedio: (8+9+7+10)/4 = 8.5 features/semana

Medición (mensual):
Month 1: 35 features deployed
Month 2: 36 features deployed
Month 3: 34 features deployed

Throughput promedio: 35 features/mes
```

**Cómo Medir:**

```sql
SELECT
  DATE_TRUNC('week', deployed_at) as week,
  COUNT(*) as features_deployed
FROM features
WHERE status = 'deployed'
GROUP BY DATE_TRUNC('week', deployed_at)
ORDER BY week DESC;
```

**Target para Savia Flow:** 8-12 features/semana
**Elite DORA performers:** 5+ features/día

**Por qué importa:**
- Predice cuánto deliveras en período fijo
- Si planificas 100 features, sabes cuándo estarán hechas
- Muestra si team es sobre-comprometido (throughput consistente es saludable)

**Relación con Cycle Time:**

```
Cycle Time corto → Throughput debe subir
Cycle Time largo → Throughput debe bajar

Si Cycle Time es 4 días:
Capacity = 5 builders × 5 days/week ÷ 4 days/feature
         = 6.25 features/week

Si Cycle Time es 10 días:
Capacity = 5 builders × 5 days/week ÷ 10 days/feature
         = 2.5 features/week
```

### 4. Change Failure Rate (CFR)

**Definición:** % de features desplegadas que causan incident, rollback, o hotfix

```
Medición (semanal):
Week 1: 8 features deployed
        1 requería rollback (incident inmediato)
        CFR = 1/8 = 12.5%

Week 2: 9 features deployed
        0 incidentes
        CFR = 0/9 = 0%

Week 3: 7 features deployed
        1 hotfix (bug encontrado post-deploy)
        CFR = 1/7 = 14.3%

Promedio: (12.5% + 0% + 14.3%) / 3 = 8.9% CFR
```

**Cómo Medir:**

```sql
SELECT
  COUNT(DISTINCT CASE WHEN had_incident THEN feature_id END) as incidents,
  COUNT(*) as total_deployed,
  ROUND(100.0 * COUNT(DISTINCT CASE WHEN had_incident THEN feature_id END) / COUNT(*), 2) as cfr_percent
FROM features
WHERE status = 'deployed'
  AND deployed_at >= NOW() - INTERVAL '4 weeks';
```

**Target para Savia Flow:** <5%
**Elite DORA performers:** <15% (pero deploy muy frecuentemente, mitigando risk)

**Por qué importa:**
- Alto CFR significa quality es problema
- Bajo CFR significa quality gates funcionan
- Permite medir impacto de mejoras (new gate agent → CFR baja)

**Incidente vs Hotfix:**

```
Incidente = Feature se rompe → Usuario experimenta problema → Rollback inmediato
Hotfix = Bug menor → Fixed sin rollback → Shipped mismo día

Ambos cuentan como failure rate.
```

---

## Cómo Medir Cada Métrica: Setup Práctico

### Step 1: Definir "Deployed"

¿Qué significa que algo está "deployed"?

```
Opción A (Strict): Código está en producción y usuario puede ver
├─ Feature flag está ON (o no existe)
├─ User ha visto/interactuado
├─ No en private beta

Opción B (Lenient): Código está en producción
├─ Incluso si feature flag es OFF
├─ Incluso si solo internal testing
├─ "Deployed" = "in codebase"

Recomendación: Opción A (strict)
Porque Opción B inflates números (code puede estar "deployed" pero nunca visible)
```

### Step 2: Definir "Started" para Cycle Time

¿Cuándo comienza el clock?

```
Opción A: Cuando spec está 100% ready
├─ Pro builder comienza a leer spec
├─ Begin trabajo arquitectónico
├─ Empieza prompting de IA

Opción B: Cuando PR es abierto
├─ Comienza code review
├─ QA gates comienzan

Opción C: Cuando builder "intenta" comenzar (loose)
├─ Cuando dicen "voy a trabajar en esto"
├─ Poco preciso

Recomendación: Opción A (spec ready)
Porque tiempo antes de que spec esté ready is "lead time", no "cycle time"
```

### Step 3: Setup Tracking

**Manual (Low Tech):**
```
Spreadsheet:
Feature | Proposed | Spec Ready | Build Start | Deployed | Cycle | Lead
--------|----------|-----------|------------|----------|-------|-----
Login   | 1/1      | 1/5       | 1/6        | 1/10     | 4d    | 9d
Search  | 1/1      | 1/6       | 1/7        | 1/12     | 5d    | 11d
```

**Automated (Better):**
```
GitHub: Use labels + milestones
├─ Label "cycle-start": Agrega cuando building comienza
├─ Label "deployed": Agrega cuando en producción
├─ Calculate: deployed date - cycle-start date

Jira: Use status transitions
├─ Status "Ready for Build"
├─ Status "In Development"
├─ Status "Deployed"
├─ Calculate automatically

Better yet: Use Grafana + Prometheus
├─ Query CI/CD logs
├─ Extract deploy timestamps
├─ Calculate automatically
```

### Step 4: Create Dashboard

**Minimal (Google Sheets):**
```
┌─────────────────────────────────────────┐
│ Team Metrics - Last 4 Weeks             │
├─────────────────────────────────────────┤
│ Cycle Time (avg): 4.2 days              │
│ Lead Time (avg): 9.8 days               │
│ Throughput: 8.3 features/week           │
│ CFR: 4.2%                               │
│                                         │
│ [Trend graph]                           │
└─────────────────────────────────────────┘
```

**Better (Grafana/Datadog):**
```
Real-time dashboard:
├─ Cycle time trend (7, 14, 30 day)
├─ Throughput by week
├─ CFR trend
├─ WIP (items in progress)
├─ Deployment frequency
├─ MTTR (mean time to recovery)
└─ Automated alerts (if cycle time > threshold)
```

---

## Benchmarks por Madurez de Equipo

### Equipo Nuevo en Savia Flow (Semanas 1-4)

| Métrica | Baseline (Scrum) | Week 2 | Week 4 | Nota |
|---------|---|---|---|---|
| Cycle Time | 18d | 12d | 7d | Rápida mejora |
| Lead Time | 30d | 24d | 15d | Specs se vuelven claras |
| Throughput | 5 items/w | 5 items/w | 7 items/w | Comienza a mejorar |
| CFR | 15% | 12% | 8% | Gates se sincronizan |

### Equipo Intermedio (Mes 2-3)

| Métrica | Target | Alcanzable | Nota |
|---------|--------|-----------|------|
| Cycle Time | 4-6 d | Sí (5.2d) | Specs claras, gates smooth |
| Lead Time | 8-12 d | Sí (10.1d) | Exploration se optimiza |
| Throughput | 8-10 items/w | Sí (8.7/w) | Team rhythm estable |
| CFR | <5% | Sí (3.8%) | Gates efectivos |

### Equipo Avanzado (Mes 4+)

| Métrica | Elite Target | Alcanzable | Nota |
|---------|---|---|---|
| Cycle Time | 2-4 d | Posible (3.1d) | Con IA optimization |
| Lead Time | 5-8 d | Posible (6.5d) | Exploration rápida |
| Throughput | 12-15 items/w | Posible (12.4/w) | Full IA collaboration |
| CFR | <3% | Posible (1.8%) | Specialized agents |

---

## Diseño de Dashboard Recomendado

### Dashboard Nivel 1: Team Daily

```
┌──────────────────────────────────────────────────┐
│ Pro Builders Alpha - Daily Standup               │
│ Last 7 Days                                      │
├──────────────────────────────────────────────────┤
│                                                  │
│ Cycle Time:     4.2 days        ↓ (improving)   │
│ Items in WIP:   3 / 5 limit      → (healthy)    │
│ Blocked items:  0                → (good)       │
│                                                  │
│ Items deployed this week: 8                      │
│ Oldest item in progress: 2 days (normal)        │
│                                                  │
│ [Simple trend graph]                             │
│                                                  │
│ Top blocker: None                                │
│                                                  │
└──────────────────────────────────────────────────┘
```

### Dashboard Nivel 2: Leadership Monthly

```
┌──────────────────────────────────────────────────────┐
│ Engineering Organization - Monthly Review           │
│ March 2026                                           │
├──────────────────────────────────────────────────────┤
│                                                      │
│ Overall Metrics:                                     │
│ ├─ Cycle Time (avg): 4.5d    (was 18d, -75%)       │
│ ├─ Lead Time (avg): 10.2d    (was 30d, -66%)       │
│ ├─ Throughput: 8.3 items/w   (was 5/w, +66%)       │
│ ├─ CFR: 3.8%                 (was 15%, -75%)       │
│ └─ MTTR: 45 min              (was 4 hrs, -81%)     │
│                                                      │
│ By Team:                                             │
│ ├─ Pro Builders Alpha:  4.2d cycle, 8.7/w output   │
│ ├─ AI QA Team:          3.8d cycle, 9.1/w output   │
│ ├─ Platform:            5.2d cycle, 6.8/w output   │
│ └─ DevOps:              2.1d cycle, 12.4/w output  │
│                                                      │
│ Risk Assessment:        GREEN (all metrics in range) │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### Dashboard Nivel 3: Eng Manager Coaching

```
┌──────────────────────────────────────────────────────┐
│ Flow Facilitator Analysis - Weekly                   │
│ Focus: Why is cycle time at 5d instead of 4d?       │
├──────────────────────────────────────────────────────┤
│                                                      │
│ This Week's Items (Analysis):                        │
│ ├─ Feature A: 4d (normal)       ✓                    │
│ ├─ Feature B: 3d (fast!)        ✓✓                   │
│ ├─ Feature C: 7d (slow)         ✗  [INVESTIGATE]   │
│ ├─ Feature D: 6d (slow)         ✗  [INVESTIGATE]   │
│ └─ Feature E: 4d (normal)       ✓                    │
│                                                      │
│ Root Cause Analysis (Features C & D):               │
│ Feature C:                                           │
│ ├─ Days 1-3: Quality gates issues (spec had gap)   │
│ ├─ Days 4-7: Waiting for decisión on architecture  │
│ └─ Fix: Earlier spec review, faster arch decisions │
│                                                      │
│ Feature D:                                           │
│ ├─ Days 1-2: Building smooth                        │
│ ├─ Days 3-6: Stuck in Level 4 gate (security)      │
│ └─ Fix: Security agent had false positive. Fixed.  │
│                                                      │
│ Action Items:                                        │
│ ├─ [ ] Improve spec review process                  │
│ ├─ [ ] Tune security agent thresholds              │
│ └─ [ ] Architecture decisions SLA: <4 hours         │
│                                                      │
└──────────────────────────────────────────────────────┘
```

---

## Métrica Adicional: IA-Específicas

### AI Code Coverage

**Definición:** % de líneas de código generadas por IA vs. manualmente

```
Medición:
Feature A:
├─ IA generated: 450 líneas
├─ Human written: 50 líneas
├─ Human refined (from IA): 30 líneas
└─ Coverage: (450) / (450+50+30) = 81% IA

Team Average: 55% IA code
```

**Target:** 40-70%
- <40%: IA no está siendo usada efectivamente
- 40-70%: Optimal (IA genera, humanos curan)
- >70%: Posible over-reliance, may have gaps

### AI Quality Score (Defect Rate)

**Definición:** % de IA-generated code que pasa gates en 1st attempt

```
Medición:
Week 1: 10 IA outputs
├─ 8 pasaron gates en 1st attempt
├─ 2 requirieron fixes
└─ Score: 80%

Target: >70%
<60%: IA prompts need improvement, or gates too strict
>85%: Maybe gates too lenient?
```

### Rework Rate

**Definición:** % de features que requieren revisión/reescritura

```
Medición:
Features deployed (last month): 30
Features requiring hotfix or rework: 5
Rework rate: 5/30 = 16.7%

Target: <15%
>20%: Quality issue, specs unclear, gates not working
<10%: Excellent (pero posible under-testing)
```

---

## Alertas Recomendadas

Configura estas alertas en tu dashboard:

```
Alert 1: Cycle Time Spike
├─ If avg cycle time > 8 days (2x target)
├─ Action: Flow Facilitator investigates
└─ Example: "Why did it jump to 9 days this week?"

Alert 2: CFR Spike
├─ If CFR > 10% (2x target)
├─ Action: Quality Architect reviews recent features
└─ Example: "3 of 5 features had issues. Why?"

Alert 3: Throughput Drop
├─ If throughput < 6 items/week (below baseline)
├─ Action: Check for blockers, tech debt
└─ Example: "Team delivered only 5 items. What's blocking?"

Alert 4: Lead Time Growing
├─ If lead time > 15 days (increasing from 10d)
├─ Action: Review exploration/spec process
└─ Example: "Specs are taking 2 weeks. Too slow."

Alert 5: WIP Limit Exceeded
├─ If items in progress > limit (usually 5)
├─ Action: Finish before starting new work
└─ Example: "7 items in progress. Stop starting, start finishing."
```

---

## Cómo Usar Métricas para Tomar Decisiones

### Ejemplo 1: ¿Necesitamos más builders?

```
Current state:
├─ Throughput: 8 items/week
├─ Wanted throughput: 12 items/week (50% más)
├─ Current team: 5 builders
├─ Cycle time: 4.2 days

Analysis:
├─ To get 12 items/week with same cycle time: need 7.5 builders
├─ Or: Reduce cycle time to 2.8 days with 5 builders

Decisión:
├─ Option A: Hire 2 more builders (expensive)
├─ Option B: Reduce cycle time (specs faster? gates faster?)
├─ Option C: Accept 8 items/week (demand management)

Recommendation:
Try Option B first. Invest in spec speed (AI assistance?),
optimize gates, then measure.
```

### Ejemplo 2: ¿Gates son demasiado estrictos?

```
Current state:
├─ CFR: 1.2% (excellent)
├─ Gate pass-through: 45% (only 45% pass on 1st attempt)
├─ Team complaints: "Gates are too strict, slowing us down"

Analysis:
├─ 1.2% CFR is excellent (target is <5%)
├─ But 45% pass-through suggests over-strictness
├─ Are gates catching real issues or false positives?

Investigation:
├─ Review last 10 rejections
├─ How many were actual bugs? (probably <50%)
├─ How many were false positives? (probably >50%)

Decisión:
├─ Tune gates to reduce false positives
├─ Keep actual bug detection
├─ Target: 75% pass-through while maintaining <5% CFR
```

### Ejemplo 3: ¿Spec process es demasiado lento?

```
Current state:
├─ Lead time: 14 days
├─ Cycle time: 4.5 days
├─ Spec + Exploration time: 14 - 4.5 = 9.5 days

Problem:
├─ Specs están tomando 9.5 days
├─ Should be 3-4 days

Analysis:
├─ What's causing delay?
├─ Unclear requirements? (user research needed)
├─ Approval bottleneck? (who's approving?)
├─ Spec writing too detailed? (reduce to essence)
├─ IA could help? (use Claude for drafting)

Decisión:
├─ Option A: Use IA to draft specs (1h → 30 min)
├─ Option B: Parallel discovery (don't wait for perfect info)
├─ Option C: Smaller specs (scope less, spec faster)

Recommendation: Combine A + B. Measure impact. Target 5-day lead time.
```

---

## Conclusión

Las 4 métricas DORA + 3 adicionales IA-specific te dan visibilidad completa:

| Métrica | Qué Responde |
|---------|-------------|
| Cycle Time | ¿Cuánto tarda construir? |
| Lead Time | ¿Cuánto tarda completamente (idea → producción)? |
| Throughput | ¿Cuánto deliveramos por semana? |
| CFR | ¿Qué tan buena es la calidad? |
| AI Coverage | ¿Cuánto está IA ayudando? |
| Rework Rate | ¿Cuánto retrabajo necesitamos? |

Usa estas métricas para:
- ✓ Identificar cuellos de botella
- ✓ Tomar decisiones data-driven
- ✓ Medir impacto de cambios
- ✓ Comunicar rendimiento a leadership

---

**Comienza a medir hoy. Los datos iluminan el camino.**
