---
id: SPEC-024
title: SPEC-024: Documentation Audit — Savia en Primera Persona
status: ACCEPTED
origin_date: "2026-03-22"
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-024: Documentation Audit — Savia en Primera Persona

> Status: **READY** · Fecha: 2026-03-22
> Origen: la usuaria — "quiero que seas tu en primera persona quien hables en toda la documentación"
> Impacto: Coherencia de marca, onboarding mas humano

---

## Problema

La documentación de pm-workspace mezcla voces:
- Algunos docs hablan en 3a persona ("pm-workspace gestiona...")
- Otros en imperativo ("ejecuta este comando...")
- Los READMEs ya hablan como Savia (1a persona) desde v3.33.0
- Los docs internos (best-practices, memory-system, etc.) no

El usuario deberia sentir que Savia le habla directamente en TODA
la documentación publica, explicando como funciona por dentro.

---

## Alcance

### Ficheros a auditar y reescribir

| Fichero | Estado actual | Acción |
|---------|--------------|--------|
| docs/best-practices-claude-code.md | 3a persona técnica | Reescribir intro como Savia |
| docs/memory-system.md | 3a persona | Reescribir como "mi sistema de memoria" |
| CONTRIBUTING.md | Impersonal | Savia invita a contribuir |
| SECURITY.md | Legal/técnico | Savia explica seguridad |
| docs/quick-starts/*.md | Mixto | Savia guia al usuario por rol |

### Fuera de alcance

- Reglas de dominio (docs/rules/) — son instrucciones internas, no user-facing
- Specs (docs/propuestas/) — son documentos tecnicos, voz neutra ok
- CHANGELOG — formato estandarizado, no reescribir

---

## Voz de Savia en documentación

Principios (de .claude/profiles/savia.md):
- Primera persona femenino: "yo gestiono", "mi memoria"
- Directa y clara, sin relleno
- Explica el por que, no solo el como
- Trata al lector como adulto competente
- Radical Honesty (Rule #24): sin endulzar, sin exagerar

Ejemplo antes/después:

**Antes:** "PM-Workspace utiliza una jerarquia de memoria..."
**Después:** "Tengo varios niveles de memoria. Los uso así..."

**Antes:** "Los hooks se ejecutan automáticamente..."
**Después:** "Mis hooks se ejecutan solos — yo no puedo saltarmelos."

---

## Implementación

1. Leer cada fichero del alcance
2. Identificar secciones en voz incorrecta
3. Reescribir manteniendo información técnica intacta
4. Verificar que no se pierde ningun dato
5. Mantener limite de 150 lineas donde aplique

## Tests

- Todos los ficheros modificados pasan lint (markdown)
- Ningun dato técnico perdido (diff review)
- validate-ci-local.sh pasa
