#!/usr/bin/env python3
"""
speculative-tool-execution.py — Speculative tool execution orchestrator (SE-220 S1).

Input (stdin):
  {"intent": "...", "available_tools": [...], "session_id": "..."}

Output (stdout, JSON):
  {
    "session_id": "...",
    "intent_hash": "...",
    "predicted_tools": [...],
    "confidence": 0.75,
    "whitelist_only": true,
    "speculative_launched": true,
    "cache_key": "...",
    "rationale": "..."
  }

Workflow:
  1. Calls predictor to get predicted_tools.
  2. If whitelist_only=true AND confidence >= 0.5: pre-executes tools in background.
  3. Results stored in /tmp/savia-speculative-cache/ with 30s TTL.
  4. When the model arrives at the real tool call, it can check the cache for a hit.
  5. Telemetry appended to output/speculative-execution-telemetry.jsonl.

Ref: SE-220 — Speculative Tool Execution, Slice 1
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

# ─────────────────────────────────────────────────────────────────────────────
# Paths
# ─────────────────────────────────────────────────────────────────────────────
_ROOT = Path(__file__).resolve().parents[1]
_PREDICTOR_SCRIPT = _ROOT / "scripts" / "speculative-tool-predictor.py"
_CACHE_DIR = Path(os.environ.get("SAVIA_SPECULATIVE_CACHE_DIR", "/tmp/savia-speculative-cache"))
_TELEMETRY_FILE = _ROOT / "output" / "speculative-execution-telemetry.jsonl"

# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────
CONFIDENCE_THRESHOLD = 0.5
DEFAULT_TTL = int(os.environ.get("SAVIA_SPECULATIVE_TTL", "30"))

# Read-only tools that are safe to pre-execute (idempotent)
READ_ONLY_WHITELIST: frozenset[str] = frozenset(["Read", "Grep", "Glob", "Bash"])


# ─────────────────────────────────────────────────────────────────────────────
# Predictor loader
# ─────────────────────────────────────────────────────────────────────────────

def _load_predictor():
    """Dynamically load speculative-tool-predictor module."""
    spec = importlib.util.spec_from_file_location("speculative_tool_predictor", _PREDICTOR_SCRIPT)
    mod = importlib.util.module_from_spec(spec)  # type: ignore[arg-type]
    spec.loader.exec_module(mod)  # type: ignore[union-attr]
    return mod


# ─────────────────────────────────────────────────────────────────────────────
# Cache helpers
# ─────────────────────────────────────────────────────────────────────────────

def _args_hash(tool_name: str, args: dict[str, Any]) -> str:
    """Stable hash for (tool, args) used as cache filename."""
    key = json.dumps({"tool": tool_name, "args": args}, sort_keys=True)
    return hashlib.sha256(key.encode()).hexdigest()[:16]


def cache_get(tool_name: str, args: dict[str, Any], ttl: int = DEFAULT_TTL) -> dict[str, Any] | None:
    """Return cached result if it exists and has not expired, else None."""
    key = _args_hash(tool_name, args)
    cache_file = _CACHE_DIR / f"{tool_name}_{key}.json"
    if not cache_file.exists():
        return None
    try:
        data = json.loads(cache_file.read_text())
        age = time.time() - data.get("_cached_at", 0)
        if age > ttl:
            cache_file.unlink(missing_ok=True)
            return None
        return data.get("result")
    except Exception:
        return None


def cache_set(tool_name: str, args: dict[str, Any], result: Any, ttl: int = DEFAULT_TTL) -> str:
    """Store result in cache. Returns cache key."""
    _CACHE_DIR.mkdir(parents=True, exist_ok=True)
    key = _args_hash(tool_name, args)
    cache_file = _CACHE_DIR / f"{tool_name}_{key}.json"
    payload = {
        "_cached_at": time.time(),
        "_ttl": ttl,
        "_tool": tool_name,
        "result": result,
    }
    # Atomic write via temp file to avoid partial reads
    tmp = cache_file.with_suffix(".tmp")
    tmp.write_text(json.dumps(payload))
    tmp.replace(cache_file)
    return key


# ─────────────────────────────────────────────────────────────────────────────
# Telemetry
# ─────────────────────────────────────────────────────────────────────────────

def _write_telemetry(record: dict[str, Any]) -> None:
    """Append a JSONL record to the telemetry file. Fails silently."""
    try:
        _TELEMETRY_FILE.parent.mkdir(parents=True, exist_ok=True)
        with _TELEMETRY_FILE.open("a") as fh:
            fh.write(json.dumps(record) + "\n")
    except Exception:
        pass


# ─────────────────────────────────────────────────────────────────────────────
# Intent hash (for telemetry — non-reversible, privacy-safe)
# ─────────────────────────────────────────────────────────────────────────────

def _intent_hash(intent: str) -> str:
    return hashlib.sha256(intent.encode()).hexdigest()[:12]


# ─────────────────────────────────────────────────────────────────────────────
# Background pre-execution
# ─────────────────────────────────────────────────────────────────────────────

def _preexecute_background(tool_name: str, intent: str, session_id: str) -> None:
    """
    Launch a background subprocess that 'simulates' the pre-execution of a
    read-only tool call. In a real integration the tool invocation would be
    the actual tool subprocess; here we record a placeholder result so the
    cache-hit path can be tested without external tool infrastructure.

    The subprocess writes directly to the cache directory so that when the
    real tool call arrives the orchestrator finds a hit.
    """
    cache_args: dict[str, Any] = {"intent": intent, "session_id": session_id}
    cache_key = _args_hash(tool_name, cache_args)
    cache_file = _CACHE_DIR / f"{tool_name}_{cache_key}.json"

    script = f"""
import json, time, pathlib, sys
cache_dir = pathlib.Path({str(_CACHE_DIR)!r})
cache_dir.mkdir(parents=True, exist_ok=True)
payload = {{
    "_cached_at": time.time(),
    "_ttl": {DEFAULT_TTL},
    "_tool": {tool_name!r},
    "result": {{"speculative": True, "tool": {tool_name!r}, "pre_executed_at": time.time()}},
}}
tmp = cache_dir / {f'{tool_name}_{cache_key}.tmp'!r}
out = cache_dir / {f'{tool_name}_{cache_key}.json'!r}
tmp.write_text(json.dumps(payload))
tmp.replace(out)
"""
    # Launch detached; ignore errors (fail-soft per Rule #2)
    try:
        subprocess.Popen(
            [sys.executable, "-c", script],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except Exception:
        pass


# ─────────────────────────────────────────────────────────────────────────────
# Main orchestration logic
# ─────────────────────────────────────────────────────────────────────────────

def orchestrate(intent: str, available_tools: list[str], session_id: str) -> dict[str, Any]:
    """
    Core orchestration: predict → filter → (optionally) pre-execute.
    Returns a result dict with prediction info and whether speculation launched.
    """
    t0 = time.monotonic()

    # 1. Load predictor and run prediction
    predictor = _load_predictor()
    prediction = predictor.predict(intent, available_tools)

    predicted_tools: list[str] = prediction.get("predicted_tools", [])
    confidence: float = prediction.get("confidence", 0.0)
    whitelist_only: bool = prediction.get("whitelist_only", False)
    rationale: str = prediction.get("rationale", "")
    intent_hash = _intent_hash(intent)

    speculative_launched = False
    cache_key = ""

    # 2. Decide whether to launch speculative pre-execution
    if whitelist_only and confidence >= CONFIDENCE_THRESHOLD and predicted_tools:
        speculative_launched = True
        for tool in predicted_tools:
            _preexecute_background(tool, intent, session_id)
        # Compute representative cache key for primary predicted tool
        primary = predicted_tools[0]
        cache_key = _args_hash(primary, {"intent": intent, "session_id": session_id})

    elapsed_ms = round((time.monotonic() - t0) * 1000, 1)

    result: dict[str, Any] = {
        "session_id": session_id,
        "intent_hash": intent_hash,
        "predicted_tools": predicted_tools,
        "confidence": confidence,
        "whitelist_only": whitelist_only,
        "speculative_launched": speculative_launched,
        "cache_key": cache_key,
        "rationale": rationale,
        "orchestration_ms": elapsed_ms,
    }

    # 3. Telemetry (best-effort)
    _write_telemetry({
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "session_id": session_id,
        "intent_hash": intent_hash,
        "predicted": predicted_tools,
        "actual": [],          # filled later by cache-hit path
        "cache_hit": False,    # updated by cache-hit path
        "latency_saved_ms": 0, # updated on actual hit
        "whitelist_only": whitelist_only,
        "confidence": confidence,
        "speculative_launched": speculative_launched,
    })

    return result


# ─────────────────────────────────────────────────────────────────────────────
# Cache-hit resolution (called when the model actually executes a tool)
# ─────────────────────────────────────────────────────────────────────────────

def resolve_cache_hit(
    tool_name: str,
    intent: str,
    session_id: str,
    actual_start_ms: float,
) -> tuple[bool, Any]:
    """
    Check if a pre-executed result exists in cache.

    Returns (hit: bool, cached_result | None).
    Also appends a telemetry record marking the cache hit.
    """
    cache_args: dict[str, Any] = {"intent": intent, "session_id": session_id}
    cached = cache_get(tool_name, cache_args)
    hit = cached is not None
    latency_saved = 0
    if hit:
        latency_saved = round(time.monotonic() * 1000 - actual_start_ms, 1)

    _write_telemetry({
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "session_id": session_id,
        "intent_hash": _intent_hash(intent),
        "predicted": [tool_name],
        "actual": [tool_name],
        "cache_hit": hit,
        "latency_saved_ms": latency_saved,
        "event": "cache_resolve",
    })

    return hit, cached


# ─────────────────────────────────────────────────────────────────────────────
# CLI entry point
# ─────────────────────────────────────────────────────────────────────────────

def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(
        description="SE-220 S1 — Speculative tool execution orchestrator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--input", "-i", help="JSON string (alternative to stdin)")
    parser.add_argument(
        "--resolve", action="store_true",
        help="Cache-hit resolve mode. Input: {tool_name, intent, session_id, actual_start_ms}",
    )
    args = parser.parse_args()

    raw = args.input or sys.stdin.read().strip()
    if not raw:
        print(json.dumps({"error": "no input provided"}), file=sys.stderr)
        return 1

    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as exc:
        print(json.dumps({"error": f"invalid JSON: {exc}"}), file=sys.stderr)
        return 1

    if args.resolve:
        tool_name = payload.get("tool_name", "")
        intent = payload.get("intent", "")
        session_id = payload.get("session_id", "unknown")
        actual_start_ms = float(payload.get("actual_start_ms", time.monotonic() * 1000))
        if not tool_name or not intent:
            print(json.dumps({"error": "tool_name and intent required for --resolve"}), file=sys.stderr)
            return 1
        hit, cached = resolve_cache_hit(tool_name, intent, session_id, actual_start_ms)
        print(json.dumps({"cache_hit": hit, "cached_result": cached}))
        return 0

    intent = payload.get("intent", "")
    available_tools = payload.get("available_tools", ["Bash", "Read", "Grep", "Edit", "Write"])
    session_id = payload.get("session_id", "unknown")

    if not intent:
        print(json.dumps({"error": "intent field is required"}), file=sys.stderr)
        return 1

    result = orchestrate(intent, available_tools, session_id)
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
