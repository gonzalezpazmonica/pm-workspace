"""Tests for the MeetingsController background job runners.

Covers `_run_transcribe` / `_run_summarize` plus the public `transcribe()` /
`summarize()` entry points that enqueue them onto the serial job queues
(`_SerialJobQueue` — one daemon worker per lane).

These are pure characterization tests: they lock in CURRENT behavior. No
network, no real whisper models — the TranscriptionService is a fake and the
LLM provider class is patched at the controller module boundary
(`services.recording.controller.OpenAICompatibleProvider`).

Determinism notes:
  * Jobs run on the queue's worker thread. Happy-path tests gate the fake
    work function on a threading.Event released only after the public entry
    point has returned, then wait for the completion event with a bounded
    poll (10 s ceiling, normally <50 ms).
  * Error-path tests call the runner directly (`_run_transcribe(_Job(...))`)
    on the test thread — single-threaded and fully deterministic.

Behavioral quirks pinned here (intentional — test what the code does):
  * `transcribe()` enqueues the job FIRST and only then writes
    transcript_status="pending"; `summarize()` likewise enqueues before
    writing summary_status="summarizing". (Tiny production race: a very fast
    worker could in principle be overwritten by the late status write.)
  * Missing-file error strings differ between DB and event:
    DB transcript_error = "audio missing on disk", event error = "audio missing".
  * Row-with-no-audio_relpath: DB error = "audio not found", event error =
    "audio not found" (these DO match).
  * `_run_summarize` with no transcript: DB summary_error = "no transcript yet",
    event error = "no transcript".
"""

from __future__ import annotations

import tempfile
import threading
import time
import wave
from pathlib import Path

import pytest

from services.database import DatabaseService
from services.recording.controller import MeetingsController, _Job
from services.settings import SettingsService
from services.transcription import CancelToken


# ────────────────────────────────────────────────────────────────── helpers


def _wait_until(predicate, timeout=10.0, interval=0.01):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return True
        time.sleep(interval)
    return False


def _make_wav(path: Path, seconds: float = 0.1, sample_rate: int = 16000) -> None:
    """Tiny valid mono PCM16 WAV written with the stdlib wave module."""
    n_frames = int(seconds * sample_rate)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        w.writeframes(b"\x00\x00" * n_frames)


_FAKE_SEGMENTS = [
    {"start_ms": 0, "end_ms": 1500, "text": "hello there"},
    {"start_ms": 1500, "end_ms": 3000, "text": "general kenobi"},
]
_FAKE_TEXT = "hello there general kenobi"


class _FakeTranscriptionService:
    """Stands in for TranscriptionService. transcribe_file matches the real
    signature in services/transcription.py:
        transcribe_file(audio_path, language="auto", on_progress=None, cancel_token=None)
    Optionally blocks on `gate` so tests control when the job "finishes".
    """

    def __init__(self):
        self.gate: threading.Event | None = None
        self.load_calls: list[tuple[str, str]] = []
        self.transcribe_calls: list[dict] = []
        self._lock = threading.Lock()
        self._active = 0
        self.max_concurrent = 0
        self.sleep_s = 0.0

    def load_model(self, model_name="tiny", device_preference="auto"):
        self.load_calls.append((model_name, device_preference))

    def transcribe_file(self, audio_path, language="auto", on_progress=None, cancel_token=None):
        with self._lock:
            self._active += 1
            self.max_concurrent = max(self.max_concurrent, self._active)
        try:
            if self.gate is not None:
                assert self.gate.wait(timeout=10.0), "test gate never released"
            if self.sleep_s:
                time.sleep(self.sleep_s)
            with self._lock:
                self.transcribe_calls.append({
                    "audio_path": audio_path,
                    "language": language,
                })
            if on_progress is not None:
                on_progress(0.5, "hello there")
            return {"text": _FAKE_TEXT, "segments": list(_FAKE_SEGMENTS), "language": "en"}
        finally:
            with self._lock:
                self._active -= 1


class _FakeProvider:
    """Replaces OpenAICompatibleProvider in the controller module. Records
    constructor kwargs and chat() calls; returns a deterministic summary."""

    RESPONSE = "## TL;DR\nA deterministic fake summary."
    instances: list["_FakeProvider"] = []
    gate: threading.Event | None = None

    def __init__(self, endpoint=None, api_key=None, default_model=None):
        self.endpoint = endpoint
        self.api_key = api_key
        self.default_model = default_model
        self.chat_calls: list[dict] = []
        type(self).instances.append(self)

    def chat(self, messages, model=None, on_stream=None, cancel_token=None):
        if type(self).gate is not None:
            assert type(self).gate.wait(timeout=10.0), "test gate never released"
        self.chat_calls.append({"messages": messages, "model": model})
        if on_stream is not None:
            on_stream(self.RESPONSE)
        return self.RESPONSE


class _Env:
    def __init__(self, ctrl, db, root, fake_ts, events):
        self.ctrl = ctrl
        self.db = db
        self.root = root
        self.fake_ts = fake_ts
        self.events = events

    def events_named(self, name):
        return [payload for (n, payload) in list(self.events) if n == name]

    def seed_recording(self, title="Quarterly planning sync", with_wav=True):
        """Create a recording row. Title is deliberately NOT a default
        timestamp title so _maybe_auto_rename_title short-circuits before it
        ever constructs an LLM provider (no network)."""
        rid = self.db.create_recording(title=title, sources=["mic"])
        rel = f"recordings/{rid}_test.wav"
        if with_wav:
            _make_wav(self.root / rel)
        self.db.set_recording_audio(
            rid, audio_relpath=rel, duration_ms=100, size_bytes=3200,
            sample_rate=16000, channels=1,
        )
        return rid


@pytest.fixture
def env():
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        db = DatabaseService(root / "test.db")
        settings = SettingsService(db)
        fake_ts = _FakeTranscriptionService()
        events: list[tuple[str, dict]] = []
        _FakeProvider.instances = []
        _FakeProvider.gate = None

        ctrl = MeetingsController(
            db=db,
            settings_service=settings,
            transcription_service=fake_ts,
            data_root=root,
            event_emitter=lambda name, payload: events.append((name, payload)),
        )
        try:
            yield _Env(ctrl, db, root, fake_ts, events)
        finally:
            ctrl._transcribe_q.shutdown()
            ctrl._summarize_q.shutdown()


# ────────────────────────────────────────────────────── transcribe happy path


class TestTranscribeHappyPath:
    def test_transcribe_persists_transcript_segments_and_emits_complete(self, env):
        rid = env.seed_recording()

        # Gate the fake so the enqueue→pending-write in transcribe() is done
        # before the worker can finish the job.
        env.fake_ts.gate = threading.Event()
        result = env.ctrl.transcribe(rid)
        assert result == {"ok": True}
        env.fake_ts.gate.set()

        # Exact completion event name used in controller.py is
        # "recording-transcribe-complete" (NOT "meetings.transcribe-complete").
        assert _wait_until(
            lambda: any(
                p.get("recordingId") == rid and p.get("success") is True
                for p in env.events_named("recording-transcribe-complete")
            )
        ), f"no successful complete event; events={env.events}"

        row = env.db.get_recording(rid, include_segments=True)
        assert row["transcript"] == _FAKE_TEXT
        assert row["transcript_status"] == "done"
        assert row["transcript_progress"] == 1.0
        assert row["language"] == "en"
        # transcript_model is whatever model _run_transcribe resolved + loaded.
        assert env.fake_ts.load_calls, "load_model was never called"
        assert row["transcript_model"] == env.fake_ts.load_calls[0][0]

        got_segments = [
            {"start_ms": s["start_ms"], "end_ms": s["end_ms"], "text": s["text"]}
            for s in row["segments"]
        ]
        assert got_segments == _FAKE_SEGMENTS

        # transcribe_file received the on-disk audio path and a language.
        call = env.fake_ts.transcribe_calls[0]
        assert call["audio_path"] == str(env.root / row["audio_relpath"])

        # on_progress is forwarded as a recording-transcribe-progress event.
        progress = env.events_named("recording-transcribe-progress")
        assert any(
            p["recordingId"] == rid and p["progress"] == 0.5
            and p["currentText"] == "hello there"
            for p in progress
        )

        # Auto-summarize is off by default → nothing landed on the summarize
        # lane and summary_status is untouched.
        assert env.events_named("recording-summarize-complete") == []

    def test_title_not_auto_renamed_when_user_titled(self, env):
        # Custom (non-timestamp) title → _maybe_auto_rename_title skips before
        # constructing any LLM provider. Locks in the no-network guarantee the
        # happy-path tests rely on.
        rid = env.seed_recording(title="Roadmap review with design")
        env.ctrl.transcribe(rid)
        assert _wait_until(
            lambda: env.db.get_recording(rid)["transcript_status"] == "done"
        )
        assert env.db.get_recording(rid)["title"] == "Roadmap review with design"


# ─────────────────────────────────────────────────── transcribe error paths


class TestTranscribeErrors:
    def test_missing_audio_file_sets_error_and_emits_failure(self, env):
        # Row exists, audio_relpath set, but no file on disk. Run the job
        # runner directly (single-threaded → deterministic).
        rid = env.seed_recording(with_wav=False)

        env.ctrl._run_transcribe(_Job(recording_id=rid, cancel_token=CancelToken()))

        row = env.db.get_recording(rid)
        assert row["transcript_status"] == "error"
        # Quirk: DB error string and event error string differ.
        assert row["transcript_error"] == "audio missing on disk"
        assert env.events_named("recording-transcribe-complete") == [
            {"recordingId": rid, "success": False, "error": "audio missing"}
        ]
        # Never reached the transcription service.
        assert env.fake_ts.transcribe_calls == []

    def test_recording_without_audio_relpath_errors_audio_not_found(self, env):
        rid = env.db.create_recording(title="No audio yet", sources=["mic"])

        env.ctrl._run_transcribe(_Job(recording_id=rid, cancel_token=CancelToken()))

        row = env.db.get_recording(rid)
        assert row["transcript_status"] == "error"
        assert row["transcript_error"] == "audio not found"
        assert env.events_named("recording-transcribe-complete") == [
            {"recordingId": rid, "success": False, "error": "audio not found"}
        ]


# ──────────────────────────────────────────────────────── summarize happy path


class TestSummarizeHappyPath:
    def test_summarize_persists_summary_and_emits_complete(self, env, monkeypatch):
        rid = env.seed_recording()
        env.db.set_recording_transcript(rid, "we talked about roadmaps", language="en", model="tiny")
        env.db.replace_recording_segments(rid, _FAKE_SEGMENTS)

        # Patch the provider class where controller.py imported it, and the
        # secrets accessors so no keyring/keychain is touched.
        monkeypatch.setattr(
            "services.recording.controller.OpenAICompatibleProvider", _FakeProvider
        )
        monkeypatch.setattr(
            "services.recording.controller.get_api_key", lambda preset: "fake-key"
        )
        monkeypatch.setattr(
            "services.recording.controller.has_api_key", lambda preset: True
        )

        _FakeProvider.gate = threading.Event()
        result = env.ctrl.summarize(rid, prompt=None)
        assert result == {"ok": True}
        _FakeProvider.gate.set()

        assert _wait_until(
            lambda: any(
                p.get("recordingId") == rid and p.get("success") is True
                for p in env.events_named("recording-summarize-complete")
            )
        ), f"no successful summarize-complete event; events={env.events}"

        row = env.db.get_recording(rid)
        assert row["summary"] == _FakeProvider.RESPONSE
        assert row["summary_status"] == "done"
        assert row["summary_progress"] == 1.0
        # Provider label is "<preset>:<model>" from the LLM config.
        cfg = env.ctrl.get_llm_config()
        assert row["summary_provider"] == f"{cfg['preset']}:{cfg['model']}"

        # Provider was constructed from the LLM config + secret store.
        provider = _FakeProvider.instances[0]
        assert provider.endpoint == cfg["endpoint"]
        assert provider.api_key == "fake-key"
        assert provider.default_model == cfg["model"]
        # Transcript was interpolated into the prompt sent to the LLM.
        sent = provider.chat_calls[0]["messages"][-1]["content"]
        assert "we talked about roadmaps" in sent

        # Streaming tokens surface as recording-summarize-progress events.
        progress = env.events_named("recording-summarize-progress")
        assert any(
            p["recordingId"] == rid and p["partialText"] == _FakeProvider.RESPONSE
            for p in progress
        )


# ───────────────────────────────────────────────────── summarize error paths


class TestSummarizeNoTranscript:
    def test_no_transcript_sets_error_status_and_emits_failure(self, env):
        # No transcript on the row → _run_summarize bails before constructing
        # a provider (no patching needed; nothing external is touched).
        rid = env.seed_recording()

        env.ctrl._run_summarize(_Job(recording_id=rid, cancel_token=CancelToken()))

        row = env.db.get_recording(rid)
        assert row["summary_status"] == "error"
        # Quirk: DB says "no transcript yet", event says "no transcript".
        assert row["summary_error"] == "no transcript yet"
        assert row["summary"] is None
        assert env.events_named("recording-summarize-complete") == [
            {"recordingId": rid, "success": False, "error": "no transcript"}
        ]


# ───────────────────────────────────────────────────────── queue serialization


class TestSerialJobQueue:
    def test_two_transcribe_jobs_run_serially_and_both_complete(self, env):
        rid1 = env.seed_recording(title="First standup")
        rid2 = env.seed_recording(title="Second standup")

        # Small sleep inside the fake so an (incorrectly) parallel queue would
        # show max_concurrent > 1.
        env.fake_ts.sleep_s = 0.05

        env.ctrl.transcribe(rid1)
        env.ctrl.transcribe(rid2)

        assert _wait_until(
            lambda: len([
                p for p in env.events_named("recording-transcribe-complete")
                if p.get("success") is True
            ]) == 2
        ), f"both jobs did not complete; events={env.events}"

        assert env.db.get_recording(rid1)["transcript_status"] == "done"
        assert env.db.get_recording(rid2)["transcript_status"] == "done"
        # _SerialJobQueue runs one worker thread → never more than one job
        # in flight, and jobs finish in enqueue order.
        assert env.fake_ts.max_concurrent == 1
        completed = [
            p["recordingId"]
            for p in env.events_named("recording-transcribe-complete")
            if p["success"]
        ]
        assert completed == [rid1, rid2]
