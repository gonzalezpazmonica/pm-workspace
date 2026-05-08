"""project-update-analyze.py — F3 deterministic consolidator.

Reads F1 outputs from ~/.savia/project-update-tmp/<slug>/ and F2 digests
from projects/<slug>_main/<slug>-monica/meetings/. Produces a single
radar markdown file under projects/<slug>_main/<slug>-monica/reports/radar/.

Pure deterministic: regex + cross-reference. No LLM. Idempotent: running
twice with same inputs produces identical body (timestamp differs only).

Usage:
  python scripts/project-update-analyze.py --slug "Project Aurora"
  python scripts/project-update-analyze.py --slug "Project Aurora" --target-dir /tmp/test
"""
import argparse
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path


SAVIA = Path.home() / ".savia"
TMP_BASE = SAVIA / "project-update-tmp"
import sys as _sys
_sys.path.insert(0, str(Path(__file__).parent))


def load_json(path, default=None):
    """Read JSON file; return default on missing/invalid."""
    if default is None:
        default = {}
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception:
        return default


def load_text(path, default=""):
    try:
        return Path(path).read_text(encoding="utf-8")
    except Exception:
        return default


def summarize_mail(payload):
    """Aggregate inbox/sent counts per account from mail.json list."""
    out = {"accounts": 0, "total_inbox": 0, "total_sent": 0, "per_account": {}}
    if not isinstance(payload, list):
        return out
    for entry in payload:
        acct = entry.get("account") or "?"
        inbox = int(entry.get("count") or 0)
        sent = int(entry.get("sent_count") or 0)
        out["per_account"][acct] = {"inbox": inbox, "sent": sent}
        out["total_inbox"] += inbox
        out["total_sent"] += sent
        out["accounts"] += 1
    return out


def summarize_calendar(payload):
    """Group calendar events by day_date."""
    out = {"total_events": 0, "per_day": {}}
    if not isinstance(payload, list):
        return out
    for entry in payload:
        for ev in entry.get("events") or []:
            day = ev.get("day_date") or "unknown"
            out["per_day"][day] = out["per_day"].get(day, 0) + 1
            out["total_events"] += 1
    return out


def summarize_onedrive(payload):
    """OneDrive recent files count."""
    if not isinstance(payload, dict):
        return {"sources": 0, "total_files": 0}
    sources = payload.get("sources") or {}
    total = 0
    for src in sources.values():
        total += int(src.get("count_total_recent_7d") or 0)
    return {"sources": len(sources), "total_files": total}


def summarize_sharepoint(payload):
    """SharePoint recordings list — count + status."""
    if not isinstance(payload, dict):
        return {"status": "unknown", "count": 0}
    status = "ok" if payload.get("source_status", {}).get("sharepoint_transcripts.py") != "fail" else "fail"
    recordings = payload.get("recordings") or []
    return {"status": status, "count": len(recordings) if isinstance(recordings, list) else 0}


def extract_action_items(digest_path):
    """Extract '- [ ]' checkbox items from a digest markdown file."""
    items = []
    try:
        for line in Path(digest_path).read_text(encoding="utf-8").splitlines():
            m = re.match(r"^\s*-\s*\[\s\]\s+(.+)$", line)
            if m:
                items.append(m.group(1).strip())
    except Exception:
        pass
    return items


def extract_decisions_count(digest_path):
    """Count items under a '## Decisiones' or '## Decisions' section."""
    try:
        text = Path(digest_path).read_text(encoding="utf-8")
    except Exception:
        return 0
    m = re.search(r"##\s+Decisi(?:o|ó)n(?:es)?[^\n]*\n(.*?)(?=\n## |\Z)", text, re.IGNORECASE | re.DOTALL)
    if not m:
        return 0
    body = m.group(1)
    return len([line for line in body.split("\n") if line.strip().startswith("-")])


def gather_digests(meetings_dir):
    """Return list of digests, deduped by case-folded basename.

    Windows + OneDrive can yield phantom duplicates; on collision keep the
    file with the latest mtime.
    """
    md_dir = Path(meetings_dir)
    if not md_dir.exists():
        return []
    by_key = {}
    for md in md_dir.glob("*.md"):
        if md.name.startswith("_"):
            continue
        key = md.name.lower()
        existing = by_key.get(key)
        if existing and existing.stat().st_mtime >= md.stat().st_mtime:
            continue
        by_key[key] = md
    out = []
    for md in sorted(by_key.values(), key=lambda p: p.name.lower()):
        out.append({
            "path": md,
            "name": md.stem,
            "action_items": extract_action_items(md),
            "decisions_count": extract_decisions_count(md),
            "mtime": datetime.fromtimestamp(md.stat().st_mtime).strftime("%Y-%m-%d %H:%M"),
        })
    return out


def render_radar(slug, inputs, fixed_ts=None):
    """Produce the radar markdown body. Pure function for idempotence."""
    ts = fixed_ts or datetime.now().strftime("%Y-%m-%d %H:%M")
    lines = []
    lines.append("# Radar — " + str(slug) + " — " + ts)
    lines.append("")
    lines.append("> Determinista. Generado por scripts/project-update-analyze.py (F3, sin LLM).")
    lines.append("")

    # Sources status
    lines.append("## Sources status")
    lines.append("")
    lines.append("| Source | Status | Items |")
    lines.append("|---|---|---|")
    auth = inputs.get("auth_status") or {}
    if isinstance(auth, dict):
        # SH02: auth payload may be {accounts: {a1: {status:...}}} OR flat {a1: status}
        accounts_dict = auth.get("accounts") if isinstance(auth.get("accounts"), dict) else auth
        for acct, info in sorted((accounts_dict or {}).items()):
            status = info.get("status") if isinstance(info, dict) else info
            tag = "OK" if status == "running" else "STALE/" + str(status or "?")
            lines.append("| daemon-" + str(acct) + " | " + tag + " | - |")

    mail = inputs.get("mail_summary") or {}
    for acct, c in sorted((mail.get("per_account") or {}).items()):
        lines.append("| mail-" + str(acct) + " | OK | " + str(c.get("inbox", 0))
                     + " inbox + " + str(c.get("sent", 0)) + " sent |")

    cal = inputs.get("calendar_summary") or {}
    if cal.get("total_events", 0):
        lines.append("| calendar | OK | " + str(cal["total_events"]) + " events 72h |")

    od = inputs.get("onedrive_summary") or {}
    if od.get("total_files", 0):
        lines.append("| onedrive | OK | " + str(od["total_files"]) + " files 7d |")

    sp = inputs.get("sharepoint_summary") or {}
    if sp:
        lines.append("| sp-recordings | " + sp.get("status", "?") + " | "
                     + str(sp.get("count", 0)) + " recordings |")

    lines.append("")

    # DevOps block
    devops_md = inputs.get("devops_md") or ""
    lines.append("## DevOps snapshot")
    lines.append("")
    if devops_md.strip():
        # Strip header line if redundant
        body = re.sub(r"^# DevOps scan[^\n]*\n+", "", devops_md, flags=re.MULTILINE).strip()
        lines.append(body)
    else:
        lines.append("(devops scan no disponible)")
    lines.append("")

    # Calendar by day
    if cal.get("per_day"):
        lines.append("## Calendario 72h")
        lines.append("")
        for day in sorted(cal["per_day"]):
            lines.append("- " + day + ": " + str(cal["per_day"][day]) + " eventos")
        lines.append("")

    # Digests
    digests = inputs.get("digests") or []
    lines.append("## Reuniones digeridas (F2)")
    lines.append("")
    if not digests:
        lines.append("(ninguna en `meetings/`)")
    else:
        for d in digests:
            n_items = len(d.get("action_items") or [])
            n_dec = d.get("decisions_count") or 0
            lines.append("- **" + d["name"] + "** ("
                         + str(n_items) + " action items, " + str(n_dec)
                         + " decisiones) — última edición " + d["mtime"])
    lines.append("")

    # Action items consolidados
    all_items = []
    for d in digests:
        for it in d.get("action_items") or []:
            all_items.append((d["name"], it))
    if all_items:
        lines.append("## Action items abiertos (consolidado)")
        lines.append("")
        for src, it in all_items:
            lines.append("- [ ] " + it + " _[" + src + "]_")
        lines.append("")

    # Footer
    lines.append("---")
    lines.append("Re-ejecutable. Mismas entradas → misma salida (modulo timestamp).")
    lines.append("")
    return "\n".join(lines)


def run_analyze(slug, tmp_dir=None, meetings_dir=None, target_dir=None):
    """Glue: load all F1+F2 inputs and render radar to target_dir.

    Returns Path to written radar file.
    """
    tmp_dir = Path(tmp_dir) if tmp_dir else (TMP_BASE / slug)
    if meetings_dir is None or target_dir is None:
        import savia_paths
        paths = savia_paths.project_paths(slug)
        if meetings_dir is None:
            meetings_dir = paths["meetings"]
        if target_dir is None:
            target_dir = paths["radar"]
    target_dir = Path(target_dir)
    target_dir.mkdir(parents=True, exist_ok=True)

    inputs = {
        "mail_summary": summarize_mail(load_json(tmp_dir / "mail.json", default=[])),
        "calendar_summary": summarize_calendar(load_json(tmp_dir / "calendar.json", default=[])),
        "onedrive_summary": summarize_onedrive(load_json(tmp_dir / "onedrive.json", default={})),
        "sharepoint_summary": summarize_sharepoint(load_json(tmp_dir / "sharepoint-recordings.json", default={})),
        "devops_md": load_text(tmp_dir / "devops-summary.md", default=""),
        "digests": gather_digests(meetings_dir),
        "auth_status": _last_auth(tmp_dir),
    }

    body = render_radar(slug, inputs)
    out = target_dir / (datetime.now().strftime("%Y%m%d-%H%M") + "-radar.md")
    out.write_text(body, encoding="utf-8")
    return out


def _last_auth(tmp_dir):
    """Find latest orchestrator-*.json and return its auth_status block, if any."""
    try:
        files = sorted(Path(tmp_dir).glob("orchestrator-*.json"))
        if not files:
            return None
        return load_json(files[-1], default={}).get("auth_status")
    except Exception:
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--slug", required=True)
    ap.add_argument("--tmp-dir", default=None)
    ap.add_argument("--meetings-dir", default=None)
    ap.add_argument("--target-dir", default=None)
    args = ap.parse_args()
    out = run_analyze(args.slug, args.tmp_dir, args.meetings_dir, args.target_dir)
    print(json.dumps({"slug": args.slug, "radar": str(out)}))


if __name__ == "__main__":
    main()
