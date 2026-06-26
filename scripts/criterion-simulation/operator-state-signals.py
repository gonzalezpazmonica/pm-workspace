#!/usr/bin/env python3
"""operator-state-signals.py — SPEC-194 Criterion Simulation Layer.

Computes operator-state signals from local data only.

Privacy: ZERO external network calls. All data is local.

Returns JSON: {fatigue_score, pressure_score, override_rate, time_band}

Usage:
    python3 scripts/criterion-simulation/operator-state-signals.py
    python3 scripts/criterion-simulation/operator-state-signals.py --operator <id>
    python3 scripts/criterion-simulation/operator-state-signals.py --json
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

# ── Guardrail: no socket calls ever ──────────────────────────────────────────
# This is enforced by the test suite; the script itself never imports socket.

# ── Defaults ──────────────────────────────────────────────────────────────────
SCRIPT_DIR    = Path(__file__).resolve().parent
WORKSPACE     = Path(os.environ.get("CLAUDE_PROJECT_DIR", SCRIPT_DIR.parent.parent))
PREFS_FILE    = Path.home() / ".savia" / "preferences.yaml"

# Env configuration
FATIGUE_BAND  = os.environ.get("SAVIA_CS_FATIGUE_HOUR_BAND", "22:00-06:00")


def _parse_hour_band(band: str) -> tuple[int, int]:
    """Parse 'HH:MM-HH:MM' into (start_hour, end_hour) in 24h format."""
    try:
        parts = band.split("-")
        start_hour = int(parts[0].split(":")[0])
        end_hour   = int(parts[1].split(":")[0])
        return start_hour, end_hour
    except (IndexError, ValueError):
        return 22, 6  # fallback


def _is_in_hour_band(hour: int, start: int, end: int) -> bool:
    """True if hour falls within [start, end] wrapping midnight."""
    if start <= end:
        return start <= hour <= end
    # wraps midnight
    return hour >= start or hour <= end


def _compute_fatigue_score(now_hour: int) -> tuple[int, str]:
    """0-30 based on whether current hour is in the atypical band."""
    start, end = _parse_hour_band(FATIGUE_BAND)
    if _is_in_hour_band(now_hour, start, end):
        fatigue = 30
        band    = "atypical"
    elif abs(now_hour - start) <= 2 or abs(now_hour - end) <= 2:
        fatigue = 15
        band    = "transition"
    else:
        fatigue = 0
        band    = "normal"
    return fatigue, band


def _compute_pressure_score(deadline_proximity: float | None) -> int:
    """0-20 heuristic from deadline_proximity (0.0-1.0 float from preferences.yaml)."""
    if deadline_proximity is None:
        return 0
    # Clamp to [0,1]
    p = max(0.0, min(1.0, float(deadline_proximity)))
    return int(round(p * 20))


def _compute_override_rate() -> int:
    """0-20 based on reaffirmations log history.

    Reads output/criterion-simulation/reaffirmations.jsonl if it exists.
    Counts reaffirmations in last 90 days vs. total tasks to estimate override rate.
    Graceful: returns 0 if file absent.
    """
    log_path = WORKSPACE / "output" / "criterion-simulation" / "reaffirmations.jsonl"
    if not log_path.exists():
        return 0

    now = datetime.now(tz=timezone.utc)
    from datetime import timedelta
    cutoff = now - timedelta(days=90)

    count = 0
    total = 0
    try:
        with log_path.open() as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    ts_str = entry.get("ts", "")
                    if not ts_str:
                        continue
                    # Parse ISO timestamp
                    ts = datetime.fromisoformat(ts_str.rstrip("Z").replace("Z", "+00:00"))
                    if ts.tzinfo is None:
                        ts = ts.replace(tzinfo=timezone.utc)
                    total += 1
                    if ts >= cutoff:
                        count += 1
                except (json.JSONDecodeError, ValueError):
                    continue
    except OSError:
        return 0

    if total == 0:
        return 0
    # Scale: if 100% of lookback are reaffirmations, score is 20
    rate  = count / max(total, 1)
    return int(round(rate * 20))


def _read_deadline_proximity() -> float | None:
    """Read deadline_proximity from ~/.savia/preferences.yaml. Returns None if absent."""
    if not PREFS_FILE.exists():
        return None
    try:
        with PREFS_FILE.open() as f:
            for line in f:
                line = line.strip()
                if line.startswith("deadline_proximity"):
                    parts = line.split(":", 1)
                    if len(parts) == 2:
                        return float(parts[1].strip())
    except (OSError, ValueError):
        pass
    return None


def compute_operator_state(operator_id: str = "default") -> dict:
    """Compute operator-state signals. All data is local. No network calls.

    Returns {fatigue_score, pressure_score, override_rate, time_band}.
    Scores:
        fatigue_score  : 0-30 (hour-of-day heuristic)
        pressure_score : 0-20 (deadline_proximity from preferences.yaml)
        override_rate  : 0-20 (local reaffirmation log history)
        time_band      : str (normal | transition | atypical)
    """
    now_hour = datetime.now().hour
    fatigue_score, time_band = _compute_fatigue_score(now_hour)

    deadline_proximity = _read_deadline_proximity()
    pressure_score = _compute_pressure_score(deadline_proximity)

    override_rate = _compute_override_rate()

    return {
        "fatigue_score":  fatigue_score,
        "pressure_score": pressure_score,
        "override_rate":  override_rate,
        "time_band":      time_band,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="SPEC-194 operator-state-signals — local only, no network"
    )
    parser.add_argument(
        "--operator", default="default",
        help="Operator identifier (used for future per-operator history; currently unused)"
    )
    args = parser.parse_args()

    state = compute_operator_state(args.operator)
    print(json.dumps(state))


if __name__ == "__main__":
    main()
