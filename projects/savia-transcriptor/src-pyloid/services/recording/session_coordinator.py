"""Session coordinator for Savia Transcriptor (SE-308 S3).

Wires the VAD supervisor to BOTH the audio recorder and the screen capture:
when VAD detects sustained speech → start audio + screen; on sustained
silence → stop both.

This is the glue between `vad.py` (detection) and `screen.py` (capture)
plus the upstream RecordingService (audio). Kept decoupled via duck-typed
`audio_recorder` / `screen_capture` so it's unit-testable without the
recording stack.
"""

from __future__ import annotations

from typing import Optional

from services.recording.vad import VadSupervisor


class SessionCoordinator:
    def __init__(
        self,
        vad_supervisor: VadSupervisor,
        audio_recorder,
        screen_capture=None,
    ) -> None:
        self._vad = vad_supervisor
        self._audio = audio_recorder
        self._screen = screen_capture
        self.is_recording = False

    def feed_frames(self, frames) -> None:
        """Process one audio block; start/stop session on transitions."""
        result = self._vad.feed(frames)
        if result.started and not self.is_recording:
            self._begin_session()
        elif result.stopped and self.is_recording:
            self._end_session()

    def _begin_session(self) -> None:
        self.is_recording = True
        self._audio.start()
        if self._screen is not None:
            self._screen.start()

    def _end_session(self) -> None:
        self.is_recording = False
        self._audio.stop()
        if self._screen is not None:
            self._screen.stop()

    def reset(self) -> None:
        if self.is_recording:
            self._end_session()
        self._vad.reset()
