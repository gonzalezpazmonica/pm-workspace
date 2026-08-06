"""RecordingsRepository — persistence for the Recording entity.

Canonical home of Recording persistence per CONTEXT.md ("Recording" entity):
a Recording is the row in the `recordings` table, with its transcript
segments in `recording_segments`. All reads/writes to those tables go
through this repository.

Schema creation/migration for the recordings tables stays in
`DatabaseService._ensure_recordings_tables` — DatabaseService owns the schema
lifecycle for every table in the DB file. This class only does row-level
persistence, borrowing the DatabaseService connection helper so connection
policy (timeouts, PRAGMAs) stays in one place.
"""

from __future__ import annotations

import json
import sqlite3
from datetime import datetime
from typing import TYPE_CHECKING, Optional

if TYPE_CHECKING:
    from services.database import DatabaseService


_RECORDING_UPDATABLE_FIELDS = frozenset({"title", "summary", "notes", "tags", "language"})


class RecordingsRepository:
    """Row-level persistence for `recordings` / `recording_segments`.

    Constructed by DatabaseService in its __init__ and exposed as
    `db.recordings`; DatabaseService keeps thin delegating methods for
    backward compatibility with existing callers.
    """

    def __init__(self, db: "DatabaseService") -> None:
        self._db = db

    def _get_connection(self) -> sqlite3.Connection:
        return self._db._get_connection()

    def create_recording(self, title: str, sources: list[str]) -> int:
        now = datetime.now().isoformat()
        conn = self._get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(
                """INSERT INTO recordings (title, sources, created_at, updated_at)
                   VALUES (?, ?, ?, ?)""",
                (title, json.dumps(sources), now, now),
            )
            rid = cursor.lastrowid
            conn.commit()
            return rid
        finally:
            conn.close()

    def get_recording(self, recording_id: int, include_segments: bool = False) -> Optional[dict]:
        conn = self._get_connection()
        try:
            row = conn.execute(
                "SELECT * FROM recordings WHERE id = ?", (recording_id,)
            ).fetchone()
            if row is None:
                return None
            rec = self._row_to_recording(row)
            if include_segments:
                seg_rows = conn.execute(
                    """SELECT id, recording_id, start_ms, end_ms, text
                       FROM recording_segments
                       WHERE recording_id = ?
                       ORDER BY start_ms ASC, id ASC""",
                    (recording_id,),
                ).fetchall()
                rec["segments"] = [dict(r) for r in seg_rows]
            return rec
        finally:
            conn.close()

    def list_recordings(
        self,
        limit: int = 100,
        offset: int = 0,
        search: Optional[str] = None,
    ) -> list[dict]:
        conn = self._get_connection()
        try:
            query = "SELECT * FROM recordings"
            params: list = []
            if search:
                query += " WHERE title LIKE ?"
                params.append(f"%{search}%")
            query += " ORDER BY created_at DESC, id DESC LIMIT ? OFFSET ?"
            params.extend([limit, offset])
            rows = conn.execute(query, params).fetchall()
            return [self._row_to_recording(r) for r in rows]
        finally:
            conn.close()

    def update_recording(self, recording_id: int, **fields) -> None:
        unknown = set(fields) - _RECORDING_UPDATABLE_FIELDS
        if unknown:
            raise ValueError(f"unknown recording fields: {sorted(unknown)}")
        if not fields:
            return
        sets, params = [], []
        for name, value in fields.items():
            if name == "tags":
                value = json.dumps(value or [])
            sets.append(f"{name} = ?")
            params.append(value)
        sets.append("updated_at = ?")
        params.append(datetime.now().isoformat())
        params.append(recording_id)

        conn = self._get_connection()
        try:
            conn.execute(
                f"UPDATE recordings SET {', '.join(sets)} WHERE id = ?", params
            )
            conn.commit()
        finally:
            conn.close()

    def set_recording_audio(
        self,
        recording_id: int,
        audio_relpath: str,
        duration_ms: Optional[int],
        size_bytes: Optional[int],
        sample_rate: Optional[int],
        channels: Optional[int],
    ) -> None:
        conn = self._get_connection()
        try:
            conn.execute(
                """UPDATE recordings
                   SET audio_relpath = ?, audio_duration_ms = ?, audio_size_bytes = ?,
                       audio_sample_rate = ?, audio_channels = ?, updated_at = ?
                   WHERE id = ?""",
                (
                    audio_relpath, duration_ms, size_bytes,
                    sample_rate, channels, datetime.now().isoformat(),
                    recording_id,
                ),
            )
            conn.commit()
        finally:
            conn.close()

    def set_recording_recorder_state(self, recording_id: int, state: Optional[str]) -> None:
        conn = self._get_connection()
        try:
            conn.execute(
                "UPDATE recordings SET recorder_state = ?, updated_at = ? WHERE id = ?",
                (state, datetime.now().isoformat(), recording_id),
            )
            conn.commit()
        finally:
            conn.close()

    def update_transcript_status(
        self,
        recording_id: int,
        status: str,
        progress: Optional[float] = None,
        error: Optional[str] = None,
    ) -> None:
        sets = ["transcript_status = ?", "updated_at = ?"]
        params: list = [status, datetime.now().isoformat()]
        if progress is not None:
            sets.insert(1, "transcript_progress = ?")
            params.insert(1, progress)
        if error is not None:
            sets.insert(-1, "transcript_error = ?")
            params.insert(-1, error)
        params.append(recording_id)
        conn = self._get_connection()
        try:
            conn.execute(
                f"UPDATE recordings SET {', '.join(sets)} WHERE id = ?", params
            )
            conn.commit()
        finally:
            conn.close()

    def update_summary_status(
        self,
        recording_id: int,
        status: str,
        progress: Optional[float] = None,
        error: Optional[str] = None,
        provider: Optional[str] = None,
    ) -> None:
        sets = ["summary_status = ?", "updated_at = ?"]
        params: list = [status, datetime.now().isoformat()]
        if progress is not None:
            sets.insert(1, "summary_progress = ?")
            params.insert(1, progress)
        if error is not None:
            sets.insert(-1, "summary_error = ?")
            params.insert(-1, error)
        if provider is not None:
            sets.insert(-1, "summary_provider = ?")
            params.insert(-1, provider)
        params.append(recording_id)
        conn = self._get_connection()
        try:
            conn.execute(
                f"UPDATE recordings SET {', '.join(sets)} WHERE id = ?", params
            )
            conn.commit()
        finally:
            conn.close()

    def set_recording_transcript(
        self,
        recording_id: int,
        transcript: str,
        language: Optional[str] = None,
        model: Optional[str] = None,
    ) -> None:
        """Persist the final transcript text. Segments go via replace_recording_segments.

        `model` is the whisper model name that produced the transcript (e.g.
        'tiny', 'large-v3'). Optional and backward-compatible — existing callers
        that don't pass it leave the column NULL or unchanged on re-transcribe.
        """
        conn = self._get_connection()
        try:
            conn.execute(
                """UPDATE recordings
                   SET transcript = ?,
                       language = COALESCE(?, language),
                       transcript_model = COALESCE(?, transcript_model),
                       updated_at = ?
                   WHERE id = ?""",
                (transcript, language, model, datetime.now().isoformat(), recording_id),
            )
            conn.commit()
        finally:
            conn.close()

    def replace_recording_segments(self, recording_id: int, segments: list[dict]) -> None:
        conn = self._get_connection()
        try:
            conn.execute(
                "DELETE FROM recording_segments WHERE recording_id = ?", (recording_id,)
            )
            if segments:
                conn.executemany(
                    """INSERT INTO recording_segments (recording_id, start_ms, end_ms, text)
                       VALUES (?, ?, ?, ?)""",
                    [
                        (recording_id, int(s["start_ms"]), int(s["end_ms"]), str(s["text"]))
                        for s in segments
                    ],
                )
            conn.commit()
        finally:
            conn.close()

    def delete_recording(self, recording_id: int) -> None:
        # Capture the audio path so the caller can delete the file off disk.
        rec = self.get_recording(recording_id)
        if rec and rec.get("audio_relpath"):
            self._db._delete_audio_file(rec["audio_relpath"])
        conn = self._get_connection()
        try:
            conn.execute("DELETE FROM recordings WHERE id = ?", (recording_id,))
            conn.commit()
        finally:
            conn.close()

    def list_unfinished_recordings(self) -> list[dict]:
        """Recordings that were left mid-flight (used by crash-recovery on startup)."""
        conn = self._get_connection()
        try:
            rows = conn.execute(
                "SELECT * FROM recordings WHERE recorder_state IS NOT NULL "
                "ORDER BY created_at ASC"
            ).fetchall()
            return [self._row_to_recording(r) for r in rows]
        finally:
            conn.close()

    @staticmethod
    def _row_to_recording(row: sqlite3.Row) -> dict:
        rec = dict(row)
        rec["sources"] = json.loads(rec.get("sources") or "[]")
        rec["tags"] = json.loads(rec.get("tags") or "[]")
        return rec
