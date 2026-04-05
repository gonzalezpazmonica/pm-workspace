# Neurodivergent Profile Integration — SPEC-061

> Complementa accessibility-output.md con dimensiones neurodivergentes.
> Perfil: .claude/profiles/users/{slug}/neurodivergent.md (N3, gitignored)

## Carga

Al inicio de sesion, si existe neurodivergent.md del usuario activo:
1. Leer silenciosamente (NUNCA mencionar en output)
2. Aplicar adaptaciones segun campos presentes
3. Auto-configurar campos de accessibility.md que correspondan

## Adaptaciones por dimension

### ADHD (adhd.present: true)
- Si focus_enhanced en active_modes: proteger hyperfocus (no interrumpir)
- Si rsd_sensitivity alta: activar review_sensitivity en accessibility.md
- Si time.estimation_calibration: aplicar factor historico a estimaciones
- Si time.time_blindness_markers: mostrar timestamps en output footer

### Autism (autism.present: true)
- Si clarity en active_modes: reescribir lenguaje ambiguo antes de output
- Si literal_precision: evitar metaforas, ironias, lenguaje figurado
- Si social_translation: anotar intenciones en mensajes de terceros
- Si communication.ceremony_preview: adelantar agenda antes de ceremonias

### Dyslexia (dyslexia.present: true)
- Activar dyslexia_friendly en accessibility.md automaticamente
- Preferir listas con bullets sobre parrafos
- Alineacion izquierda (nunca justificado)

### Giftedness (giftedness.present: true)
- cognitive_load: high por defecto (mas detalle, no menos)
- Output tecnico denso — NO simplificar

### Dyscalculia (dyscalculia.present: true)
- Acompanar numeros con descripcion verbal
- Ejemplo: "85% (alto — por encima del objetivo)"

### Sensory Budget (sensory_budget.batch_notifications: true)
- Agrupar notificaciones en un solo bloque al terminar la tarea actual
- No interrumpir con mensajes individuales durante trabajo profundo
- alert_at_percent: umbral para activar batching (env: SAVIA_SENSORY_ALERT_PCT)

### Ceremony Preview (communication.ceremony_preview: true)
- Antes de ceremonias Scrum: mostrar agenda, tiempos, participantes, turno esperado
- Integra con /meeting-agenda: genera preview automatico (env: SAVIA_CEREMONY_PREVIEW)

### Time Blindness (time.time_blindness_markers: true)
- Timestamp [HH:MM] en footer de cada respuesta (env: SAVIA_TIME_MARKERS)

### Strengths Map (strengths_map)
- /pbi-assign considera fortalezas ND al calcular scoring de asignacion
- pattern_recognition→analysis, hyperfocus→deep-focus, detail_orientation→review
- Bonus +10% scoring cuando fortaleza alta coincide con tipo de tarea

## Composabilidad

Las dimensiones se combinan sin conflicto. Si ADHD + Autism ambos activos,
todas las adaptaciones de ambos aplican simultaneamente.

## Privacidad (INMUTABLE)

- neurodivergent.md es N3 — SOLO el usuario, NUNCA compartido
- Savia NUNCA menciona el perfil en output
- NUNCA en auto-memory, agent-memory ni logs
- /savia-forget --neurodivergent borra el perfil completo
- Sin analytics ni tracking de uso ND

## Integracion con reglas existentes

| Campo ND | Auto-configura en |
|---|---|
| adhd.rsd_sensitivity: high | accessibility.md review_sensitivity: true |
| dyslexia.present: true | accessibility.md dyslexia_friendly: true |
| giftedness.present: true | accessibility.md cognitive_load: high |
| autism.literal_precision | adaptive-output.md (evitar hedging) |
| active_modes: [structure] | guided-work-protocol.md guided_work: true |
| sensory_budget.batch_notifications | context-health batching (SAVIA_SENSORY_BATCH) |
| communication.ceremony_preview | /meeting-agenda preview (SAVIA_CEREMONY_PREVIEW) |
| time.time_blindness_markers | output footer timestamps (SAVIA_TIME_MARKERS) |
| strengths_map | /pbi-assign scoring bonus (+10%) |
