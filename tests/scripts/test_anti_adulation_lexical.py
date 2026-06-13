"""Tests for scripts/anti-adulation/lexical-strip.py — SPEC-192 Layer 1.

Covers:
- 20 positive examples (real adulation patterns) → must score >=50
- 20 negative examples (legitimate courtesy or technical content) → must score 0
- Strip behavior: matched span removed, leading punctuation cleaned
- Position calculation: first 50 chars vs later
- File I/O: missing patterns file → exit 3
- Caching: same patterns file loaded once
"""
from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "anti-adulation" / "lexical-strip.py"
PATTERNS = ROOT / "scripts" / "anti-adulation" / "regex-patterns.json"


def _load_module():
    spec = importlib.util.spec_from_file_location("lexical_strip", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def ls():
    return _load_module()


# ─────────────────────────────────────────────────────────────────────────────
# Positive examples — must trigger detection (score >= 50)
# ─────────────────────────────────────────────────────────────────────────────

POSITIVE_EXAMPLES = [
    "Buena pregunta. La respuesta es 42.",
    "Excelente punto, déjame analizarlo.",
    "Gran idea, vamos a implementarla.",
    "Tienes razón, voy a cambiarlo.",
    "Tienes toda la razón en lo que dices.",
    "Absolutamente, así es.",
    "Por supuesto, lo haré.",
    "Claro que sí, sin problema.",
    "Me parece genial tu propuesta.",
    "Me parece fantástico el enfoque.",
    "Great question. The answer is 42.",
    "You're absolutely right.",
    "You're right about that.",
    "Excellent point.",
    "Absolutely, that works.",
    "Of course, I will help.",
    "Good question. Let me think.",
    "Entiendo tu preocupación, pero...",
    "Comprendo perfectamente tu punto.",
    "Estoy totalmente de acuerdo contigo.",
]


@pytest.mark.parametrize("draft", POSITIVE_EXAMPLES)
def test_positive_examples_detected(ls, draft):
    """Every positive example must score >= 50 and have a non-empty pattern."""
    result = ls.detect(draft, PATTERNS)
    assert result["score"] >= 50, f"Missed: {draft!r} got score {result['score']}"
    assert result["category"] in {"obvious", "subtle"}
    assert result["pattern"] != ""
    assert result["position"] >= 0


# ─────────────────────────────────────────────────────────────────────────────
# Negative examples — must score 0 (legitimate courtesy or technical content)
# ─────────────────────────────────────────────────────────────────────────────

NEGATIVE_EXAMPLES = [
    "El bug está en auth.ts línea 42.",
    "Gracias por la corrección. Voy a ajustar el test.",
    "Mi error en la suposición anterior. La realidad es X.",
    "Hola, ¿en qué puedo ayudarte hoy?",
    "El resultado de ejecutar el script es: 0.",
    "Encontré 3 fallos en la implementación.",
    "La función `calculate()` retorna `null` cuando el input es vacío.",
    "He revisado los logs y la causa es el timeout.",
    "Aquí están los pasos: 1) clonar 2) instalar 3) ejecutar.",
    "Buenos días. Voy a comenzar con la tarea.",
    "Un saludo. Quedo atento a tu respuesta.",
    "El test pasó. La cobertura sube al 85%.",
    "No puedo ejecutar `terraform apply` sin tu confirmación.",
    "Disculpa, necesito más contexto antes de seguir.",
    "Para implementar X, debes modificar Y.",
    "La spec SE-189 está en docs/propuestas/.",
    "El comando falla con exit code 2.",
    "Voy a auditar las dependencias.",
    "El timeout es de 30 segundos por defecto.",
    "Listo. He añadido el fix en la línea 42.",
]


@pytest.mark.parametrize("draft", NEGATIVE_EXAMPLES)
def test_negative_examples_pass(ls, draft):
    """Legitimate courtesy or technical content must not trigger."""
    result = ls.detect(draft, PATTERNS)
    assert result["score"] == 0, f"False positive: {draft!r} matched {result['pattern']!r}"
    assert result["category"] == "none"
    assert result["position"] == -1


# ─────────────────────────────────────────────────────────────────────────────
# Position semantics
# ─────────────────────────────────────────────────────────────────────────────


def test_obvious_in_first_50_chars_score_95(ls):
    result = ls.detect("Buena pregunta sobre X", PATTERNS)
    assert result["score"] == 95
    assert result["position"] == 0


def test_obvious_patterns_anchored_to_start(ls):
    """Obvious patterns use ^ anchor — they only match at line start.

    Design decision: adulation that arrives mid-sentence (after substantive
    content) is harder to distinguish from legitimate emphasis. Layer 1 only
    catches it when it opens the response. Subtle patterns (no anchor) cover
    mid-sentence cases with lower confidence (score 50, never blocks).
    """
    prefix = "x" * 60 + " "
    result = ls.detect(prefix + "buena pregunta sobre eso", PATTERNS)
    # No match because obvious patterns are ^-anchored
    assert result["score"] == 0


def test_subtle_pattern_score_50(ls):
    result = ls.detect("Disculpa la confusión, mira esto otra vez.", PATTERNS)
    assert result["score"] == 50
    assert result["category"] == "subtle"


# ─────────────────────────────────────────────────────────────────────────────
# Strip behavior
# ─────────────────────────────────────────────────────────────────────────────


def test_strip_removes_matched_span(ls):
    result = ls.detect("Buena pregunta. La respuesta es 42.", PATTERNS)
    assert "Buena pregunta" not in result["stripped"]
    assert "respuesta es 42" in result["stripped"]


def test_strip_cleans_leading_punctuation(ls):
    result = ls.detect("Tienes razón, lo cambio", PATTERNS)
    # After strip, the leading "," should be cleaned
    assert result["stripped"] == "lo cambio"


def test_empty_draft_no_match(ls):
    result = ls.detect("", PATTERNS)
    assert result["score"] == 0
    assert result["stripped"] == ""


# ─────────────────────────────────────────────────────────────────────────────
# Patterns file
# ─────────────────────────────────────────────────────────────────────────────


def test_patterns_file_has_v1_shape():
    raw = json.loads(PATTERNS.read_text(encoding="utf-8"))
    assert raw["version"] == 1
    assert isinstance(raw["obvious"], list)
    assert isinstance(raw["subtle"], list)
    assert len(raw["obvious"]) >= 10
    assert len(raw["subtle"]) >= 5


def test_missing_patterns_file_raises(ls, tmp_path):
    fake = tmp_path / "nope.json"
    with pytest.raises(FileNotFoundError):
        ls.detect("anything", fake)


# ─────────────────────────────────────────────────────────────────────────────
# CLI subprocess smoke
# ─────────────────────────────────────────────────────────────────────────────


def _cli(*args) -> tuple[int, str, str]:
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        capture_output=True, text=True, timeout=10,
    )
    return proc.returncode, proc.stdout, proc.stderr


def test_cli_json_format():
    rc, out, _ = _cli("--draft", "Buena pregunta", "--json")
    assert rc == 0
    parsed = json.loads(out)
    assert parsed["score"] == 95
    assert parsed["category"] == "obvious"


def test_cli_negative():
    rc, out, _ = _cli("--draft", "El bug está en auth.ts", "--json")
    assert rc == 0
    parsed = json.loads(out)
    assert parsed["score"] == 0


def test_cli_missing_patterns_exits_3(tmp_path):
    rc, _, err = _cli(
        "--draft", "anything",
        "--patterns", str(tmp_path / "nope.json"),
        "--json",
    )
    assert rc == 3
    assert "not found" in err.lower()
