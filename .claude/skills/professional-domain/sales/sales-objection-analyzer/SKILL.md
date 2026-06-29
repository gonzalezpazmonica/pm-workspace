---
name: sales-objection-analyzer
description: "Analizador de Objeciones Comerciales: clasifica y responde objeciones según taxonomía y etapa del deal."
summary: "Recibe objeción literal + contexto. Produce tipo, causa raíz, respuesta recomendada y señal de alerta si el deal está perdido."
maturity: stable
context: fork
context_cost: low
context_tier: L3
category: "professional-domain/sales"
tags: ["ventas", "objeciones", "deal", "PRECIO", "TIMING", "COMPETENCIA"]
trigger:
  keywords: ["objeción", "el cliente dice", "no están convencidos", "pero el precio", "análisis objeción"]
---

# Skill: Sales Objection Analyzer

Clasifica objeciones comerciales según su tipo real (no el tipo declarado),
identifica la causa raíz y produce una respuesta recomendada con pregunta
de seguimiento para avanzar el deal.

## Cuándo usarlo

- Tras recibir una objeción en reunión o email que bloquea el avance
- Cuando el deal lleva semanas sin movimiento y no está claro el porqué
- Para preparar respuestas a objeciones frecuentes antes de una reunión
- Para diagnosticar si un deal está perdido o recuperable

## Inputs requeridos

| Campo | Descripción |
|---|---|
| `objecion_literal` | Texto exacto de la objeción, tal como la expresó el cliente |
| `etapa_deal` | Prospección / Calificación / Propuesta / Negociación / Cierre |
| `contexto` | Historial del deal, quién la hace, qué se sabe del cliente |
| `solución_propuesta` | Qué se está vendiendo |

## Output producido

1. **Tipo de objeción**: PRECIO / TIMING / COMPETENCIA / RIESGO / INTERNO / OTRO
2. **Causa raíz probable**: por qué surge realmente (no siempre la razón declarada)
3. **Respuesta recomendada**: texto adaptado al contexto y la etapa
4. **Pregunta de seguimiento**: para obtener más información o avanzar
5. **Señal de alerta**: si la objeción indica que el deal está perdido

## Restricciones absolutas

- No inventar información sobre el cliente — solo trabajar con el contexto aportado
- Señal de alerta obligatoria si la objeción sugiere que el Economic Buyer no está alineado
- La respuesta recomendada no es una plantilla genérica — debe referenciar el contexto
- No minimizar objeciones legítimas con frases del tipo "eso es normal"

## Relación con otros skills

- **Upstream**: `sales-account-research` — contexto de cuenta para interpretar la objeción
- **Paralelo**: `sales-pipeline-analyst` — registrar el tipo de objeción por deal
- **Downstream**: `sales-proposal-writer` — ajustar propuesta si la objeción revela gaps
