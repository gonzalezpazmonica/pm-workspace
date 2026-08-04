"""Meeting post-processor for Savia Transcriptor (SE-308 S4).

After a recording session finishes, this transcribes the audio (via an
injected transcription service) and writes:
- transcript.vtt — subtitle-style transcript with segment timestamps
- transcript.md  — plain markdown transcript
- meta.json      — updated with transcription metadata

Decoupled from the upstream TranscriptionService via the injected
`transcriber` duck type (`.transcribe_file(path, language, ...) -> dict`).
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Optional


def _fmt_vtt_timestamp(ms: float) -> str:
    ms = max(0, int(ms))
    h, rem = divmod(ms, 3_600_000)
    m, rem = divmod(rem, 60_000)
    s, ms = divmod(rem, 1000)
    return f"{h:02d}:{m:02d}:{s:02d}.{ms:03d}"


class MeetingPostProcessor:
    def __init__(self, transcriber, language: str = "auto") -> None:
        self._transcriber = transcriber
        self._language = language

    def process(self, meeting_dir: Path) -> Optional[dict]:
        """Transcribe the meeting audio and write transcript files."""
        meeting_dir = Path(meeting_dir)
        audio = meeting_dir / "audio.wav"
        if not audio.exists():
            return None

        result = self._transcriber.transcribe_file(str(audio), language=self._language)
        text = result.get("text", "")
        segments = result.get("segments", [])
        lang = result.get("language", "auto")

        vtt = self._write_vtt(meeting_dir, segments)
        md = self._write_markdown(meeting_dir, text, segments)

        meta = self._load_meta(meeting_dir)
        meta["transcribed"] = True
        meta["language"] = lang
        meta["transcript_files"] = ["transcript.vtt", "transcript.md"]
        self._save_meta(meeting_dir, meta)

        return {"text": text, "language": lang, "vtt": vtt, "md": md}

    def _write_vtt(self, meeting_dir: Path, segments: list[dict]) -> Path:
        lines = ["WEBVTT", ""]
        for i, seg in enumerate(segments, 1):
            start = _fmt_vtt_timestamp(seg.get("start_ms", 0))
            end = _fmt_vtt_timestamp(seg.get("end_ms", 0))
            lines.append(f"{start} --> {end}")
            lines.append(seg.get("text", "").strip())
            lines.append("")
        vtt = meeting_dir / "transcript.vtt"
        vtt.write_text("\n".join(lines), encoding="utf-8")
        return vtt

    def _write_markdown(self, meeting_dir: Path, text: str, segments: list[dict]) -> Path:
        lines = ["# Transcripcion de reunion", ""]
        if segments:
            for seg in segments:
                t = _fmt_vtt_timestamp(seg.get("start_ms", 0))
                lines.append(f"[{t}] {seg.get('text', '').strip()}")
        else:
            lines.append(text.strip())
        md = meeting_dir / "transcript.md"
        md.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return md

    def _load_meta(self, meeting_dir: Path) -> dict:
        meta_path = meeting_dir / "meta.json"
        if meta_path.exists():
            try:
                return json.loads(meta_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                pass
        return {}

    def _save_meta(self, meeting_dir: Path, meta: dict) -> None:
        (meeting_dir / "meta.json").write_text(
            json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8"
        )
