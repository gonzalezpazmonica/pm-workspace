"""
pm-radar.py — PM Radar State Manager
Reads agent-*.md files from tmp-dir, parses items, merges into state.json,
detects inconsistencies, emits radar-report.json.

Usage:
    python scripts/pm-radar.py --tmp-dir ~/.savia/radar-tmp --state ~/.savia/pm-radar/state.json

Stdlib only: json, re, pathlib, datetime, os, sys, argparse, tempfile, shutil
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
import shutil
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any


# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────

BAND_ORDER = ["critico", "urgente", "importante", "seguimiento"]

BAND_SCORE_DEFAULTS = {
    "critico": {"urgencia": 9, "importancia": 9, "prioridad": 8, "antiguedad": 5},
    "urgente": {"urgencia": 7, "importancia": 7, "prioridad": 6, "antiguedad": 4},
    "importante": {"urgencia": 5, "importancia": 5, "prioridad": 5, "antiguedad": 3},
    "seguimiento": {"urgencia": 3, "importancia": 3, "prioridad": 3, "antiguedad": 2},
}

# Regex patterns to extract items from agent-*.md content
# Matches lines like: - [SCORE] title, - [ID] title, **[SCORE]** title
ITEM_LINE_PATTERNS = [
    # Bullet with bracketed score/id: - [86] Some title or - [ID-123] title
    re.compile(r"^\s*-\s+\[([^\]]+)\]\s+(.+)$", re.MULTILINE),
    # Bold score: **[86]** title or **86** title
    re.compile(r"^\s*\*\*\[?([^\]\*]+)\]?\*\*\s+(.+)$", re.MULTILINE),
    # Bullet with bold id: - **ACTION-ID** description
    re.compile(r"^\s*-\s+\*\*([A-Z][A-Z0-9\-]+)\*\*\s+(.+)$", re.MULTILINE),
]

# Detect numeric score in first capture group
SCORE_RE = re.compile(r"^\d+$")

# Detect band keywords in item text
BAND_KEYWORDS = {
    "critico": re.compile(r"\b(critico|crítico|CRITICO|CRÍTICO|bloqueante|regulatorio|vencido)\b", re.I),
    "urgente": re.compile(r"\b(urgente|URGENTE|sin escalar|bloqueado)\b", re.I),
    "importante": re.compile(r"\b(importante|IMPORTANTE|riesgo|risk|sin PBI)\b", re.I),
}

# Actions > 7 days old owner=PM (from agent-meetings-actions.md)
ACTIONS_OLD_THRESHOLD_DAYS = 7

# Roadmap deadline threshold for "no PBI" inconsistency
ROADMAP_NOPBI_THRESHOLD_DAYS = 14

# Meeting prep threshold: within 24h
MEETING_PREP_THRESHOLD_HOURS = 24


# ─────────────────────────────────────────────────────────────────────────────
# Scoring
# ─────────────────────────────────────────────────────────────────────────────

def compute_score(urgencia: int, importancia: int, prioridad: int, antiguedad: int) -> int:
    """Score = urgencia*3 + importancia*3 + prioridad*2 + antiguedad*2. Max=40."""
    return urgencia * 3 + importancia * 3 + prioridad * 2 + antiguedad * 2


def score_from_defaults(band: str) -> int:
    d = BAND_SCORE_DEFAULTS.get(band, BAND_SCORE_DEFAULTS["seguimiento"])
    return compute_score(d["urgencia"], d["importancia"], d["prioridad"], d["antiguedad"])


def infer_band(text: str, existing_score: int | None = None) -> str:
    """Infer priority band from text keywords or score."""
    for band, pattern in BAND_KEYWORDS.items():
        if pattern.search(text):
            return band
    if existing_score is not None:
        if existing_score >= 75:
            return "critico"
        if existing_score >= 60:
            return "urgente"
        if existing_score >= 45:
            return "importante"
    return "seguimiento"


# ─────────────────────────────────────────────────────────────────────────────
# Parsing agent-*.md files
# ─────────────────────────────────────────────────────────────────────────────

def slugify(text: str) -> str:
    """Create a stable ID slug from text."""
    text = text.upper()
    text = re.sub(r"[^A-Z0-9]+", "-", text)
    text = text.strip("-")
    return text[:60]


def parse_agent_file(path: Path) -> list[dict[str, Any]]:
    """
    Parse a single agent-*.md file and return list of raw item dicts.
    Each dict has: id, title, band, score, source_file, raw_text.
    Errors are caught and skipped item by item.
    """
    items: list[dict[str, Any]] = []
    try:
        content = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return items

    source_name = path.stem  # e.g. "agent-meetings-actions"
    seen_ids: set[str] = set()

    for pattern in ITEM_LINE_PATTERNS:
        for match in pattern.finditer(content):
            try:
                first_group = match.group(1).strip()
                title_raw = match.group(2).strip()

                # Determine score or use as ID hint
                if SCORE_RE.match(first_group):
                    numeric_score = int(first_group)
                    item_id = slugify(title_raw[:40])
                else:
                    # first_group is an ID or text label
                    item_id = slugify(first_group)
                    numeric_score = None

                if not item_id or item_id in seen_ids:
                    continue
                seen_ids.add(item_id)

                band = infer_band(title_raw + " " + first_group, numeric_score)
                score = numeric_score if numeric_score is not None else score_from_defaults(band)

                items.append({
                    "id": item_id,
                    "title": title_raw[:200],
                    "band": band,
                    "score": score,
                    "source_file": source_name,
                    "raw_text": match.group(0).strip()[:300],
                })
            except Exception:
                continue  # skip malformed match

    return items


def load_agent_files(tmp_dir: Path) -> list[dict[str, Any]]:
    """Load all agent-*.md from tmp_dir."""
    all_items: list[dict[str, Any]] = []
    if not tmp_dir.exists():
        return all_items
    for md_file in sorted(tmp_dir.glob("agent-*.md")):
        try:
            file_items = parse_agent_file(md_file)
            all_items.extend(file_items)
        except Exception:
            continue
    return all_items


# ─────────────────────────────────────────────────────────────────────────────
# Inconsistency detection
# ─────────────────────────────────────────────────────────────────────────────

def detect_inconsistencies(tmp_dir: Path, now: datetime) -> list[dict[str, Any]]:
    """
    Detect 3 types of inconsistencies from known agent files.
    Returns list of inconsistency dicts.
    """
    inconsistencies: list[dict[str, Any]] = []

    # 1. Action items owner=PM without progress > 7 days
    try:
        actions_file = tmp_dir / "agent-meetings-actions.md"
        if actions_file.exists():
            content = actions_file.read_text(encoding="utf-8", errors="replace")
            # Look for dates in format YYYY-MM-DD followed by action text
            date_action_re = re.compile(
                r"\*?\*?(\d{4}-\d{2}-\d{2})\*?\*?\s*\|?\s*([^\n\|]{10,80})",
                re.MULTILINE,
            )
            for m in date_action_re.finditer(content):
                try:
                    action_date = datetime.strptime(m.group(1), "%Y-%m-%d")
                    delta = (now - action_date).days
                    if delta > ACTIONS_OLD_THRESHOLD_DAYS:
                        action_text = m.group(2).strip()
                        inconsistencies.append({
                            "type": "action_stale",
                            "severity": "urgente",
                            "description": (
                                f"Action item sin progreso {delta}d "
                                f"(owner=PM): {action_text[:100]}"
                            ),
                            "source": "agent-meetings-actions",
                            "age_days": delta,
                        })
                except ValueError:
                    continue
    except Exception:
        pass

    # 2. Meetings within next 24h without prep
    try:
        calendar_file = tmp_dir / "agent-calendar.md"
        if calendar_file.exists():
            content = calendar_file.read_text(encoding="utf-8", errors="replace")
            # Look for prep=no entries
            meeting_re = re.compile(
                r"\[(\d{2}:\d{2})-(\d{2}:\d{2})\]\s+([^\|]+)\|[^\|]+\|\s*prep=no",
                re.MULTILINE,
            )
            for m in meeting_re.finditer(content):
                try:
                    time_str = m.group(1)
                    meeting_title = m.group(3).strip()
                    # Assume today's date for these meetings
                    meeting_dt = datetime.combine(
                        now.date(),
                        datetime.strptime(time_str, "%H:%M").time(),
                    )
                    hours_until = (meeting_dt - now).total_seconds() / 3600
                    if 0 <= hours_until <= MEETING_PREP_THRESHOLD_HOURS:
                        inconsistencies.append({
                            "type": "meeting_no_prep",
                            "severity": "urgente",
                            "description": (
                                f"Reunion proxima {hours_until:.1f}h sin prep: "
                                f"{meeting_title[:80]} a las {time_str}"
                            ),
                            "source": "agent-calendar",
                            "hours_until": round(hours_until, 1),
                        })
                except Exception:
                    continue
    except Exception:
        pass

    # 3. Roadmap commitments < 14 days without PBI
    try:
        roadmap_file = tmp_dir / "agent-roadmap.md"
        if roadmap_file.exists():
            content = roadmap_file.read_text(encoding="utf-8", errors="replace")
            # Look for SIN PBI section entries with dates
            sin_pbi_section_re = re.compile(
                r"## SIN PBI.*?(?=##|\Z)",
                re.DOTALL,
            )
            date_entry_re = re.compile(
                r"\[(\d{1,2}\s+\w+|\d{4}-\d{2}-\d{2})\]\s+\*?\*?([^\n\*]{10,120})",
            )
            month_map = {
                "ene": 1, "feb": 2, "mar": 3, "abr": 4, "may": 5, "jun": 6,
                "jul": 7, "ago": 8, "sep": 9, "oct": 10, "nov": 11, "dic": 12,
                "jan": 1, "apr": 4, "jun": 6, "aug": 8, "oct": 10, "dec": 12,
            }

            section_match = sin_pbi_section_re.search(content)
            if section_match:
                section = section_match.group(0)
                for m in date_entry_re.finditer(section):
                    try:
                        date_str = m.group(1).strip()
                        item_text = m.group(2).strip()

                        # Parse flexible date formats: "28 abr" or "2026-04-28"
                        commit_date = None
                        if re.match(r"\d{4}-\d{2}-\d{2}", date_str):
                            commit_date = datetime.strptime(date_str, "%Y-%m-%d")
                        else:
                            # "28 abr" style
                            parts = date_str.lower().split()
                            if len(parts) == 2:
                                day = int(parts[0])
                                month = month_map.get(parts[1][:3], 0)
                                if month:
                                    year = now.year
                                    commit_date = datetime(year, month, day)

                        if commit_date:
                            days_until = (commit_date - now).days
                            if 0 <= days_until <= ROADMAP_NOPBI_THRESHOLD_DAYS:
                                inconsistencies.append({
                                    "type": "roadmap_no_pbi",
                                    "severity": "critico",
                                    "description": (
                                        f"Compromiso roadmap en {days_until}d sin PBI: "
                                        f"{item_text[:100]}"
                                    ),
                                    "source": "agent-roadmap",
                                    "days_until": days_until,
                                    "deadline": commit_date.strftime("%Y-%m-%d"),
                                })
                    except Exception:
                        continue
    except Exception:
        pass

    return inconsistencies


# ─────────────────────────────────────────────────────────────────────────────
# State management
# ─────────────────────────────────────────────────────────────────────────────

def load_state(state_path: Path) -> dict[str, Any]:
    """Load existing state.json or return empty structure."""
    if not state_path.exists():
        return {"items": {}, "runs": []}
    try:
        with state_path.open(encoding="utf-8") as f:
            data = json.load(f)
        if "items" not in data:
            data["items"] = {}
        if "runs" not in data:
            data["runs"] = []
        return data
    except (json.JSONDecodeError, OSError):
        return {"items": {}, "runs": []}


def merge_items(
    state: dict[str, Any],
    new_items: list[dict[str, Any]],
    now: datetime,
) -> tuple[dict[str, Any], list[str], list[str], list[str]]:
    """
    Merge new_items into state["items"].
    Returns updated state plus lists: added_ids, closed_ids, reprio_ids.
    """
    now_iso = now.isoformat(timespec="seconds")
    existing = state["items"]

    added_ids: list[str] = []
    reprio_ids: list[str] = []

    # Reactivate deferred items whose defer_until <= today
    for item_id, item in existing.items():
        try:
            if item.get("status") == "deferred":
                defer_until_str = item.get("defer_until", "")
                if defer_until_str:
                    defer_dt = datetime.strptime(defer_until_str, "%Y-%m-%d")
                    if defer_dt.date() <= now.date():
                        item["status"] = "active"
                        item.setdefault("history", []).append({
                            "ts": now_iso,
                            "action": "reactivated",
                            "note": f"defer_until {defer_until_str} reached",
                        })
        except Exception:
            continue

    # Build a set of IDs already in state for dedup
    seen_new: set[str] = set()

    for raw in new_items:
        try:
            item_id = raw["id"]
            if item_id in seen_new:
                continue
            seen_new.add(item_id)

            if item_id in existing:
                # Update existing item
                old_band = existing[item_id].get("band") or existing[item_id].get("reprio_band", "seguimiento")
                new_band = raw.get("band", "seguimiento")
                existing[item_id]["last_updated"] = now_iso
                existing[item_id]["last_seen"] = now_iso

                # Only upgrade band (never downgrade automatically)
                if BAND_ORDER.index(new_band) < BAND_ORDER.index(old_band):
                    existing[item_id]["band"] = new_band
                    existing[item_id].setdefault("history", []).append({
                        "ts": now_iso,
                        "action": "reprio",
                        "note": f"band {old_band} -> {new_band} (from agent file)",
                    })
                    reprio_ids.append(item_id)
            else:
                # New item
                source_file = raw.get("source_file", "unknown")
                source = source_file.replace("agent-", "").replace("-", "_")
                new_entry: dict[str, Any] = {
                    "id": item_id,
                    "title": raw.get("title", ""),
                    "source": source,
                    "source_file": source_file,
                    "band": raw.get("band", "seguimiento"),
                    "score": raw.get("score", 30),
                    "status": "active",
                    "first_seen": now_iso,
                    "last_seen": now_iso,
                    "history": [],
                }
                existing[item_id] = new_entry
                added_ids.append(item_id)
        except Exception:
            continue

    state["items"] = existing

    # closed_ids: manual-only via /pm-radar update {id} close
    closed_ids: list[str] = []

    return state, added_ids, closed_ids, reprio_ids


def compute_delta(
    state: dict[str, Any],
    added_ids: list[str],
    closed_ids: list[str],
    reprio_ids: list[str],
) -> dict[str, Any]:
    """Compute delta vs last run."""
    runs = state.get("runs", [])
    last_run_id = runs[-1].get("run_id") if runs else None
    return {
        "vs_run": last_run_id,
        "added": added_ids,
        "closed": closed_ids,
        "reprio": reprio_ids,
        "added_count": len(added_ids),
        "closed_count": len(closed_ids),
        "reprio_count": len(reprio_ids),
    }


def write_state_atomic(state: dict[str, Any], state_path: Path) -> None:
    """Write state.json atomically using tempfile + rename with simple file lock."""
    lock_path = state_path.parent / ".lock"
    state_path.parent.mkdir(parents=True, exist_ok=True)

    # Simple file lock: write PID to .lock, check if stale
    lock_acquired = False
    try:
        if lock_path.exists():
            try:
                lock_pid = int(lock_path.read_text().strip())
                # Check if PID is alive (OS-agnostic: try os.kill with signal 0)
                try:
                    os.kill(lock_pid, 0)
                    # Process alive — skip lock acquisition
                except (OSError, ProcessLookupError):
                    # PID dead, stale lock — remove it
                    lock_path.unlink(missing_ok=True)
            except (ValueError, OSError):
                lock_path.unlink(missing_ok=True)

        lock_path.write_text(str(os.getpid()))
        lock_acquired = True

        # Write to temp file then rename
        tmp_fd, tmp_path_str = tempfile.mkstemp(
            dir=state_path.parent, suffix=".tmp"
        )
        try:
            with os.fdopen(tmp_fd, "w", encoding="utf-8") as f:
                json.dump(state, f, ensure_ascii=False, indent=2)
            shutil.move(tmp_path_str, str(state_path))
        except Exception:
            try:
                os.unlink(tmp_path_str)
            except OSError:
                pass
            raise
    finally:
        if lock_acquired:
            try:
                lock_path.unlink(missing_ok=True)
            except OSError:
                pass


# ─────────────────────────────────────────────────────────────────────────────
# Report generation
# ─────────────────────────────────────────────────────────────────────────────

def build_report(
    state: dict[str, Any],
    inconsistencies: list[dict[str, Any]],
    delta: dict[str, Any],
    now: datetime,
    run_id: str,
) -> dict[str, Any]:
    """Build radar-report.json structure."""
    items = state.get("items", {})

    # Filter: only active items (not closed/discarded)
    # deferred only if defer_until <= today
    active_items = []
    for item in items.values():
        try:
            status = item.get("status", "active")
            if status in ("closed", "discarded"):
                continue
            if status == "deferred":
                defer_until = item.get("defer_until", "")
                if defer_until:
                    defer_dt = datetime.strptime(defer_until, "%Y-%m-%d")
                    if defer_dt.date() > now.date():
                        continue
            active_items.append(item)
        except Exception:
            active_items.append(item)

    # Sort by band then score descending
    band_rank = {b: i for i, b in enumerate(BAND_ORDER)}
    active_items.sort(
        key=lambda x: (
            band_rank.get(x.get("reprio_band") or x.get("band", "seguimiento"), 99),
            -(x.get("score", 0)),
        )
    )

    # Stats by band
    stats: dict[str, int] = {b: 0 for b in BAND_ORDER}
    stats["total_active"] = len(active_items)
    stats["total_items"] = len(items)
    for item in active_items:
        band = item.get("reprio_band") or item.get("band", "seguimiento")
        if band in stats:
            stats[band] += 1

    return {
        "run_id": run_id,
        "timestamp": now.isoformat(timespec="seconds"),
        "items": active_items,
        "inconsistencies": inconsistencies,
        "delta": delta,
        "stats": stats,
    }


# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────

def expand_path(p: str) -> Path:
    return Path(os.path.expandvars(os.path.expanduser(p)))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="PM Radar — parse agent-*.md, merge state, emit radar-report.json"
    )
    parser.add_argument(
        "--tmp-dir",
        required=True,
        help="Directory containing agent-*.md files",
    )
    parser.add_argument(
        "--state",
        required=True,
        help="Path to state.json (read + write)",
    )
    parser.add_argument(
        "--output",
        default=None,
        help="Path for radar-report.json (default: state dir / radar-report.json)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse and report without writing state",
    )
    args = parser.parse_args()

    now = datetime.now()
    run_id = now.strftime("run-%Y%m%d-%H%M%S")

    tmp_dir = expand_path(args.tmp_dir)
    state_path = expand_path(args.state)
    output_path = (
        expand_path(args.output)
        if args.output
        else state_path.parent / "radar-report.json"
    )

    # ── Load agent files ──────────────────────────────────────────────────────
    print(f"[pm-radar] Loading agent files from: {tmp_dir}", file=sys.stderr)
    new_items = load_agent_files(tmp_dir)
    print(f"[pm-radar] Parsed {len(new_items)} raw items", file=sys.stderr)

    # ── Detect inconsistencies ────────────────────────────────────────────────
    print("[pm-radar] Detecting inconsistencies...", file=sys.stderr)
    inconsistencies = detect_inconsistencies(tmp_dir, now)
    print(f"[pm-radar] Found {len(inconsistencies)} inconsistencies", file=sys.stderr)

    # ── Load state ────────────────────────────────────────────────────────────
    print(f"[pm-radar] Loading state from: {state_path}", file=sys.stderr)
    state = load_state(state_path)

    # ── Merge ─────────────────────────────────────────────────────────────────
    state, added_ids, closed_ids, reprio_ids = merge_items(state, new_items, now)

    # ── Delta ─────────────────────────────────────────────────────────────────
    delta = compute_delta(state, added_ids, closed_ids, reprio_ids)

    # ── Record run ────────────────────────────────────────────────────────────
    state.setdefault("runs", []).append({
        "run_id": run_id,
        "ts": now.isoformat(timespec="seconds"),
        "items_parsed": len(new_items),
        "items_added": len(added_ids),
        "inconsistencies": len(inconsistencies),
    })
    # Keep last 50 runs
    state["runs"] = state["runs"][-50:]

    # ── Write state ───────────────────────────────────────────────────────────
    if not args.dry_run:
        print(f"[pm-radar] Writing state to: {state_path}", file=sys.stderr)
        write_state_atomic(state, state_path)

    # ── Build and emit report ─────────────────────────────────────────────────
    report = build_report(state, inconsistencies, delta, now, run_id)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    if not args.dry_run:
        with output_path.open("w", encoding="utf-8") as f:
            json.dump(report, f, ensure_ascii=False, indent=2)
        print(f"[pm-radar] Report written to: {output_path}", file=sys.stderr)

    # ── Summary to stdout ─────────────────────────────────────────────────────
    stats = report["stats"]
    print(f"\nPM Radar — {now.strftime('%Y-%m-%d %H:%M')}")
    print(f"  Items activos : {stats['total_active']}")
    print(f"  Critico       : {stats.get('critico', 0)}")
    print(f"  Urgente       : {stats.get('urgente', 0)}")
    print(f"  Importante    : {stats.get('importante', 0)}")
    print(f"  Seguimiento   : {stats.get('seguimiento', 0)}")
    print(f"  Inconsistencias: {len(inconsistencies)}")
    print(f"  Delta: +{len(added_ids)} nuevos, {len(closed_ids)} cerrados, {len(reprio_ids)} reprio")

    if inconsistencies:
        print("\nInconsistencias detectadas:")
        for inc in inconsistencies[:10]:
            print(f"  [{inc['severity'].upper()}] {inc['description'][:100]}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
