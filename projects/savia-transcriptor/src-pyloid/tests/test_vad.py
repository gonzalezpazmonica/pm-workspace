"""Tests for the VAD auto-trigger supervisor (SE-308 S2).

The supervisor listens to audio frames, detects continuous speech (start)
and continuous silence (stop) using a VAD backend, and exposes state
transitions for the RecordingController to act on.

VAD backend is injected — tests use a deterministic fake; production uses
silero-vad.
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from services.recording.vad import VadSupervisor, VadResult


class FakeVadBackend:
    """Deterministic VAD: returns speech probability per call via a queue."""

    def __init__(self, probabilities):
        self._probs = list(probabilities)
        self.calls = 0

    def speech_probability(self, frames) -> float:
        self.calls += 1
        if self._probs:
            return self._probs.pop(0)
        return 0.0


def make_supervisor(speech_ms=3000, silence_ms=60000, **kw):
    return VadSupervisor(
        vad=FakeVadBackend([]),
        sample_rate=16000,
        speech_ms=speech_ms,
        silence_ms=silence_ms,
        **kw,
    )


def frames(duration_s, rate=16000):
    """A float32 mono block of `duration_s` seconds (numpy-free placeholder)."""
    return object()


class TestInitialState:
    def test_starts_idle(self):
        sup = make_supervisor()
        assert sup.state == "IDLE"

    def test_idle_reports_no_action(self):
        sup = make_supervisor()
        result = sup.feed(frames(0.03))
        assert result.state == "IDLE"


class TestSpeechStart:
    def test_short_speech_does_not_start(self):
        """Voz < speech_ms no arranca."""
        sup = make_supervisor(speech_ms=3000)
        # 1s of speech → below 3s threshold
        sup.vad._probs = [0.95] * 33  # ~1s a 33 frames/s de 30ms
        for _ in range(33):
            result = sup.feed(frames(0.03))
        assert sup.state == "IDLE"
        assert result.state == "IDLE"

    def test_sustained_speech_starts_recording(self):
        """Voz continua >= speech_ms arranca la grabacion."""
        sup = make_supervisor(speech_ms=3000)
        sup.vad._probs = [0.9] * 110  # ~3.3s
        any_started = False
        for _ in range(110):
            result = sup.feed(frames(0.03))
            if result.started:
                any_started = True
        assert sup.state == "RECORDING"
        assert any_started is True

    def test_interrupted_speech_resets_timer(self):
        """Voz interrumpida por silencio resetea el contador de inicio."""
        sup = make_supervisor(speech_ms=3000)
        sup.vad._probs = [0.9] * 60 + [0.05] * 10 + [0.9] * 110
        for _ in range(60 + 10 + 110):
            sup.feed(frames(0.03))
        assert sup.state == "RECORDING"


class TestSilenceStop:
    def test_silence_stops_after_threshold(self):
        """Silencio continuo >= silence_ms para la grabacion."""
        sup = make_supervisor(speech_ms=1000, silence_ms=60000)
        # Arrancar con 2s de voz
        sup.vad._probs = [0.9] * 67
        for _ in range(67):
            sup.feed(frames(0.03))
        assert sup.state == "RECORDING"

        # Ahora silencio largo: 60s a 30ms = 2000 frames
        sup.vad._probs = [0.05] * 2000
        any_stopped = False
        for _ in range(2000):
            result = sup.feed(frames(0.03))
            if result.stopped:
                any_stopped = True
        assert sup.state == "IDLE"
        assert any_stopped is True

    def test_short_silence_does_not_stop(self):
        sup = make_supervisor(speech_ms=1000, silence_ms=60000)
        sup.vad._probs = [0.9] * 67
        for _ in range(67):
            sup.feed(frames(0.03))
        # 5s de silencio (< 60s) → sigue grabando
        sup.vad._probs = [0.05] * 167
        any_stopped = False
        for _ in range(167):
            result = sup.feed(frames(0.03))
            if result.stopped:
                any_stopped = True
        assert sup.state == "RECORDING"
        assert any_stopped is False


class TestFrameAccounting:
    def test_accumulates_speech_time(self):
        sup = make_supervisor(speech_ms=3000)
        sup.vad._probs = [0.9] * 50
        for _ in range(50):
            sup.feed(frames(0.03))
        # 50 * 30ms = 1.5s de voz acumulada
        assert abs(sup._speech_ms - 1500) < 100

    def test_accumulates_silence_time(self):
        sup = make_supervisor(silence_ms=60000)
        sup.state = "RECORDING"
        sup.vad._probs = [0.05] * 100
        for _ in range(100):
            sup.feed(frames(0.03))
        assert abs(sup._silence_ms - 3000) < 100
