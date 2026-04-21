---
name: mutation-audit
description: Mutation testing — mide calidad real de tests, detecta zombies AI-generated. On-demand sobre módulo concreto. Invocable.
summary: |
  Mutation testing on-demand. Siembra mutantes determinísticos en un
  módulo y mide cuántos matan los tests. Detecta tests zombies (cobertura
  alta pero sin asserciones que capturen cambios lógicos).
maturity: beta
context: fork
agent: test-engineer
category: "quality"
tags: ["testing", "mutation", "quality", "zombies", "ai-generated"]
priority: "medium"
disable-model-invocation: false
user-invocable: true
allowed-tools: [Read, Bash, Glob]
---

# Skill: Mutation Audit

> Detecta tests zombies. Cobertura alta ≠ tests efectivos.
> Ref: SE-035, research `javiergomezcorio substack` (57% → 74% mutation score automated).

## Cuándo usar

- Sprint-end quality check sobre módulos críticos con tests AI-generated
- Pre-merge de specs que añaden batería grande de tests
- Auditoría periódica (mensual) de módulos core
- Cuando la cobertura de un módulo es >90% pero se sospecha debilidad real

## Cuándo NO usar

- Cada PR (demasiado costoso, CI bloqueante)
- Módulos sin tests aún (antes escribir tests básicos)
- Lenguajes no soportados en Slice 1 (Slice 1: bash + python + TS)

## Invocación

```bash
# Bash module
bash scripts/mutation-audit.sh --target scripts/X.sh --tests tests/test-X.bats

# Python module
bash scripts/mutation-audit.sh --target src/module.py --tests tests/test_module.py --runner pytest

# TypeScript
bash scripts/mutation-audit.sh --target src/Y.ts --tests test/Y.test.ts --runner "npm test"

# Con threshold custom
bash scripts/mutation-audit.sh --target scripts/X.sh --tests tests/test-X.bats --threshold 80 --mutants 10 --json
```

## Output

### Verbose (default)

```
=== SE-035 Mutation Audit ===
Target:    scripts/X.sh
Tests:     tests/test-X.bats
Mutants:   5 seeded
Killed:    4
Survived:  1 (line 42: comparison-boundary)
Score:     80% [PASS threshold 70%]
```

### JSON (--json)

```json
{
  "target":"scripts/X.sh",
  "tests":"tests/test-X.bats",
  "mutants_total":5,
  "mutants_killed":4,
  "mutants_survived":1,
  "score_pct":80,
  "threshold_pct":70,
  "verdict":"PASS",
  "survivors":[{"line":42,"mutator":"comparison-boundary","diff":"..."}]
}
```

## Mutadores (Slice 1)

| Mutador | Aplica a | Ejemplo |
|---|---|---|
| arithmetic-op-swap | bash/py/ts | `+` → `-`, `*` → `/` |
| comparison-boundary | bash/py/ts | `>` → `>=`, `<` → `<=` |
| conditional-negate | bash/py/ts | `if X` → `if ! X` |
| return-null | py/ts | `return X` → `return None/null` |

## Interpretación del score

- **≥ 80%**: tests fuertes, detectan cambios lógicos reales
- **70-79%**: tests aceptables, hay algunos survivors
- **< 70%**: tests débiles o zombies — revisar

Cada superviviente (mutante no matado) indica un gap concreto: diff muestra qué cambio NO fue detectado.

## Integración en flujo

- `/mutation-audit --target scripts/X.sh` (command wrapper pendiente)
- Sprint-end: ejecutar sobre módulos críticos del sprint
- Post-merge: trending mensual en `output/mutation-scores-YYYYMM.md`

## Restricciones

- Opera sobre copia en `$TMPDIR` — NO modifica el repo real
- Mutadores determinísticos con `--seed` para reproducibilidad
- Max 20 mutantes por invocación (bound de tiempo)

## Referencias

- Spec: `docs/propuestas/SE-035-mutation-testing-skill.md`
- Script: `scripts/mutation-audit.sh`
- Tests: `tests/test-mutation-audit.bats`
- Research: 2026-04-18 javiergomezcorio substack (57% → 74% automated)
- Roadmap: Era 183 Tier 3 Champions #2
