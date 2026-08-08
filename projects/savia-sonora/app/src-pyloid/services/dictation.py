"""DictationPipeline — the release-to-paste sequence for one push-to-talk
dictation (the History entity in CONTEXT.md terms).

Owns everything that happens after the hotkey is released and audio is in
hand: wait for the whisper model, transcribe, paste at the cursor, persist to
history (optionally with the audio attachment). UI callbacks stay in
AppController — `run()` returns the pasted text ("" when nothing usable) and
raises on transcription errors, so the caller decides how to surface both.

Extracted from AppController so this sequence is testable with fakes instead
of mocking seven services through the hotkey path.
"""

import time
import wave
from pathlib import Path
from typing import TypedDict

import numpy as np

from services.logger import info, warning, error


class AudioAttachmentMeta(TypedDict):
    audio_relpath: str
    audio_duration_ms: int
    audio_size_bytes: int
    audio_mime: str


class DictationPipeline:
    def __init__(
        self,
        *,
        settings_service,
        transcription_service,
        clipboard_service,
        db,
        audio_service,
        is_model_loaded,
        is_model_loading,
    ):
        self.settings_service = settings_service
        self.transcription_service = transcription_service
        self.clipboard_service = clipboard_service
        self.db = db
        self.audio_service = audio_service
        self._is_model_loaded = is_model_loaded
        self._is_model_loading = is_model_loading

    def wait_for_model(self, timeout_s: float = 30, poll_s: float = 1.0) -> str:
        """Block until the whisper model is usable.

        Returns "ready", "absent" (not loaded and no load in flight), or
        "timeout"."""
        waited = 0.0
        while not self._is_model_loaded() and waited < timeout_s:
            if not self._is_model_loading():
                return "absent"
            info(f"Waiting for model to load... ({waited:g}s)")
            time.sleep(poll_s)
            waited += poll_s
        return "ready" if self._is_model_loaded() else "timeout"

    def run(self, audio: np.ndarray) -> str:
        """Transcribe `audio`, paste the text at the cursor, save history.

        Blocking — callers run it on a worker thread. Returns the pasted text,
        or "" when nothing usable came out (model unavailable / empty
        transcript). Raises on transcription/paste errors."""
        readiness = self.wait_for_model()
        if readiness == "absent":
            warning("Model not loaded and not loading, skipping transcription")
            return ""
        if readiness == "timeout":
            error("Model load timeout, skipping transcription")
            return ""

        settings = self.settings_service.get_settings()
        info(f"Transcribing with language: {settings.language}")

        text = self.transcription_service.transcribe(
            audio,
            language=settings.language,
        )
        info(f"Transcription result: '{text}'")

        if not text:
            warning("No text transcribed (empty result)")
            return ""

        # Prepend space if enabled (useful for continuous dictation)
        if settings.prepend_space:
            text = " " + text

        info("Pasting text at cursor...")
        self.clipboard_service.paste_at_cursor(text)

        history_id = self.db.add_history(text)

        if settings.save_audio_to_history:
            import sqlite3
            try:
                audio_meta = self.save_audio_attachment(history_id, audio)
                self.db.update_history_audio(
                    history_id,
                    audio_relpath=audio_meta["audio_relpath"],
                    audio_duration_ms=audio_meta["audio_duration_ms"],
                    audio_size_bytes=audio_meta["audio_size_bytes"],
                    audio_mime=audio_meta["audio_mime"],
                )
                info(f"Saved audio attachment for history {history_id}")
            except (OSError, wave.Error, sqlite3.Error, ValueError) as exc:
                warning(f"Failed to save audio attachment: {exc}")

        return text

    def save_audio_attachment(self, history_id: int, audio: np.ndarray) -> AudioAttachmentMeta:
        """Persist recorded audio as WAV and return metadata for DB update."""
        # Ensure audio directory exists
        audio_dir = self.db.db_path.parent / "audio"
        audio_dir.mkdir(parents=True, exist_ok=True)

        relpath = Path("audio") / f"history_{history_id}.wav"
        output_path = self.db.db_path.parent / relpath
        tmp_path = output_path.with_suffix(".wav.tmp")

        # Normalize audio into flat int16 PCM
        audio_array = np.asarray(audio)
        if audio_array.ndim > 1:
            audio_array = audio_array.reshape(-1)

        if np.issubdtype(audio_array.dtype, np.floating):
            audio_clipped = np.clip(audio_array, -1.0, 1.0)
            audio_int16 = (audio_clipped * 32767).astype(np.int16)
        elif audio_array.dtype == np.int16:
            audio_int16 = audio_array
        else:
            # Fallback: clip to int16 range
            audio_clipped = np.clip(audio_array, -32768, 32767)
            audio_int16 = audio_clipped.astype(np.int16)

        with wave.open(str(tmp_path), "wb") as wf:
            wf.setnchannels(self.audio_service.CHANNELS)
            wf.setsampwidth(2)  # 16-bit PCM
            wf.setframerate(self.audio_service.SAMPLE_RATE)
            wf.writeframes(audio_int16.tobytes())

        tmp_path.replace(output_path)

        duration_ms = int((len(audio_int16) / float(self.audio_service.SAMPLE_RATE)) * 1000)
        size_bytes = output_path.stat().st_size

        return {
            "audio_relpath": relpath.as_posix(),
            "audio_duration_ms": duration_ms,
            "audio_size_bytes": size_bytes,
            "audio_mime": "audio/wav",
        }
