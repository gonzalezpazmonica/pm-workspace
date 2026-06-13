"""judge_verdict.py — SPEC-198: Schema v1 del veredicto de un juez del Tribunal.

Frozen dataclass que valida y serializa el output de los 7 jueces del
Recommendation Tribunal (SPEC-125 + SPEC-192). Reemplaza el uso de dicts
sueltos por un contrato Python tipado.

- Frozen: inmutable tras instanciacion.
- kw-only: forzar nombres explicitos al construir.
- Validation: rango de score 0-100, confidence 0.0-1.0, reason 1-500 chars.
- Backward compat: from_dict acepta dicts legacy con defaults sensatos.
- Hashable: tuple para evidence (no list).
- JSON round-trip: to_json/from_json preservan datos.

Stdlib only. No external deps.

Ref: docs/propuestas/SPEC-198-judge-verdict-frozen-dataclass.md
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Any, Literal


@dataclass(frozen=True, kw_only=True)
class JudgeVerdict:
    """Schema v1 del veredicto de un juez del Recommendation Tribunal.

    All fields are required unless marked optional (evidence defaults to
    empty tuple; mitigation defaults to None; extra defaults to empty dict).
    """
    schema_version: Literal[1] = 1
    judge: str = ""
    score: int = 0
    veto: bool = False
    confidence: float = 0.0
    reason: str = ""
    evidence: tuple[str, ...] = field(default_factory=tuple)
    mitigation: str | None = None
    extra: dict = field(default_factory=dict, hash=False, compare=False)

    def __post_init__(self) -> None:
        """Validate after construction (frozen requires object.__setattr__)."""
        # Coerce evidence to tuple if it arrives as list (round-trip JSON)
        if not isinstance(self.evidence, tuple):
            object.__setattr__(self, 'evidence', tuple(self.evidence))

        if not self.judge:
            raise ValueError("judge name must be non-empty")
        if not isinstance(self.score, int) or not (0 <= self.score <= 100):
            raise ValueError(f"score must be int 0-100, got {self.score!r}")
        if not isinstance(self.veto, bool):
            raise ValueError(f"veto must be bool, got {type(self.veto).__name__}")
        if not isinstance(self.confidence, (int, float)) or not (0.0 <= self.confidence <= 1.0):
            raise ValueError(f"confidence must be 0.0-1.0, got {self.confidence!r}")
        if not self.reason:
            raise ValueError("reason must be non-empty")
        if len(self.reason) > 500:
            raise ValueError(f"reason must be 1-500 chars, got {len(self.reason)}")

    @classmethod
    def from_dict(cls, d: dict) -> "JudgeVerdict":
        """Build from raw dict (legacy-tolerant).

        Accepts:
        - missing confidence -> 0.0
        - missing reason -> "no reason provided"
        - evidence as str -> single-element tuple
        - evidence as list -> tuple
        - missing evidence -> empty tuple
        - extra fields -> preserved in `.extra`

        Raises ValueError if score, veto, or judge name are invalid.
        """
        if not isinstance(d, dict):
            raise TypeError(f"from_dict expects dict, got {type(d).__name__}")

        # Normalize evidence
        evidence_raw = d.get("evidence", ())
        if evidence_raw is None:
            evidence: tuple = ()
        elif isinstance(evidence_raw, str):
            evidence = (evidence_raw,) if evidence_raw else ()
        elif isinstance(evidence_raw, (list, tuple)):
            evidence = tuple(str(e) for e in evidence_raw)
        else:
            evidence = (str(evidence_raw),)

        known = {"judge", "score", "veto", "confidence", "reason",
                 "evidence", "mitigation", "schema_version"}
        extra = {k: v for k, v in d.items() if k not in known}

        return cls(
            judge=str(d.get("judge", "unknown")),
            score=int(d.get("score", 0)),
            veto=bool(d.get("veto", False)),
            confidence=float(d.get("confidence", 0.0)),
            reason=str(d.get("reason", "no reason provided")),
            evidence=evidence,
            mitigation=d.get("mitigation"),
            extra=extra,
        )

    @classmethod
    def from_json(cls, s: str) -> "JudgeVerdict":
        """Parse JSON string into a JudgeVerdict."""
        return cls.from_dict(json.loads(s))

    def to_dict(self) -> dict[str, Any]:
        """Serialize to dict (evidence as list for JSON-friendliness)."""
        d: dict[str, Any] = {
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
        # Extras last (do not override schema fields)
        for k, v in self.extra.items():
            if k not in d:
                d[k] = v
        return d

    def to_json(self) -> str:
        """Serialize to JSON string."""
        return json.dumps(self.to_dict(), ensure_ascii=False)


def validate_dict(d: dict) -> tuple[bool, str]:
    """Validate without raising; returns (is_valid, error_msg).

    Convenience for the aggregator to log validation failures without
    crashing the tribunal pipeline.
    """
    try:
        JudgeVerdict.from_dict(d)
        return True, ""
    except (ValueError, TypeError, KeyError) as e:
        return False, str(e)


if __name__ == "__main__":
    # Quick CLI smoke for `judge_verdict.py <json_file>`
    import sys
    if len(sys.argv) != 2:
        print("usage: judge_verdict.py <json_file>", file=sys.stderr)
        sys.exit(2)
    try:
        with open(sys.argv[1]) as f:
            data = json.load(f)
        v = JudgeVerdict.from_dict(data)
        print(v.to_json())
        sys.exit(0)
    except (ValueError, TypeError, json.JSONDecodeError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
