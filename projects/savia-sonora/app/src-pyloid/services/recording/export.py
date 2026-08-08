"""Recording export: TXT / MD / JSON / SRT.

Every formatter is a pure function over the dict shape returned by
`DatabaseService.get_recording(id, include_segments=True)`. `export_recording`
writes the chosen format to a file under the target directory and returns the
path.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


class UnknownExportFormatError(ValueError):
    pass


_SLUG_RE = re.compile(r"[^a-zA-Z0-9._-]+")


def _slug(title: str) -> str:
    s = _SLUG_RE.sub("-", (title or "recording").strip()).strip("-")
    return s[:60] if s else "recording"


# ---------- public ----------

def export_recording(recording: dict, fmt: str, out_dir: Path) -> Path:
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    fmt = fmt.lower()
    base = f"{_slug(recording.get('title', ''))}_{recording.get('id', 0)}"

    if fmt == "txt":
        path = out_dir / f"{base}.txt"
        path.write_text(format_txt(recording), encoding="utf-8")
    elif fmt == "md":
        path = out_dir / f"{base}.md"
        path.write_text(format_md(recording), encoding="utf-8")
    elif fmt == "json":
        path = out_dir / f"{base}.json"
        path.write_text(format_json(recording), encoding="utf-8")
    elif fmt == "srt":
        path = out_dir / f"{base}.srt"
        path.write_text(format_srt(recording.get("segments") or []), encoding="utf-8")
    else:
        raise UnknownExportFormatError(f"unknown export format: {fmt!r}")

    return path


# ---------- formatters ----------

def format_txt(recording: dict) -> str:
    """Plain transcript text. If segments are present we join them with newlines
    for readability; otherwise fall back to the raw transcript string."""
    segments = recording.get("segments") or []
    if segments:
        return "\n".join(
            (s.get("text") or "").strip()
            for s in segments
            if (s.get("text") or "").strip()
        ) + "\n"
    return (recording.get("transcript") or "").rstrip() + "\n"


def format_md(recording: dict) -> str:
    out: list[str] = []
    title = recording.get("title") or f"Recording {recording.get('id', '')}"
    out.append(f"# {title}")
    out.append("")
    meta_parts = []
    if recording.get("created_at"):
        meta_parts.append(f"**Date:** {recording['created_at']}")
    if recording.get("audio_duration_ms"):
        ms = int(recording["audio_duration_ms"])
        meta_parts.append(f"**Duration:** {ms // 60_000}m {(ms // 1000) % 60}s")
    if recording.get("language"):
        meta_parts.append(f"**Language:** {recording['language']}")
    if recording.get("tags"):
        meta_parts.append(f"**Tags:** {', '.join(recording['tags'])}")
    if meta_parts:
        out.append("  \n".join(meta_parts))
        out.append("")

    summary = (recording.get("summary") or "").strip()
    if summary:
        out.append("## Summary")
        out.append("")
        out.append(summary)
        out.append("")

    out.append("## Transcript")
    out.append("")
    for seg in (recording.get("segments") or []):
        text = (seg.get("text") or "").strip()
        if not text:
            continue
        ts = _format_timestamp_mm_ss(seg.get("start_ms", 0))
        out.append(f"[{ts}] {text}")
    return "\n".join(out) + "\n"


def format_json(recording: dict) -> str:
    return json.dumps(recording, indent=2, ensure_ascii=False)


def format_srt(segments: Iterable[dict]) -> str:
    """Emit SRT. Overlapping segments are clipped so the timestamp ranges are
    monotonic — required by most SRT parsers."""
    segs = [
        s for s in segments
        if (s.get("text") or "").strip()
    ]
    out: list[str] = []
    for i, seg in enumerate(segs, start=1):
        start = int(seg.get("start_ms", 0))
        end = int(seg.get("end_ms", start))
        # Clip end so it doesn't overrun the next segment's start.
        if i < len(segs):
            next_start = int(segs[i].get("start_ms", end))
            if end >= next_start:
                end = max(start, next_start - 1)
        out.append(str(i))
        out.append(f"{format_timestamp_srt(start)} --> {format_timestamp_srt(end)}")
        out.append((seg.get("text") or "").strip())
        out.append("")
    return "\n".join(out)


# ---------- helpers ----------

def format_timestamp_srt(ms: int) -> str:
    ms = max(0, int(ms))
    seconds, millis = divmod(ms, 1000)
    minutes, secs = divmod(seconds, 60)
    hours, mins = divmod(minutes, 60)
    return f"{hours:02d}:{mins:02d}:{secs:02d},{millis:03d}"


def _format_timestamp_mm_ss(ms: int) -> str:
    seconds = max(0, int(ms)) // 1000
    minutes, secs = divmod(seconds, 60)
    hours, mins = divmod(minutes, 60)
    return f"{hours:02d}:{mins:02d}:{secs:02d}"
