---
id: SPEC-025
title: SPEC-025: Chinese (ZH) Compatibility Study
status: PROPOSED
origin_date: "2026-03-22"
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-025: Chinese (ZH) Compatibility Study

> Status: **RESEARCH** · Fecha: 2026-03-22 · Score: 3.60
> Origen: Roadmap — expansion multilingual a mercado chino
> Impacto: Accesibilidad para ~1B hablantes potenciales

---

## Problema

pm-workspace funciona en ES/EN y 7 idiomas europeos. El chino
(simplificado y tradicional) presenta retos unicos:

1. **CJK tokenization** — caracteres no separados por espacios
2. **Encoding** — UTF-8 con caracteres de 3 bytes (vs 1 byte latin)
3. **Bidireccionalidad** — mezcla con numeros y código latin
4. **Longitud de texto** — chino es mas denso (menos caracteres = mas información)
5. **Búsqueda** — grep y vector search necesitan tokenizer CJK
6. **Fuentes** — terminal puede no renderizar CJK correctamente

---

## Investigacion necesaria

### R1. Impacto en memory-store

- JSONL maneja UTF-8 nativo → deberia funcionar
- Topic keys: slug generation con caracteres CJK → necesita pinyin o transliteracion
- Vector search: all-MiniLM-L6-v2 soporta chino (multilingual) → verificar recall
- Grep search: regex CJK funciona en bash → verificar

### R2. Impacto en CLI

- Bash maneja UTF-8 si locale correcta (LANG=zh_CN.UTF-8)
- Tablas ASCII: ancho de caracteres CJK (2 columnas vs 1) → problemas de alineacion
- Emojis en banners: compatibles

### R3. Impacto en documentación

- README.zh-CN.md (simplificado) + README.zh-TW.md (tradicional)
- Requiere: revision por hablante nativo (no solo traduccion automatica)

### R4. Impacto en Savia persona

- Savia deberia hablar en chino con tono natural
- Modismos PM son diferentes (Scrum terminology en chino)
- Radical Honesty en contexto cultural chino: ajustar directness

---

## Entregable

Informe en `output/research/chinese-compatibility-report.md`:
- Matriz de compatibilidad por componente
- Cambios necesarios (estimacion de esfuerzo)
- Recomendacion: Go / No-Go / Partial
- Si Go: roadmap de implementación

## Requisitos

- Corpus de test en chino (20 frases PM tipicas)
- Acceso a terminal con soporte CJK
- Idealmente: revision por hablante nativo antes de publicar
