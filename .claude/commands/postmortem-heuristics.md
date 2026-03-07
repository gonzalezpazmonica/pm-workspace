---
name: postmortem-heuristics
description: Extract debugging heuristics from postmortems
---

---

# Compilar Debugging Heuristics

**alias:** `/postmortem-heuristics`, `/heuristics-compile`

**propósito:** Extraer reglas "si X, chequea Y" de todos los postmortems.

**parámetros:** 
- `--module {nombre}` (agrupar por módulo)
- `--category {auth|db|perf|etc}` (agrupar por categoría)
- Sin parámetros: compilar todas

## Flujo

1. Leer "Heuristic Extraction" de postmortems
2. Agrupar por módulo/categoría
3. Desduplicar similares
4. Ordenar por frecuencia
5. Generar playbook: `output/debugging-playbook.md`

## Template de heurística

```
### Cuando: {síntoma observable}
- Checklist: {métrica/log primero}
- Causa común: {patrón raíz}
- False positive: {lo que parece pero no}
- Escalada: {a quién llamar}
```

## Output

Playbook ordenado por severidad. Listo para on-call en stress.
