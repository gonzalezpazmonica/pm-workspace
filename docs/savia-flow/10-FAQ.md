# FAQ: Preguntas Frecuentes sobre Savia Flow

**Autor:** la usuaria González Paz, pm-workspace
**Fecha:** Marzo 2026
**Versión:** 1.0

---

## Implementación & Adopción

### P: ¿Cuánto tiempo toma adoptar Savia Flow?
**R:** 12 semanas para implementación completa. Pero beneficios comienzan en semana 2 (specs claras) y son evidentes en semana 4 (cycle time 30% más rápido).

### P: ¿Podemos mantener Scrum mientras experimentamos con Savia Flow?
**R:** Sí. Patrón híbrido es recomendado para transición. Semanas 1-4: keep sprints, agrega specs. Semanas 5-8: elimina dailies, mantén sprints. Semanas 9-12: flujo continuo completo.

### P: ¿Qué pasa si nuestro equipo no conoce IA?
**R:** No es problema. Savia Flow es agnóstico de IA. Pro builders aprenderán IA collaboration naturalmente en semanas 2-3. Los gates funcionan sin IA (son automáticos igual).

### P: ¿Savia Flow funciona para equipos pequeños (<5 personas)?
**R:** Sí, pero overhead de roles es proporcional al tamaño. Para <5 personas, combina roles (PM hace aussi Flow Facilitator, uno de los builders es QA Architect).

### P: ¿Necesitamos nuevas herramientas?
**R:** No. GitHub + CI/CD pipeline + analytics tool es suficiente. Optionalmente, usa Notion para specs, Jira para tracking. No es necesario comprar herramientas especializadas.

---

## Métricas & Medición

### P: ¿Por qué eliminar velocity (story points)?
**R:** Velocity es gameable (equipos inflan puntos) y no predice bien con IA (variabilidad 200%+). DORA metrics (cycle time, throughput, CFR) son factual y correlacionan con value real.

### P: ¿Cómo explico DORA metrics a stakeholders acostumbrados a velocity?
**R:** Muestra datos. Primeras 4 semanas con Savia Flow, mide cycle time. Muestra: "Antes 18 días, ahora 5 días. Eso es 3.6x más rápido." Stakeholders entienden rápido.

### P: ¿Qué cycle time debería esperar?
**R:** Savia Flow target: 3-7 días. Primeras 4 semanas puede ser 8-10 días mientras team aprende. Después de 8 semanas, 4-5 días es normal. Elite performers: <1 día posible pero raro.

### P: ¿Cuál es CFR target realista?
**R:** <5% es excelente. <10% es good. >15% significa quality gates need tuning.

### P: ¿Cómo mido "IA coverage" (% de código generado por IA)?
**R:** Manualmente al principio (builders track). Idealmente: tool que cuenta líneas generadas vs. modificadas. Target: 40-70%.

---

## Roles & Responsabilidades

### P: ¿Nuestro Product Owner puede ser el AI PM?
**R:** Sí, si entienden datos y pueden escribir con precisión. Si no, aprender toma 2-3 semanas.

### P: ¿Necesitamos un Flow Facilitator separado del Scrum Master?
**R:** No necesariamente. Scrum Master que aprende metrics y coaching puede transicionar a Flow Facilitator. Diferencia: SM ejecuta ceremonias, FF optimiza flujo.

### P: ¿Todos los builders deben ser "Pro Builders" o es gradual?
**R:** Gradual. Builders junior aprenden mientras trabajar. Seniors mentoran. En 4-6 semanas, todos son "pro builders" en capacidades (aunque varían en experiencia).

### P: ¿Quality Architect debe ser person full-time?
**R:** Inicialmente no. 1-2 días/semana es suficiente para gates básicas. Con 15+ agentes especializados, puede escalar a full-time.

### P: ¿Podemos externalizar QA?
**R:** Gates automatizadas sí (incluso cloud-hosted). Pero Level 5 human review debe ser internal (requiere product/architecture knowledge).

---

## Especificaciones & Clarity

### P: ¿Las specs reemplazan user stories completamente?
**R:** No. Stories pueden existir (para comunicación con stakeholders), pero specs deben ser specs (para building). Relación: Story = "why", Spec = "exactly how".

### P: ¿Cuánto detalle debe estar en una spec?
**R:** 2-5 páginas típicamente. Suficiente para que builder no haga preguntas (no adivine). Prueba: Muestra spec a builder, si tiene preguntas, spec necesita más detalle.

### P: ¿IA puede ayudar a escribir specs?
**R:** Sí. Claude puede draftar spec basado en PM outline. Típicamente 30-40% es útil, PM refina 60-70%.

### P: ¿Qué pasa si spec cambia durante building?
**R:** Cambios menores: OK (builder ajusta). Cambios mayores: builder escalada a PM, posible delay o scope reduction.

### P: ¿Specs hacen que building sea más lento?
**R:** Contraintuitivo: specs hacen building más RÁPIDO. Builder no gasta tiempo "adivinando", menos rework. Net time: -30% típicamente.

---

## Quality Gates

### P: ¿Cuántos levels de gates necesitamos?
**R:** Mínimo 3 (Lint, Tests, Integration). Máximo 5 (agregar Security, Performance, Human). Recomendado: 5 para máxima calidad.

### P: ¿Gates ralentizan deployment?
**R:** Al principio, parecen (5-10 min por feature). Pero evitan rework (que toma horas). Net time: mucho más rápido.

### P: ¿Cómo manejamos false positives en SAST?
**R:** Tune agent thresholds, no disable. Ejemplo: Si SQL injection detector tiene 50% false positives, ajusta regex patterns, re-test con histórico.

### P: ¿Podemos hacer gates opcionales (en lugar de requeridos)?
**R:** Sí, pero no recomendado. Si optional, algunos builders las esquivan. Better: Make gates fast (todas deben ser <2 min total), no optional.

### P: ¿Necesitamos gates separadas para frontend y backend?
**R:** Sí, parcialmente. Lint/tests son language-specific. Security checks varían (XSS para frontend, SQL injection para backend). Combine lo que se puede.

---

## IA & Collaboration

### P: ¿Cuál IA debemos usar (Copilot, Claude, etc.)?
**R:** Depende de tech stack. JS/Python: Copilot es estándar. Para exploración conceptual: Claude excele. Recomendación: Ambas si es posible.

### P: ¿Builders necesitan ser "prompt engineers"?
**R:** No experts, pero basics sí. "Write detailed prompts first, iterate less" es la lección principal.

### P: ¿IA va a reemplazar builders?
**R:** No. IA reemplaza 60-70% del typing/coding manual. Pero builders hacen arquitectura, code review, debugging, validation. Esos trabajos siguen siendo 100% humanos.

### P: ¿Podemos usar IA para code review?
**R:** Parcialmente. Para checklist (does function exist, coverage > 80%), sí. Para architecture/logic, todavía es mejor human.

### P: ¿Cómo asegurar que IA output es seguro?
**R:** Security gates (SAST, secrets scanning). Plus: builders review IA code (no trusted blindly). Plus: extensive testing. Combination = muy seguro.

---

## Troubleshooting

### P: Nuestro cycle time no mejora. ¿Qué hacer?
**R:** Debug: ¿Dónde está el delay?
- Specs: ¿Toman 5+ días? Use IA para draft.
- Building: ¿Toma 10+ días? Builders quizás no colaboran bien con IA. Coaching.
- Gates: ¿Esperando results? Optimize gate speed.
- Human review: ¿Review toma 3+ días? SLA: debe ser <4 horas.

### P: CFR es alto (>10%). ¿Qué hacer?
**R:** Investigate bugs escapando. ¿Patrón? (missing auth, performance, etc.) Build agente especializado para ese patrón. Re-test. CFR debería bajar.

### P: Gates rechazando demasiado código (>40% rejection rate).
**R:** Gates probablemente too strict. Opción A: Reduce strictness. Opción B: Better builders prompting. Opción C: Bugs fueron reales y gates salvaban asses. Review qué fue rechazado.

### P: Builders frustrados con specs "ambiguas".
**R:** PM feedback es valiosa. PM debe reescribir spec basado en confusión de builders. Specs mejoran con iteración.

### P: IA está generando código que no lo hace qué queremos.
**R:** Prompts probablemente son vagas. Detalle: "Exactly what should happen?" vs "Generate a function". Better prompts = mejor output.

---

## Business & ROI

### P: ¿Cuál es el ROI de adoptando Savia Flow?
**R:** Típicamente 1600%+ en 6 meses. Comes from: 40% menos tiempo en ceremonias, 60% menos rework, 70% mejora en cycle time. Your actual ROI depende de contexto.

### P: ¿Necesitamos más builders?
**R:** No. Mismo team delivera 60-70% más con Savia Flow. Si crecimiento exige más builders, eso es bueno (means producto crece).

### P: ¿Cuándo veré resultados?
**R:**
- Semana 2: Specs claras, builderless confusion
- Semana 4: Cycle time mejora 20-30%
- Semana 8: Cycle time mejora 50%+, throug puts mejora 40%+
- Semana 12: Full implementation, esperando 70% mejora en cycle time

### P: ¿Esto es solo para "fast" companies?
**R:** No. Healthcare, finance, regulated industries use Savia Flow (con gates adicionales). Es universal metodología.

### P: ¿Podemos medir business impact (revenue)?
**R:** Difícil causality (many factors). Pero: Más features → more market coverage → higher revenue probable. Faster feedback → better products → higher retention probable.

---

## Comparison Questions

### P: ¿Es Savia Flow lo mismo que Shape Up (Basecamp)?
**R:** Relacionado, pero diferente. Shape Up: 6-week cycles, team ownership. Savia Flow: flujo continuo, spec-driven, IA-native. Usa concepts from Shape Up, evoluciona más.

### P: ¿Es Savia Flow lo mismo que Kanban?
**R:** Kanban: visual board, WIP limits, flujo continuo. Savia Flow: incluye kanban principles pero adds specs, metrics DORA, roles, quality gates. Kanban es subset de Savia Flow.

### P: ¿Qué ventaja sobre SAFe (Scaled Agile)?
**R:** SAFe: enterprise, hierarchical, ceremonies heavy. Savia Flow: lightweight, outcome-focused, IA-native. Si empresa es SAFe adherent, puedes adoptar Savia Flow at team level (not conflicting).

### P: ¿Savia Flow vs. Waterfall?
**R:** Waterfall: Linear, months to deploy, high risk, low feedback. Savia Flow: Iterative, days to deploy, low risk, high feedback. Savia Flow gana en casi todo.

---

## Getting Started

### P: ¿Dónde comenzamos?
**R:**
1. Lee whitepaper (01)
2. Convence stakeholders (show comparison, 02)
3. Forma equipo de adopción (4-5 personas)
4. Comienza guía rápida (03) semana 1
5. Asigna roles (04)
6. Implementa specs + gates progresivamente

### P: ¿Necesitamos externa coaching?
**R:** Helpful pero no required. Si equipo es new to metrics/specs, 40-60 horas coaching accelerates learning. Otherwise, self-service con suite de docs.

### P: ¿Dónde obtenemos feedback?
**R:** Whitepaper tiene contact info. pm-workspace project es source. Comunidad está creciendo.

### P: ¿Puedo personalizar Savia Flow?
**R:** Sí. 7 Pilares son core, pero implementation varía. Specs pueden be Markdown o formal. Gates pueden be minimal o extensive. Roles pueden be combined para equipos pequeños.

---

## Conclusion

**Más preguntas?** Referencia el whitepaper (01) para profundidad, o contacta via pm-workspace.

**Comienza hoy. La comunidad de Savia Flow está creciendo, y estamos aquí para apoyar.**
