---
name: sales-proposal-writer
description: "Redactor de Propuesta Comercial B2B: genera propuestas consultivas personalizadas con índice completo y tono adaptable."
summary: "Propuesta B2B con Value Selling + Challenger. Nunca inventa cifras ROI. Usa [DATO PENDIENTE] donde faltan datos."
maturity: stable
context: fork
context_cost: high
context_tier: L3
category: "professional-domain/sales"
tags: ["ventas", "propuesta-comercial", "B2B", "value-selling", "challenger"]
trigger:
  keywords: ["propuesta comercial", "redactar propuesta", "oferta B2B", "documento de propuesta", "presentación comercial"]
---

# Skill: Sales Proposal Writer

Genera propuestas comerciales B2B consultivas y personalizadas, estructuradas
según el estándar español de propuesta profesional. Tono adaptable: FORMAL,
CONSULTIVO o EJECUTIVO según el perfil del destinatario.

## Cuándo usarlo

- Tras una primera reunión con el cliente donde se identificó el pain
- Para responder a un RFP o solicitud de propuesta formal
- Para convertir un Account Brief en un documento de propuesta
- Para actualizar una propuesta rechazada con un enfoque diferente

## Inputs requeridos

| Campo | Descripción |
|---|---|
| `empresa_cliente` | Nombre y datos básicos del cliente |
| `pain_identificado` | Problema concreto que la propuesta resuelve |
| `solucion_propuesta` | Qué se ofrece exactamente |
| `stakeholder_destinatario` | A quién va dirigida: técnico, ejecutivo, sponsor |
| `tono` | FORMAL / CONSULTIVO / EJECUTIVO |
| `datos_disponibles` | ROI conocidos, referencias, casos de éxito aplicables |

## Output producido

Propuesta con índice completo:
1. Resumen ejecutivo (adaptado al tono)
2. Comprensión de la situación del cliente
3. Pain identificado y su coste de no resolución
4. Solución propuesta con alcance detallado
5. Metodología de entrega
6. Resultados esperados (sin inventar cifras)
7. Casos de referencia aplicables
8. Inversión y condiciones
9. Próximos pasos

## Restricciones absolutas

- NUNCA inventar cifras de ROI, ahorro o retorno sin datos reales del cliente
- Usar `[DATO PENDIENTE: descripción específica]` donde faltan datos concretos
- "Prueba de especificidad": verificar que ningún párrafo podría aplicar a otra empresa sin cambios
- No usar lenguaje genérico de catálogo — cada sección debe referenciar el pain específico
- El resumen ejecutivo es para el Economic Buyer: sin tecnicismos, con coste del problema

## Relación con otros skills

- **Upstream**: `sales-account-research` — el brief alimenta la propuesta
- **Paralelo**: `sales-objection-analyzer` — anticipar objeciones antes de enviar
- **Downstream**: `sales-pipeline-analyst` — registrar la propuesta en el pipeline
