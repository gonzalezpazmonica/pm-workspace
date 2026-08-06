"""Long-form audio recorder for the Meetings feature.

Independent of the PTT `AudioService`. Streams frames from one or two
`AudioSource`s into a 16 kHz PCM16 WAV file on disk via `soundfile.SoundFile`.

Channel layout (ADR-0001):
  * 1 source  → mono
  * 2 sources → stereo, mic on L (ch 0), loopback on R (ch 1)

Pause semantics (Q3): silence is written for the wall-clock duration of the
pause so audio-time and wall-time stay aligned. Frames that arrive during a
paused window are dropped.
"""

from __future__ import annotations

import collections
import threading
import time
from pathlib import Path
from typing import Callable, Optional

import numpy as np
import soundfile as sf

from services.recording.audio_source import AudioSource
from services.recording.clock import Clock, RealClock


SAMPLE_RATE = 16000
_PEAK_FLOOR_DB = -60.0
_PEAK_EMIT_HZ = 10.0
# In stereo mode, if one source hasn't delivered a frame for this long while
# the other is producing audio, we stop waiting and flush the active side as
# mono-on-channel. Prevents the recorder from freezing when (e.g.) parec
# stalls during a PipeWire source suspension.
_STEREO_STARVATION_S = 0.15

from services.logger import get_logger
log = get_logger("meeting_audio")


class RecorderError(Exception):
    pass


class RecorderAlreadyStartedError(RecorderError):
    pass


class RecorderNotRunningError(RecorderError):
    pass


class NoAudioSourcesError(RecorderError):
    pass


class RecordingService:
    """Owns the active recording. Singleton-like (a second `start()` while
    already running raises) but not a process-global singleton — instances are
    constructed by `AppController`."""

    def __init__(self, clock: Optional[Clock] = None) -> None:
        self._clock: Clock = clock or RealClock()

        self._lock = threading.Lock()
        self._state: str = "idle"  # idle | recording | paused | stopping
        self._mic: Optional[AudioSource] = None
        self._loopback: Optional[AudioSource] = None

        self._mic_queue: collections.deque = collections.deque()
        self._loopback_queue: collections.deque = collections.deque()
        self._silence_frames_pending: int = 0
        self._pause_started_at: Optional[float] = None
        self._frames_written: int = 0

        self._channels: int = 1
        self._file: Optional[sf.SoundFile] = None
        self._file_path: Optional[Path] = None
        self._recording_id: Optional[int] = None

        self._writer_thread: Optional[threading.Thread] = None
        self._stop_writer = False
        self._wake = threading.Event()

        # Peak-dB tracking for the live level meter on the recorder page.
        # Updated on every source-callback (cheap — one numpy max), exposed
        # via get_state() which the frontend polls at ~4 Hz.
        self._mic_peak_db: Optional[float] = None
        self._loopback_peak_db: Optional[float] = None

        # Last-frame timestamps for starvation detection in stereo mode.
        self._last_mic_frame_at: Optional[float] = None
        self._last_loopback_frame_at: Optional[float] = None

    # ------------------------------------------------------------------ public

    def start(
        self,
        recording_id: int,
        file_path: Path,
        mic: Optional[AudioSource] = None,
        loopback: Optional[AudioSource] = None,
    ) -> None:
        if mic is None and loopback is None:
            raise NoAudioSourcesError("at least one of mic/loopback must be provided")

        with self._lock:
            if self._state != "idle":
                raise RecorderAlreadyStartedError(
                    f"recorder is {self._state}; stop the previous recording first"
                )

            self._recording_id = recording_id
            self._file_path = Path(file_path)
            self._mic = mic
            self._loopback = loopback
            self._channels = 2 if (mic is not None and loopback is not None) else 1

            self._mic_queue.clear()
            self._loopback_queue.clear()
            self._silence_frames_pending = 0
            self._frames_written = 0
            self._pause_started_at = None
            self._stop_writer = False
            self._wake.clear()

            self._file = sf.SoundFile(
                str(self._file_path),
                mode="w",
                samplerate=SAMPLE_RATE,
                channels=self._channels,
                subtype="PCM_16",
            )
            self._state = "recording"

        # Start sources outside the lock — their `start` might call back synchronously.
        if mic is not None:
            mic.start(self._on_mic_frames)
        if loopback is not None:
            loopback.start(self._on_loopback_frames)

        self._writer_thread = threading.Thread(target=self._writer_loop, daemon=True)
        self._writer_thread.start()

    def pause(self) -> None:
        with self._lock:
            if self._state != "recording":
                raise RecorderNotRunningError(f"cannot pause while {self._state}")
            self._state = "paused"
            self._pause_started_at = self._clock.monotonic()

    def resume(self) -> None:
        with self._lock:
            if self._state != "paused":
                raise RecorderNotRunningError(f"cannot resume while {self._state}")
            elapsed = self._clock.monotonic() - (self._pause_started_at or 0.0)
            silence = int(round(elapsed * SAMPLE_RATE))
            if silence > 0:
                self._silence_frames_pending += silence
            self._state = "recording"
            self._pause_started_at = None
        self._wake.set()

    def stop(self) -> dict:
        with self._lock:
            if self._state == "idle":
                raise RecorderNotRunningError("recorder is not running")
            self._state = "stopping"

        # Stop sources so no more frames arrive.
        if self._mic is not None:
            self._mic.stop()
        if self._loopback is not None:
            self._loopback.stop()

        # Drain anything still queued, then shut the writer down.
        self.wait_for_flush()
        with self._lock:
            self._stop_writer = True
        self._wake.set()
        if self._writer_thread is not None:
            self._writer_thread.join(timeout=2.0)

        # Snapshot result before tearing down.
        sources: list[str] = []
        if self._mic is not None:
            sources.append("mic")
        if self._loopback is not None:
            sources.append("loopback")
        channels = self._channels
        frames_written = self._frames_written
        file_path = self._file_path

        if self._file is not None:
            self._file.close()
        self._file = None
        self._mic = None
        self._loopback = None
        self._writer_thread = None

        with self._lock:
            self._state = "idle"
            self._recording_id = None

        size_bytes = file_path.stat().st_size if (file_path and file_path.exists()) else 0
        return {
            "sources": sources,
            "channels": channels,
            "sample_rate": SAMPLE_RATE,
            "duration_ms": int(frames_written * 1000 / SAMPLE_RATE),
            "size_bytes": size_bytes,
        }

    def get_state(self) -> dict:
        with self._lock:
            return {
                "state": self._state,
                "recording_id": self._recording_id,
                "duration_ms": int(self._frames_written * 1000 / SAMPLE_RATE),
                "mic_peak_db": self._mic_peak_db,
                "loopback_peak_db": self._loopback_peak_db,
            }

    def wait_for_flush(self, timeout: float = 2.0) -> None:
        """Block until writer has consumed all queued frames + scheduled silence."""
        import time as _time
        deadline = _time.monotonic() + timeout
        # Wake the writer so it doesn't idle through this poll.
        self._wake.set()
        while _time.monotonic() < deadline:
            with self._lock:
                empty = (
                    not self._mic_queue
                    and not self._loopback_queue
                    and self._silence_frames_pending == 0
                )
            if empty:
                return
            _time.sleep(0.005)
        raise TimeoutError("recorder writer did not flush in time")

    # ------------------------------------------------------------------ callbacks

    def _on_mic_frames(self, frames: np.ndarray) -> None:
        arr = np.asarray(frames, dtype=np.float32)
        peak_db = _peak_db(arr)
        now = self._clock.monotonic()
        with self._lock:
            self._mic_peak_db = peak_db
            self._last_mic_frame_at = now
            if self._state == "recording":
                self._mic_queue.append(arr)
        self._wake.set()

    def _on_loopback_frames(self, frames: np.ndarray) -> None:
        arr = np.asarray(frames, dtype=np.float32)
        peak_db = _peak_db(arr)
        now = self._clock.monotonic()
        with self._lock:
            self._loopback_peak_db = peak_db
            self._last_loopback_frame_at = now
            if self._state == "recording":
                self._loopback_queue.append(arr)
        self._wake.set()

    # ------------------------------------------------------------------ writer

    def _writer_loop(self) -> None:
        last_heartbeat = time.monotonic()
        last_frames_written = 0
        while True:
            self._wake.wait(timeout=0.05)
            self._wake.clear()
            with self._lock:
                if self._stop_writer:
                    return
            try:
                self._writer_step()
            except Exception:
                # Stay alive — a bad block shouldn't kill the recording, but
                # we need visibility into why progress halted (the field-bug
                # where duration froze at 0:59 was silently masked here).
                log.exception("recorder writer step crashed")

            # Diagnostic heartbeat — every 5s log queue depth and progress so
            # we can see exactly when/why the writer stops advancing.
            now = time.monotonic()
            if now - last_heartbeat > 5.0:
                with self._lock:
                    mic_q = len(self._mic_queue)
                    loop_q = len(self._loopback_queue)
                    last_mic = self._last_mic_frame_at
                    last_loop = self._last_loopback_frame_at
                    fw = self._frames_written
                    state = self._state
                delta = fw - last_frames_written
                mic_idle_ms = int((now - last_mic) * 1000) if last_mic is not None else None
                loop_idle_ms = int((now - last_loop) * 1000) if last_loop is not None else None
                log.info(
                    "recorder heartbeat",
                    state=state,
                    frames_written=fw,
                    delta_frames=delta,
                    mic_queue_blocks=mic_q,
                    loopback_queue_blocks=loop_q,
                    mic_idle_ms=mic_idle_ms,
                    loopback_idle_ms=loop_idle_ms,
                )
                last_heartbeat = now
                last_frames_written = fw

    def _writer_step(self) -> None:
        # 1) Flush any scheduled silence first (preserves audio-time).
        with self._lock:
            silence = self._silence_frames_pending
            self._silence_frames_pending = 0
        if silence > 0 and self._file is not None:
            block = np.zeros((silence, self._channels), dtype=np.float32)
            self._file.write(block)
            self._frames_written += silence

        # 2) Drain real frames.
        if self._channels == 1:
            queue = self._mic_queue if self._mic is not None else self._loopback_queue
            while True:
                with self._lock:
                    if not queue:
                        return
                    block = queue.popleft()
                if self._file is not None:
                    self._file.write(block)
                    self._frames_written += block.size
        else:
            while True:
                with self._lock:
                    is_stopping = self._state == "stopping"
                    has_mic = bool(self._mic_queue)
                    has_loop = bool(self._loopback_queue)
                    if not has_mic and not has_loop:
                        return

                    # Starvation detection: a side is "starved" if it HAS
                    # delivered before but its last frame was more than
                    # _STEREO_STARVATION_S ago. Treats "never delivered yet"
                    # as warming up so first-frame races don't write mono.
                    now = self._clock.monotonic()
                    mic_starved = (
                        self._last_mic_frame_at is not None
                        and (now - self._last_mic_frame_at) > _STEREO_STARVATION_S
                    )
                    loop_starved = (
                        self._last_loopback_frame_at is not None
                        and (now - self._last_loopback_frame_at) > _STEREO_STARVATION_S
                    )
                    drain_mode = (
                        is_stopping
                        or (has_mic and not has_loop and loop_starved)
                        or (has_loop and not has_mic and mic_starved)
                    )
                    if not drain_mode and (not has_mic or not has_loop):
                        return

                    mic_block = self._mic_queue.popleft() if has_mic else None
                    loop_block = self._loopback_queue.popleft() if has_loop else None

                if mic_block is not None and loop_block is not None:
                    n = min(mic_block.size, loop_block.size)
                    stereo = np.zeros((n, 2), dtype=np.float32)
                    stereo[:, 0] = mic_block[:n]
                    stereo[:, 1] = loop_block[:n]
                    if self._file is not None:
                        self._file.write(stereo)
                        self._frames_written += n
                    with self._lock:
                        if mic_block.size > n:
                            self._mic_queue.appendleft(mic_block[n:])
                        if loop_block.size > n:
                            self._loopback_queue.appendleft(loop_block[n:])
                elif mic_block is not None:
                    n = mic_block.size
                    stereo = np.zeros((n, 2), dtype=np.float32)
                    stereo[:, 0] = mic_block
                    if self._file is not None:
                        self._file.write(stereo)
                        self._frames_written += n
                elif loop_block is not None:
                    n = loop_block.size
                    stereo = np.zeros((n, 2), dtype=np.float32)
                    stereo[:, 1] = loop_block
                    if self._file is not None:
                        self._file.write(stereo)
                        self._frames_written += n


def _peak_db(arr: np.ndarray) -> Optional[float]:
    if arr.size == 0:
        return _PEAK_FLOOR_DB
    peak = float(np.abs(arr).max())
    if peak < 1e-6:
        return _PEAK_FLOOR_DB
    db = 20.0 * float(np.log10(peak))
    if db < _PEAK_FLOOR_DB:
        return _PEAK_FLOOR_DB
    return db
