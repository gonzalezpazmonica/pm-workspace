---
spec_id: SPEC-107
title: AI Cognitive Debt Mitigation — measure and counter "AI brain fry" in heavy Claude Code users
status: PROPOSED
origin: User request (2026-04-15) — "investigación profunda sobre AI brain fry y cómo combatirlo con pm-workspace con medidas reales"
severity: Alta
effort: ~32h (3 sprints — measurement → friction hooks → calibration)
related_specs:
  - SPEC-106 (Truth Tribunal — verifies AI output reliability; complementary)
  - SPEC-061 (neurodivergent integration — wellbeing baseline)
  - SPEC-085 (postponement-judge — anti-deferral pattern)
related_rules:
  - .claude/rules/domain/code-comprehension.md
  - .claude/rules/domain/dev-session-protocol.md
  - .claude/rules/domain/emotional-regulation.md
  - .claude/rules/domain/verification-before-done.md
priority: baja
---

# SPEC-107: AI Cognitive Debt Mitigation

## El problema en una frase

Trabajar 8h/día con Claude Code degrada la memoria episódica, la
conectividad neural, la capacidad de síntesis original y el sentido
de autoría — y la deuda persiste cuando se quita la herramienta.

## Evidencia (no opinión)

### MIT Media Lab — "Your Brain on ChatGPT" (Kosmyna et al., 2025)
arXiv 2506.08872 · 54 participantes · 32-channel EEG · 4 sesiones de redacción.

- Grupo LLM mostró **conectividad neural más débil** en alpha/beta/theta/delta
  que el grupo de bolígrafo. Patrón dosis-respuesta.
- **83% de los usuarios LLM no pudieron citar una sola frase** del ensayo
  que acababan de escribir minutos antes (vs ~11% en el grupo sin LLM).
- Ensayos LLM **estadísticamente homogéneos** dentro del mismo tema —
  pérdida de variación creativa pese a usar 2-3× más entidades nombradas.
- **Sentido de autoría fragmentado** en autoinformes.
- **Crossover crítico**: participantes LLM→bolígrafo en sesión 4 mantuvieron
  patrones de subactivación. La deuda **persiste tras retirar la herramienta**.

### Microsoft Research + CMU — Lee et al., CHI 2025
319 trabajadores del conocimiento · 936 ejemplos primera mano de tareas con GenAI.

- **Mayor confianza en GenAI ↔ menos pensamiento crítico** (correlación
  significativa, negativa).
- El esfuerzo cognitivo se desplaza de **generación** a **verificación,
  integración, stewardship** — pero los usuarios **saltan la verificación
  bajo presión de tiempo**.
- Tres barreras identificadas: (1) desconocer la necesidad de verificar,
  (2) presión temporal, (3) dificultad de refinar prompts en dominios no
  familiares.

### Carnegie Mellon / ICER 2025 — Copilot longitudinal
arXiv 2509.20353 · estudiantes de programación.

- Estudiantes con **metacognición fuerte previa** se beneficiaron de Copilot.
- Estudiantes con **metacognición débil** rindieron **peor con Copilot que
  sin él**. La atrofia es diferencial — los menos preparados pagan el coste.

### Roediger & Karpicke (2006) — base de la ciencia del aprendizaje
Active recall produce **+50% retención a 1 semana** vs re-lectura. La
intervención más replicada en ciencia del aprendizaje. Aplicable directo:
**recordar antes de buscar** preserva memoria.

## Lo que NO funciona (descartado)

- "Usa la IA con conciencia" — vago, no medible, no replicado
- Dashboards de productividad (PRs, commits, líneas) — la evidencia MIT/CMU
  muestra que pueden subir mientras la cognición baja
- Pomodoro genérico sin desconexión real de la IA — no hay RCT que muestre
  efecto sobre cognitive debt específicamente
- Flashcards generadas por IA sin contrato de retrieval espaciado

## Solución: 5 intervenciones medibles

Ranking por fuerza de evidencia. Las primeras 3 forman el MVP de Phase 1.

### I1 — Hypothesis-first commit trailer (evidencia: ★★★)

**Fundamento**: Roediger-Karpicke (retrieval practice) + Lee-MS/CMU
(verification shift). Forzar al desarrollador a articular su hipótesis
ANTES de pedir código a Claude.

**Mecánica**:
- Hook PreToolUse sobre Edit/Write en código de producción
- Si el commit en curso no tiene trailer `Hypothesis: …` con ≥30 chars,
  bloqueo suave: "¿Cuál era tu hipótesis sobre cómo resolver esto?"
- Trailer va al commit message como `Hypothesis: { user statement }`
- Métrica derivada: % commits con hipótesis no trivial

**No-block en**: fixes triviales de 1 línea, format-only commits, merge
commits, revert commits.

### I2 — Teach-back gate al cerrar spec (evidencia: ★★★)

**Fundamento**: MIT — el 83% no recordaba lo que acababa de escribir. La
explicación verbal sin mirar fuerza la consolidación.

**Mecánica**:
- Stop hook al detectar marca "spec done" / status update a Implemented
- Pregunta: "Sin mirar el código, en 3 frases: qué hace, por qué este
  enfoque, qué falla"
- Respuesta se persiste en `.spec.crc` junto a la spec
- Si la respuesta tiene <50 chars o solo cita los nombres de los ficheros
  → bloqueo, repregunta una vez

**Honest limit**: el hook no juzga la calidad de la explicación (eso
requiere LLM call y crearía dependencia circular). Solo verifica que
existe explicación de longitud razonable y no es paste del código.

### I3 — Critical evaluation checklist en /pr-plan (evidencia: ★★)

**Fundamento**: Lee-MS/CMU barrera #1 — el desconocimiento de la
necesidad de verificar. Hacer la verificación explícita y obligatoria.

**Mecánica**:
- Nuevo gate en `pr-plan.sh` (G11): para cada PR con código generado
  por Claude, presentar checklist:
  - [ ] ¿Qué falla si entra una entrada inesperada?
  - [ ] ¿Qué asumió el modelo que no está en la spec?
  - [ ] ¿Probaste el camino feliz Y un edge case?
  - [ ] ¿Entiendes por qué este código resuelve el problema, o solo que
    pasa los tests?
- Respuestas se firman con el commit (commit trailer
  `CriticalReview: {hash de respuestas}`)
- Skip permitido con `--skip-critical-review` + razón obligatoria,
  registrada en log

### I4 — AI dependency telemetry (evidencia: ★★)

**Fundamento**: MIT crossover — la deuda persiste. Para combatirla hay
que verla. Empezar midiendo.

**Mecánica**:
- Hook async PostToolUse registra cada llamada a Claude (Edit/Write/Task)
  con timestamp + duración de sesión
- Persiste en `~/.savia/cognitive-load/{user}.jsonl` (N3, gitignored)
- Comando `/cognitive-status` muestra:
  - Horas Claude-active hoy / esta semana
  - Ratio aceptación-rápida (<5s entre suggest y accept) — proxy de
    skip-verification de Lee-MS/CMU
  - Streak de días sin "no-AI interval" ≥2h
- Solo telemetría — sin bloqueos. Espejo, no policía.

### I5 — Weekly retrieval drill (evidencia: ★★)

**Fundamento**: Karpicke-Roediger directo. Forzar recall semanal sobre
trabajo propio reciente.

**Mecánica**:
- Comando `/retrieval-drill` (sugerido por session-init los lunes)
- Selecciona 3 PRs/specs cerrados en los últimos 14 días por el usuario
- Por cada uno: "Sin abrir el código, describe en 2 frases qué hace y
  por qué tomaste esa decisión"
- Compara la respuesta contra la descripción del PR/spec usando
  similitud léxica simple (no LLM — evita dependencia circular)
- Score 0-100 + tendencia semanal en `~/.savia/cognitive-load/`

## Lo que esta spec NO hace

- **No mide la calidad del pensamiento** — eso requiere LLM-judge y
  reintroduce el problema. Mide proxies conductuales.
- **No bloquea el trabajo** — todos los gates tienen escape documentado.
  Friction, no firewall.
- **No reemplaza wellbeing-guardian** — añade dimensión cognitiva sobre
  la dimensión de horario/break que ya existe.
- **No predice burnout** — eso es burnout-radar. Mide degradación
  cognitiva, no estado emocional.

## Integración con componentes existentes

| Existente | Cómo se complementa |
|---|---|
| `wellbeing-guardian` | Añade `cognitive_load_score` a su modelo. Hoy mide breaks; añadirá ratio de aceptación-rápida y horas Claude-active. |
| `burnout-radar` | Consume score cognitivo como nuevo indicador (peso bajo, complementario). |
| `code-comprehension.md` rule | I2 (teach-back) refuerza la validación 3AM ya documentada. |
| `dev-session-protocol.md` | I1 (hypothesis-first) encaja en Phase 1 (Spec Load) sin perturbar el flujo de slices. |
| `verification-before-done.md` (Rule #22) | I3 (critical eval) operativiza la regla con un gate concreto en `/pr-plan`. |
| `postponement-judge.sh` | Patrón análogo (Stop hook que cuestiona). Reusar arquitectura. |
| `emotional-regulation.md` | Reportar score cognitivo en idle notification si excede umbral, sin pánico. |

## Métricas de éxito (medibles, no aspiracionales)

Tras 30 días en producción con un usuario:

- **% commits con `Hypothesis:` trailer**: meta ≥70%
- **% specs cerrados con teach-back ≥50 chars**: meta ≥80%
- **Mediana de horas Claude-active/día**: solo medir, no fijar meta
- **Ratio aceptación-rápida (<5s)**: tendencia descendente esperada
- **Score retrieval drill**: tendencia ascendente esperada

NO se promete reducción de "AI brain fry" como tal — no hay forma de
medirla sin EEG. Se promete: visibilidad + friction validada por evidencia.

## Privacidad

- Todos los datos cognitivos viven en `~/.savia/cognitive-load/{user}.jsonl`
  — N3, gitignored, solo el usuario los ve.
- NUNCA se exponen a equipo, manager, ni reportes ejecutivos.
- `/savia-forget --cognitive` borra todo el historial.
- Sin telemetría externa, sin envío a servidores.

## Restricciones inviolables

- **CD-01**: ningún hook de esta spec puede ejecutar código del usuario
  ni invocar LLM. Solo introspección de strings y archivos.
- **CD-02**: bloqueos de hooks SIEMPRE tienen escape (`--skip-cognitive`
  + razón). Friction, no firewall.
- **CD-03**: la telemetría es N3. Ni el manager, ni el equipo, ni
  reportes corporativos pueden leerla. La PM no puede monitorizar a su
  equipo con esto — viola Rule #23 (Equality Shield) usar fatiga
  cognitiva como criterio de evaluación.
- **CD-04**: el opt-out es de un comando: `bash scripts/cognitive-debt.sh disable`.
  Por defecto, esta spec está **opt-in** en Phase 1 (no se activa sin
  decisión explícita del usuario).

## Plan por fases

### Phase 1 — Measurement + opt-in (sprint 1, ~12h)
- [ ] `scripts/cognitive-debt.sh` (enable/disable/status)
- [ ] Hook telemetry async (I4) + comando `/cognitive-status`
- [ ] Hook hypothesis-first (I1) en modo warning, no bloquea
- [ ] BATS test ≥85 score
- [ ] Documentación: `docs/cognitive-debt-guide.md`

### Phase 2 — Friction hooks activos (sprint 2, ~12h)
- [ ] I1 a modo bloqueante (con escape)
- [ ] I2 teach-back gate
- [ ] I3 critical-eval checklist en /pr-plan G11
- [ ] BATS test ≥85 score

### Phase 3 — Retrieval + calibración (sprint 3, ~8h)
- [ ] I5 weekly retrieval drill
- [ ] Calibración de umbrales con datos de 30 días reales
- [ ] Integración bidireccional con wellbeing-guardian
- [ ] Documentación de calibración

## Riesgos

| Riesgo | Mitigación |
|---|---|
| Friction hooks generan rechazo del usuario | Phase 1 opt-in. Recoger feedback antes de Phase 2. |
| Métricas conductuales no correlacionan con cognitive debt real | Honest limit ya documentado. La spec promete proxies, no medición directa. |
| Telemetría se filtra a manager/equipo | CD-03 inviolable. N3 gitignored. Auditoría con `confidentiality-scan.sh`. |
| Crear nueva forma de presión / culpa al usuario | I4-I5 son espejos, no policía. UI con tono de `emotional-regulation.md` (datos, no juicio). |
| Sesgo contra neurodivergentes (ADHD/TDAH adoran offloading) | Integrar con `neurodivergent.md`: si `adhd.present=true` con `time.estimation_calibration`, ajustar umbrales (más permisivo en ratio aceptación-rápida). |

## Decisiones pendientes para el humano

1. **Granularidad de la telemetría**: ¿registramos cada llamada a Claude o
   solo agregados horarios? Cada llamada da más resolución pero más datos
   sensibles. Default propuesto: agregados horarios.
2. **Default opt-in vs opt-out**: Phase 1 propone opt-in. ¿Se mantiene
   opt-in indefinidamente, o pasa a opt-out tras N semanas estables?
3. **Integración con team-sentiment**: ¿el agregado anonimizado del
   ratio cognitivo del equipo entra en pulse surveys? (riesgo: viola
   CD-03 si se desanonimiza).
4. **Umbrales por defecto**: ¿qué constituye "ratio aceptación-rápida
   alto"? Sin datos, propuesta es **>40% de aceptaciones en <5s**, a
   recalibrar en Phase 3.

## Referencias

- Kosmyna et al. 2025, "Your Brain on ChatGPT" — arxiv.org/abs/2506.08872
- Lee et al. CHI 2025, "The Impact of Generative AI on Critical Thinking"
  — microsoft.com/en-us/research/wp-content/uploads/2025/01/lee_2025_ai_critical_thinking_survey.pdf
- ICER 2025 longitudinal Copilot — arxiv.org/pdf/2509.20353
- Roediger & Karpicke 2006 — base de retrieval practice
- pm-workspace componentes existentes: ver `related_rules` en frontmatter

## Aprobación

Tras revisión humana → arrancar Phase 1 (telemetría + warning). Métricas
y feedback de 30 días deciden si pasar a Phase 2 (friction hooks activos).
