---
id: SPEC-016
title: SPEC-016: Intelligent Compact with Memory Extraction
status: Implemented
origin_date: "2026-03-22"
migrated_at: "2026-04-18"
migrated_from: body-prose
---

# SPEC-016: Intelligent Compact with Memory Extraction

> Status: **PHASE 1 DONE** · Fecha: 2026-03-22 · Phase 1 implementada: 2026-03-22
> Origen: OpenViking (conversation compression) + Fabrik-Codek (quality gate)
> Impacto: Zero-loss compaction — nada importante se pierde al compactar

---

## Problema

`/compact` trunca el contexto para liberar espacio, pero pierde información:
- Decisiones tomadas durante la sesión
- Lecciones aprendidas de errores
- Patrones de trabajo observados
- Estado intermedio de tareas en progreso

context-health.md dice "al compactar, SIEMPRE preservar ficheros modificados,
scores, decisiones", pero esto depende de que Claude lo haga bien cada vez.
No hay mecanismo sistemático.

OpenViking convierte conversación en memorias durables en vez de truncar.
Fabrik-Codek añade quality gate para evitar ruido.

---

## Diseño

### Pre-compact extraction pipeline

Antes de ejecutar /compact, Savia ejecuta un pipeline de extracción:

```
1. SCAN — Identificar en el contexto actual:
   a. Decisiones: "vamos con X", "elegimos Y", "descartamos Z"
   b. Correcciones: "no, eso está mal", "cambia X por Y"
   c. Descubrimientos: "resulta que X funciona así"
   d. Estado de trabajo: "estamos en paso 3 de 5", "falta X"

2. QUALITY GATE — Filtrar:
   a. Min 50 caracteres (no trivial)
   b. No es repetición de algo ya en memoria
   c. No es dato efímero (línea de código, ruta temporal)
   d. Tiene valor entre sesiones (test: "sería útil si lo leo mañana?")

3. CLASSIFY — Por tipo y destino:
   a. Feedback → auto-memory feedback type
   b. Decisión → auto-memory project type / tasks/lessons.md
   c. Estado → preservar en compact summary (no persistir)
   d. Patron → auto-memory user type

4. PERSIST — Escribir en destino correcto

5. COMPACT — Ahora sí, ejecutar /compact normal con summary que incluye:
   - Lista de items extraídos (referencia, no contenido)
   - Estado de trabajo actual
   - Ficheros modificados en la sesión
```

### Compact summary template

Al compactar, el summary siempre incluye:

```
## Session context (pre-compact extraction)
- Decisions persisted: 2 (see auto-memory)
- Lessons captured: 1 (see tasks/lessons.md)
- Current task: [descripcion breve]
- Files modified: [lista]
- Last command: [comando] → [resultado breve]
```

### Integración con SPEC-013

SPEC-013 (Session Memory Extraction) y SPEC-016 comparten el mismo extractor.
La diferencia:
- SPEC-013 se ejecuta al CERRAR sesión (Stop hook, async)
- SPEC-016 se ejecuta al COMPACTAR (inline, sync, rápido)

El extractor es una función compartida con dos modos:
- `mode=full`: analiza todo el transcript (SPEC-013, más lento)
- `mode=quick`: analiza solo el contexto actual (SPEC-016, más rápido)

---

## Implementación

### Fase 1 — Extracción básica en /compact (1 sprint)

1. Actualizar comportamiento de /compact en context-health.md
2. Antes de compactar: scan de decisiones y correcciones
3. Quality gate con umbral de 50 chars
4. Persistir en auto-memory
5. Incluir extraction summary en compact output

### Fase 2 — Extractor compartido con SPEC-013 (1 sprint)

1. Refactorizar extractor como módulo reutilizable
2. SPEC-013 usa mode=full, SPEC-016 usa mode=quick
3. Métricas: items extraídos por compact, falsos positivos

---

## Criterios de aceptación

- [ ] /compact extrae >= 1 item util en sesiones de 20+ min
- [ ] Quality gate rechaza >= 70% de candidatos triviales
- [ ] Compact summary incluye siempre: ficheros, estado, ultimo comando
- [ ] Tiempo adicional de /compact < 3 segundos
- [ ] Ningún ítem duplicado en auto-memory tras compact

---

## Ficheros afectados

- `docs/rules/domain/context-health.md` — actualizar seccion compact
- `scripts/session-extract.sh` — módulo compartido (nuevo)
- `docs/rules/domain/async-hooks-config.md` — documentar

---

## Riesgos

| Riesgo | Mitigacion |
|--------|-----------|
| Extraction lenta retrasa /compact | mode=quick: max 3s, solo contexto actual |
| Ruido en auto-memory | Quality gate estricto + review mensual |
| Extrae decisiones que luego el usuario revierte | Timestamp permite identificar y borrar |
