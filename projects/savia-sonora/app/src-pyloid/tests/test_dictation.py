"""Unit tests for DictationPipeline (services/dictation.py) — the
release-to-paste sequence, testable with fakes instead of mocking seven
services through the hotkey path."""

import tempfile
import wave
from pathlib import Path
from unittest.mock import Mock

import numpy as np
import pytest

from services.database import DatabaseService
from services.dictation import DictationPipeline
from services.settings import Settings


@pytest.fixture
def db():
    with tempfile.TemporaryDirectory() as tmpdir:
        yield DatabaseService(Path(tmpdir) / "test.db")


def make_pipeline(db, *, settings=None, transcript="hello world",
                  model_loaded=True, model_loading=False):
    settings_service = Mock()
    settings_service.get_settings.return_value = settings or Settings()
    transcription = Mock()
    transcription.transcribe.return_value = transcript
    clipboard = Mock()
    audio_service = Mock(CHANNELS=1, SAMPLE_RATE=16000)
    pipeline = DictationPipeline(
        settings_service=settings_service,
        transcription_service=transcription,
        clipboard_service=clipboard,
        db=db,
        audio_service=audio_service,
        is_model_loaded=lambda: model_loaded,
        is_model_loading=lambda: model_loading,
    )
    return pipeline, transcription, clipboard


AUDIO = np.zeros(1600, dtype=np.float32)


class TestRun:
    def test_happy_path_pastes_and_saves_history(self, db):
        pipeline, transcription, clipboard = make_pipeline(db)

        text = pipeline.run(AUDIO)

        assert text == "hello world"
        clipboard.paste_at_cursor.assert_called_once_with("hello world")
        history = db.get_history()
        assert len(history) == 1
        assert history[0]["text"] == "hello world"

    def test_prepend_space_setting(self, db):
        pipeline, _, clipboard = make_pipeline(
            db, settings=Settings(prepend_space=True)
        )

        text = pipeline.run(AUDIO)

        assert text == " hello world"
        clipboard.paste_at_cursor.assert_called_once_with(" hello world")

    def test_empty_transcript_skips_paste_and_history(self, db):
        pipeline, _, clipboard = make_pipeline(db, transcript="")

        assert pipeline.run(AUDIO) == ""
        clipboard.paste_at_cursor.assert_not_called()
        assert db.get_history() == []

    def test_model_absent_skips_transcription(self, db):
        pipeline, transcription, _ = make_pipeline(
            db, model_loaded=False, model_loading=False
        )

        assert pipeline.run(AUDIO) == ""
        transcription.transcribe.assert_not_called()

    def test_model_timeout_returns_empty(self, db):
        pipeline, transcription, _ = make_pipeline(
            db, model_loaded=False, model_loading=True
        )

        # Tiny timeout so the test is fast.
        assert pipeline.wait_for_model(timeout_s=0.02, poll_s=0.01) == "timeout"
        transcription.transcribe.assert_not_called()

    def test_transcription_error_propagates(self, db):
        pipeline, transcription, clipboard = make_pipeline(db)
        transcription.transcribe.side_effect = RuntimeError("boom")

        with pytest.raises(RuntimeError):
            pipeline.run(AUDIO)
        clipboard.paste_at_cursor.assert_not_called()

    def test_save_audio_attachment_writes_wav_and_metadata(self, db):
        pipeline, _, _ = make_pipeline(
            db, settings=Settings(save_audio_to_history=True)
        )

        text = pipeline.run(AUDIO)
        assert text == "hello world"

        entry = db.get_history(include_audio_meta=True)[0]
        assert entry["audio_relpath"] == f"audio/history_{entry['id']}.wav"
        wav_path = db.db_path.parent / entry["audio_relpath"]
        assert wav_path.exists()
        with wave.open(str(wav_path), "rb") as wf:
            assert wf.getframerate() == 16000
            assert wf.getnchannels() == 1
        # 1600 samples @ 16 kHz = 100 ms
        assert entry["audio_duration_ms"] == 100


class TestWaitForModel:
    def test_ready_immediately(self, db):
        pipeline, _, _ = make_pipeline(db, model_loaded=True)
        assert pipeline.wait_for_model() == "ready"

    def test_absent(self, db):
        pipeline, _, _ = make_pipeline(db, model_loaded=False, model_loading=False)
        assert pipeline.wait_for_model() == "absent"
