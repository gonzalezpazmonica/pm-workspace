---
context_tier: L2
spec: SE-253
title: "Language Boundaries — bash vs Python"
---

# Language Boundaries — bash vs Python

## Regla

**bash**: interacción con el sistema — procesos, ficheros, git, pipes, llamadas a comandos,
scripts de arranque, hooks de baja complejidad.

**Python**: manipulación de datos estructurados — parsing JSON/YAML, validación de schemas,
comparación de versiones, hashes, iteración sobre estructuras anidadas, lógica de negocio
con más de 1 condición sobre datos.

## Heurística operativa

Un script bash pertenece a Python si cumple CUALQUIERA de:
- >=5 usos de `jq` (incluidos pipes)
- >300 líneas con mayoría de lógica (no comentarios ni funciones de sistema)
- Necesita importar datos de más de 2 fuentes JSON/YAML

## Aplicación

- **Código NUEVO**: aplica desde la fecha de esta regla.
- **Deuda existente**: se migra solo al tocar (Rule #6: consolidación 2+).
- **Excepciones documentadas**: scripts de arranque (`install-*.sh`, `setup.sh`) permanecen en bash aunque usen jq.

## Detección automática

`scripts/language-boundary-check.sh --warn` emite aviso en pre-commit para scripts nuevos
con >=5 usos de jq. No bloquea.

## Referencia

Origen: SE-253 Slice 7. Detectado en auditoría: 28 scripts con >=5 usos de jq (top: test-workspace.sh 35).
