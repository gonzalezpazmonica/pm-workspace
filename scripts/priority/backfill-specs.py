#!/usr/bin/env python3
"""
SPEC-154 Slice 2 — Backfill scripts/priority/ para specs en docs/propuestas/.

Reglas (AC-07, AC-11):
- NUNCA inventa value/urgency/effort si no hay base declarada.
- Si la spec tiene value+urgency+effort_score ya: verifica consistencia (±5%).
- Si tiene priority (alta/media/baja/P0..P3): mapea con tabla heurística.
- Si no tiene nada: marca needs-triage: true.
- Backfill SOLO añade campos, nunca modifica los existentes.

stdlib only.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Heurística declarada (priority-canonical-formula.md tabla)
# ---------------------------------------------------------------------------
PRIORITY_MAP = {
    # Claves normalizadas a minúsculas
    "p0":       {"value": 90, "urgency": 95},
    "critical": {"value": 90, "urgency": 95},
    "alta":     {"value": 90, "urgency": 95},
    "high":     {"value": 90, "urgency": 95},
    "p1":       {"value": 70, "urgency": 65},
    "media":    {"value": 70, "urgency": 65},
    "medium":   {"value": 70, "urgency": 65},
    "p2":       {"value": 50, "urgency": 35},
    "p3":       {"value": 50, "urgency": 35},
    "baja":     {"value": 50, "urgency": 35},
    "low":      {"value": 50, "urgency": 35},
}

EFFORT_TEXT_MAP = {
    "xs": 10, "s": 20, "m": 40, "l": 65, "xl": 85,
    "xsmall": 10, "small": 20, "medium": 40, "large": 65, "xlarge": 85,
}

ACTIVE_STATUSES = {"APPROVED", "PROPOSED", "IN_PROGRESS", "DRAFT", "ACCEPTED"}


def read_frontmatter(text: str) -> tuple[dict[str, Any], str]:
    """Extract YAML-ish frontmatter. Returns (fields, body)."""
    if not text.startswith("---"):
        return {}, text
    end = text.find("\n---", 3)
    if end == -1:
        return {}, text
    fm_block = text[3:end].strip()
    body = text[end + 4:]
    fields: dict[str, Any] = {}
    for line in fm_block.splitlines():
        m = re.match(r"^(\w[\w_-]*):\s*(.*)", line)
        if m:
            key, val = m.group(1), m.group(2).strip()
            # Try numeric
            for cast in (int, float):
                try:
                    val = cast(val)  # type: ignore[assignment]
                    break
                except (ValueError, TypeError):
                    pass
            fields[key] = val
    return fields, body


def write_frontmatter(fields: dict[str, Any], body: str) -> str:
    """Serialize fields back to YAML frontmatter."""
    lines = ["---"]
    for k, v in fields.items():
        if isinstance(v, bool):
            lines.append(f"{k}: {'true' if v else 'false'}")
        elif isinstance(v, float):
            lines.append(f"{k}: {v}")
        elif isinstance(v, int):
            lines.append(f"{k}: {v}")
        else:
            lines.append(f"{k}: {v}")
    lines.append("---")
    return "\n".join(lines) + "\n" + body


def normalize_effort_heuristic(fields: dict[str, Any]) -> int | None:
    """Try to get effort_score from effort field (text: S/M/L/XL) or effort_score directly."""
    if "effort_score" in fields:
        try:
            return int(fields["effort_score"])
        except (ValueError, TypeError):
            pass
    effort_raw = str(fields.get("effort", "")).lower().strip()
    # Extract first token
    first = re.split(r"[\s,/~]", effort_raw)[0] if effort_raw else ""
    return EFFORT_TEXT_MAP.get(first)


def check_consistency(value: int, urgency: int, effort_score: int, priority_score: float) -> bool:
    """AC-03: priority_score = (value * urgency) / effort_score ±5%."""
    expected = (value * urgency) / max(1, effort_score)
    tolerance = expected * 0.05
    return abs(priority_score - expected) <= tolerance + 0.1  # +0.1 for rounding


def compute_priority_score(value: int, urgency: int, effort_score: int) -> float:
    return round((value * urgency) / max(1, effort_score), 1)


def process_spec(path: Path, dry_run: bool, validate_only: bool) -> dict[str, Any]:
    """
    Process one spec file.
    Returns a result dict with keys: file, action, details, error.
    """
    text = path.read_text(encoding="utf-8")
    fields, body = read_frontmatter(text)

    status = str(fields.get("status", "")).strip().upper()
    if status not in ACTIVE_STATUSES:
        return {"file": str(path), "action": "skipped", "reason": f"status={status or 'none'}"}

    result: dict[str, Any] = {"file": str(path.name), "action": "ok", "details": ""}

    has_score = "priority_score" in fields
    has_vue = all(k in fields for k in ("value", "urgency", "effort_score"))
    has_needs_triage = fields.get("needs-triage") is True or str(fields.get("needs-triage", "")).lower() == "true"
    has_priority = "priority" in fields

    # --- Validate only mode ---
    if validate_only:
        if has_needs_triage:
            result["action"] = "ok"
            result["details"] = "needs-triage accepted"
            return result
        if has_vue and has_score:
            ok = check_consistency(
                int(fields["value"]), int(fields["urgency"]),
                int(fields["effort_score"]), float(fields["priority_score"])
            )
            result["action"] = "ok" if ok else "inconsistent"
            result["details"] = f"V={fields['value']}/U={fields['urgency']}/E={fields['effort_score']} → expected≈{compute_priority_score(int(fields['value']), int(fields['urgency']), int(fields['effort_score']))}, found={fields['priority_score']}"
            return result
        if not has_vue and not has_score and not has_needs_triage:
            result["action"] = "missing-metadata"
            result["details"] = "no V/U/E and no needs-triage"
            return result
        result["details"] = "partial metadata"
        return result

    # --- Backfill mode ---
    modified = False

    # Case 1: already has all 4 fields → verify consistency, report only
    if has_vue and has_score:
        ok = check_consistency(
            int(fields["value"]), int(fields["urgency"]),
            int(fields["effort_score"]), float(fields["priority_score"])
        )
        if ok:
            result["action"] = "verified-consistent"
            result["details"] = f"score={fields['priority_score']}"
        else:
            expected = compute_priority_score(int(fields["value"]), int(fields["urgency"]), int(fields["effort_score"]))
            result["action"] = "inconsistent"
            result["details"] = f"found={fields['priority_score']}, expected≈{expected}"
        return result

    # Case 2: has value+urgency+effort_score but no priority_score → add it
    if has_vue and not has_score:
        ps = compute_priority_score(int(fields["value"]), int(fields["urgency"]), int(fields["effort_score"]))
        if not dry_run:
            fields["priority_score"] = ps
        result["action"] = "added-priority_score"
        result["details"] = f"computed={ps}"
        modified = True

    # Case 3: has priority text but not V/U/E → map with heuristic
    elif not has_vue and has_priority and not has_needs_triage:
        priority_raw = str(fields.get("priority", "")).lower().strip()
        # Try exact, then prefix match
        mapping = PRIORITY_MAP.get(priority_raw)
        if not mapping:
            for k in PRIORITY_MAP:
                if priority_raw.startswith(k):
                    mapping = PRIORITY_MAP[k]
                    break
        effort_s = normalize_effort_heuristic(fields)

        if mapping and effort_s is not None:
            value = mapping["value"]
            urgency = mapping["urgency"]
            ps = compute_priority_score(value, urgency, effort_s)
            if not dry_run:
                if "value" not in fields:
                    fields["value"] = value
                if "urgency" not in fields:
                    fields["urgency"] = urgency
                if "effort_score" not in fields:
                    fields["effort_score"] = effort_s
                if "priority_score" not in fields:
                    fields["priority_score"] = ps
            result["action"] = "backfilled-from-priority"
            result["details"] = f"priority={fields.get('priority')} → V={value}/U={urgency}/E={effort_s}/score={ps}"
            modified = True
        else:
            # Cannot map cleanly → needs-triage
            if not has_needs_triage:
                if not dry_run:
                    fields["needs-triage"] = True
                result["action"] = "marked-needs-triage"
                result["details"] = f"priority={fields.get('priority')}, effort could not be mapped (effort_raw={fields.get('effort', 'none')})"
                modified = True

    # Case 4: no metadata at all → needs-triage (AC-07: never invent)
    elif not has_vue and not has_priority and not has_needs_triage and not has_score:
        if not dry_run:
            fields["needs-triage"] = True
        result["action"] = "marked-needs-triage"
        result["details"] = "no V/U/E, no priority field"
        modified = True

    elif has_needs_triage:
        result["action"] = "already-needs-triage"
        result["details"] = "skipped"

    # Write back only if modified and not dry_run
    if modified and not dry_run:
        new_text = write_frontmatter(fields, body)
        path.write_text(new_text, encoding="utf-8")

    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="SPEC-154 frontmatter backfill")
    parser.add_argument("--dry-run", action="store_true", help="Preview without writing")
    parser.add_argument("--validate", action="store_true", help="Validate only, exit 1 if inconsistent")
    parser.add_argument("--dir", default="docs/propuestas", help="Directory to scan")
    args = parser.parse_args()

    base = Path(args.dir)
    if not base.is_dir():
        print(f"ERROR: {base} is not a directory", file=sys.stderr)
        return 1

    specs = sorted(base.glob("*.md"))
    results = []
    for spec in specs:
        r = process_spec(spec, dry_run=args.dry_run, validate_only=args.validate)
        results.append(r)

    # Stats
    stats: dict[str, int] = {}
    for r in results:
        action = r.get("action", "unknown")
        stats[action] = stats.get(action, 0) + 1

    # Output report
    today = datetime.now().strftime("%Y%m%d")
    report_path = Path(f"output/priority-backfill-{today}.json")
    report = {
        "generated_at": datetime.now().isoformat(),
        "dry_run": args.dry_run,
        "validate_only": args.validate,
        "total_files": len(specs),
        "stats": stats,
        "results": results,
    }

    if not args.dry_run and not args.validate:
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"Report: {report_path}")

    # Print summary
    print(f"\n=== Backfill {'DRY-RUN ' if args.dry_run else ''}{'VALIDATE ' if args.validate else ''}Stats ===")
    print(f"Total files scanned: {len(specs)}")
    for action, count in sorted(stats.items()):
        print(f"  {action}: {count}")

    if args.validate:
        has_errors = stats.get("inconsistent", 0) > 0 or stats.get("missing-metadata", 0) > 0
        if has_errors:
            print("\nVALIDATION FAILED: inconsistencies detected (see stats above)")
            return 1
        print("\nVALIDATION PASSED")
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
