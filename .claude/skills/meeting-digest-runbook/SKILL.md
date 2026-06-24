---
skill_id: meeting-digest-runbook
title: Meeting Digest — Runbook completo
status: CALIBRATED
origin_agent: meeting-digest
extracted_by: SE-099
extracted_at: 2026-06-24
sla: agent ≤4096B (Rule #22)
---

# Meeting Digest — Runbook

Cargado por el agente `meeting-digest` para detalle operativo completo.

## Pipeline 5 fases (0-4)

**Fase 0 — Transcription Resolution**: corregir errores ASR con contexto del proyecto.
Protocolo: `docs/rules/domain/transcription-resolution.md`. Scoring: ≥80% auto, 50-79% marcado, <50% gap abierto.

**Fase 1 — Extraccion** (Sonnet): leer transcripcion normalizada. Marcar segmentos sensibles.
Extraer bloques: PERFIL, NEGOCIO, NOTAS PM. Datos marcados NUNCA en bloques.

**Fase 2 — Juicio de privacidad** (delegacion a Opus via Task `meeting-confidentiality-judge`):
fragmentos marcados + 3 bloques extraidos + lista motivos. Aplicar veredicto.

**Fase 3 — Analisis de riesgos** (delegacion a Opus via Task `meeting-risk-analyst`):
bloques ya filtrados + proyecto + tipo. El analista NUNCA ve datos marcados.

**Fase 4 — Actualizacion de contexto** (OBLIGATORIA): propagar info nueva a docs vivos.
1. Buscar indice: `README.md` o `CLAUDE.md`
2. Identificar docs relevantes para info extraida
3. Leer cada candidato; si desactualizado → actualizar con Edit
4. Solo datos no marcados. Limite 150 lineas por fichero
5. Registrar en ACTUALIZACIONES: ficheros modificados y tipo de cambio

## Extraccion de perfil (modo one2one)

Extraer sobre la persona entrevistada (NO el PM):

- **Basicos**: nombre, handle, email, rol, seniority, manager
- **Localizacion**: pais, region, ciudad
- **Skills**: tecnicas, blandas, debilidades, dislikes
- **Equipo**: squad, rol en squad, relaciones clave (tipo + notas)
- **Personal**: preferencias trabajo, contexto familiar, aficiones, vacaciones
- **Profesional**: aspiraciones, preocupaciones actuales, tiempo en proyecto
- **Citas clave**: 5-12 citas textuales que revelen personalidad o insights

## Deteccion de segmentos sensibles

### Marcadores verbales directos
Expresiones como: peticion de discrecion, "no registres esto", "fuera de acta",
"en confianza", peticion de no difusion, variantes coloquiales equivalentes.

### Categorias sensibles por defecto
Salud, situaciones legales, reclamaciones salariales, busqueda de empleo,
orientacion sexual, religion, ideologia, conflictos personales extra-laborales.

### Fin de segmento sensible
1. Retorno explicito a tema laboral ("ya puedes apuntar", "volviendo al tema")
2. Cambio explicito de tema a asuntos del proyecto
3. Sin senal clara → se extiende hasta cambio de tema detectable

### Tratamiento de segmentos marcados
1. Marcar como `[REDACTADO: motivo]`
2. NO incluir en bloques PERFIL/NEGOCIO/NOTAS PM
3. Pasar al juez (Fase 2) para validacion
4. AMBIGUO → marcar `[DATO AMBIGUO — confirmar con PM]`
5. MARCADO CRITICO → solo informar a PM en conversacion, NUNCA en ficheros

## Formato de salida

```
=== PERFIL ===
[YAML estructura member-template]

=== NEGOCIO ===
[Markdown: stakeholders, problemas, reglas, dinamicas]

=== NOTAS PM ===
[Markdown: riesgos, seguimiento, observaciones]

=== RIESGOS ===
[Output del meeting-risk-analyst]
```

## Tipos de reunion

| Tipo | Foco | Risk analysis |
|---|---|---|
| one2one | Perfil + negocio + notas | Conflictos, burnout, contradicciones |
| sprint-review | Decisiones + metricas | Decisiones vs reglas, dependencias |
| retro | Problemas + sentimiento | Conflictos, patrones recurrentes |
| refinement/stakeholder | Requisitos + decisiones | Duplicidades, gaps, dependencias |

## Reglas de extraccion

1. Marcar con `# inferido` campos no confirmados explicitamente
2. Citas entrecomilladas, copiadas literalmente
3. Extraer TODO excepto segmentos marcados
4. No juzgar ni interpretar sentimientos no expresados
5. Ambiguedades → pendiente de confirmar
6. Datos marcados → NUNCA en ficheros, solo informar a PM verbalmente

## Memoria y Context Index

- Memoria: `projects/{proyecto}/agent-memory/meeting-digest/MEMORY.md`
- Context Index: si existe `projects/{proyecto}/.context-index/PROJECT.ctx`, usar `[digest-target]` para destinos
