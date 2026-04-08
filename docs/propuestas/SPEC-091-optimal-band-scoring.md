---
spec_id: SPEC-091
title: Optimal Band Scoring — utilización óptima como banda, no como mínimo
status: Proposed
origin: llmfit research (2026-04-08)
severity: Media
effort: ~1h
---

# SPEC-091: Optimal Band Scoring

## Problema

scoring-curves.md usa degradación lineal para context usage: 0% = 100 score,
100% = 0 score. Esto premia tener contexto vacío, lo cual no es realista.
Un contexto al 5% significa que no estamos usando la herramienta.

llmfit demuestra que la utilización óptima es una BANDA: el score es máximo
cuando la utilización está entre 50-80%, no al 0% ni al 100%.

## Solución

Actualizar la curva de Context Usage en scoring-curves.md:

```
Antes (lineal):
  0% → 100, 50% → 80, 70% → 50, 85% → 25, 100% → 0

Después (banda óptima):
  0-20% → 60  (infrautilización — no estás trabajando)
  20-40% → 85 (calentando — normal inicio de sesión)
  40-65% → 100 (banda óptima — máximo rendimiento)
  65-80% → 70  (degradación gradual — /compact recomendado)
  80-90% → 30  (zona alerta — sin operaciones pesadas)
  90%+ → 5    (crítico — /compact obligatorio)
```

## Criterios de aceptación

- [ ] scoring-curves.md actualizado con banda óptima
- [ ] context-health.md zonas alineadas con nueva curva
- [ ] Tests BATS que verifican la curva (si scoring-curves tiene tests)
- [ ] Documentado el razonamiento (llmfit + TurboQuant)
