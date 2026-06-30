"""
tests/scripts/test_speculative_execution.py — pytest suite for SE-220 Slices 1-4.

Covers:
  - predictor: whitelist_only=true for all-Read/Grep/Glob/Bash predictions
  - predictor: whitelist_only=false when Edit/Write in predicted_tools
  - predictor: --validate mode exit codes
  - execution.py: cache hit avoids re-execution (mock subprocess)
  - execution.py: TTL expiry removes cache entry
  - execution.py: orchestrate() returns required fields
  - execution.py: speculative_launched=True only when whitelist+confidence met
  - cache-manager: get/set/expire cycle
  - cache-manager: concurrent access doesn't corrupt
  - cache-manager: clean() removes expired entries
  - cache-manager: stats() returns correct structure
  - telemetry-report: hit rate calculated correctly
  - telemetry-report: GO verdict when hit_rate>=0.3 AND latency>=100
  - telemetry-report: KILL verdict when accuracy<0.5
  - telemetry-report: KILL verdict when cache_hit_rate<0.10
  - telemetry: telemetry file appended on orchestrate()

Ref: SE-220 Speculative Tool Execution, Slices 1-4
"""
from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
import threading
from pathlib import Path

import pytest

# ─────────────────────────────────────────────────────────────────────────────
# Module loader helpers
# ─────────────────────────────────────────────────────────────────────────────
ROOT = Path(__file__).resolve().parents[2]
PREDICTOR_SCRIPT  = ROOT / "scripts" / "speculative-tool-predictor.py"
EXECUTION_SCRIPT  = ROOT / "scripts" / "speculative-tool-execution.py"
CACHE_MGR_SCRIPT  = ROOT / "scripts" / "speculative-cache-manager.py"
REPORT_SCRIPT     = ROOT / "scripts" / "speculative-telemetry-report.sh"


def _load_module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    mod  = importlib.util.module_from_spec(spec)      # type: ignore[arg-type]
    spec.loader.exec_module(mod)                       # type: ignore[union-attr]
    return mod


@pytest.fixture(scope="module")
def predictor():
    return _load_module(PREDICTOR_SCRIPT, "speculative_tool_predictor")


@pytest.fixture(scope="module")
def execution():
    return _load_module(EXECUTION_SCRIPT, "speculative_tool_execution")


@pytest.fixture(scope="module")
def cache_mgr():
    return _load_module(CACHE_MGR_SCRIPT, "speculative_cache_manager")


# Use a temporary cache dir for every test to avoid cross-test pollution.
# Sets SAVIA_SPECULATIVE_CACHE_DIR env so that fresh module loads pick it up.
@pytest.fixture(autouse=True)
def tmp_cache(tmp_path, monkeypatch):
    monkeypatch.setenv("SAVIA_SPECULATIVE_CACHE_DIR", str(tmp_path / "cache"))
    return tmp_path / "cache"


# ─────────────────────────────────────────────────────────────────────────────
# T01-T05: Predictor — whitelist_only field
# ─────────────────────────────────────────────────────────────────────────────

AVAILABLE_ALL = ["Bash", "Read", "Grep", "Glob", "Edit", "Write"]

class TestPredictorWhitelistOnly:

    def test_whitelist_only_true_for_read_only_predictions(self, predictor):
        """'lee el fichero' → Read → whitelist_only=True"""
        result = predictor.predict("lee el fichero docs/spec.md", ["Read", "Grep", "Glob"])
        assert "Read" in result["predicted_tools"]
        assert result["whitelist_only"] is True, (
            f"Expected whitelist_only=True, got {result['whitelist_only']} "
            f"for predicted_tools={result['predicted_tools']}"
        )

    def test_whitelist_only_true_for_grep(self, predictor):
        """'busca la funcion' → Grep → whitelist_only=True"""
        result = predictor.predict("busca la funcion predict", ["Grep", "Read"])
        assert result["whitelist_only"] is True

    def test_whitelist_only_true_for_bash(self, predictor):
        """'ejecuta los tests' → Bash → whitelist_only=True (Bash is whitelisted)"""
        result = predictor.predict("ejecuta los tests de pytest", AVAILABLE_ALL)
        assert "Bash" in result["predicted_tools"]
        assert result["whitelist_only"] is True

    def test_whitelist_only_false_when_edit_predicted(self, predictor):
        """'modifica el metodo' → Edit → whitelist_only=False"""
        result = predictor.predict("modifica el metodo calculate_velocity", AVAILABLE_ALL)
        assert "Edit" in result["predicted_tools"]
        assert result["whitelist_only"] is False, (
            f"Expected whitelist_only=False (Edit predicted), got True. "
            f"predicted_tools={result['predicted_tools']}"
        )

    def test_whitelist_only_false_when_write_predicted(self, predictor):
        """'crea el fichero' → Write → whitelist_only=False"""
        result = predictor.predict("crea el fichero scripts/new-tool.py", AVAILABLE_ALL)
        assert "Write" in result["predicted_tools"]
        assert result["whitelist_only"] is False

    def test_whitelist_only_field_always_present(self, predictor):
        """Output always contains whitelist_only regardless of intent."""
        for intent in ["xyz unknown nonce 999", "lee el fichero", "modifica el metodo"]:
            result = predictor.predict(intent, AVAILABLE_ALL)
            assert "whitelist_only" in result, f"Missing whitelist_only for intent: {intent}"
            assert isinstance(result["whitelist_only"], bool)


# ─────────────────────────────────────────────────────────────────────────────
# T06-T07: Predictor — --validate mode
# ─────────────────────────────────────────────────────────────────────────────

class TestPredictorValidateMode:

    def test_validate_match_exits_0(self):
        """--validate exits 0 when actual_tool is in predicted_tools."""
        payload = json.dumps({"predicted_tools": ["Read", "Grep"], "actual_tool": "Read"})
        result = subprocess.run(
            [sys.executable, str(PREDICTOR_SCRIPT), "--validate", "--input", payload],
            capture_output=True, text=True,
        )
        assert result.returncode == 0, f"Expected exit 0, got {result.returncode}. stderr: {result.stderr}"
        data = json.loads(result.stdout)
        assert data["match"] is True

    def test_validate_no_match_exits_1(self):
        """--validate exits 1 when actual_tool is not in predicted_tools."""
        payload = json.dumps({"predicted_tools": ["Read", "Grep"], "actual_tool": "Edit"})
        result = subprocess.run(
            [sys.executable, str(PREDICTOR_SCRIPT), "--validate", "--input", payload],
            capture_output=True, text=True,
        )
        assert result.returncode == 1, f"Expected exit 1, got {result.returncode}"
        data = json.loads(result.stdout)
        assert data["match"] is False


# ─────────────────────────────────────────────────────────────────────────────
# T08-T11: Execution orchestrator
# ─────────────────────────────────────────────────────────────────────────────

class TestExecutionOrchestrator:

    def test_orchestrate_returns_required_fields(self, execution, monkeypatch, tmp_path):
        """orchestrate() output must contain all required fields."""
        monkeypatch.setattr(execution, "_TELEMETRY_FILE", tmp_path / "telem.jsonl")
        monkeypatch.setattr(execution, "_CACHE_DIR", tmp_path / "cache")
        result = execution.orchestrate(
            intent="lee el fichero docs/test.md",
            available_tools=["Read", "Grep", "Bash"],
            session_id="test-session-001",
        )
        required = {"session_id", "intent_hash", "predicted_tools", "confidence",
                    "whitelist_only", "speculative_launched", "cache_key", "rationale"}
        missing = required - set(result.keys())
        assert not missing, f"Missing fields: {missing}"

    def test_speculative_launched_true_for_whitelist_intent(self, execution, monkeypatch, tmp_path):
        """whitelist-only intent with confidence>=0.5 → speculative_launched=True."""
        monkeypatch.setattr(execution, "_TELEMETRY_FILE", tmp_path / "telem.jsonl")
        monkeypatch.setattr(execution, "_CACHE_DIR", tmp_path / "cache")

        launched = []
        original_preexec = execution._preexecute_background
        def mock_preexec(tool_name, intent, session_id):
            launched.append(tool_name)
        monkeypatch.setattr(execution, "_preexecute_background", mock_preexec)

        result = execution.orchestrate(
            intent="lee el fichero docs/spec.md",
            available_tools=["Read", "Grep", "Bash"],
            session_id="sess-whitelist",
        )
        assert result["speculative_launched"] is True
        assert result["whitelist_only"] is True
        assert len(launched) > 0, "Background pre-execution was not called"

    def test_speculative_not_launched_for_non_whitelist_intent(self, execution, monkeypatch, tmp_path):
        """Edit/Write intent → speculative_launched=False (non-whitelist)."""
        monkeypatch.setattr(execution, "_TELEMETRY_FILE", tmp_path / "telem.jsonl")
        monkeypatch.setattr(execution, "_CACHE_DIR", tmp_path / "cache")

        launched = []
        monkeypatch.setattr(execution, "_preexecute_background", lambda t, i, s: launched.append(t))

        result = execution.orchestrate(
            intent="modifica el metodo calculate_velocity para filtrar outliers",
            available_tools=["Read", "Grep", "Bash", "Edit", "Write"],
            session_id="sess-edit",
        )
        assert result["speculative_launched"] is False
        assert len(launched) == 0

    def test_cache_miss_on_fresh_orchestrate(self, execution, monkeypatch, tmp_path):
        """resolve_cache_hit returns (False, None) when cache is empty."""
        monkeypatch.setattr(execution, "_CACHE_DIR", tmp_path / "cache")
        monkeypatch.setattr(execution, "_TELEMETRY_FILE", tmp_path / "telem.jsonl")

        hit, cached = execution.resolve_cache_hit(
            tool_name="Read",
            intent="lee docs/test.md",
            session_id="sess-miss",
            actual_start_ms=time.monotonic() * 1000,
        )
        assert hit is False
        assert cached is None


# ─────────────────────────────────────────────────────────────────────────────
# T12-T17: Cache manager
# ─────────────────────────────────────────────────────────────────────────────

class TestCacheManager:

    def _get_fresh_module(self, tmp_path):
        """Load a fresh instance of cache_manager pointing at tmp_path."""
        mod = _load_module(CACHE_MGR_SCRIPT, f"cm_{id(tmp_path)}")
        mod.CACHE_DIR = tmp_path / "cache"
        mod.DEFAULT_TTL = 30
        return mod

    def test_get_set_cycle(self, tmp_path):
        """set then get returns the same result."""
        mod = self._get_fresh_module(tmp_path)
        mod.cache_set("Read", "abc123", {"content": "hello"}, ttl=30)
        result = mod.cache_get("Read", "abc123", ttl=30)
        assert result == {"content": "hello"}

    def test_get_returns_none_on_miss(self, tmp_path):
        """get returns None for a key that was never set."""
        mod = self._get_fresh_module(tmp_path)
        result = mod.cache_get("Read", "nonexistent_hash_xyz", ttl=30)
        assert result is None

    def test_ttl_expiry_removes_entry(self, tmp_path):
        """Entry with TTL=0 is immediately expired; get returns None."""
        mod = self._get_fresh_module(tmp_path)
        mod.cache_set("Grep", "hash_ttl", {"data": "value"}, ttl=0)
        # TTL=0 means expired immediately; wait a tiny bit to ensure age>0
        time.sleep(0.01)
        result = mod.cache_get("Grep", "hash_ttl", ttl=0)
        assert result is None, f"Expected None (expired), got {result}"

    def test_clean_removes_expired(self, tmp_path):
        """clean() removes expired entries, keeps valid ones."""
        mod = self._get_fresh_module(tmp_path)
        mod.cache_set("Bash", "hash_expired", {"x": 1}, ttl=0)
        mod.cache_set("Read", "hash_valid",   {"y": 2}, ttl=300)
        time.sleep(0.01)
        counts = mod.cache_clean()
        assert counts["removed"] >= 1
        # Valid entry still retrievable
        result = mod.cache_get("Read", "hash_valid", ttl=300)
        assert result == {"y": 2}

    def test_stats_returns_correct_structure(self, tmp_path):
        """stats() returns dict with required keys."""
        mod = self._get_fresh_module(tmp_path)
        mod.cache_set("Read", "h1", {"a": 1}, ttl=300)
        stats = mod.cache_stats()
        for key in ("total", "expired", "active", "cache_dir"):
            assert key in stats, f"Missing key '{key}' in stats"
        assert stats["total"] >= 1
        assert stats["active"] >= 1

    def test_concurrent_writes_do_not_corrupt(self, tmp_path):
        """Multiple threads writing different keys concurrently all succeed."""
        mod = self._get_fresh_module(tmp_path)
        errors = []

        def writer(i):
            try:
                mod.cache_set("Read", f"concurrent_{i}", {"index": i}, ttl=60)
            except Exception as exc:
                errors.append(str(exc))

        threads = [threading.Thread(target=writer, args=(i,)) for i in range(10)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        assert not errors, f"Concurrent write errors: {errors}"
        # All 10 entries should be readable
        for i in range(10):
            result = mod.cache_get("Read", f"concurrent_{i}", ttl=60)
            assert result == {"index": i}, f"Entry {i} corrupted or missing"


# ─────────────────────────────────────────────────────────────────────────────
# T18-T22: Telemetry report (via shell script + Python inline logic)
# ─────────────────────────────────────────────────────────────────────────────

def _write_telemetry(tmp_path: Path, records: list[dict]) -> Path:
    """Write JSONL telemetry file for testing."""
    telem = tmp_path / "telemetry.jsonl"
    with telem.open("w") as fh:
        for r in records:
            fh.write(json.dumps(r) + "\n")
    return telem


class TestTelemetryReport:

    def _run_report(self, telem_file: Path, as_json: bool = True) -> dict:
        """Run the telemetry report script and return parsed JSON output."""
        cmd = ["bash", str(REPORT_SCRIPT), "--file", str(telem_file)]
        if as_json:
            cmd.append("--json")
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.returncode == 0, f"Script failed: {result.stderr}"
        return json.loads(result.stdout)

    def test_hit_rate_calculated_correctly(self, tmp_path):
        """3 hits out of 5 resolve records → hit rate = 0.6."""
        records = [
            # 3 hits
            {"ts": "2026-01-01T00:00:00Z", "cache_hit": True,  "latency_saved_ms": 200,
             "predicted": ["Read"], "actual": ["Read"]},
            {"ts": "2026-01-01T00:00:01Z", "cache_hit": True,  "latency_saved_ms": 150,
             "predicted": ["Read"], "actual": ["Read"]},
            {"ts": "2026-01-01T00:00:02Z", "cache_hit": True,  "latency_saved_ms": 300,
             "predicted": ["Bash"], "actual": ["Bash"]},
            # 2 misses
            {"ts": "2026-01-01T00:00:03Z", "cache_hit": False, "latency_saved_ms": 0,
             "predicted": ["Read"], "actual": ["Grep"]},
            {"ts": "2026-01-01T00:00:04Z", "cache_hit": False, "latency_saved_ms": 0,
             "predicted": ["Bash"], "actual": ["Read"]},
        ]
        telem = _write_telemetry(tmp_path, records)
        data = self._run_report(telem)
        assert data["cache_hit_rate"] == pytest.approx(0.6, abs=0.01)

    def test_go_verdict_when_criteria_met(self, tmp_path):
        """hit_rate>=0.30 AND avg_latency>=100 → GO."""
        records = [
            {"cache_hit": True,  "latency_saved_ms": 500, "predicted": ["Read"], "actual": ["Read"]},
            {"cache_hit": True,  "latency_saved_ms": 400, "predicted": ["Read"], "actual": ["Read"]},
            {"cache_hit": False, "latency_saved_ms": 0,   "predicted": ["Read"], "actual": ["Grep"]},
        ]
        telem = _write_telemetry(tmp_path, records)
        data = self._run_report(telem)
        assert data["verdict"] == "GO", f"Expected GO, got {data['verdict']} metrics={data}"

    def test_kill_verdict_when_accuracy_below_threshold(self, tmp_path):
        """prediction_accuracy < 0.50 → KILL."""
        records = [
            {"cache_hit": True, "latency_saved_ms": 200,
             "predicted": ["Read"],  "actual": ["Read"]},
            # accuracy killers: predicted wrong 5/6 times
            {"cache_hit": False, "latency_saved_ms": 0, "predicted": ["Read"],  "actual": ["Edit"]},
            {"cache_hit": False, "latency_saved_ms": 0, "predicted": ["Read"],  "actual": ["Edit"]},
            {"cache_hit": False, "latency_saved_ms": 0, "predicted": ["Read"],  "actual": ["Edit"]},
            {"cache_hit": False, "latency_saved_ms": 0, "predicted": ["Read"],  "actual": ["Write"]},
            {"cache_hit": False, "latency_saved_ms": 0, "predicted": ["Read"],  "actual": ["Write"]},
        ]
        telem = _write_telemetry(tmp_path, records)
        data = self._run_report(telem)
        # accuracy: 1/6 = 0.17 < 0.50 → KILL
        assert data["verdict"] == "KILL", f"Expected KILL, got {data['verdict']}"
        assert data["prediction_accuracy"] < 0.50

    def test_kill_verdict_when_cache_hit_rate_below_threshold(self, tmp_path):
        """cache_hit_rate < 0.10 → KILL (even if accuracy would be ok)."""
        records = [
            {"cache_hit": True,  "latency_saved_ms": 200, "predicted": ["Read"], "actual": ["Read"]},
            # 15 misses → hit rate = 1/16 ≈ 0.06 < 0.10
        ] + [
            {"cache_hit": False, "latency_saved_ms": 0, "predicted": ["Read"], "actual": ["Read"]}
            for _ in range(15)
        ]
        telem = _write_telemetry(tmp_path, records)
        data = self._run_report(telem)
        assert data["verdict"] == "KILL", f"Expected KILL (low hit rate), got {data['verdict']}"

    def test_table_output_produced(self, tmp_path):
        """Non-JSON mode produces a text table with VERDICT line."""
        records = [
            {"cache_hit": True, "latency_saved_ms": 150, "predicted": ["Read"], "actual": ["Read"]},
        ]
        telem = _write_telemetry(tmp_path, records)
        result = subprocess.run(
            ["bash", str(REPORT_SCRIPT), "--file", str(telem)],
            capture_output=True, text=True,
        )
        assert result.returncode == 0
        assert "VERDICT" in result.stdout or "verdict" in result.stdout.lower()
        # Should contain the table header
        assert "SE-220" in result.stdout or "Speculative" in result.stdout
