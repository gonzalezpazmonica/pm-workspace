---
spec_id: SPEC-103
title: Deterministic-first pattern for word / pptx / excel digest agents
status: IN_PROGRESS
origin: opendataloader-pdf analysis pattern (2026-04-15)
severity: Media
effort: ~6h
priority: baja
---

# SPEC-103: Deterministic-first Digests

## Problema

Los agentes `word-digest`, `pptx-digest`, `excel-digest` siempre invocan
Claude Vision para imágenes embebidas, incluso cuando no aportan
información nueva (logos, iconos, header corporativo). Esto:

- Infla el coste de cada digest
- Añade latencia evitable
- Contamina el output con descripciones irrelevantes

opendataloader-pdf valida el patrón **local-first, AI solo en páginas de
baja confianza**. Aplicar mismo patrón a word/pptx/excel sin cambiar de
librería base.

## Solucion

Heurística de confianza local antes de invocar Vision:

```
1. Extraer estructura con python-docx / python-pptx / openpyxl
2. Por cada imagen:
   a. Computar checksum SHA-256
   b. Si checksum en cache "irrelevant" (logos, iconos vistos antes) → skip
   c. Si tamaño < umbral (< 50x50 px o < 10KB) → skip (probable icono)
   d. Si aspect ratio extremo (banner horizontal) → skip (probable header)
3. Para imágenes que pasan filtros: invocar Vision
4. Registrar decisión en log para mejorar heurística
```

## Cache de imágenes irrelevantes

```
~/.savia/digest-cache/images/
├── skip-list.txt       # SHA-256 de imágenes conocidas irrelevantes
└── last-seen.jsonl     # Log: {sha, decision, timestamp, path}
```

Si una imagen aparece ≥3 veces marcada como "no aporta info", auto-añadir
a skip-list. Heurística se refina con uso.

## Criterios de aceptacion

- [ ] `scripts/image-relevance-filter.sh` con check/skip/log subcomandos
- [ ] Heurísticas de tamaño, aspect ratio, cache de checksums
- [ ] `word-digest`, `pptx-digest`, `excel-digest` consultan filtro antes de Vision
- [ ] Log de decisiones en cache (refinamiento automático)
- [ ] Tests BATS >= 12 casos
- [ ] Reducción medible de llamadas Vision (target: 40% menos)

## Out of scope

- Migración de pdf-digest (SPEC-102)
- ML model para decidir relevance (heurísticas simples bastan)

## Referencias

- opendataloader-pdf hybrid mode pattern
- `.claude/agents/word-digest.md`, `pptx-digest.md`, `excel-digest.md`
