"""VAD auto-trigger supervisor for Savia Transcriptor (SE-308 S2).

Listens to audio frames in IDLE. When continuous speech exceeds
`speech_ms`, emits `started` — the RecordingController begins capture.
When in RECORDING and continuous silence exceeds `silence_ms`, emits
`stopped` — the controller finishes the session.

The VAD backend is injected (`speech_probability(frames) -> float`). The
production backend is silero-vad; tests use a deterministic fake.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol


class VadBackend(Protocol):
    def speech_probability(self, frames) -> float: ...


@dataclass
class VadResult:
    state: str          # "IDLE" | "RECORDING"
    started: bool       # True cuando se acaba de arrancar
    stopped: bool       # True cuando se acaba de parar
    speech_prob: float  # ultima probabilidad de voz


class VadSupervisor:
    def __init__(
        self,
        vad: VadBackend,
        sample_rate: int = 16000,
        speech_ms: int = 3000,
        silence_ms: int = 60000,
        frame_ms: int = 30,
        speech_threshold: float = 0.5,
    ) -> None:
        self.vad = vad
        self.sample_rate = sample_rate
        self.speech_ms = speech_ms
        self.silence_ms = silence_ms
        self.frame_ms = frame_ms
        self.speech_threshold = speech_threshold

        self.state = "IDLE"
        self._speech_ms = 0.0
        self._silence_ms = 0.0

    def feed(self, frames) -> VadResult:
        """Process one audio block; return state + transition flags."""
        prob = self.vad.speech_probability(frames)
        block_ms = self.frame_ms

        started = False
        stopped = False

        if prob >= self.speech_threshold:
            self._speech_ms += block_ms
            self._silence_ms = 0.0
        else:
            self._speech_ms = 0.0
            self._silence_ms += block_ms

        if self.state == "IDLE" and self._speech_ms >= self.speech_ms:
            self.state = "RECORDING"
            started = True
            self._silence_ms = 0.0

        elif self.state == "RECORDING" and self._silence_ms >= self.silence_ms:
            self.state = "IDLE"
            stopped = True
            self._speech_ms = 0.0

        return VadResult(
            state=self.state,
            started=started,
            stopped=stopped,
            speech_prob=prob,
        )

    def reset(self) -> None:
        self.state = "IDLE"
        self._speech_ms = 0.0
        self._silence_ms = 0.0
