"""SPEC-X01: PENDING auto-sync from radar findings.

Reads radar-report.json, maps scoring bands to PENDING tiers,
appends new entries to target PENDING.md without overwriting manual edits.

PENDING path resolution: --pending flag > SAVIA_PENDING_PATH env > first
*/notes/PENDING.md found under the current project root.
"""
import argparse
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path


TIER_MAP = [
    (80, "AHORA", "CRIT"),
    (60, "ESTA SEMANA", "URG"),
    (40, "ESTE SPRINT", "IMP"),
    (0, "BACKLOG", "SEG"),
]


def score_to_tier(score):
    for threshold, label, code in TIER_MAP:
        if score >= threshold:
            return label, code
    return "BACKLOG", "SEG"


def resolve_pending_path(flag_val):
    if flag_val:
        return Path(flag_val)
    env_val = os.environ.get("SAVIA_PENDING_PATH")
    if env_val:
        return Path(env_val)
    root = Path(os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd())
    candidates = list(root.glob("projects/*/*/notes/PENDING.md"))
    if candidates:
        return candidates[0]
    raise SystemExit("PENDING.md not found. Set --pending or SAVIA_PENDING_PATH env")


def load_existing(pending_path):
    if not pending_path.exists():
        return set(), ""
    content = pending_path.read_text(encoding="utf-8")
    ids = set(m.group(0) for m in re.finditer(r"\[P(\d+)\.(\d+)\]", content))
    return ids, content


def radar_id_to_pending(radar_item):
    src = radar_item.get("source", "rdr")
    rid = radar_item.get("id", "")
    hid = abs(hash(src + str(rid))) % 9999
    return "P9." + str(hid)


def main():
    ap = argparse.ArgumentParser(description="PENDING auto-sync (SPEC-X01)")
    ap.add_argument("--radar-report", default=str(Path.home() / ".savia" / "pm-radar" / "radar-report.json"))
    ap.add_argument("--pending", default=None)
    ap.add_argument("--max-adds", type=int, default=10)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    report_path = Path(args.radar_report)
    pending_path = resolve_pending_path(args.pending)
    if not report_path.exists():
        print("radar-report.json missing: " + str(report_path), file=sys.stderr)
        sys.exit(2)

    radar = json.loads(report_path.read_text(encoding="utf-8"))
    items = radar.get("items", [])
    if not items:
        print("[sync] no items", file=sys.stderr)
        return
    items.sort(key=lambda x: -(x.get("score") or 0))
    hot = [i for i in items if (i.get("score") or 0) >= 60]

    existing_ids, existing_content = load_existing(pending_path)
    print("[sync] target: " + str(pending_path), file=sys.stderr)
    print("[sync] existing ids: " + str(len(existing_ids)), file=sys.stderr)

    additions = []
    for item in hot:
        pid = radar_id_to_pending(item)
        if pid in existing_ids:
            continue
        desc = (item.get("description") or item.get("title") or "")[:150]
        if desc and desc.lower() in existing_content.lower():
            continue
        score = item.get("score", 0)
        tier, code = score_to_tier(score)
        additions.append({
            "id": pid,
            "score": score,
            "tier": tier,
            "code": code,
            "description": desc,
            "source": item.get("source", "?"),
            "detected": datetime.now().strftime("%Y-%m-%d"),
        })
        if len(additions) >= args.max_adds:
            break

    if not additions:
        print("[sync] nothing new", file=sys.stderr)
        return

    print("[sync] adding " + str(len(additions)) + " items", file=sys.stderr)
    if args.dry_run:
        for a in additions:
            print("  DRY: [" + str(a["score"]) + "] " + a["id"] + " - " + a["tier"] + " - " + a["description"][:80])
        return

    block = ["", "", "## Auto-sync from radar " + datetime.now().strftime("%Y-%m-%d %H:%M"), ""]
    for a in additions:
        block.append("### [" + str(a["score"]) + "] " + a["id"] + " - " + a["description"][:100])
        block.append("**Tier**: " + a["code"] + " " + a["tier"] + " - **Source**: " + a["source"] + " - **Detected**: " + a["detected"])
        block.append("")

    new_content = existing_content + "\n".join(block) + "\n"
    tmp = pending_path.with_suffix(".tmp")
    tmp.write_text(new_content, encoding="utf-8")
    tmp.replace(pending_path)
    print("[sync] done: +" + str(len(additions)) + " items", file=sys.stderr)


if __name__ == "__main__":
    main()
