"""
SPEC-154 — Module exposing process_spec_text for tests.
Thin wrapper around backfill-specs.py logic.
stdlib only.
"""
from __future__ import annotations

import re
from typing import Any

PRIORITY_MAP = {
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
            for cast in (int, float):
                try:
                    val = cast(val)
                    break
                except (ValueError, TypeError):
                    pass
            if isinstance(val, str) and val.lower() == "true":
                val = True
            elif isinstance(val, str) and val.lower() == "false":
                val = False
            fields[key] = val
    return fields, body


def write_frontmatter(fields: dict[str, Any], body: str) -> str:
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
    if "effort_score" in fields:
        try:
            return int(fields["effort_score"])
        except (ValueError, TypeError):
            pass
    effort_raw = str(fields.get("effort", "")).lower().strip()
    first = re.split(r"[\s,/~]", effort_raw)[0] if effort_raw else ""
    return EFFORT_TEXT_MAP.get(first)


def check_consistency(value: int, urgency: int, effort_score: int, priority_score: float) -> bool:
    expected = (value * urgency) / max(1, effort_score)
    tolerance = expected * 0.05
    return abs(priority_score - expected) <= tolerance + 0.1


def compute_priority_score(value: int, urgency: int, effort_score: int) -> float:
    return round((value * urgency) / max(1, effort_score), 1)


def process_spec_text(
    text: str,
    dry_run: bool = False,
    validate_only: bool = False,
) -> tuple[dict[str, Any], str, str | None]:
    """
    Process spec text (string) instead of file.
    Returns (fields, action, new_text_or_None).
    Used by tests.
    """
    fields, body = read_frontmatter(text)

    status = str(fields.get("status", "")).strip().upper()
    if status not in ACTIVE_STATUSES:
        return fields, "skipped", None

    has_score = "priority_score" in fields
    has_vue = all(k in fields for k in ("value", "urgency", "effort_score"))
    has_needs_triage = fields.get("needs-triage") is True
    has_priority = "priority" in fields

    if validate_only:
        if has_needs_triage:
            return fields, "needs-triage accepted", None
        if has_vue and has_score:
            ok = check_consistency(
                int(fields["value"]), int(fields["urgency"]),
                int(fields["effort_score"]), float(fields["priority_score"])
            )
            return fields, "ok" if ok else "inconsistent", None
        if not has_vue and not has_score and not has_needs_triage:
            return fields, "missing-metadata", None
        return fields, "partial-metadata", None

    modified = False

    if has_vue and has_score:
        ok = check_consistency(
            int(fields["value"]), int(fields["urgency"]),
            int(fields["effort_score"]), float(fields["priority_score"])
        )
        action = "verified-consistent" if ok else "inconsistent"
        return fields, action, None

    if has_vue and not has_score:
        ps = compute_priority_score(int(fields["value"]), int(fields["urgency"]), int(fields["effort_score"]))
        if not dry_run:
            fields["priority_score"] = ps
        return fields, "added-priority_score", write_frontmatter(fields, body)

    if not has_vue and has_priority and not has_needs_triage:
        priority_raw = str(fields.get("priority", "")).lower().strip()
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
            return fields, "backfilled-from-priority", write_frontmatter(fields, body)
        else:
            if not dry_run:
                fields["needs-triage"] = True
            return fields, "marked-needs-triage", write_frontmatter(fields, body)

    if not has_vue and not has_priority and not has_needs_triage and not has_score:
        if not dry_run:
            fields["needs-triage"] = True
        return fields, "marked-needs-triage", write_frontmatter(fields, body)

    if has_needs_triage:
        return fields, "already-needs-triage", None

    return fields, "ok", None
