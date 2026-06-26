"""tests/scripts/test_trace_prompt_optimizer.py — SPEC-044

Tests for scripts/trace-prompt-optimizer.py: prompt analysis heuristics.
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest

# ── Load module ───────────────────────────────────────────────────────────────
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "trace-prompt-optimizer.py"


def _load():
    spec = importlib.util.spec_from_file_location("trace_prompt_optimizer", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["trace_prompt_optimizer"] = mod
    spec.loader.exec_module(mod)
    return mod


mod = _load()
analyze = mod.analyze


# ── test 1: verbose prompt (>2000 chars) ──────────────────────────────────────
def test_verbose_detection():
    prompt = "Do something. " * 200  # ~2800 chars
    result = analyze(prompt)
    types = [i.type for i in result.issues]
    assert "verbose" in types
    assert result.score < 100


# ── test 2: repetitive concept (>3 times) ─────────────────────────────────────
def test_repetitive_detection():
    prompt = (
        "You must validate the input carefully. "
        "Always validate the input before processing. "
        "Make sure to validate the input in every case. "
        "Remember to validate the input at all times. "
        "Never skip validate the input step."
    )
    result = analyze(prompt)
    types = [i.type for i in result.issues]
    assert "repetitive" in types


# ── test 3: contradictory instructions ───────────────────────────────────────
def test_contradictory_detection():
    prompt = "Be brief and concise. Also provide a detailed and exhaustive analysis."
    result = analyze(prompt)
    types = [i.type for i in result.issues]
    assert "contradictory" in types
    assert result.score <= 80  # high severity issue should drop score


# ── test 4: no examples for structured output ────────────────────────────────
def test_no_examples_detection():
    prompt = (
        "You are a data extraction agent. "
        "Parse the input document and return a structured JSON response. "
        "The output format must be valid JSON with the required fields. "
        "Ensure proper structure in the response. " * 5
    )
    result = analyze(prompt)
    types = [i.type for i in result.issues]
    assert "no_examples" in types


# ── test 5: hedging overuse ───────────────────────────────────────────────────
def test_hedging_detection():
    prompt = (
        "Maybe you could try to analyze this. Perhaps it might be useful "
        "to consider the options. If possible, sort of organize the output. "
        "It seems like you might want to include details, kind of."
    )
    result = analyze(prompt)
    types = [i.type for i in result.issues]
    assert "hedging" in types


# ── test 6: clean short prompt → score 100, no issues ─────────────────────────
def test_clean_prompt_perfect_score():
    prompt = "Summarize the following text in 3 bullet points."
    result = analyze(prompt)
    assert result.score == 100
    assert len(result.issues) == 0


# ── test 7: suggestions are generated for issues ──────────────────────────────
def test_suggestions_generated():
    prompt = (
        "Be brief. Be detailed. Maybe perhaps possibly if possible include examples. "
        * 10
    )
    result = analyze(prompt)
    assert len(result.suggestions) > 0


# ── test 8: output is valid JSON via CLI ──────────────────────────────────────
def test_cli_output_is_json(tmp_path, monkeypatch):
    output_lines: list[str] = []
    original_print = print

    def capture_print(*args, **kwargs):
        output_lines.append(" ".join(str(a) for a in args))

    monkeypatch.setattr("builtins.print", capture_print)
    result_code = mod.main(["--prompt", "Short prompt."])
    monkeypatch.setattr("builtins.print", original_print)

    assert result_code == 0
    full_output = "\n".join(output_lines)
    parsed = json.loads(full_output)
    assert "issues" in parsed
    assert "score" in parsed
    assert "suggestions" in parsed


# ── test 9: score decreases proportionally with issues ────────────────────────
def test_score_decreases_with_issues():
    clean = "Summarize the text."
    noisy = "Be brief and also comprehensive. " * 200  # verbose + contradictory
    clean_result = analyze(clean)
    noisy_result = analyze(noisy)
    assert clean_result.score > noisy_result.score


# ── test 10: no_output_format for long prompts ───────────────────────────────
def test_no_output_format_detection():
    prompt = (
        "You are a code review agent. Review the following pull request diff. "
        "Check for logic errors, security issues, and style violations. "
        "Provide comprehensive feedback on all aspects of the code changes. "
        "Be thorough and check every line carefully." * 3
    )
    result = analyze(prompt)
    types = [i.type for i in result.issues]
    assert "no_output_format" in types
