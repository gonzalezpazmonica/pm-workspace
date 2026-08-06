"""Tests for the server-side meeting-state push ticker.

The ticker replaces the old 4 Hz HTTP polling from the dashboard. While the
recorder is in "recording" or "paused" state, the controller emits
`meeting-state` events through the event_emitter callback at ~4 Hz so the
dashboard (and popup) stay updated over Qt WebChannel — never HTTP.

We exercise just the ticker mechanism here, not the full
MeetingsController construction (which pulls in DB / settings / transcription
fixtures). A minimal stand-in object that exposes the methods the ticker
touches is plenty to pin the contract."""

from __future__ import annotations

import threading
import time
from typing import Any

import pytest

from services.recording.controller import MeetingsController


class _FakeRecorder:
    def __init__(self, state_sequence: list[dict[str, Any]]):
        self._states = list(state_sequence)
        self._lock = threading.Lock()

    def get_state(self) -> dict[str, Any]:
        with self._lock:
            if not self._states:
                return {"state": "idle"}
            if len(self._states) == 1:
                return self._states[0]
            return self._states.pop(0)


def _make_controller_stub(recorder, emitter):
    """Sidestep MeetingsController.__init__'s heavy dependencies — we only
    need the ticker plumbing. Build the minimum surface MeetingsController's
    tick code touches."""
    ctrl = MeetingsController.__new__(MeetingsController)
    ctrl.recorder = recorder
    ctrl._emit = emitter
    ctrl._tick_stop = threading.Event()
    ctrl._tick_thread = None
    return ctrl


def _wait_until(predicate, timeout=2.0, interval=0.02):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return True
        time.sleep(interval)
    return False


# ────────────────────────────────────────────────────────────────────── tests


class TestTickLifecycle:
    def test_start_emits_meeting_state_while_recording(self):
        recorder = _FakeRecorder([
            {"state": "recording", "duration_ms": 1000, "recording_id": 7,
             "mic_peak_db": -20.0, "loopback_peak_db": -30.0},
        ])
        events: list[tuple[str, dict]] = []
        ctrl = _make_controller_stub(
            recorder, lambda name, payload: events.append((name, payload))
        )

        ctrl._start_tick()
        try:
            # 250 ms cadence — wait for at least 2 emits before asserting.
            assert _wait_until(lambda: len(events) >= 2, timeout=1.5), (
                f"expected ≥2 emits, got {len(events)}"
            )
        finally:
            ctrl._stop_tick()

        # Every emit must be a meeting-state with the rich payload shape.
        for name, payload in events:
            assert name == "meeting-state"
            assert payload["state"] == "recording"
            assert payload["durationMs"] == 1000
            assert payload["recordingId"] == 7
            assert payload["micPeakDb"] == -20.0
            assert payload["loopbackPeakDb"] == -30.0

    def test_tick_exits_when_recorder_goes_idle(self):
        recorder = _FakeRecorder([
            {"state": "recording", "duration_ms": 500, "recording_id": 1,
             "mic_peak_db": None, "loopback_peak_db": None},
            {"state": "recording", "duration_ms": 750, "recording_id": 1,
             "mic_peak_db": None, "loopback_peak_db": None},
            {"state": "idle", "duration_ms": 0, "recording_id": None,
             "mic_peak_db": None, "loopback_peak_db": None},
        ])
        events: list[tuple[str, dict]] = []
        ctrl = _make_controller_stub(
            recorder, lambda name, payload: events.append((name, payload))
        )

        ctrl._start_tick()
        # Thread should self-terminate within a couple of ticks of the recorder
        # reporting idle.
        assert _wait_until(
            lambda: ctrl._tick_thread is None
            or not ctrl._tick_thread.is_alive(),
            timeout=2.0,
        )

    def test_tick_keeps_running_through_pause(self):
        recorder = _FakeRecorder([
            {"state": "recording", "duration_ms": 100, "recording_id": 2,
             "mic_peak_db": None, "loopback_peak_db": None},
            {"state": "paused", "duration_ms": 100, "recording_id": 2,
             "mic_peak_db": None, "loopback_peak_db": None},
            {"state": "paused", "duration_ms": 100, "recording_id": 2,
             "mic_peak_db": None, "loopback_peak_db": None},
        ])
        seen_states: list[str] = []
        ctrl = _make_controller_stub(
            recorder,
            lambda name, payload: seen_states.append(payload["state"]),
        )

        ctrl._start_tick()
        try:
            assert _wait_until(
                lambda: "paused" in seen_states, timeout=1.5
            ), f"never saw paused emit, got: {seen_states}"
        finally:
            ctrl._stop_tick()

    def test_start_tick_is_idempotent(self):
        recorder = _FakeRecorder([
            {"state": "recording", "duration_ms": 0, "recording_id": 1,
             "mic_peak_db": None, "loopback_peak_db": None},
        ])
        ctrl = _make_controller_stub(recorder, lambda *_: None)

        ctrl._start_tick()
        first = ctrl._tick_thread
        ctrl._start_tick()
        second = ctrl._tick_thread
        try:
            # Same thread — second call must not spawn a duplicate.
            assert first is second
            assert first is not None and first.is_alive()
        finally:
            ctrl._stop_tick()

    def test_stop_tick_unblocks_quickly(self):
        recorder = _FakeRecorder([
            {"state": "recording", "duration_ms": 0, "recording_id": 1,
             "mic_peak_db": None, "loopback_peak_db": None},
        ])
        ctrl = _make_controller_stub(recorder, lambda *_: None)
        ctrl._start_tick()
        thread = ctrl._tick_thread
        assert thread is not None

        ctrl._stop_tick()
        thread.join(timeout=1.0)
        assert not thread.is_alive(), "tick thread did not exit within 1 s of stop"

    def test_emit_exception_does_not_kill_tick(self):
        """If the emitter raises (e.g. main thread tearing down), the ticker
        must keep checking state — never let a transient exception kill the
        push loop silently."""
        recorder = _FakeRecorder([
            {"state": "recording", "duration_ms": 0, "recording_id": 1,
             "mic_peak_db": None, "loopback_peak_db": None},
        ])
        call_count = {"n": 0}

        def flaky_emit(_name, _payload):
            call_count["n"] += 1
            if call_count["n"] <= 2:
                raise RuntimeError("simulated emit failure")

        ctrl = _make_controller_stub(recorder, flaky_emit)
        ctrl._start_tick()
        try:
            # Wait for at least a few more emits past the failures — the loop
            # must have survived the exceptions.
            assert _wait_until(
                lambda: call_count["n"] >= 5, timeout=2.5
            ), f"tick died after exception, only got {call_count['n']} calls"
        finally:
            ctrl._stop_tick()
