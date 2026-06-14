---
status: IMPLEMENTED
---

# SPEC-198 — JudgeVerdict Frozen Dataclass Contract

> **Priority:** P2 · **Estimate (human):** 3-4d · **Estimate (agent):** 4-5h · **Category:** standard · **Type:** refactor

> **Dual estimate**: 3-4 dias humano (definir tipo + migrar 7 jueces + agregador + tests). 4-5h agente.

## Objective

Hoy cada juez del Recommendation Tribunal (SPEC-125 + SPEC-192) emite un dict JSON suelto. Campos esperados: `score, veto, confidence, reason, evidence`. Pero no hay contrato formal — un juez puede olvidar `confidence`, otro puede usar `score` como string en lugar de int, otro puede emitir `evidence: ""` en lugar de `[]`. El agregador defiende con jq fallbacks (`.confidence // 0`).

DiffusionGemma usa `flax.struct.dataclass` y `@dataclasses.dataclass(frozen=True)` para todos los outputs entre fases (`SampleStepOutput`, `_WhileLoopCarry`, etc.). Inmutables, kw-only, hashables. Esto:
1. Documenta el contrato en codigo, no en prosa dispersa.
2. Hace que un juez que rompe contrato falle al emitir, no en el agregador.
3. Permite type-checking estatico.

Esta spec define `JudgeVerdict` como dataclass Python frozen, con factory de validacion que cualquier juez usa. El agregador consume `JudgeVerdict` en lugar de dict.

Trade-off honesto: refactor que toca 7 jueces + agregador + tests. **No anade funcionalidad nueva**. Solo robustez. Justificable si en el ultimo mes hubo >=2 bugs por contrato roto entre juez-agregador. Si no los hubo, P3, no P2. Telemetria pendiente.

## Principles affected

- **#5 Truth as common good** — Contrato explicito vs prosa dispersa.
- **#3 Reversible** — Cada juez puede revertirse a dict suelto si el wrapper falla; el agregador es retrocompatible (acepta JSON con o sin schema).

## Design

### Overview

```
[juez emite dict crudo (legacy)]
            ↓
[wrapper JudgeVerdict.from_dict(d) -> ValidationError | JudgeVerdict]
            ↓
[serializa a JSON con schema_version=1]
            ↓
[agregador parsea JudgeVerdict.from_json(s)]
            ↓
[type-checked downstream: v.score, v.veto, v.evidence]
```

### Components

| # | Name | Kind | Purpose |
|---|------|------|---------|
| 1 | `scripts/recommendation-tribunal/judge_verdict.py` | py module (stdlib) | `@dataclass(frozen=True, kw_only=True) class JudgeVerdict` con factory + validacion |
| 2 | Wrappers en cada juez | mod existente | Parsea dict crudo, llama `JudgeVerdict.from_dict`, serializa a JSON |
| 3 | Modificar `aggregate.sh` | extension | Parsea JudgeVerdict en lugar de dict; fallback retrocompatible |
| 4 | Tests pytest `tests/scripts/test_judge_verdict.py` | tests | 20+ casos: validation, serializacion, retrocompat |
| 5 | `docs/rules/domain/judge-verdict-schema.md` | rule | Documenta el schema y el patron de extension |

### Contracts

#### JudgeVerdict

```python
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Literal
import json

@dataclass(frozen=True, kw_only=True)
class JudgeVerdict:
    """Schema v1 del veredicto de un juez del Recommendation Tribunal.

    Todos los campos son requeridos excepto `evidence` (default []) y
    `mitigation` (default None, solo usado por algunos jueces como
    expertise-asymmetry).
    """
    schema_version: Literal[1] = 1
    judge: str                              # nombre del juez ej "sycophancy"
    score: int                              # 0-100
    veto: bool
    confidence: float                       # 0.0-1.0
    reason: str                             # 1 frase
    evidence: tuple[str, ...] = field(default_factory=tuple)
    mitigation: str | None = None
    extra: dict = field(default_factory=dict)  # campos especificos del juez

    def __post_init__(self):
        # Tuple para ser hashable (frozen requires)
        if not isinstance(self.evidence, tuple):
            object.__setattr__(self, 'evidence', tuple(self.evidence))
        if not (0 <= self.score <= 100):
            raise ValueError(f"score must be 0-100, got {self.score}")
        if not (0.0 <= self.confidence <= 1.0):
            raise ValueError(f"confidence must be 0.0-1.0, got {self.confidence}")
        if not self.reason or len(self.reason) > 500:
            raise ValueError(f"reason must be 1-500 chars, got {len(self.reason)}")

    @classmethod
    def from_dict(cls, d: dict) -> "JudgeVerdict":
        # Tolerancia: aceptar evidence como list, str (split), o ausente
        evidence = d.get("evidence", ())
        if isinstance(evidence, str):
            evidence = (evidence,) if evidence else ()
        elif isinstance(evidence, list):
            evidence = tuple(evidence)
        return cls(
            judge=d["judge"],
            score=int(d["score"]),
            veto=bool(d["veto"]),
            confidence=float(d.get("confidence", 0.0)),
            reason=str(d.get("reason", "no reason provided")),
            evidence=evidence,
            mitigation=d.get("mitigation"),
            extra={k: v for k, v in d.items() if k not in {
                "judge", "score", "veto", "confidence", "reason",
                "evidence", "mitigation", "schema_version"
            }},
        )

    @classmethod
    def from_json(cls, s: str) -> "JudgeVerdict":
        return cls.from_dict(json.loads(s))

    def to_dict(self) -> dict:
        d = {
            "schema_version": self.schema_version,
            "judge": self.judge,
            "score": self.score,
            "veto": self.veto,
            "confidence": self.confidence,
            "reason": self.reason,
            "evidence": list(self.evidence),
        }
        if self.mitigation is not None:
            d["mitigation"] = self.mitigation
        d.update(self.extra)
        return d

    def to_json(self) -> str:
        return json.dumps(self.to_dict())
```

#### Aggregator backward compatibility

`aggregate.sh` consume `JudgeVerdict.from_dict()` que aplica defaults sensatos. Si un juez emite legacy dict sin `confidence`, default 0.0; veto efectivo solo si conf>=0.8 -> no triggers VETO accidental. **Retrocompat sin downgrade silencioso.**

### Configuration

Sin nuevas env vars. Solo refactor.

## Acceptance criteria

1. `JudgeVerdict(judge="x", score=50, veto=False, confidence=0.5, reason="ok")` valida.
2. `JudgeVerdict(score=200, ...)` raise ValueError.
3. `JudgeVerdict(confidence=1.5, ...)` raise ValueError.
4. `from_dict({"judge":"x","score":50,"veto":false,"reason":"ok"})` aplica default confidence=0.0.
5. `from_dict({...,"evidence":"single phrase"})` convierte a tupla `("single phrase",)`.
6. `from_dict({...,"evidence":["a","b"]})` convierte a `("a","b")`.
7. `to_json()` produce JSON parseable que round-trips a JudgeVerdict identica via `from_json()`.
8. Frozen: `v.score = 99` raise FrozenInstanceError.
9. Hashable: `hash(v)` no falla; dos JudgeVerdicts identicas tienen mismo hash.
10. Cada uno de los 7 jueces (memory, rule, hallucination, expertise, sycophancy, concession, repetition-truth) emite JSON validable por `JudgeVerdict.from_json()`.
11. `aggregate.sh` recibe JudgeVerdicts y verdict final coincide bit-a-bit con el comportamiento previo (legacy dict).
12. Test: 5 dicts legacy de los logs reales del workspace todos parsean sin error.
13. Test: 5 dicts con campos extra (ej. `cited_priors` del concession-judge) preservan los extras en `v.extra`.
14. CHANGELOG documenta el cambio + plan de deprecation del formato legacy.

## Out of scope

- Migrar Truth Tribunal (SPEC-106). Misma idea, otra spec.
- Schema v2: introducir cambios solo cuando esten justificados.
- Validacion strict que rechace dicts legacy: aceptar como tolerancia, NO romper backward compat.

## Dependencies

- Related: SPEC-125, SPEC-192. Compatible con SPEC-195 (iterative) y SPEC-196 (early-cancel).

## Migration path

| Semana | Cambio |
|---|---|
| 1 | Implementar `judge_verdict.py` + tests. |
| 2 | Modificar 1 juez (sycophancy) como piloto. Verificar agregador acepta. |
| 3 | Migrar los 6 jueces restantes. |
| 4 | Documentar regla; CHANGELOG. |
| 8 | Si todo estable 30d, considerar deprecar dict legacy en aggregate (warning). |

Reverse: cada juez puede emitir dict legacy si el wrapper falla. El agregador acepta ambos.

## Reference code

Patron Gemma:

```python
flax struct dataclass decorator
class SampleStepOutput:
    sampled_tokens: Tokens
    sc_embeddings: Embeddings
    logits: Logits
    modified_tokens_mask: Bool['*B L']
```

Inmutable, type-checked, hashable, serializable.

## Impact statement

Refactor de robustez. No anade features. Reduce probabilidad de bugs cross-juez (el juez que olvida un campo) en el orden del 80% (los validadores fallan al emitir, no al consumir). Coste: 2-3d de trabajo de migration.

Justificable solo si telemetria muestra >=2 incidentes en 90d por contrato roto. Si la telemetria muestra 0, P3 (no urgente).

Origen: patron `flax.struct.dataclass` y `@dataclasses.dataclass(frozen=True)` consistente en Gemma.

## OpenCode Implementation Plan

**Classification**: Tier 2 (refactor cross-spec).

### Phase 1 — Module + tests (semana 1)

1. Crear `scripts/recommendation-tribunal/judge_verdict.py`.
2. Tests pytest: 20+ casos.

### Phase 2 — Pilot juez (semana 2)

3. Modificar sycophancy-judge para emitir via JudgeVerdict.
4. Verificar aggregate.sh sigue pasando con outputs nuevos.
5. Tests bats end-to-end.

### Phase 3 — Migracion completa (semana 3)

6. Migrar los 6 jueces restantes.
7. Update tests bats para todos.

### Phase 4 — Documentacion + telemetria (semana 4)

8. Crear `docs/rules/domain/judge-verdict-schema.md`.
9. Telemetria a `output/judge-verdict-validation-errors.jsonl` para detectar regresiones.

### Risks

- **Migrar 7 jueces toca muchos prompts**: cada juez es markdown con prompt. La forma del JSON output esta documentada en cada uno. Mitigacion: piloto + verificar antes de extender.
- **Round-trip via JSON pierde tipos** (tuple vs list): `to_dict` convierte tuple a list para JSON; `from_dict` reconvierte. Test 7 lo verifica.
- **Extras dict pierde orden**: aceptable; las pruebas comparan keys + values, no orden.
