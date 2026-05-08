"""project-update-sync.py — F4 deterministic PENDING.md updater.

Reads the most recent radar markdown file produced by F3 and appends NEW
action items to projects/<slug>_main/<slug>-monica/notes/PENDING.md under
the "Acciones esta semana" section. Dedup is based on case-folded action
text (with the source label stripped). Idempotent: re-running does nothing.

Pure deterministic: regex + set membership. No LLM. No external API.

Usage:
  python scripts/project-update-sync.py --slug "Project Aurora"
  python scripts/project-update-sync.py --radar /path/to/radar.md --pending /path/to/PENDING.md
"""
import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path


def find_latest_radar(radar_dir):
    """Return Path to newest *-radar.md by name (timestamp prefix), or None."""
    radar_dir = Path(radar_dir)
    if not radar_dir.exists():
        return None
    files = sorted(radar_dir.glob("*-radar.md"), key=lambda p: p.name, reverse=True)
    return files[0] if files else None


def extract_radar_items(radar_path):
    """Extract checkbox items under '## Action items abiertos (consolidado)'."""
    try:
        text = Path(radar_path).read_text(encoding="utf-8")
    except Exception:
        return []
    m = re.search(
        r"##\s+Action items abiertos[^\n]*\n(.*?)(?=\n## |\n---|\Z)",
        text, re.DOTALL,
    )
    if not m:
        return []
    body = m.group(1)
    items = []
    for line in body.splitlines():
        cm = re.match(r"^\s*-\s*\[\s\]\s+(.+?)(?:\s*_\[(.+?)\]_)?\s*$", line)
        if not cm:
            continue
        text_part = cm.group(1).strip()
        source = (cm.group(2) or "").strip()
        if not text_part:
            continue
        items.append({"text": text_part, "source": source})
    return items


def dedup_key(text):
    """Case-folded, whitespace-collapsed key for dedup."""
    return re.sub(r"\s+", " ", str(text).strip().lower())


def existing_item_keys(pending_path):
    """Return set of dedup keys for all checkbox items currently in PENDING.md."""
    keys = set()
    try:
        text = Path(pending_path).read_text(encoding="utf-8")
    except Exception:
        return keys
    for line in text.splitlines():
        cm = re.match(r"^\s*-\s*\[\s?[xX ]?\s?\]\s+(.+?)(?:\s*_\[.+?\]_)?\s*$", line)
        if not cm:
            continue
        keys.add(dedup_key(cm.group(1).strip()))
    return keys


WEEK_HEADER = "## Acciones esta semana"


def update_pending(radar_path, pending_path, today=None):
    """Append NEW radar items to PENDING.md week section. Returns count added."""
    today = today or datetime.now().strftime("%Y-%m-%d")
    radar_path = Path(radar_path)
    pending_path = Path(pending_path)

    items = extract_radar_items(radar_path)
    if not items:
        return 0

    pending_path.parent.mkdir(parents=True, exist_ok=True)
    if not pending_path.exists():
        pending_path.write_text(
            "# PENDING\n\n**Última actualización**: " + today + "\n\n",
            encoding="utf-8",
        )

    body = pending_path.read_text(encoding="utf-8")
    existing = existing_item_keys(pending_path)

    new_lines = []
    for it in items:
        key = dedup_key(it["text"])
        if key in existing:
            continue
        existing.add(key)
        line = "- [ ] " + it["text"]
        if it.get("source"):
            line += " _[" + it["source"] + "]_"
        new_lines.append(line)

    if not new_lines:
        return 0

    if WEEK_HEADER in body:
        # Insert just below the header line
        idx = body.index(WEEK_HEADER) + len(WEEK_HEADER)
        # Move past possible '\n' or '\n(ninguno)\n'
        rest = body[idx:]
        m = re.match(r"\n\(ninguno\)\n?", rest)
        if m:
            insertion_at = idx + m.end()
            block = "\n".join(new_lines) + "\n"
            body = body[:idx] + "\n" + block + body[insertion_at:]
        else:
            block = "\n" + "\n".join(new_lines) + "\n"
            body = body[:idx] + block + body[idx:]
    else:
        sep = "" if body.endswith("\n") else "\n"
        body = body + sep + "\n" + WEEK_HEADER + "\n" + "\n".join(new_lines) + "\n"

    # Update timestamp line if present
    body = re.sub(
        r"^(\*\*Última actualización\*\*:)\s*\d{4}-\d{2}-\d{2}",
        r"\1 " + today, body, count=1, flags=re.MULTILINE,
    )

    pending_path.write_text(body, encoding="utf-8")
    return len(new_lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--slug", default=None)
    ap.add_argument("--radar", default=None,
                    help="Explicit radar.md path; overrides --slug")
    ap.add_argument("--pending", default=None,
                    help="Explicit PENDING.md path; overrides --slug")
    args = ap.parse_args()

    sys.path.insert(0, str(Path(__file__).parent))
    import savia_paths
    paths = savia_paths.project_paths(args.slug) if args.slug else None

    if args.radar:
        radar = Path(args.radar)
    elif paths:
        radar = find_latest_radar(paths["radar"])
    else:
        sys.exit("FATAL: pass --slug or --radar")

    if not radar:
        print(json.dumps({"added": 0, "reason": "no radar found"}))
        return

    if args.pending:
        pending = Path(args.pending)
    else:
        pending = paths["pending"]

    n = update_pending(radar, pending)
    print(json.dumps({"added": n, "radar": str(radar), "pending": str(pending)}))


if __name__ == "__main__":
    main()
