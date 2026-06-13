"""Tests for scripts/recommendation-tribunal/judge_verdict.py — SPEC-198.

Covers validation, serialization, backward compat with legacy dicts.
"""
from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from dataclasses import FrozenInstanceError
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "recommendation-tribunal" / "judge_verdict.py"


def _load_module():
    import sys as _sys
    spec = importlib.util.spec_from_file_location("judge_verdict", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    _sys.modules["judge_verdict"] = mod  # required for dataclass introspection
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def jv_mod():
    return _load_module()


# ─────────────────────────────────────────────────────────────────────────────
# Construction + validation
# ─────────────────────────────────────────────────────────────────────────────


def test_minimal_valid(jv_mod):
    v = jv_mod.JudgeVerdict(judge="x", score=50, veto=False, confidence=0.5, reason="ok")
    assert v.judge == "x"
    assert v.score == 50
    assert v.veto is False
    assert v.confidence == 0.5
    assert v.reason == "ok"
    assert v.evidence == ()
    assert v.mitigation is None
    assert v.schema_version == 1


def test_score_out_of_range_raises(jv_mod):
    with pytest.raises(ValueError, match="score"):
        jv_mod.JudgeVerdict(judge="x", score=200, veto=False, confidence=0.5, reason="ok")
    with pytest.raises(ValueError, match="score"):
        jv_mod.JudgeVerdict(judge="x", score=-1, veto=False, confidence=0.5, reason="ok")


def test_confidence_out_of_range_raises(jv_mod):
    with pytest.raises(ValueError, match="confidence"):
        jv_mod.JudgeVerdict(judge="x", score=50, veto=False, confidence=1.5, reason="ok")
    with pytest.raises(ValueError, match="confidence"):
        jv_mod.JudgeVerdict(judge="x", score=50, veto=False, confidence=-0.1, reason="ok")


def test_empty_reason_raises(jv_mod):
    with pytest.raises(ValueError, match="reason"):
        jv_mod.JudgeVerdict(judge="x", score=50, veto=False, confidence=0.5, reason="")


def test_reason_too_long_raises(jv_mod):
    with pytest.raises(ValueError, match="1-500 chars"):
        jv_mod.JudgeVerdict(judge="x", score=50, veto=False, confidence=0.5, reason="a" * 501)


def test_empty_judge_raises(jv_mod):
    with pytest.raises(ValueError, match="judge"):
        jv_mod.JudgeVerdict(judge="", score=50, veto=False, confidence=0.5, reason="ok")


def test_veto_not_bool_raises(jv_mod):
    with pytest.raises(ValueError, match="veto must be bool"):
        jv_mod.JudgeVerdict(judge="x", score=50, veto="true", confidence=0.5, reason="ok")


def test_evidence_list_coerced_to_tuple(jv_mod):
    v = jv_mod.JudgeVerdict(judge="x", score=50, veto=False, confidence=0.5,
                            reason="ok", evidence=["a", "b"])
    assert v.evidence == ("a", "b")
    assert isinstance(v.evidence, tuple)


def test_frozen_immutable(jv_mod):
    v = jv_mod.JudgeVerdict(judge="x", score=50, veto=False, confidence=0.5, reason="ok")
    with pytest.raises(FrozenInstanceError):
        v.score = 99


def test_hashable(jv_mod):
    v1 = jv_mod.JudgeVerdict(judge="x", score=50, veto=False, confidence=0.5, reason="ok")
    v2 = jv_mod.JudgeVerdict(judge="x", score=50, veto=False, confidence=0.5, reason="ok")
    assert hash(v1) == hash(v2)


# ─────────────────────────────────────────────────────────────────────────────
# from_dict (backward compat)
# ─────────────────────────────────────────────────────────────────────────────


def test_from_dict_minimal(jv_mod):
    v = jv_mod.JudgeVerdict.from_dict({
        "judge": "x", "score": 50, "veto": False,
        "confidence": 0.5, "reason": "ok"
    })
    assert v.score == 50


def test_from_dict_missing_confidence_defaults_zero(jv_mod):
    v = jv_mod.JudgeVerdict.from_dict({
        "judge": "x", "score": 50, "veto": False, "reason": "ok"
    })
    assert v.confidence == 0.0


def test_from_dict_missing_reason_uses_default(jv_mod):
    v = jv_mod.JudgeVerdict.from_dict({
        "judge": "x", "score": 50, "veto": False, "confidence": 0.5
    })
    assert "no reason" in v.reason.lower()


def test_from_dict_evidence_as_str(jv_mod):
    v = jv_mod.JudgeVerdict.from_dict({
        "judge": "x", "score": 50, "veto": False,
        "confidence": 0.5, "reason": "ok", "evidence": "single phrase"
    })
    assert v.evidence == ("single phrase",)


def test_from_dict_evidence_as_empty_str(jv_mod):
    v = jv_mod.JudgeVerdict.from_dict({
        "judge": "x", "score": 50, "veto": False,
        "confidence": 0.5, "reason": "ok", "evidence": ""
    })
    assert v.evidence == ()


def test_from_dict_evidence_as_list(jv_mod):
    v = jv_mod.JudgeVerdict.from_dict({
        "judge": "x", "score": 50, "veto": False,
        "confidence": 0.5, "reason": "ok", "evidence": ["a", "b", "c"]
    })
    assert v.evidence == ("a", "b", "c")


def test_from_dict_evidence_none(jv_mod):
    v = jv_mod.JudgeVerdict.from_dict({
        "judge": "x", "score": 50, "veto": False,
        "confidence": 0.5, "reason": "ok", "evidence": None
    })
    assert v.evidence == ()


def test_from_dict_preserves_extras(jv_mod):
    v = jv_mod.JudgeVerdict.from_dict({
        "judge": "concession", "score": 70, "veto": False,
        "confidence": 0.8, "reason": "stance reversed",
        "position_changed": True,
        "evidence_diff": "none",
    })
    assert "position_changed" in v.extra
    assert v.extra["position_changed"] is True
    assert v.extra["evidence_diff"] == "none"


def test_from_dict_non_dict_raises(jv_mod):
    with pytest.raises(TypeError, match="dict"):
        jv_mod.JudgeVerdict.from_dict([1, 2, 3])


# ─────────────────────────────────────────────────────────────────────────────
# JSON round-trip
# ─────────────────────────────────────────────────────────────────────────────


def test_to_dict_includes_schema_version(jv_mod):
    v = jv_mod.JudgeVerdict(judge="x", score=50, veto=False, confidence=0.5, reason="ok")
    d = v.to_dict()
    assert d["schema_version"] == 1


def test_to_dict_evidence_as_list(jv_mod):
    v = jv_mod.JudgeVerdict(judge="x", score=50, veto=False,
                            confidence=0.5, reason="ok", evidence=("a", "b"))
    d = v.to_dict()
    assert d["evidence"] == ["a", "b"]
    assert isinstance(d["evidence"], list)


def test_to_dict_omits_mitigation_when_none(jv_mod):
    v = jv_mod.JudgeVerdict(judge="x", score=50, veto=False, confidence=0.5, reason="ok")
    d = v.to_dict()
    assert "mitigation" not in d


def test_to_dict_includes_mitigation_when_set(jv_mod):
    v = jv_mod.JudgeVerdict(judge="x", score=50, veto=False,
                            confidence=0.5, reason="ok", mitigation="reframe")
    d = v.to_dict()
    assert d["mitigation"] == "reframe"


def test_json_roundtrip(jv_mod):
    v1 = jv_mod.JudgeVerdict(
        judge="sycophancy", score=85, veto=True, confidence=0.92,
        reason="empty validation", evidence=("buena pregunta", "lo cambio"),
        extra={"position_changed": True},
    )
    s = v1.to_json()
    v2 = jv_mod.JudgeVerdict.from_json(s)
    assert v1.judge == v2.judge
    assert v1.score == v2.score
    assert v1.veto == v2.veto
    assert v1.confidence == v2.confidence
    assert v1.reason == v2.reason
    assert v1.evidence == v2.evidence
    assert v1.extra["position_changed"] == v2.extra["position_changed"]


def test_to_json_extras_dont_override_schema(jv_mod):
    v = jv_mod.JudgeVerdict(judge="x", score=50, veto=False, confidence=0.5,
                            reason="ok", extra={"score": 999, "custom": "yes"})
    d = v.to_dict()
    assert d["score"] == 50  # schema wins
    assert d["custom"] == "yes"


# ─────────────────────────────────────────────────────────────────────────────
# validate_dict helper
# ─────────────────────────────────────────────────────────────────────────────


def test_validate_dict_returns_true_for_valid(jv_mod):
    ok, err = jv_mod.validate_dict({
        "judge": "x", "score": 50, "veto": False,
        "confidence": 0.5, "reason": "ok"
    })
    assert ok is True
    assert err == ""


def test_validate_dict_returns_false_with_msg_for_invalid(jv_mod):
    ok, err = jv_mod.validate_dict({
        "judge": "x", "score": 200, "veto": False,
        "confidence": 0.5, "reason": "ok"
    })
    assert ok is False
    assert "score" in err


# ─────────────────────────────────────────────────────────────────────────────
# CLI smoke
# ─────────────────────────────────────────────────────────────────────────────


def _cli(*args) -> tuple[int, str, str]:
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        capture_output=True, text=True, timeout=10,
    )
    return proc.returncode, proc.stdout, proc.stderr


def test_cli_valid_file(jv_mod, tmp_path):
    p = tmp_path / "verdict.json"
    p.write_text(json.dumps({
        "judge": "x", "score": 50, "veto": False,
        "confidence": 0.5, "reason": "ok"
    }))
    rc, out, _ = _cli(str(p))
    assert rc == 0
    parsed = json.loads(out)
    assert parsed["score"] == 50


def test_cli_invalid_file_exits_1(jv_mod, tmp_path):
    p = tmp_path / "bad.json"
    p.write_text(json.dumps({
        "judge": "x", "score": 200, "veto": False,
        "confidence": 0.5, "reason": "ok"
    }))
    rc, _, err = _cli(str(p))
    assert rc == 1
    assert "score" in err.lower()


def test_cli_no_args_exits_2(jv_mod):
    rc, _, err = _cli()
    assert rc == 2
    assert "usage" in err.lower()


# ─────────────────────────────────────────────────────────────────────────────
# Real-world legacy dicts (from existing tribunal outputs)
# ─────────────────────────────────────────────────────────────────────────────


def test_legacy_dict_sycophancy(jv_mod):
    # Real format from .opencode/agents/sycophancy-judge.md
    legacy = {
        "score": 85, "veto": False, "confidence": 0.7,
        "reason": "Opens with 'buena pregunta' filler",
        "evidence": ["buena pregunta"],
        "judge": "sycophancy",
    }
    v = jv_mod.JudgeVerdict.from_dict(legacy)
    assert v.score == 85
    assert v.evidence == ("buena pregunta",)


def test_legacy_dict_concession(jv_mod):
    legacy = {
        "score": 70, "veto": False, "confidence": 0.85,
        "reason": "Position reversed without new evidence",
        "position_changed": True,
        "evidence_diff": "none",
        "judge": "concession",
    }
    v = jv_mod.JudgeVerdict.from_dict(legacy)
    assert v.extra["position_changed"] is True
    assert v.extra["evidence_diff"] == "none"
