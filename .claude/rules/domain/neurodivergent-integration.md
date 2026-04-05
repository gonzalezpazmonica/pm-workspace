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
