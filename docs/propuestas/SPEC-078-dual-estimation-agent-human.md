---
id: SPEC-078
status: IMPLEMENTED
priority: alta
applied_at: "2026-04-04"
implemented_at: "2026-04-25"
era: 187
---

# SPEC-078: Dual Estimation — Agent-Time vs Human-Time

**Status:** IMPLEMENTED | **Priority:** HIGH | **Era:** 179+ | **Author:** Savia (auditoria 2026-04-04)

---

## Problema

pm-workspace estima todas las tareas con un solo valor en horas. Pero un agente tarda minutos en lo que un humano tarda horas (CRUD, tests, traducciones), y un humano decide en segundos lo que un agente no puede resolver ni con horas de contexto (arquitectura novel, arbitraje de requisitos ambiguos).

**Dato clave:** La auditoria del 2026-04-04 estimo "33h" de trabajo correctivo. Un agente ejecuto las correcciones de contadores en 9 READMEs en <2 minutos. La PM no tiene forma de saber que vale la pena delegar y que no.

**Investigacion de soporte:**
- METR RCT (246 tareas, 16 devs senior): AI tools hicieron a los devs 19% MAS LENTOS, pese a percibir 20% de mejora (gap de percepcion del 39%)
- Agents completan trabajo rutinario 88% mas rapido, con gaps de calidad significativos
- Claude Code: 80.8% SWE-bench, ~4% commits GitHub (~135K/dia)
- Ratio sostenible de codigo AI: 25-40% antes de que la calidad degrade
- No existe ningun framework formal de estimacion dual agent/human publicado

---

## Propuesta: 3 Dimensiones de Estimacion

Cada tarea se estima en 3 ejes:

```
agent_effort_minutes:  15    # Tiempo real de ejecucion del agente
human_effort_hours:    4     # Tiempo equivalente si lo hiciera un humano
review_effort_minutes: 30    # Tiempo de revision humana del output del agente
```

### Por que minutos para agentes y horas para humanos

Los agentes operan en escala de minutos (2-30 min tipico). Los humanos en escala de horas (1-8h tipico). Usar la misma unidad crea confusion: "2h" para un agente es una eternidad, para un humano es razonable.

### Factor de contexto del agente

```
context_risk: low | medium | high | exceeds

low:     tarea cabe en <30% del context window
medium:  tarea cabe en 30-60% del context window
high:    tarea requiere 60-85% (calidad degrada)
exceeds: tarea NO cabe — requiere slicing o humano
```

Referencia: TurboQuant (arXiv:2504.19874) — calidad degrada gradualmente a partir del 60-70%.

---

## Matriz de Decision PM

| Tipo de tarea | Agent min | Human h | Review min | Context risk | Recomendacion |
|---------------|-----------|---------|------------|--------------|---------------|
| CRUD endpoint | 5-10 | 2-4 | 15 | low | Agent (5-10x mas rapido) |
| Tests unitarios | 10-20 | 3-6 | 15 | low | Agent (boilerplate) |
| Traduccion docs | 3-5 | 4-8 | 10 | low | Agent (mecanico) |
| Bug fix simple | 10-30 | 1-2 | 20 | medium | Agent (si patron claro) |
| Refactor grande | 30-60 | 4-8 | 45 | high | Humano (contexto cruzado) |
| Diseno arquitectura | N/A | 4-16 | N/A | exceeds | Humano (juicio experto) |
| Code review | N/A | 1-2 | N/A | N/A | SIEMPRE humano (E1) |
| Security audit | 15-30 | 8-16 | 60 | medium | Agent + humano (pipeline) |
| Correccion contadores | 1-2 | 1-2 | 5 | low | Agent (mecanico, 100x) |
| Decisiones de negocio | N/A | 1-4 | N/A | exceeds | SIEMPRE humano |

### Regla de oro

```
Si agent_minutes < human_hours x 10 Y context_risk <= medium Y no requiere juicio:
  -> Delegar a agente, reservar review_minutes de humano
Si no:
  -> Humano implementa
```

---

## Campos en Spec SDD

Seccion obligatoria en template de spec:

```markdown
## Effort Estimation (Dual Model)

| Dimension | Value |
|-----------|-------|
| Agent effort | XX min |
| Human effort | XX h |
| Review effort | XX min |
| Context risk | low / medium / high / exceeds |
| Agent-capable | yes / no / partial |
| Fallback plan | Si agente falla: humano necesita Xh desde cero |
```

---

## Campos en PBI/Task

### Para Azure DevOps (custom fields)

| Campo | Tipo | Descripcion |
|-------|------|-------------|
| Custom.AgentEffortMin | Integer | Minutos estimados para agente |
| Custom.HumanEffortHours | Decimal | Horas estimadas para humano |
| Custom.ReviewEffortMin | Integer | Minutos de revision humana |
| Custom.ContextRisk | String | low / medium / high / exceeds |
| Custom.AgentCapable | Boolean | true si la tarea es delegable |
| Custom.ActualAgentMin | Integer | Minutos reales del agente |
| Custom.ActualHumanHours | Decimal | Horas reales del humano |

OriginalEstimate se mantiene como "esfuerzo total equivalente en horas humanas" para compatibilidad.

### Para Savia Flow (YAML frontmatter)

```yaml
agent_effort_min: 10
human_effort_h: 3
review_effort_min: 15
context_risk: low
agent_capable: true
```

---

## Insight critico: Review Bottleneck

Los agentes generan carga de revision humana. Cada tarea delegada consume review_minutes del humano.

```
human_net_capacity = human_capacity - sum(review_minutes_all_agent_tasks)
```

Si review_load > 30% de human_capacity: los humanos pasan mas tiempo revisando que implementando. Alerta de bottleneck.

---

## Formulas de Capacity Planning

```
# Humana (existente, no cambia)
human_capacity_h = (dias_habiles - dias_off) x 8 x 0.75

# Agentes (nueva)
agent_capacity_tasks = MAX_PARALLEL x (sprint_hours x 60 / avg_task_min)
agent_review_load_h  = agent_capacity_tasks x avg_review_min / 60
human_net_capacity_h = human_capacity_h - agent_review_load_h
```

---

## Metricas nuevas

- **Agent utilization:** tasks_agent / total_tasks
- **Review bottleneck:** sum(review_min) / human_capacity_h
- **Agent accuracy:** approved_first_try / sent_to_agent
- **Delegation ROI:** (human_hours_saved x rate) / agent_cost
- **Velocity dual:** SP_agent / sprint vs SP_human / sprint

---

## Implementacion por fases

### Fase 1 — Template + campos
- Agente: 20 min | Humano: 2h | Review: 15 min
- Anadir seccion dual al spec-template y pbi-decompose

### Fase 2 — Auto-estimacion
- Agente: 30 min | Humano: 3h | Review: 30 min
- Heuristicas basadas en assignment-matrix + task type
- Context risk auto-calculado desde spec size

### Fase 3 — Tracking + metricas
- Agente: 30 min | Humano: 4h | Review: 30 min
- Dashboard dual en /sprint-review
- Calibracion con datos reales (feedback loop)

### Fase 4 — Capacity planning dual
- Agente: 20 min | Humano: 3h | Review: 20 min
- Review bottleneck alerts
- Sprint autoplan con balance agent/human

---

## Fuentes

- METR Task-Completion Time Horizons (metr.org/time-horizons/)
- METR RCT 2025: AI devs 19% slower (metr.org/blog/2025-07-10)
- Anthropic Agentic Coding Trends Report 2026
- TurboQuant (arXiv:2504.19874) — context degradation curves
- Factory.ai: The Context Window Problem
- Martin Fowler: Humans and Agents in SE Loops
- AI Code Benchmarks 2026 (blog.exceeds.ai)

---

## Hook: dual-estimation-gate (Fase 1)

### Proposito

Hook PostToolUse (Edit|Write) que detecta cuando se escribe o modifica una spec (.spec.md) o PBI (backlog/pbi/*.md, backlog/task/*.md) que contiene alguna estimacion de esfuerzo, y verifica que la estimacion incluye las dos escalas (agent + human). Si falta una escala, emite un warning solicitando completarla antes de continuar.

### Trigger

- **Evento:** PostToolUse
- **Matcher:** Edit|Write
- **Filtro de ficheros:** Solo actua en *.spec.md, */backlog/pbi/*.md, */backlog/task/*.md
- **Profile tier:** standard

### Logica de deteccion

1. Extraer file_path del JSON de input del hook
2. Filtrar: solo ficheros spec/PBI/task (por extension y ruta)
3. Leer contenido del fichero
4. Detectar si hay ALGUNA estimacion (regex: effort|esfuerzo|estimat|hours|horas|minutes|minutos)
5. Si NO hay estimacion: exit 0 silencioso (draft temprano, no forzar)
6. Si HAY estimacion: verificar presencia de ambas escalas:
   - Agent scale: agent.*(effort|min)|agent_effort|agente.*(esfuerzo|min)
   - Human scale: human.*(effort|hour|hora)|human_effort|humano.*(esfuerzo|hora)
7. Si ambas presentes: exit 0 (todo OK)
8. Si falta alguna: warning con indicacion de que escala falta

### Output del warning

```
Dual Estimation Gate: {filename} tiene estimacion pero falta escala {missing}.

  Toda spec/PBI con estimacion necesita las dos escalas:
    agent_effort_minutes:  XX   (tiempo real del agente)
    human_effort_hours:    XX   (tiempo equivalente humano)
    review_effort_minutes: XX   (revision humana del output)
```

### Comportamiento

- NO bloquea (exit 0 siempre) — es un warning, no un gate
- Solo se dispara si el fichero ya contiene alguna estimacion
- No se dispara en drafts sin estimacion (no interrumpir flujo creativo)
- Compatible con hook profiles: tier standard (activo en standard, strict, ci)

### Evolucion futura (Fase 2+)

- Fase 2: promover a soft-block (exit 2) para specs en estado Ready o Approved
- Fase 3: auto-sugerir valores basandose en assignment-matrix y task type
- Fase 4: validar coherencia entre agent_minutes y human_hours (ratios imposibles)

### Registro en settings.json

Ubicacion: PostToolUse, matcher Edit|Write, junto a los hooks existentes. Timeout: 5s. Async: false (debe mostrar warning antes de que el usuario continue).

## Resolution (2026-04-25)

**Status drift correction.** SPEC-078 Fase 1 (template + fields + hook) fue implementado en Era 179 pero el status del spec quedó en PROPOSED. Verificación 2026-04-25 confirma deliverables presentes:

### Files delivered (Fase 1 MVP)

- `scripts/dual-estimate.sh` — engine CLI con subcomandos `classify`, `capacity`, `bottleneck`, `matrix`, `help`. Clasifica task types (crud, tests, translation, bugfix, refactor, architecture, code-review, security-audit, counter-fix, business-decision) y recomienda agent vs human.
- `tests/test-dual-estimate.bats` — certified score 82.
- `.opencode/hooks/dual-estimation-gate.sh` — PostToolUse warning hook (no bloquea, solo avisa cuando spec/PBI tiene estimación pero falta una de las 3 escalas).
- `docs/politica-estimacion.md` — política dual extendida con ejemplos.

### Coverage verification

Hook activo en sesiones standard tier. Verificado en uso: warnings emitidos cuando agent_effort_minutes/human_effort_hours/review_effort_minutes parcialmente presentes.

### Acceptance criteria final (Fase 1 MVP)

- [x] Engine CLI funcional con clasificación + capacity planning + bottleneck detection
- [x] Hook gate Phase 1 (warning-only, no bloquea)
- [x] Política documentada con regla de oro y matriz de decisión
- [x] Tests certified ≥80 (score 82)
- [x] Compatible con hook profiles (tier standard)

### Fases futuras (NO bloquean status)

Las Fases 2-4 (auto-estimación, tracking, capacity dual) son evolución gradual. Status IMPLEMENTED corresponde al MVP Fase 1 funcional. Las fases siguientes serán specs separados cuando haya señal de uso suficiente.

### Era

Implementación inicial Era 179 (auditoría correctiva), status flip Era 187 (drift correction).
