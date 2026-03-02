# Comparativa: Scrum vs. Savia Flow
## Guía para Gestores de Proyectos en Transición

**Autor:** Mónica González Paz, pm-workspace
**Fecha:** Marzo 2026
**Versión:** 1.0

---

## Resumen Ejecutivo

Scrum ha sido excelente para equipos completamente humanos durante 20 años. Sin embargo, con IA generativa, introduce fricción que ralentiza entrega y reduce transparencia. Savia Flow es su evolución natural para equipos aumentados por IA.

**Pregunta clave:** ¿Colabora tu equipo con IA o no?
- Si no: Scrum sigue siendo válido (pero considera evolucionar)
- Si sí: Savia Flow es más adecuado

---

## Comparación Dimensión por Dimensión

### 1. Contenedor de Tiempo

| Aspecto | Scrum | Savia Flow |
|--------|-------|-----------|
| **Unidad de trabajo** | Sprint (2 semanas) | Flujo continuo + ciclos de outcome (2-7 días) |
| **Ritmo** | Rígido (sprints fijos) | Flexible (respeta flujo natural) |
| **Predecibilidad** | Alta (trabajo estimado) | Alta (métricas de ciclo de tiempo) |
| **Velocidad ajustable** | Sí (planificación/sprint) | Sí (priorización, WIP limits) |
| **Con IA** | Problemático (velocidad variable) | Ideal (métrica natural de flujo) |

**Ejemplo:**
```
Scrum: Feature X estimada 5 puntos → Entra a sprint de 2 semanas
       IA la termina en 12 horas. Pero "debe esperar" a fin de sprint.

Savia Flow: Feature X en backlog → Comienza cuando ready
            IA termina en 12 horas → Quality gates (4 horas)
            Deploy al día siguiente. Feedback inmediato.
```

**Veredicto:** Savia Flow gana para equipos con IA.

---

### 2. Ceremonias

| Ceremonia | Scrum | Savia Flow |
|-----------|-------|-----------|
| **Sprint Planning** | Semanal, 4 horas | Continuo, async (specs escritas) |
| **Daily Standup** | Diario, 15 minutos | Dashboard continuo, no meetings |
| **Sprint Review** | Bisemanal, 1.5 horas | Demo cuando está ready, continuo |
| **Sprint Retro** | Bisemanal, 1.5 horas | Monthly + feedback loops continuos |
| **Refinement** | 2-4 horas/semana | Integrado en exploration track |
| **Total horas/semana** | ~9-12 horas | ~1-2 horas |

**Impacto de tiempo:**

```
Equipo de 10 personas, Scrum:
- Planning: 4 hrs
- Dailies: 2.5 hrs (15 min × 10 días)
- Review: 1.5 hrs
- Retro: 1.5 hrs
- Refinement: 4 hrs
Total: 13.5 hrs/semana = 540 hrs/año

Equipo de 10 personas, Savia Flow:
- Async stand-in (dashboard): 0 hrs
- Meetings asincrónicas: 1-2 hrs
- Monthly retro: 1.5 hrs (vs bisemanal)
Total: 10-20 hrs/año

Ahorro anual: 520 horas = ~$65,000 en salarios
```

**Veredicto:** Savia Flow gana dramáticamente en eficiencia de tiempo.

---

### 3. Especificación de Trabajo

| Aspecto | Scrum | Savia Flow |
|---------|-------|-----------|
| **Formato** | User stories ("As a..., I want...") | Especificaciones ejecutables |
| **Detalles técnicos** | Débiles (detalles emergen) | Fuertes (predefinidos) |
| **Ambigüedad** | Aceptable (team resuelve) | Minimizada (spec es contrato) |
| **Facilita IA** | No (narrativas vagas) | Sí (precisión = IA happiness) |
| **Reduce rework** | ~30-40% rework | ~10-15% rework |

**Ejemplo:**

```
Scrum User Story:
"As a customer, I want to search by price range
so that I find affordable products."

Acceptance Criteria:
- Slider component appears on search page
- Range is 0-1000 (currency?)
- Applied when user moves slider

Issues: No spec técnica. Builders preguntan:
- ¿Qué moneda? ¿USD, EUR, otro?
- ¿Exactamente 0-1000 o máximo dinámico?
- ¿Qué pasa si usuario ingresa manualmente?
- ¿Performance si 100K productos en rango?

Resultado: 2-3 iteraciones, 5-7 días total.

Savia Flow Spec:
"Help customers find products in their budget"

Success Metrics:
- Conversion: +8% (baseline 3.2%)
- Time to result: <2 seconds
- Feature used by 20%+ of search users

Functional:
- Range slider: $0 to max(product_price)
- Dynamic bounds based on filtered results
- Re-filter on change (not wait for click)
- Mobile: Input field instead slider

Technical:
- Debounce slider changes 300ms
- Use indexed DB queries (<100ms)
- Cache price buckets

Issues: Spec es clara. IA la entiende.
Resultado: 1 iteración, 3-4 días total.
```

**Veredicto:** Savia Flow gana con IA.

---

### 4. Métricas

| Métrica | Scrum | Savia Flow |
|---------|-------|-----------|
| **Primaria** | Velocity (puntos/sprint) | Cycle time (días) |
| **Secundarias** | Burndown | Lead time, throughput, CFR |
| **Gameable** | Sí (inflar puntos) | No (basadas en hechos) |
| **Correlaciona con valor** | Débil | Fuerte |
| **Con IA** | Falla (variabilidad alta) | Excelente |
| **Predice rendimiento** | Débil | Fuerte (DORA correlated) |

**Comparación de Métricas:**

```
Scrum - Velocity:
Week 1: 35 points completed (velocity = 35)
Week 2: 38 points completed (velocity = 38)
Week 3: 32 points completed (velocity = 32)
Promedio: 35 points/sprint

Problem: 35 points ¿es rápido? ¿es lento? Sin contexto, es opaco.
Con IA, 35 puede ser "2 features complejas" o "10 features triviales".

Savia Flow - Cycle Time:
Week 1: 8 items deployed, avg cycle = 4.2 days
Week 2: 9 items deployed, avg cycle = 3.8 days
Week 3: 10 items deployed, avg cycle = 4.5 days
Trend: Cycle time stable (~4.2 days), throughput mejora (+25%)

Clarity: Sabemos que items toman 4 días en promedio.
Sabemos que entregamos 9 items/semana.
Si queremos más rápido, optimizamos ciclo time (bloqueadores, WIP limits).
```

**Veredicto:** Savia Flow gana en claridad y correlación con valor.

---

### 5. Roles y Responsabilidades

| Rol | Scrum | Savia Flow |
|-----|-------|-----------|
| **Product Owner** | Define features, prioriza | AI Product Manager: define outcomes, métricas |
| **Scrum Master** | Facilita, remueve blockers | Flow Facilitator: optimiza flujo, métricas |
| **Developer** | Construye features | Pro Builder: orquestra IA, arquitectura |
| **QA** | Testa (a menudo separado) | Quality Architect: diseña gates autónomas |

**Requerimientos de Rol:**

```
Scrum Developer:
- Coding skills
- Estimación de esfuerzo
- Comunicación con team
- Quality mindset

Savia Flow Pro Builder:
- Coding skills (igual que Scrum)
+ Prompt engineering (comunicar con IA)
+ Pensamiento arquitectónico (no solo coding)
+ Debugging IA (why generó esto?)
+ Quality gates (automatización, no ejecución manual)
```

**Veredicto:** Roles Savia Flow requieren más profundidad técnica, pero son más autónomos.

---

### 6. Gobernanza de Calidad

| Aspecto | Scrum | Savia Flow |
|---------|-------|-----------|
| **Cuándo testa** | Fase de testing (post-dev) | Continuo (CI/CD gates) |
| **Quién testa** | QA engineers | Automated agents + architects |
| **Coverage** | Manual decisions | Métricas automatizadas |
| **Governance** | Retrospectiva | Continuous metrics |
| **Con IA** | Ineficiente (humano lento para volumen) | Escalable (agentes supervisan agentes) |

**Ejemplo de Flujo:**

```
Scrum:
Dev → "done" → QA testing phase → Found bugs → Dev fixes → Deploy

Problems:
- Testing es fase separada (serial, no parallel)
- Si IA genera 10x código, QA humano es bottleneck
- Bugs encontrados tarde (post-sprint)

Savia Flow:
Dev (con IA) → Level 1-4 gates (auto) → Level 5 (human review) → Deploy

Parallel:
- While Dev writes code
- Lint checks (instant)
- Unit tests (instant)
- Integration tests (instant)
- Security agents (instant)
- Human reviews while all auto-checks pass

Result: Feedback es immediate. Bugs found early. No bottleneck.
```

**Veredicto:** Savia Flow gana en escalabilidad y velocidad de feedback.

---

### 7. Adaptabilidad al Cambio

| Aspecto | Scrum | Savia Flow |
|---------|-------|-----------|
| **Priorización** | Replan cada sprint | Flujo continuo, repriorización as-needed |
| **Emergencias** | Interrumpe sprint | Jumps WIP limits, ingresa fase |
| **Learnings** | Retro bisemanal | Feedback continuo |
| **Ajustes** | Próximo sprint | Inmediato |

**Scenario: Customer Issue Discovered**

```
Scrum:
Friday: Descubren customer issue crítica
Options:
A) Esperar a fin de sprint (Monday), re-plan
B) Interrupt sprint (bad practice), cause disruption
C) Wait until next sprint (customer sufre)

Typical: Esperar hasta Monday, lose 3-4 días.

Savia Flow:
Friday: Descubren customer issue crítica
Action: Add to top of backlog, pull next work in queue
        Pro Builder begins Saturday
        Quality gates pass Sunday
        Deploy Monday morning

Result: Issue fixed in 36 horas, not 5-7 días.
```

**Veredicto:** Savia Flow gana en adaptabilidad.

---

## Cuándo Scrum Sigue Siendo la Opción Correcta

Scrum es todavía válido (incluso preferible) cuando:

1. **Equipo sin IA**
   - Si no colaboras con IA, las variabilidades de Scrum son menos problemáticas
   - Humanos son predecibles; sprints funcionan

2. **Equipo muy junio (startup)**
   - <5 personas puede usar Scrum simple
   - Overhead de Savia Flow es overkill

3. **Contexto altamente regulado (healthcare, finance)**
   - Si necesitas documentación detallada de auditoría de cada decisión
   - Scrum + ceremonias = evidencia de proceso
   - Pero: Savia Flow specs + gates proporciona evidencia de calidad aún mejor

4. **Equipo profundamente acostumbrado a Scrum**
   - Si cambio es disruptivo organizacionalmente
   - Puedes adoptar Savia Flow gradualmente (hybrid approach)

5. **Stakeholders que requieren burn-downs y planning ceremony**
   - Si tu org está "Scrum puro", transición requiere educación
   - Pero: Muestra resultados en 6 semanas, cambio de opinión es rápido

---

## Cuándo Savia Flow es Claramente Superior

Savia Flow es claramente mejor cuando:

1. **Colaboras con IA (Copilot, Claude, specialized agents)**
   - IA rompe la predictibilidad de Scrum
   - Savia Flow está diseñado para esto

2. **Cambio es importante (startup, scale-up)**
   - Velocidad de entrega es competencia
   - 3x mejora en cycle time = 3x mejora en feedback

3. **Calidad importa (defects son caros)**
   - Quality gates autónomas escalan QA
   - Defect escape rate cae 70%+

4. **Equipo está exhausto por ceremonias**
   - Savia Flow libera ~40% de tiempo
   - Moral = Mejora dramática

5. **Métricas SON gobernanza (no theater)**
   - Si necesitas evidencia de rendimiento continuo
   - Savia Flow proporciona datos en tiempo real

---

## El Camino Híbrido: Transición Gradual

Si necesitas transicionar de Scrum a Savia Flow sin disruption:

### Mes 1: Introduce Spec-Driven Development
```
Día 1-7: Team aprende especificaciones ejecutables
Día 8-30: Escribir specs para próximas 3-5 features en lugar de historias
         Mantener sprints y dailies (aún Scrum)
         Pero builders tienen specs claras

Result: Familiaridad con formato sin disruption. Beneficio: 20% menos rework.
```

### Mes 2: Introduce Continuous Metrics
```
Paralelo a sprints:
- Add cycle time tracking (cuántos días feature tarda sprint → prod)
- Add CFR tracking (cuántos deploys requieren hotfix)
- Dashboard visible daily

Still sprint-based, pero ahora ves flujo real.

Result: Visibility into actual performance. Conversations shift from
        "velocity" to "cycle time".
```

### Mes 3: Eliminate Daily & Introduce Async Dashboard
```
Remove: Daily standup
Replace: Dashboard standing-in
         Everyone checks in the morning: What's blocked?

Status: Still sprint-based, ceremonias reduced 60%.

Result: 4 horas liberadas por semana. Builders happy.
```

### Mes 4: Stop Sprint Boundaries
```
Work: Instead of "sprint planning", do continuous intake from backlog
      Specs are ready → Pro builders pull when capacity available
      No sprint boundaries, but still team capacity limits

Metrics: Now cycle time is pure metric, unobstructed by sprint boundaries.

Result: Cycle time improves another 30-40%. Team is now ~80% Savia Flow.
```

### Mes 5-6: Complete Integration
```
Formalize:
- Quality gates (integrate automated testing)
- Role evolution (formalize AI PM, Flow Facilitator, Pro Builder, QA Architect)
- Eliminate sprint ceremonies completely

Result: Full Savia Flow implementation.
```

**Timeline Summary:**
```
Month 1: Specs + Sprints
Month 2: Specs + Sprints + Metrics
Month 3: Specs + Flujo continuo (informal) + Metrics
Month 4: Specs + Flujo continuo + Metrics + Quality gates
Month 5-6: Full Savia Flow
```

---

## Lista de Verificación de Migración

### Pre-Migration Assessment

- [ ] Equipo colabora con IA (Copilot, Claude, etc.) u otros assistentes?
- [ ] Scrum ceremonies se sienten como "theater" (not valuable)?
- [ ] Cycle time es >7 días (room for improvement)?
- [ ] Defect escape rate es >2% (quality issues)?
- [ ] Team frustración con velocity tracking?
- [ ] Management está open a cambio de metodología?

### Migration Planning

- [ ] Obtener buy-in de engineering leadership
- [ ] Designar Flow Facilitator (puede ser ex-Scrum Master)
- [ ] Allocate 20% time for 6 weeks (learning curve)
- [ ] Choose pilot team (no necesita ser toda org)
- [ ] Set success metrics (cycle time, CFR, team satisfaction)

### Phase 1: Foundation (Weeks 1-2)

- [ ] Team completa training (7 Pilares, roles, métricas)
- [ ] Set up metrics dashboard (básico es OK)
- [ ] Escribe 2-3 spec ejemplos
- [ ] Appoint roles (AI PM, Flow Facilitator, QA Architect)
- [ ] Start tracking cycle time

### Phase 2: Experiment (Weeks 3-6)

- [ ] Escribir specs para próximas 5 features
- [ ] Stop daily standups, usar dashboard
- [ ] Run first quality gates (manual + 1-2 automated checks)
- [ ] Monthly retro (en lugar de bisemanal)
- [ ] Medir impact en cycle time y rework

### Phase 3: Integration (Weeks 7-12)

- [ ] Automate quality gates (Lint, Unit tests, Integration tests)
- [ ] Spec template estable y usado por todo team
- [ ] Role responsibilities son formales
- [ ] Metrics dashboard es comprehensive
- [ ] Sprint ceremonies completamente eliminadas

### Post-Migration (Month 4+)

- [ ] Optimizar quality gates (agregar security, performance checks)
- [ ] Expand a otros teams (if pilot is successful)
- [ ] Continuous improvement (retro insights implement)
- [ ] Scale IA collaboration (15+ agents in gates)

---

## FAQ: Scrum vs. Savia Flow

**P: ¿Perderemos predictibilidad sin sprints?**
R: No. Cycle time es incluso más predecible que velocity. Sabemos que features toman 4 días en promedio, no "35 points" que es opaco.

**P: ¿Qué pasa si necesitamos cumplir deadline?**
R: Savia Flow es mejor para deadlines. Con flow continuo, sabes exactamente cuántos items/semana entregas. Scrum es adivina.

**P: ¿Nuestros stakeholders necesitan ceremonias?**
R: Cámbialo a "demo when ready" + "quarterly business review". Stakeholder visibility es mejor, no peor.

**P: ¿Y si nuestro equipo es resistente al cambio?**
R: Comienza con specs + guardar sprints. Beneficio es visible en 4 semanas (20% menos rework). Adoption sigue naturalmente.

**P: ¿Requiere herramientas especiales?**
R: No. GitHub/Jira + CI/CD pipeline que ya tienes. Specs pueden ser en Markdown.

**P: ¿Qué pasa con asignación de trabajo?**
R: En lugar de sprint planning, Pro Builders pullan trabajo del top del backlog cuando capacity disponible. Self-organized, no assigned.

---

## Conclusión

| Criterio | Ganador |
|----------|---------|
| Equipos sin IA | Scrum ✓ |
| Equipos con IA | Savia Flow ✓✓✓ |
| Velocity como métrica | Scrum ✓ |
| Cycle time como métrica | Savia Flow ✓✓ |
| Predictibilidad | Savia Flow ✓ (datos reales) |
| Eficiencia de tiempo | Savia Flow ✓✓✓ |
| Gobernanza de calidad | Savia Flow ✓ |
| Adaptabilidad | Savia Flow ✓ |
| Escalabilidad con IA | Savia Flow ✓✓✓ |

**Recomendación:** Si tu equipo colabora con IA y está considerando cambio de metodología, Savia Flow es el siguiente paso natural. La adopción puede ser gradual; el impacto es inmediato.

---

**Comienza hoy: Escribe tu primer spec ejecutable esta semana.**
