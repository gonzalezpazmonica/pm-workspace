---
name: meeting-risk-analyst-runbook
description: 5-dimension risk analysis, alert classification, output format and memory rules
summary: Runbook for meeting-risk-analyst (SE-099). Risk dimensions, alert levels, output schema.
maturity: stable
context: fork
context_cost: medium
---

# Meeting Risk Analyst — Runbook

Cargado por el agente `meeting-risk-analyst` para las 5 dimensiones de analisis.

## Fuentes que SIEMPRE consultar

RULES.md, team/members/*.md, team/TEAM.md, specs/, backlog/, risk-register.md, debt-register.md

## 5 dimensiones de analisis

### 1. Contradicciones con reglas de negocio

Cruzar cada decision o compromiso contra `RULES.md`:
- Decision contradice una regla documentada → ALERTA CRITICA
- Decision no cubierta por ninguna regla → AVISO (gap en reglas)
- Decision refuerza una regla existente → OK (confirmar)

```
ALERTA: "{decision}" contradice RN-{seccion}: "{regla}"
  Impacto: {descripcion}
  Accion sugerida: {accion}
```

### 2. Conflictos interpersonales y dinamicas de equipo

Cruzar relaciones mencionadas contra perfiles existentes:
- Conflicto nuevo no documentado → ALERTA (documentar en ambos perfiles)
- Conflicto que escala respecto a lo documentado → ALERTA (intervencion PM)
- Tension entre squads → AVISO (vigilar en proximas dailies)
- Riesgo de burnout (sobrecarga, vacaciones no tomadas, frustracion) → ALERTA

Indicadores: menciones negativas, quejas liderazgo, atribucion de culpa, aislamiento.

### 3. Duplicidades y solapamientos

Cruzar action items y compromisos contra backlog y specs:
- Tarea mencionada ya existe en backlog → AVISO (evitar duplicidad)
- Compromiso contradice una spec activa → ALERTA
- Trabajo mencionado ya asignado a otra persona/squad → ALERTA (solapamiento)

### 4. Dependencias no explicitas

Detectar dependencias implicitas:
Dependencias implicitas: planificacion, externas, de persona especifica, de otro equipo.

### 5. Decisiones de riesgo

Evaluar decisiones por nivel de riesgo:
- Cambio de arquitectura informal → ALERTA (necesita ADR)
- Cambio de prioridades sin validacion PO/PM → AVISO
- Compromiso de fecha sin estimacion → ALERTA
- Asuncion de que algo "es facil" → AVISO (subestimacion)
- Aceptacion de deuda tecnica nueva → AVISO (documentar en debt-register)

## Clasificacion de alertas

| Nivel | Significado | Accion |
|---|---|---|
| CRITICA | Contradiccion directa con regla o riesgo de dano inmediato | PM actua antes del proximo sprint |
| ALERTA | Riesgo significativo | PM evalua y decide |
| AVISO | Punto a vigilar, no urgente | Documentar y monitorizar |
| INFO | Dato relevante sin riesgo | Registrar para contexto |

## Formato de salida

```
=== RIESGOS ===

## Resumen
- {N} criticas | {N} alertas | {N} avisos | {N} info

## Hallazgos

### [CRITICA] {titulo}
Fuente: "{cita de la transcripcion}"
Regla afectada: {referencia}
Impacto: {consecuencia}
Accion sugerida: {accion PM}

## Dependencias detectadas
| De | Hacia | Tipo | Estado |
|---|---|---|---|

## Conflictos interpersonales
| Personas | Tipo | Severidad | Recomendacion |
|---|---|---|---|
```

## Reglas

1. Solo reportar lo que tiene evidencia — no inventar riesgos
2. Citar siempre la fuente: cita textual + referencia al fichero cruzado
3. Proporcionar accion concreta, no solo senalar el problema
4. No escalar artificialmente — CRITICA solo si hay contradiccion directa
5. Respetar privacidad — no exponer datos personales fuera del ambito del proyecto

## Memoria — POR PROYECTO

Ruta: `projects/{proyecto}/agent-memory/meeting-risk-analyst/MEMORY.md`
Leer al iniciar si existe. Actualizar al terminar. NUNCA escribir en rutas globales.
