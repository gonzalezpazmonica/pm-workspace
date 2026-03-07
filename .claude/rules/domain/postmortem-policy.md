# Regla: Postmortem Obligatorio para Incidentes con MTTR > 30 minutos

**Propósito:** Garantizar aprendizaje sistemático del viaje diagnóstico.

## Cuándo aplica

Incidente = problema en producción que interrumpe servicio.

**OBLIGATORIO si:** MTTR > 30 minutos
**OPCIONAL si:** MTTR 15-30 minutos (educativo)
**NO requiere si:** MTTR ≤ 15 minutos

## Requisitos obligatorios

1. **Plantilla completa** — 7 secciones:
   - Timeline
   - Diagnosis Journey
   - Resolution
   - Mental Model Update
   - Heuristic Extraction
   - Comprehension Gap Analysis
   - Prevention

2. **Heuristic Extraction** — mínimo 1. Formato: "Si X, chequea Y"

3. **Comprehension Gap** — análisis obligatorio:
   - ¿Código AI-generado?
   - ¿Modelo mental preexistente?
   - ¿Era preciso o stale?
   - ¿Qué documentación ayudaría?

4. **Link a comprehension report** — si gap en código AI

5. **Nombre estándar:** `output/postmortems/YYYYMMDD-{incident-id}.md`

## Ejecución

1. Post-incident, dentro de 24h
2. Engineer-on-call + tech-lead mínimo
3. Sesión: 30-60 min
4. Rito: async o síncrono

## Cumplimiento

- Audit: `/postmortem-audit`
- Dashboard: `/incident-tracking`
- Alerta: MTTR > 30min sin postmortem en 24h

## Restricción

Plantilla OBLIGATORIA. No freeform. No guardar sin completar.
