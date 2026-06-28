---
name: sales-account-research
description: "Research de Cuenta Comercial: genera un Account Brief estructurado con snapshot, situación actual, pain probable y contexto competitivo."
summary: "Análisis de cuenta objetivo con metodología MEDDIC. Separa datos verificados de hipótesis. Nunca inventa cifras."
maturity: stable
context: fork
context_cost: medium
context_tier: L3
category: "professional-domain/sales"
tags: ["ventas", "account-research", "MEDDIC", "B2B", "cuenta-comercial"]
trigger:
  keywords: ["account brief", "investigar cuenta", "research cuenta", "perfil empresa", "análisis cliente objetivo"]
---

# Skill: Sales Account Research

Genera un Account Brief estructurado de una empresa objetivo antes de una
primera reunión, propuesta o apertura de oportunidad comercial.

## Cuándo usarlo

- Antes de la primera reunión con un prospecto nuevo
- Al retomar una cuenta dormida tras más de 6 meses
- Cuando un comercial se incorpora a un deal en marcha y necesita contexto rápido
- Para preparar una propuesta cuando hay información limitada sobre el cliente

## Inputs requeridos

| Campo | Descripción |
|---|---|
| `empresa` | Nombre oficial y sector de la empresa objetivo |
| `web` | URL de la web corporativa |
| `contacto_conocido` | Nombre y cargo del contacto inicial (si existe) |
| `contexto_deal` | Qué se está intentando vender y en qué fase |
| `fuentes_disponibles` | LinkedIn, web, notas de llamadas, emails, informes públicos |

## Output producido

1. **Snapshot de cuenta**: tamaño, sector, modelo de negocio, presencia geográfica
2. **Situación actual inferida**: tecnología usada, procesos visibles, retos probables
3. **Pain probable**: qué problemas estructurales tiene el tipo de empresa, con qué
   probabilidad aplican a esta cuenta concreta
4. **Stakeholders iniciales**: roles típicos de decisión para esta tipología de compra
5. **Contexto competitivo**: competidores visibles y posicionamiento probable
6. **Ángulo de entrada recomendado**: primer mensaje o propuesta de valor adaptada

## Restricciones absolutas

- Separa siempre `datos_verificados` de `hipótesis` en el output
- NUNCA inventar cifras de facturación, empleados o resultados financieros
- Usar `[DATO PENDIENTE]` para lo que no está disponible en las fuentes
- No presentar hipótesis como datos de mercado establecidos
- Si las fuentes disponibles son insuficientes, decirlo antes del brief

## Relación con otros skills

- **Upstream**: `org-stakeholder-mapper` si ya hay contactos conocidos
- **Downstream**: `sales-proposal-writer` — el brief alimenta la propuesta
- **Paralelo**: `sales-pipeline-analyst` — el brief se integra en el CRM deal
