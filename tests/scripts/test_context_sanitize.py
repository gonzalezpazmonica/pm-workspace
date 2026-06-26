"""Tests for SPEC-193 Capa A: normalize.py + homoglyph-detect.py

Covers:
- 30 positive examples (homoglyphs Cyrillic/Greek/bidi/mathematical)  → homoglyph_score >= 30
- 30 negative examples (clean text, normal code, normal prose)         → homoglyph_score == 0
- Bidi rejection: bidi_present=True always when bidi chars present
- NFKC normalization applied
- Transformations list populated correctly
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
NORMALIZE_SCRIPT   = ROOT / "scripts" / "context-sanitize" / "normalize.py"
HOMOGLYPH_SCRIPT   = ROOT / "scripts" / "context-sanitize" / "homoglyph-detect.py"


def _load(path: Path):
    name = path.stem.replace("-", "_")
    spec = importlib.util.spec_from_file_location(name, path)
    mod  = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def norm():
    return _load(NORMALIZE_SCRIPT)


@pytest.fixture(scope="module")
def hg():
    return _load(HOMOGLYPH_SCRIPT)


# ─────────────────────────────────────────────────────────────────────────────
# 30 POSITIVE examples — score must be >= 30
# ─────────────────────────────────────────────────────────────────────────────

# Cyrillic confusables (visually identical to Latin letters)
CYRILLIC_A  = "\u0430"  # Cyrillic а — looks like Latin a
CYRILLIC_E  = "\u0435"  # Cyrillic е — looks like Latin e
CYRILLIC_O  = "\u043e"  # Cyrillic о — looks like Latin o
CYRILLIC_P  = "\u0440"  # Cyrillic р — looks like Latin p
CYRILLIC_C  = "\u0441"  # Cyrillic с — looks like Latin c
CYRILLIC_H  = "\u043d"  # Cyrillic н
GREEK_ALPHA = "\u03b1"  # Greek α — looks like Latin a
GREEK_OMICRON = "\u03bf"  # Greek ο — looks like Latin o
GREEK_UPSILON = "\u03c5"  # Greek υ
MATH_A      = "\U0001d400"  # Mathematical Bold Capital A
MATH_a      = "\U0001d41a"  # Mathematical Bold Small a
RLO         = "\u202e"  # RIGHT-TO-LEFT OVERRIDE
LRO         = "\u202d"  # LEFT-TO-RIGHT OVERRIDE
ZWS         = "\u200b"  # Zero-width space
ZWJ         = "\u200d"  # Zero-width joiner
SOFT_HYPHEN = "\u00ad"
TAG_A       = "\U000e0041"  # Unicode Tag 'A'

POSITIVE_CASES = [
    # 1-10: Cyrillic mixing in words
    ("payp" + CYRILLIC_A + "l",         "latin_cyrillic word mixing"),
    ("g" + CYRILLIC_O + "ogle",         "cyrillic o in word"),
    ("micr" + CYRILLIC_O + "soft",      "cyrillic o mid-word"),
    (CYRILLIC_A + "mazon",              "cyrillic a at start"),
    ("app" + CYRILLIC_C + "tore",       "cyrillic c in appstore"),
    ("f" + CYRILLIC_A + "cebook",       "cyrillic a in facebook"),
    ("twitt" + CYRILLIC_E + "r",        "cyrillic e in twitter"),
    ("git" + CYRILLIC_H + "ub",         "cyrillic n in github"),
    (CYRILLIC_P + "aypal",              "cyrillic p at start"),
    ("dropb" + CYRILLIC_O + "x",        "cyrillic o in dropbox"),

    # 11-16: Greek mixing
    ("p" + GREEK_ALPHA + "ypal",        "greek alpha in word"),
    (GREEK_OMICRON + "racle",           "greek omicron at start"),
    ("netfl" + GREEK_UPSILON + "x",     "greek upsilon in word"),
    ("s" + GREEK_ALPHA + "msung",       "greek alpha in samsung"),
    ("g" + GREEK_OMICRON + "ogle",      "greek omicron in google"),
    ("ub" + GREEK_UPSILON + "ntu",      "greek upsilon in ubuntu"),

    # 17-19: Mathematical Alphanumeric symbols
    (MATH_A + "pple",                   "math alpha A at start"),
    ("Open" + MATH_a + "I",             "math small a in OpenAI"),
    (MATH_A + MATH_a + "B",             "multiple math symbols"),

    # 20-22: Bidi controls
    ("hello" + RLO + "world",           "RLO bidi control"),
    ("text" + LRO + "here",             "LRO bidi control"),
    ("normal" + "\u202a" + "text",      "LRE bidi control"),

    # 23-25: Zero-width chars
    ("hello" + ZWS + "world",           "zero-width space"),
    ("text" + ZWJ + "here",             "zero-width joiner"),
    ("key" + ZWS + ZWJ + "word",        "multiple zero-width"),

    # 26-27: Soft hyphen in alpha
    ("ex" + SOFT_HYPHEN + "ample",      "soft hyphen in word"),
    ("pay" + SOFT_HYPHEN + "pal",       "soft hyphen paypal"),

    # 28-29: Unicode tags
    ("hello" + TAG_A + "world",         "unicode tag block char"),
    (TAG_A + "inject",                  "unicode tag at start"),

    # 30: Combined attack (multiple signals)
    ("p" + CYRILLIC_A + "y" + ZWS + "pal" + RLO,  "combined cyrillic+zwspace+bidi"),
]


@pytest.mark.parametrize("text,desc", POSITIVE_CASES)
def test_positive_homoglyph_score_ge_30(norm, text, desc):
    """Positive examples must yield homoglyph_score >= 30."""
    result = norm.normalize(text)
    assert result["homoglyph_score"] >= 30, (
        f"[{desc}] Expected score>=30, got {result['homoglyph_score']} "
        f"for {text!r}"
    )


@pytest.mark.parametrize("text,desc", POSITIVE_CASES)
def test_positive_normalized_output_exists(norm, text, desc):
    """normalize() must always return a normalized string."""
    result = norm.normalize(text)
    assert "normalized" in result
    assert isinstance(result["normalized"], str)


# ── Bidi always detected ──────────────────────────────────────────────────────

BIDI_CASES = [
    "hello" + RLO + "world",
    "text" + LRO + "here",
    "x" + "\u202a" + "y",
    "a" + "\u202b" + "b",
    "c" + "\u2066" + "d",
    "e" + "\u2067" + "f",
    "g" + "\u2068" + "h",
    "i" + "\u2069" + "j",
]

@pytest.mark.parametrize("text", BIDI_CASES)
def test_bidi_present_always_detected(norm, text):
    """bidi_present must be True for any text with bidi controls."""
    result = norm.normalize(text)
    assert result["bidi_present"] is True, (
        f"bidi_present not True for {text!r}"
    )


# ─────────────────────────────────────────────────────────────────────────────
# 30 NEGATIVE examples — clean text → score == 0
# ─────────────────────────────────────────────────────────────────────────────

NEGATIVE_CASES = [
    # Plain English
    ("hello world",                             "plain english"),
    ("The quick brown fox jumps",               "english sentence"),
    ("How are you today?",                      "question"),
    ("OpenCode is a coding assistant.",         "normal sentence"),

    # Spanish
    ("hola mundo",                              "plain spanish"),
    ("¿Cómo estás? Estoy bien, gracias.",       "spanish with accents"),
    ("La revisión del código fue exitosa.",     "spanish technical"),
    ("Implementa el módulo de autenticación.",  "spanish instruction"),

    # Technical content (ASCII only)
    ("import json\nresult = json.loads(data)",  "python code"),
    ("SELECT * FROM users WHERE id = 1;",       "sql query"),
    ("git commit -m 'fix: resolve bug'",        "git command"),
    ("https://example.com/path?q=1",            "url"),
    ("function normalize(text) { return text; }", "js code"),

    # Numbers and symbols
    ("score = 42",                              "assignment"),
    ("price: $9.99",                            "price"),
    ("100% complete",                           "percentage"),
    ("2026-06-24",                              "date"),
    ("+34 91 123 45 67",                        "phone"),

    # Proper nouns (all-Latin)
    ("Google",                                  "proper noun"),
    ("Amazon",                                  "brand"),
    ("PayPal",                                  "brand paypal"),
    ("Microsoft",                               "brand microsoft"),
    ("GitHub",                                  "brand github"),

    # Code identifiers
    ("normalize_text",                          "snake_case"),
    ("HomoglyphDetect",                         "PascalCase"),
    ("SAVIA_HARDENING",                         "screaming_snake"),
    ("camelCaseVariable",                       "camelCase"),

    # Mixed alphanum (no script mixing)
    ("abc123",                                  "alphanumeric"),
    ("test_123_abc",                            "underscore numeric"),

    # Unicode accented chars in single script (Latin)
    ("über",                                    "german umlaut"),
    ("naïve",                                   "french accent"),
]


@pytest.mark.parametrize("text,desc", NEGATIVE_CASES)
def test_negative_homoglyph_score_zero(norm, text, desc):
    """Clean text must yield homoglyph_score == 0."""
    result = norm.normalize(text)
    assert result["homoglyph_score"] == 0, (
        f"[{desc}] Expected score=0, got {result['homoglyph_score']} "
        f"for {text!r}"
    )


@pytest.mark.parametrize("text,desc", NEGATIVE_CASES)
def test_negative_bidi_not_present(norm, text, desc):
    """Clean text must not have bidi_present=True."""
    result = norm.normalize(text)
    assert result["bidi_present"] is False, (
        f"[{desc}] bidi_present should be False for clean text"
    )


# ─────────────────────────────────────────────────────────────────────────────
# NFKC normalization behavior
# ─────────────────────────────────────────────────────────────────────────────

def test_nfkc_fullwidth_latin(norm):
    """Fullwidth Latin 'Ａ' should NFKC-normalize to 'A'."""
    text = "\uff21"  # FULLWIDTH LATIN CAPITAL LETTER A
    result = norm.normalize(text)
    assert result["normalized"] == "A"
    assert "nfkc_normalized" in result["transformations"]


def test_nfkc_ligature(norm):
    """fi ligature should normalize to fi."""
    text = "\ufb01"  # LATIN SMALL LIGATURE FI
    result = norm.normalize(text)
    assert result["normalized"] == "fi"


def test_invisible_stripped(norm):
    """Zero-width chars should be stripped."""
    text = "hello\u200bworld"
    result = norm.normalize(text)
    assert "\u200b" not in result["normalized"]
    assert "invisible_stripped" in result["transformations"]


def test_original_preserved(norm):
    """Original text must be preserved unmodified."""
    text = "p\u0430ypal"
    result = norm.normalize(text)
    assert result["original"] == text


def test_transformations_list_is_list(norm):
    result = norm.normalize("hello")
    assert isinstance(result["transformations"], list)


# ─────────────────────────────────────────────────────────────────────────────
# homoglyph-detect.py standalone score tests
# ─────────────────────────────────────────────────────────────────────────────

def test_hg_score_pure_latin_zero(hg):
    assert hg.score("paypal") == 0


def test_hg_score_cyrillic_mixing_above_30(hg):
    text = "p\u0430ypal"  # Cyrillic а
    assert hg.score(text) >= 30


def test_hg_score_bidi_above_50(hg):
    text = "hello\u202eworld"
    assert hg.score(text) >= 50


def test_hg_score_capped_at_100(hg):
    text = "\u202e" * 5 + "\u0430" * 5 + "\u200b" * 10
    assert hg.score(text) <= 100


def test_hg_analyze_returns_risk_pass(hg):
    result = hg.analyze("hello world")
    assert result["risk"] == "pass"
    assert result["score"] == 0


def test_hg_analyze_returns_risk_warn(hg):
    text = "p\u0430ypal"
    result = hg.analyze(text)
    assert result["risk"] in ("warn", "block")


def test_hg_analyze_returns_risk_block(hg):
    text = "p\u0430yp\u0430l\u202e"  # cyrillic + bidi
    result = hg.analyze(text)
    assert result["risk"] == "block"
    assert result["score"] >= 70
