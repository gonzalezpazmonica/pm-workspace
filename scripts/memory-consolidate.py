#!/usr/bin/env python3
"""memory-consolidate.py — dedup + strip test/bench + stale flag (SE-264).

Opera sobre output/.memory-store.jsonl (local, CRIT-001). Reversible: lo que
se strip queda en output/memory-stripped-<fecha>.jsonl; lo stale se marca y
se archiva a MEMORY-ARCHIVE.md. NUNCA toca entradas human_authored ni
decision/architecture (solo pueden marcarse stale, no strippearse).

Uso:
  memory-consolidate.py --store FILE [--dry-run] [--stale-days N]
                        [--stripped-dir DIR] [--archive FILE]
Exit: 0 ok · 2 usage. Emite informe JSON a stdout.
"""

import argparse
import datetime
import json
import os
import re
import sys

STRIP_RE = re.compile(
    r"(^|[\s_\-])(test|tests|bench|benchmark|eval|fixture|repro|rebuild|assert)"
    r"|ep-|inject-test|^many$| episode: many",
    re.IGNORECASE,
)

PROTECTED_TYPES = {"decision", "architecture", "lesson", "convention", "config"}


def iso_now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_store(path):
    if not os.path.exists(path):
        return []
    out = []
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return out


def should_strip(entry):
    """Entradas de tests/bench (ruido). Protegidas NUNCA se strip."""
    if entry.get("type") in PROTECTED_TYPES:
        return False
    if entry.get("human_authored"):
        return False
    haystack = " ".join(
        str(entry.get(k, "")) for k in ("type", "title", "topic", "topic_key", "content")
    )
    return bool(STRIP_RE.search(haystack))


def should_flag_stale(entry, stale_days, now):
    if entry.get("stale"):
        return False
    if entry.get("read_at") or entry.get("refs"):
        return False
    ts = entry.get("ts", "")
    try:
        t = datetime.datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except (ValueError, TypeError):
        return False
    age_days = (now - t).total_seconds() / 86400.0
    return age_days > stale_days


def main():
    ap = argparse.ArgumentParser(description="SE-264 memory consolidation")
    ap.add_argument("--store", required=True)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--stale-days", type=int, default=90)
    ap.add_argument("--stripped-dir", default=None)
    ap.add_argument("--archive", default=None)
    args = ap.parse_args()

    store = load_store(args.store)
    now = datetime.datetime.now(datetime.timezone.utc)
    now_dt = datetime.datetime.now(datetime.timezone.utc)
    now_iso = iso_now()

    seen = {}
    deduped = 0
    stripped = 0
    stale = 0
    kept = []
    stripped_rows = []

    for entry in store:
        key = entry.get("topic_key") or entry.get("id") or ""
        if key and key in seen:
            prev = seen[key]
            # conservar la más reciente; si igual antigüedad, la de más contenido
            if entry.get("ts", "") >= prev.get("ts", "") or len(str(entry.get("content", ""))) >= len(
                str(prev.get("content", ""))
            ):
                seen[key] = entry
            deduped += 1
            continue
        seen[key] = entry

    for entry in seen.values():
        if should_strip(entry):
            stripped += 1
            stripped_rows.append(entry)
            continue
        if should_flag_stale(entry, args.stale_days, now_dt):
            entry["stale"] = True
            entry["stale_at"] = now_iso
            stale += 1
        kept.append(entry)

    report = {
        "ts": now_iso,
        "scanned": len(store),
        "deduped": deduped,
        "stripped": stripped,
        "stale": stale,
        "kept": len(kept),
        "dry_run": args.dry_run,
    }

    if args.dry_run:
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 0

    # Escribir store consolidado
    with open(args.store, "w", encoding="utf-8") as f:
        for e in kept:
            f.write(json.dumps(e, ensure_ascii=False) + "\n")

    # Stripped a fichero reversible en output/
    if stripped_rows:
        sdir = args.stripped_dir or os.path.join(os.path.dirname(args.store), "memory-stripped")
        os.makedirs(sdir, exist_ok=True)
        sfile = os.path.join(sdir, f"stripped-{now.isoformat().split('T')[0]}.jsonl")
        with open(sfile, "w", encoding="utf-8") as f:
            for e in stripped_rows:
                f.write(json.dumps(e, ensure_ascii=False) + "\n")
        report["stripped_file"] = sfile

    # Archive de stale a MEMORY-ARCHIVE.md (append)
    stale_rows = [e for e in kept if e.get("stale")]
    if stale_rows and args.archive:
        os.makedirs(os.path.dirname(os.path.abspath(args.archive)), exist_ok=True)
        with open(args.archive, "a", encoding="utf-8") as f:
            for e in stale_rows:
                f.write(f"- [{e.get('type','?')}] {e.get('title','')} `{e.get('topic_key','')}` (stale {now_iso})\n")

    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
