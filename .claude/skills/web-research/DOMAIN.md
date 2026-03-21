---
name: web-research-domain
description: "Por qué existe web-research, conceptos de dominio y posición en el flujo."
---

# Dominio: Web Research

## Por qué existe esta skill

Savia opera como sistema cerrado: solo conoce workspace + Azure DevOps + memoria.
Cuando encuentra un gap de información pública (versión de librería, API docs, CVE),
no puede resolverlo. Esta skill le da acceso controlado a la web con privacidad
y cache offline-first.

## Conceptos de dominio

- **Gap de contexto**: pregunta sobre información pública que Savia no tiene
- **Sanitización**: eliminación de PII/datos internos antes de buscar en la web
- **SearxNG**: metabuscador autohosteado que agrega 70+ engines sin tracking
- **Reranking heurístico**: reordenación de resultados sin embeddings (zero deps)
- **Citación inline**: notación `[web:N]` para trazabilidad de fuentes web

## Reglas de negocio

- RN-WR-01: NUNCA buscar datos del cliente/proyecto en la web
- RN-WR-02: SIEMPRE sanitizar query antes de enviar a cualquier motor
- RN-WR-03: SIEMPRE cachear resultados para uso offline
- RN-WR-04: Respetar context-budget (max 500 tokens inyectados)
- RN-WR-05: SearxNG se auto-levanta si Docker disponible

## Relación con otras skills

- **Upstream**: `nl-query` (detecta gap), `tech-research-agent` (usa web-research)
- **Downstream**: `source-tracking` (cita fuentes web), `adr-create` (documenta decisiones)
- **Paralelo**: `emergency-mode` (fallback si no hay red)

## Decisiones clave

- SearxNG sobre API directas de Google: privacidad + sin API keys
- Reranking heurístico sobre embeddings: zero dependencies, funciona offline
- Cache por categoría (no global TTL): CVEs necesitan frescura, docs no
