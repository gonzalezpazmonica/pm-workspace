"""SPEC-X02: Meetings auto-digest daily.

Scans a transcript source directory (recursive); for each VTT or
.transcript.txt without matching digest md, dispatches a digest
(simple text extraction) and writes .md to target.

Sources supported:
  - *.vtt           (Stream/SharePoint VTT, gold standard)
  - *.transcript.txt (Teams web recap-panel scroll, for meetings
                      where VTT is not downloadable — owner restrictions
                      or shared-attendee scenarios)

Idempotent: skips entries whose slug+date already has a digest.
"""
import argparse
import hashlib
import os
import re
import sys
from datetime import datetime
from pathlib import Path


# Patrones de búsqueda recursiva: VTT en cualquier subdir + transcript.txt
TRANSCRIPT_PATTERNS = ("**/*.vtt", "**/*.transcript.txt")


def slugify(s):
    s = s.lower().strip()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    s = re.sub(r"-+", "-", s).strip("-")
    return s[:80]


def extract_vtt_text(vtt_path):
    """Extract text content from VTT — basic parser."""
    try:
        content = vtt_path.read_text(encoding="utf-8")
    except Exception:
        try:
            content = vtt_path.read_text(encoding="latin-1")
        except Exception as err:
            return ""
    lines = content.split("\n")
    out = []
    skip_header = True
    for line in lines:
        line = line.strip()
        if skip_header:
            if line == "" or line.startswith("WEBVTT") or line.startswith("NOTE"):
                continue
            skip_header = False
        if re.match(r"^\d{2}:\d{2}:\d{2}", line):
            continue
        if "-->" in line:
            continue
        if line.isdigit():
            continue
        if not line:
            continue
        # Strip voice tags like <v speaker>
        line = re.sub(r"<v\s+([^>]+)>", r"[\1] ", line)
        line = re.sub(r"</v>", "", line)
        out.append(line)
    return "\n".join(out)


def extract_transcript_txt(txt_path):
    """Extract body text from a Teams recap-panel transcript.

    Format (see scripts/extract-teams-transcripts.py save_transcript):
        # Teams transcript
        Title: <title>
        Extracted: YYYY-MM-DD HH:MM

        ============================================================
        <body lines>
    """
    try:
        content = txt_path.read_text(encoding="utf-8")
    except Exception:
        try:
            content = txt_path.read_text(encoding="latin-1")
        except Exception:
            return ""
    parts = content.split("=" * 60, 1)
    body = parts[1] if len(parts) == 2 else content
    return body.strip()


def extract_text(path):
    """Dispatch on extension: VTT vs transcript.txt."""
    name = path.name.lower()
    if name.endswith(".vtt"):
        return extract_vtt_text(path)
    if name.endswith(".transcript.txt"):
        return extract_transcript_txt(path)
    return ""


def parse_title_from_txt(txt_path):
    """Read 'Title:' header from a transcript.txt to use as friendly name."""
    try:
        with open(txt_path, encoding="utf-8") as f:
            for _ in range(5):
                line = f.readline()
                if line.startswith("Title:"):
                    return line.split(":", 1)[1].strip()
    except Exception:
        pass
    return None


def summarize_text(text, max_lines=50):
    """Very basic summary: first line + speakers + last N lines."""
    lines = [l for l in text.split("\n") if l.strip()]
    speakers = set()
    for line in lines:
        m = re.match(r"\[([^\]]+)\]", line)
        if m:
            speakers.add(m.group(1))
    return {
        "total_lines": len(lines),
        "speakers": sorted(speakers)[:20],
        "preview": "\n".join(lines[:5]),
        "tail": "\n".join(lines[-max_lines:]),
    }


def has_existing_digest(target_dir, slug, file_date):
    """Check if a digest matching slug+date already exists."""
    for f in target_dir.glob("*.md"):
        name = f.name.lower()
        if slug in name and (file_date in name or file_date.replace("-", "") in name):
            return True
    return False


def main():
    ap = argparse.ArgumentParser(description="Meetings auto-digest (SPEC-X02)")
    ap.add_argument("--vtt-dir", default=os.environ.get("SAVIA_VTT_DIR", str(Path.home() / ".savia" / "captured-vtt")))
    ap.add_argument("--target-dir", required=True, help="Digest output dir (project-specific)")
    ap.add_argument("--log", default=None)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    vtt_dir = Path(args.vtt_dir)
    target_dir = Path(args.target_dir)
    target_dir.mkdir(parents=True, exist_ok=True)
    log_path = Path(args.log) if args.log else target_dir / "_meeting-digest-log.md"

    if not vtt_dir.exists():
        print("VTT dir missing: " + str(vtt_dir), file=sys.stderr)
        sys.exit(2)

    transcripts = []
    seen = set()
    for pat in TRANSCRIPT_PATTERNS:
        for p in vtt_dir.glob(pat):
            rp = p.resolve()
            if rp in seen:
                continue
            seen.add(rp)
            transcripts.append(p)
    n_vtt = sum(1 for p in transcripts if p.name.lower().endswith(".vtt"))
    n_txt = sum(1 for p in transcripts if p.name.lower().endswith(".transcript.txt"))
    print("[digest] found " + str(len(transcripts))
          + " transcripts (VTT=" + str(n_vtt) + ", TXT=" + str(n_txt) + ")",
          file=sys.stderr)
    digested = 0
    skipped = 0
    failed = 0

    for src in transcripts:
        stem = src.stem
        if stem.endswith(".transcript"):
            stem = stem[: -len(".transcript")]
        # Try to extract date from filename: YYYYMMDD or YYYY-MM-DD
        m = re.search(r"(\d{4})[-_]?(\d{2})[-_]?(\d{2})", stem)
        if m:
            file_date = m.group(1) + "-" + m.group(2) + "-" + m.group(3)
        else:
            mtime = datetime.fromtimestamp(src.stat().st_mtime)
            file_date = mtime.strftime("%Y-%m-%d")
        # For .transcript.txt prefer the human title in the file header
        friendly = None
        if src.name.lower().endswith(".transcript.txt"):
            friendly = parse_title_from_txt(src)
        slug_base = friendly if friendly else stem
        slug = slugify(slug_base.replace(file_date.replace("-", ""), ""))
        if has_existing_digest(target_dir, slug, file_date):
            skipped += 1
            continue

        if args.dry_run:
            print("  DRY: " + file_date + " " + slug + " <- " + src.name)
            digested += 1
            continue

        text = extract_text(src)
        if not text:
            failed += 1
            continue
        summary = summarize_text(text)
        digest_name = file_date.replace("-", "") + "-" + slug + ".md"
        source_label = "Teams recap (no VTT)" if src.name.lower().endswith(".transcript.txt") else "VTT"
        lines = [
            "# Meeting digest - " + slug,
            "",
            "**Última actualización**: " + datetime.now().strftime("%Y-%m-%d"),
            "**Fecha reunión**: " + file_date,
            "**Fuente**: " + source_label,
            "**Source file**: " + str(src.name),
            "**Líneas totales**: " + str(summary["total_lines"]),
            "**Speakers**: " + ", ".join(summary["speakers"][:10]),
            "",
            "## Inicio",
            "",
            summary["preview"],
            "",
            "## Final (últimas líneas)",
            "",
            summary["tail"],
            "",
            "> NOTA: digest deterministico basico. Para extraccion de action items,",
            "> decisiones y riesgos invocar el agente meeting-digest manualmente sobre",
            "> " + str(src.name),
            "",
        ]
        out_file = target_dir / digest_name
        out_file.write_text("\n".join(lines), encoding="utf-8")
        digested += 1
        # Append to log
        log_line = datetime.now().strftime("%Y-%m-%d %H:%M") + " - " + str(src.name) + " -> " + digest_name + "\n"
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(log_line)

    print("[digest] digested: " + str(digested) + " skipped: " + str(skipped) + " failed: " + str(failed), file=sys.stderr)


if __name__ == "__main__":
    main()
