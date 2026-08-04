"""Meeting store for Savia Transcriptor (SE-308 S4).

Manages meeting session folders under `reuniones/YYYY-MM-DD-HH-MM/`. Each
session starts with a `meta.json`; audio, transcripts and captures are added
as the session progresses / post-processes.

`list_undigested()` is the hook Savia uses to detect new content: a meeting
whose `meta.json` has no `digested: true` is new and ready for a digest.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


class MeetingStore:
    def __init__(self, root: Path) -> None:
        self.root = Path(root)

    def new_session(self) -> Path:
        """Create a timestamped session folder with a meta.json."""
        self.root.mkdir(parents=True, exist_ok=True)
        ts = datetime.now(timezone.utc).strftime('%Y-%m-%d-%H-%M')
        folder = self.root / ts
        suffix = 2
        while folder.exists():
            folder = self.root / f"{ts}-{suffix}"
            suffix += 1
        folder.mkdir(parents=True, exist_ok=False)
        meta = {
            "started_at": datetime.now(timezone.utc).isoformat(),
            "transcribed": False,
            "digested": False,
            "capture_interval_s": 15,
            "captures": 0,
        }
        (folder / "meta.json").write_text(
            json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8"
        )
        return folder

    def list_sessions(self) -> list[Path]:
        if not self.root.exists():
            return []
        return sorted(
            [p for p in self.root.iterdir() if p.is_dir()],
            key=lambda p: p.name,
            reverse=True,
        )

    def list_undigested(self) -> list[Path]:
        return [s for s in self.list_sessions() if not self._is_digested(s)]

    def mark_digested(self, session: Path) -> None:
        meta = self._load_meta(session)
        meta["digested"] = True
        self._save_meta(session, meta)

    def mark_transcribed(self, session: Path) -> None:
        meta = self._load_meta(session)
        meta["transcribed"] = True
        self._save_meta(session, meta)

    def _is_digested(self, session: Path) -> bool:
        return bool(self._load_meta(session).get("digested", False))

    def _load_meta(self, session: Path) -> dict:
        meta_path = session / "meta.json"
        if meta_path.exists():
            try:
                return json.loads(meta_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                pass
        return {}

    def _save_meta(self, session: Path, meta: dict) -> None:
        (session / "meta.json").write_text(
            json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8"
        )
