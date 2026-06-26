"""Tests for scripts/router-mode-classifier.py — SPEC-163 Slice 3.

Covers:
- query intent → mode1
- action intent → mode2
- has_code_change=true → always mode2
- estimated_tokens > 5000 → mode2
- confidence in [0, 1]
- output has all required fields
- shadow mode always returns exit 0 (via subprocess)
- multiple workspace intents correctly classified
- conservative default: ambiguous intent → mode2
"""
from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "router-mode-classifier.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("router_mode_classifier", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def clf():
    return _load_module()


# ─── helper ──────────────────────────────────────────────────────────────────

def _run(payload: dict) -> dict:
    """Invoke classifier as subprocess, return parsed output."""
    result = subprocess.run(
        [sys.executable, str(SCRIPT)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout.strip())


# ─── Test 1: query intent → mode1 ────────────────────────────────────────────

def test_query_intent_estado_returns_mode1(clf):
    out = clf.classify({"intent": "ver estado del sprint", "command": "", "has_code_change": False, "estimated_tokens": 100})
    assert out["mode"] == "mode1"


def test_query_intent_listar_returns_mode1(clf):
    out = clf.classify({"intent": "listar todos los items del backlog", "command": "", "has_code_change": False, "estimated_tokens": 200})
    assert out["mode"] == "mode1"


def test_query_intent_show_returns_mode1(clf):
    out = clf.classify({"intent": "show current sprint status", "command": "", "has_code_change": False, "estimated_tokens": 50})
    assert out["mode"] == "mode1"


def test_query_intent_cuantos_returns_mode1(clf):
    out = clf.classify({"intent": "cuántos PBIs quedan en el sprint?", "command": "", "has_code_change": False, "estimated_tokens": 80})
    assert out["mode"] == "mode1"


# ─── Test 2: action intent → mode2 ───────────────────────────────────────────

def test_action_intent_implementar_returns_mode2(clf):
    out = clf.classify({"intent": "implementar nuevo endpoint en la API", "command": "", "has_code_change": False, "estimated_tokens": 300})
    assert out["mode"] == "mode2"


def test_action_intent_commit_returns_mode2(clf):
    out = clf.classify({"intent": "hacer commit con los cambios", "command": "", "has_code_change": False, "estimated_tokens": 150})
    assert out["mode"] == "mode2"


def test_action_intent_crear_returns_mode2(clf):
    out = clf.classify({"intent": "crear una nueva spec para el módulo de autenticación", "command": "", "has_code_change": False, "estimated_tokens": 400})
    assert out["mode"] == "mode2"


def test_action_intent_modificar_returns_mode2(clf):
    out = clf.classify({"intent": "modificar la clase UserService", "command": "", "has_code_change": False, "estimated_tokens": 200})
    assert out["mode"] == "mode2"


# ─── Test 3: has_code_change=true → always mode2 ─────────────────────────────

def test_has_code_change_true_forces_mode2(clf):
    out = clf.classify({"intent": "ver estado del sprint", "command": "sprint-status", "has_code_change": True, "estimated_tokens": 100})
    assert out["mode"] == "mode2"
    assert out["confidence"] == 1.0


def test_has_code_change_overrides_query_intent(clf):
    out = clf.classify({"intent": "listar items", "command": "", "has_code_change": True, "estimated_tokens": 50})
    assert out["mode"] == "mode2"
    assert out["confidence"] == 1.0


def test_has_code_change_overrides_mode1_command(clf):
    out = clf.classify({"intent": "status", "command": "sprint-status", "has_code_change": True, "estimated_tokens": 100})
    assert out["mode"] == "mode2"


# ─── Test 4: estimated_tokens > 5000 → mode2 ─────────────────────────────────

def test_tokens_over_threshold_returns_mode2(clf):
    out = clf.classify({"intent": "ver estado", "command": "sprint-status", "has_code_change": False, "estimated_tokens": 5001})
    assert out["mode"] == "mode2"


def test_tokens_at_threshold_not_mode2(clf):
    # Exactly 5000 should NOT trigger the > 5000 rule
    out = clf.classify({"intent": "ver estado del sprint", "command": "sprint-status", "has_code_change": False, "estimated_tokens": 5000})
    # Should fall through to command tier (mode1 from frontmatter)
    assert out["mode"] == "mode1"


def test_tokens_way_over_threshold(clf):
    out = clf.classify({"intent": "listar items", "command": "", "has_code_change": False, "estimated_tokens": 20000})
    assert out["mode"] == "mode2"


# ─── Test 5: confidence in [0, 1] ────────────────────────────────────────────

@pytest.mark.parametrize("payload", [
    {"intent": "ver estado", "command": "", "has_code_change": False, "estimated_tokens": 100},
    {"intent": "implementar endpoint", "command": "", "has_code_change": True, "estimated_tokens": 300},
    {"intent": "algo completamente ambiguo xyz", "command": "", "has_code_change": False, "estimated_tokens": 0},
    {"intent": "commit push merge", "command": "", "has_code_change": False, "estimated_tokens": 200},
])
def test_confidence_in_range(clf, payload):
    out = clf.classify(payload)
    assert 0.0 <= out["confidence"] <= 1.0, f"confidence={out['confidence']} out of [0,1]"


# ─── Test 6: output has all required fields ───────────────────────────────────

def test_output_has_required_fields(clf):
    out = clf.classify({"intent": "ver sprint", "command": "sprint-status", "has_code_change": False, "estimated_tokens": 100})
    assert "mode" in out
    assert "confidence" in out
    assert "reason" in out
    assert "complexity_tier" in out


def test_mode_is_valid_value(clf):
    out = clf.classify({"intent": "ver estado", "command": "", "has_code_change": False, "estimated_tokens": 100})
    assert out["mode"] in ("mode1", "mode2")


def test_complexity_tier_is_valid_value(clf):
    out = clf.classify({"intent": "ver estado", "command": "", "has_code_change": False, "estimated_tokens": 100})
    assert out["complexity_tier"] in ("mode1", "mode2", "auto")


# ─── Test 7: shadow mode subprocess always exits 0 ───────────────────────────

def test_subprocess_exit_0_normal_input():
    result = subprocess.run(
        [sys.executable, str(SCRIPT)],
        input=json.dumps({"intent": "ver estado del sprint", "command": "sprint-status", "has_code_change": False, "estimated_tokens": 100}),
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0


def test_subprocess_exit_1_invalid_json_but_produces_output():
    """Invalid JSON → exit 1 but still emits conservative mode2 output."""
    result = subprocess.run(
        [sys.executable, str(SCRIPT)],
        input="{not valid json!!!}",
        capture_output=True,
        text=True,
    )
    # Exit 1 on invalid JSON (documented), but output is still valid JSON mode2
    assert result.returncode == 1
    out = json.loads(result.stdout.strip())
    assert out["mode"] == "mode2"


def test_subprocess_empty_input_exits_0():
    result = subprocess.run(
        [sys.executable, str(SCRIPT)],
        input="{}",
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0


# ─── Test 8: workspace intents correctly classified ──────────────────────────

@pytest.mark.parametrize("intent,expected_mode", [
    ("estado del sprint actual", "mode1"),
    ("cuántos story points quedan", "mode1"),
    ("show board status", "mode1"),
    ("ver mi foco del día", "mode1"),
    ("implementar SPEC-163 router", "mode2"),
    ("crear pull request para la feature", "mode2"),
    ("modificar el hook de seguridad", "mode2"),
    ("hacer merge de la rama feature", "mode2"),
])
def test_workspace_intents_classification(clf, intent, expected_mode):
    out = clf.classify({"intent": intent, "command": "", "has_code_change": False, "estimated_tokens": 200})
    assert out["mode"] == expected_mode, (
        f"intent='{intent}' expected {expected_mode}, got {out['mode']} (reason: {out['reason']})"
    )


# ─── Test 9: known commands classify correctly ───────────────────────────────

@pytest.mark.parametrize("command,expected_mode", [
    ("sprint-status", "mode1"),
    ("my-sprint", "mode1"),
    ("my-focus", "mode1"),
    ("board-flow", "mode1"),
    ("daily-routine", "mode1"),
    ("savia-live", "mode1"),
    ("help", "mode1"),
    ("savia-shield", "mode2"),
])
def test_known_commands_classification(clf, command, expected_mode):
    out = clf.classify({"intent": "generic task", "command": command, "has_code_change": False, "estimated_tokens": 200})
    assert out["mode"] == expected_mode, (
        f"command='{command}' expected {expected_mode}, got {out['mode']} (reason: {out['reason']})"
    )


# ─── Test 10: conservative default for ambiguous intent ──────────────────────

def test_ambiguous_intent_defaults_to_mode2(clf):
    out = clf.classify({"intent": "xyzzy gibberish token foobar", "command": "", "has_code_change": False, "estimated_tokens": 100})
    assert out["mode"] == "mode2"


def test_empty_intent_defaults_to_mode2(clf):
    out = clf.classify({"intent": "", "command": "", "has_code_change": False, "estimated_tokens": 0})
    assert out["mode"] == "mode2"


def test_reason_is_non_empty_string(clf):
    out = clf.classify({"intent": "", "command": "", "has_code_change": False, "estimated_tokens": 0})
    assert isinstance(out["reason"], str)
    assert len(out["reason"]) > 0
