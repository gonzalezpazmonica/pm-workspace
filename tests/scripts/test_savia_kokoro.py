"""test_savia_kokoro.py — SE-075 Slice 3.

Tests for scripts/savia-kokoro.py (Kokoro CPU TTS CLI wrapper).

Run: python3 -m pytest tests/scripts/test_savia_kokoro.py -q
"""
from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import types
from pathlib import Path
from unittest.mock import patch

import pytest

# ── Paths ────────────────────────────────────────────────────────────────────
REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts" / "savia-kokoro.py"
TELEMETRY = REPO_ROOT / "output" / "kokoro-telemetry.jsonl"


# ── Module loader (filename has hyphens → cannot use normal import) ───────────

def _load_module():
    """Load savia-kokoro.py as a module (handles hyphen in filename)."""
    mod_name = "savia_kokoro"
    if mod_name in sys.modules:
        return sys.modules[mod_name]
    spec = importlib.util.spec_from_file_location(mod_name, SCRIPT)
    mod = importlib.util.module_from_spec(spec)  # type: ignore[arg-type]
    sys.modules[mod_name] = mod
    spec.loader.exec_module(mod)  # type: ignore[union-attr]
    return mod


# Pre-load once at collection time
_MOD = _load_module()


# ── Helper ───────────────────────────────────────────────────────────────────

def run_script(*args: str, stdin: str | None = None) -> subprocess.CompletedProcess:
    """Run savia-kokoro.py with given args, return CompletedProcess."""
    cmd = [sys.executable, str(SCRIPT)] + list(args)
    return subprocess.run(
        cmd,
        input=stdin,
        capture_output=True,
        text=True,
    )


def parse_json_stdout(stdout: str) -> dict:
    """Extract and parse the JSON line from stdout (ignores stray print() lines)."""
    for line in reversed(stdout.splitlines()):
        line = line.strip()
        if line.startswith("{"):
            return json.loads(line)
    raise ValueError(f"No JSON object found in stdout:\n{stdout!r}")


# ── Test 1: kokoro imports correctly ─────────────────────────────────────────

def test_kokoro_import():
    """kokoro package is importable."""
    import kokoro  # noqa: F401


def test_soundfile_import():
    """soundfile package is importable (required for WAV I/O)."""
    import soundfile  # noqa: F401


def test_numpy_import():
    """numpy is importable."""
    import numpy  # noqa: F401


# ── Test 2: produces valid WAV for short text ────────────────────────────────

def test_produces_valid_wav(tmp_path):
    """savia-kokoro.py generates a WAV file for short text."""
    import soundfile as sf

    out = tmp_path / "out.wav"
    proc = run_script("--text", "Hola", "--output", str(out))

    assert proc.returncode == 0, f"stderr: {proc.stderr}"
    assert out.exists(), "Output WAV not created"
    data, sr = sf.read(str(out))
    assert sr == 24000
    assert len(data) > 0


# ── Test 3: --json output is parseable with required fields ──────────────────

def test_json_output_parseable(tmp_path):
    """--json flag produces parseable JSON with required fields."""
    out = tmp_path / "json.wav"
    proc = run_script("--text", "Hola Savia", "--output", str(out), "--json")

    assert proc.returncode == 0, f"stderr: {proc.stderr}\nstdout: {proc.stdout}"
    payload = parse_json_stdout(proc.stdout)

    assert "file" in payload
    assert "duration_s" in payload
    assert "voice" in payload
    assert "lang" in payload
    assert payload["duration_s"] > 0
    assert Path(payload["file"]).exists()


# ── Test 4: empty text → exit 1 ──────────────────────────────────────────────

def test_empty_text_exit_1(tmp_path):
    """Empty --text exits with code 1."""
    out = tmp_path / "empty.wav"
    proc = run_script("--text", "", "--output", str(out))
    assert proc.returncode == 1


def test_empty_stdin_exit_1(tmp_path):
    """Empty stdin exits with code 1."""
    out = tmp_path / "empty2.wav"
    proc = run_script("--output", str(out), stdin="   ")
    assert proc.returncode == 1


# ── Test 5: long text (>500 chars) → chunking ────────────────────────────────

def test_long_text_chunking(tmp_path):
    """Text >500 chars is handled via automatic chunking."""
    import soundfile as sf

    long_text = (
        "El proyecto Savia integra múltiples herramientas de IA para gestionar "
        "sprints, backlogs e informes de manera autónoma. "
        * 6
    ).strip()
    assert len(long_text) > 500, f"Test setup: text is only {len(long_text)} chars"

    out = tmp_path / "long.wav"
    proc = run_script("--text", long_text, "--output", str(out))

    assert proc.returncode == 0, f"stderr: {proc.stderr}"
    assert out.exists()
    data, sr = sf.read(str(out))
    assert len(data) > 0


# ── Test 6: kokoro not installed → graceful error ────────────────────────────

def test_kokoro_not_installed_graceful(tmp_path):
    """When kokoro is not importable, main() returns 1 with clear error."""
    mod = _load_module()
    out = tmp_path / "nok.wav"
    original = mod._import_kokoro

    def _broken():
        raise ImportError("No module named 'kokoro'")

    mod._import_kokoro = _broken
    try:
        result = mod.main(["--text", "Hola", "--output", str(out)])
        assert result == 1
    finally:
        mod._import_kokoro = original


def test_kokoro_not_installed_json_error(tmp_path):
    """With --json, error is returned as parseable JSON."""
    mod = _load_module()
    out = tmp_path / "nok2.wav"
    original = mod._import_kokoro
    captured_stdout: list[str] = []

    def _broken():
        raise ImportError("No module named 'kokoro'")

    import builtins as _builtins
    original_print = _builtins.print

    def _capture(*a, **kw):
        if not kw.get("file"):  # stdout prints only
            captured_stdout.append(" ".join(str(x) for x in a))
        original_print(*a, **kw)

    mod._import_kokoro = _broken
    try:
        with patch("builtins.print", side_effect=_capture):
            result = mod.main(["--text", "Hola", "--output", str(out), "--json"])
        assert result == 1
        assert captured_stdout, "no stdout output captured"
        payload = json.loads(captured_stdout[0])
        assert "error" in payload
        assert "install" in payload
    finally:
        mod._import_kokoro = original


# ── Test 7: voice ef_dora (español) available ────────────────────────────────

def test_voice_ef_dora_available(tmp_path):
    """ef_dora voice produces audio without error."""
    import soundfile as sf

    out = tmp_path / "dora.wav"
    proc = run_script(
        "--text", "Buenas tardes",
        "--output", str(out),
        "--voice", "ef_dora",
        "--lang", "es",
    )
    assert proc.returncode == 0, f"stderr: {proc.stderr}"
    data, sr = sf.read(str(out))
    assert len(data) > 0


# ── Test 8: telemetry is written ─────────────────────────────────────────────

def test_telemetry_written(tmp_path):
    """After synthesis, a record appears in telemetry file."""
    mod = _load_module()
    out = tmp_path / "tel.wav"
    original_tel = mod.TELEMETRY_FILE
    temp_tel = tmp_path / "telemetry.jsonl"
    mod.TELEMETRY_FILE = temp_tel

    try:
        result = mod.main(["--text", "Hola", "--output", str(out)])
        assert result == 0, "synthesis failed"
        assert temp_tel.exists(), "Telemetry file not created"
        records = [json.loads(line) for line in temp_tel.read_text().splitlines() if line.strip()]
        assert len(records) >= 1
        r = records[-1]
        for field in ("ts", "voice", "lang", "duration_s", "chars", "ok"):
            assert field in r, f"Missing field: {field}"
        assert r["ok"] is True
    finally:
        mod.TELEMETRY_FILE = original_tel


# ── Test 9: duration > 0 for non-empty text ──────────────────────────────────

def test_duration_positive(tmp_path):
    """Synthesized audio has duration > 0."""
    out = tmp_path / "dur.wav"
    proc = run_script("--text", "Probando uno dos tres", "--output", str(out), "--json")
    assert proc.returncode == 0, f"stderr: {proc.stderr}\nstdout: {proc.stdout}"
    payload = parse_json_stdout(proc.stdout)
    assert payload["duration_s"] > 0, "duration_s must be positive"


# ── Test 10: soundfile can read the generated WAV ────────────────────────────

def test_soundfile_reads_wav(tmp_path):
    """soundfile can read the generated WAV without errors."""
    import soundfile as sf

    out = tmp_path / "sf.wav"
    proc = run_script("--text", "Audio válido", "--output", str(out))
    assert proc.returncode == 0, f"stderr: {proc.stderr}"

    data, sr = sf.read(str(out), dtype="float32")
    assert sr == 24000
    assert data.ndim >= 1
    assert data.shape[0] > 0

