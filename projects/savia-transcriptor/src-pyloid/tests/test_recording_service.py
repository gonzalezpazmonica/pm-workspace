"""Tests for the long-form RecordingService (slice 3).

Uses the FakeAudioSource + FakeClock test seams from
`services.recording.audio_source` and `services.recording.clock` so no real
microphone or wall-clock is required.

Contract surfaces verified:
  * Lifecycle: idle → recording → paused → recording → idle
  * Channel layout (ADR-0001): mono with 1 source, stereo with 2 (mic on L, loopback on R)
  * Pause writes silence so audio-clock == wall-clock (Q3)
  * Errors: starting twice, starting with no sources, pausing when idle
  * RecordingResult has correct duration/size/sample_rate/channels/sources
"""

from __future__ import annotations

import numpy as np
import pytest
import soundfile as sf

from services.recording.audio_source import FakeAudioSource
from services.recording.clock import FakeClock
from services.recording.recorder import (
    RecordingService,
    RecorderAlreadyStartedError,
    RecorderNotRunningError,
    NoAudioSourcesError,
)


# ---------- helpers ----------

def _ones(n: int, value: float = 0.5) -> np.ndarray:
    return np.full((n,), value, dtype=np.float32)


def _make_recorder() -> tuple[RecordingService, FakeClock]:
    clock = FakeClock()
    return RecordingService(clock=clock), clock


def _read(path) -> tuple[np.ndarray, int]:
    data, sr = sf.read(str(path), dtype="float32", always_2d=True)
    return data, sr


# ---------- lifecycle / errors ----------

class TestLifecycle:
    def test_recorder_starts_in_idle(self):
        rec, _ = _make_recorder()
        assert rec.get_state()["state"] == "idle"

    def test_start_with_no_sources_raises(self, tmp_path):
        rec, _ = _make_recorder()
        with pytest.raises(NoAudioSourcesError):
            rec.start(recording_id=1, file_path=tmp_path / "x.wav", mic=None, loopback=None)

    def test_start_twice_raises(self, tmp_path):
        rec, _ = _make_recorder()
        mic = FakeAudioSource()
        rec.start(recording_id=1, file_path=tmp_path / "a.wav", mic=mic)
        try:
            with pytest.raises(RecorderAlreadyStartedError):
                rec.start(recording_id=2, file_path=tmp_path / "b.wav", mic=FakeAudioSource())
        finally:
            rec.stop()

    def test_pause_when_idle_raises(self):
        rec, _ = _make_recorder()
        with pytest.raises(RecorderNotRunningError):
            rec.pause()

    def test_stop_when_idle_raises(self):
        rec, _ = _make_recorder()
        with pytest.raises(RecorderNotRunningError):
            rec.stop()

    def test_state_transitions(self, tmp_path):
        rec, _ = _make_recorder()
        mic = FakeAudioSource()
        rec.start(recording_id=1, file_path=tmp_path / "x.wav", mic=mic)
        assert rec.get_state()["state"] == "recording"
        rec.pause()
        assert rec.get_state()["state"] == "paused"
        rec.resume()
        assert rec.get_state()["state"] == "recording"
        rec.stop()
        assert rec.get_state()["state"] == "idle"


# ---------- mono ----------

class TestMonoRecording:
    def test_one_source_writes_mono_wav(self, tmp_path):
        rec, clock = _make_recorder()
        mic = FakeAudioSource()
        path = tmp_path / "mono.wav"
        rec.start(recording_id=1, file_path=path, mic=mic)
        mic.push(_ones(16000))  # 1 second
        clock.advance(1.0)
        rec.wait_for_flush()
        rec.stop()

        data, sr = _read(path)
        assert sr == 16000
        assert data.shape[1] == 1  # mono
        assert data.shape[0] == 16000
        assert np.allclose(data[:, 0], 0.5, atol=1e-3)

    def test_mono_result_metadata(self, tmp_path):
        rec, clock = _make_recorder()
        mic = FakeAudioSource()
        rec.start(recording_id=1, file_path=tmp_path / "m.wav", mic=mic)
        mic.push(_ones(8000))
        clock.advance(0.5)
        rec.wait_for_flush()
        result = rec.stop()

        assert result["sources"] == ["mic"]
        assert result["channels"] == 1
        assert result["sample_rate"] == 16000
        assert result["duration_ms"] == 500
        assert result["size_bytes"] > 0

    def test_loopback_only_writes_mono_wav(self, tmp_path):
        rec, clock = _make_recorder()
        loop = FakeAudioSource()
        rec.start(recording_id=1, file_path=tmp_path / "lo.wav", loopback=loop)
        loop.push(_ones(16000, value=0.25))
        clock.advance(1.0)
        rec.wait_for_flush()
        result = rec.stop()

        assert result["sources"] == ["loopback"]
        assert result["channels"] == 1
        data, _ = _read(tmp_path / "lo.wav")
        assert np.allclose(data[:, 0], 0.25, atol=1e-3)


# ---------- stereo (ADR-0001) ----------

class TestStereoRecording:
    def test_two_sources_writes_stereo_wav(self, tmp_path):
        rec, clock = _make_recorder()
        mic, loop = FakeAudioSource(), FakeAudioSource()
        rec.start(recording_id=1, file_path=tmp_path / "st.wav", mic=mic, loopback=loop)
        mic.push(_ones(16000, value=0.3))
        loop.push(_ones(16000, value=0.6))
        clock.advance(1.0)
        rec.wait_for_flush()
        result = rec.stop()

        assert result["sources"] == ["mic", "loopback"]
        assert result["channels"] == 2
        data, _ = _read(tmp_path / "st.wav")
        assert data.shape[1] == 2

    def test_stereo_mic_on_left_loopback_on_right(self, tmp_path):
        """ADR-0001: mic must end up on L (channel 0), loopback on R (channel 1)."""
        rec, clock = _make_recorder()
        mic, loop = FakeAudioSource(), FakeAudioSource()
        rec.start(recording_id=1, file_path=tmp_path / "lr.wav", mic=mic, loopback=loop)
        mic.push(_ones(16000, value=0.1))   # distinctly low on L
        loop.push(_ones(16000, value=0.9))  # distinctly high on R
        clock.advance(1.0)
        rec.wait_for_flush()
        rec.stop()

        data, _ = _read(tmp_path / "lr.wav")
        # Read may be slightly fewer samples if the writer truncated to min — check what's there.
        assert np.allclose(data[:, 0], 0.1, atol=1e-2)
        assert np.allclose(data[:, 1], 0.9, atol=1e-2)


# ---------- pause = silence (Q3) ----------

class TestStereoStopWithUnevenQueues:
    """Regression for the field-bug where stop() timed out because the two
    sources rarely shut down on the same frame boundary — leftover frames
    in one queue blocked the writer's stereo pairing loop forever."""

    def test_stop_drains_uneven_queues_without_timeout(self, tmp_path):
        rec, _ = _make_recorder()
        mic, loop = FakeAudioSource(), FakeAudioSource()
        rec.start(recording_id=1, file_path=tmp_path / "uneven.wav", mic=mic, loopback=loop)
        # Mic delivers more than loopback — what happens in real life when one
        # subprocess (parec) shuts down a few frames before the other.
        mic.push(_ones(16000, value=0.4))
        loop.push(_ones(8000, value=0.7))
        # Do NOT call wait_for_flush here — pairing requires both sides during
        # 'recording' state. stop() does the right thing: flips to 'stopping'
        # then drains.
        result = rec.stop()
        assert result["channels"] == 2
        data, _ = _read(tmp_path / "uneven.wav")
        assert data.shape[1] == 2
        # First 8000 frames: paired (both channels non-zero).
        assert np.allclose(data[:8000, 0], 0.4, atol=1e-2)
        assert np.allclose(data[:8000, 1], 0.7, atol=1e-2)
        # Frames 8000..16000: mic-only on L, silence on R.
        assert data.shape[0] == 16000
        assert np.allclose(data[8000:, 0], 0.4, atol=1e-2)
        assert np.allclose(data[8000:, 1], 0.0, atol=1e-3)


class TestStarvationRecovery:
    """Regression for the 'stuck at 0:59' field-bug: in stereo mode, if one
    source stalls mid-recording (parec died, source went suspended, network
    audio dropped...) the writer must not freeze waiting forever. After
    _STEREO_STARVATION_S of no frames on one side, it drains the live side
    as mono on its channel and keeps the duration counter moving."""

    def test_loopback_dies_mid_recording_does_not_freeze(self, tmp_path):
        rec, clock = _make_recorder()
        mic, loop = FakeAudioSource(), FakeAudioSource()
        rec.start(recording_id=1, file_path=tmp_path / "starved.wav", mic=mic, loopback=loop)

        # Phase A: both sources deliver normally for half a second.
        mic.push(_ones(8000, value=0.4))
        loop.push(_ones(8000, value=0.6))
        clock.advance(0.05)
        rec.wait_for_flush()

        # Phase B: loopback dies. Mic keeps delivering. The writer must drain
        # the mic side after the starvation threshold elapses.
        mic.push(_ones(16000, value=0.4))
        clock.advance(0.2)  # > _STEREO_STARVATION_S (0.15)
        rec.wait_for_flush()  # would have timed out without the starvation fix
        result = rec.stop()

        assert result["channels"] == 2
        data, _ = _read(tmp_path / "starved.wav")
        # First 8000 frames had both channels.
        assert np.allclose(data[:8000, 0], 0.4, atol=1e-2)
        assert np.allclose(data[:8000, 1], 0.6, atol=1e-2)
        # Next 16000 frames: mic-only on L, silence on R.
        assert data.shape[0] >= 24000
        assert np.allclose(data[8000:24000, 0], 0.4, atol=1e-2)
        assert np.allclose(data[8000:24000, 1], 0.0, atol=1e-3)


class TestPeakDb:
    def test_peak_db_reported_in_state(self, tmp_path):
        rec, clock = _make_recorder()
        mic = FakeAudioSource()
        rec.start(recording_id=1, file_path=tmp_path / "p.wav", mic=mic)
        # Pre-push state — peak hasn't been observed yet, so reports None.
        assert rec.get_state()["mic_peak_db"] is None
        # Push frames at 0.5 amplitude → ~-6 dB.
        mic.push(_ones(1024, value=0.5))
        clock.advance(1.0)
        rec.wait_for_flush()
        st = rec.get_state()
        assert st["mic_peak_db"] is not None
        assert -7.0 < st["mic_peak_db"] < -5.0
        rec.stop()

    def test_silence_clamps_to_floor(self, tmp_path):
        rec, _ = _make_recorder()
        mic = FakeAudioSource()
        rec.start(recording_id=1, file_path=tmp_path / "s.wav", mic=mic)
        mic.push(np.zeros(1024, dtype=np.float32))
        rec.wait_for_flush()
        st = rec.get_state()
        # -60 dB floor (configurable in recorder.py).
        assert st["mic_peak_db"] == -60.0
        rec.stop()


class TestPauseWritesSilence:
    def test_pause_then_resume_preserves_wallclock_duration(self, tmp_path):
        """1s audio + 2s pause + 1s audio → 4s file, middle 2s = zeros."""
        rec, clock = _make_recorder()
        mic = FakeAudioSource()
        rec.start(recording_id=1, file_path=tmp_path / "p.wav", mic=mic)
        # Pre-pause: 1s of audio at value=0.4
        mic.push(_ones(16000, value=0.4))
        clock.advance(1.0)
        rec.wait_for_flush()

        rec.pause()
        clock.advance(2.0)  # 2 wall-clock seconds elapse
        rec.resume()

        # Post-resume: 1s of audio at value=0.7
        mic.push(_ones(16000, value=0.7))
        clock.advance(1.0)
        rec.wait_for_flush()
        result = rec.stop()

        assert result["duration_ms"] == 4000
        data, _ = _read(tmp_path / "p.wav")
        assert data.shape[0] == 4 * 16000

        # First second non-zero
        assert np.allclose(data[:16000, 0], 0.4, atol=1e-2)
        # Middle two seconds silent
        assert np.allclose(data[16000:48000, 0], 0.0, atol=1e-3)
        # Last second non-zero
        assert np.allclose(data[48000:64000, 0], 0.7, atol=1e-2)
