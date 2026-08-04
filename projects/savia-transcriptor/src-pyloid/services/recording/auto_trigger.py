"""VAD auto-trigger orchestration for Savia Transcriptor (SE-308 S2).

Owns a listener `AudioSource` (the always-listening monitor/mic source)
and a `VadSupervisor`. On VAD start → calls `on_start` (RecordingController
begins capture). On VAD stop → calls `on_stop` (controller finishes).

Kept decoupled from RecordingController via callbacks so it's unit-testable
without the full recording stack.
"""

from __future__ import annotations

from typing import Callable, Optional

from services.recording.vad import VadSupervisor


class AutoTrigger:
    def __init__(
        self,
        vad_supervisor: VadSupervisor,
        listener,
        on_start: Callable[[], None],
        on_stop: Callable[[], None],
    ) -> None:
        self._vad = vad_supervisor
        self._listener = listener
        self._on_start = on_start
        self._on_stop = on_stop
        self._running = False

    @property
    def running(self) -> bool:
        return self._running

    def start(self) -> None:
        if self._running:
            return
        self._running = True
        self._listener.start(self._on_frames)

    def stop(self) -> None:
        self._running = False
        self._listener.stop()

    def _on_frames(self, frames) -> None:
        if not self._running:
            return
        result = self._vad.feed(frames)
        if result.started:
            self._on_start()
        elif result.stopped:
            self._on_stop()
