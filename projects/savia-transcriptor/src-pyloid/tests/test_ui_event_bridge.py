"""Tests for UiEventBridge — the single backend→UI event pathway.

Queued Qt delivery needs a QCoreApplication and event-loop processing; these
tests drive the loop manually with processEvents()."""

import threading
import time

import pytest

pytest.importorskip("PySide6")
from PySide6.QtCore import QCoreApplication

from services.ui_event_bridge import UiEventBridge


@pytest.fixture(scope="module")
def qt_app():
    app = QCoreApplication.instance() or QCoreApplication([])
    yield app


def _pump_until(app, predicate, timeout_s=5.0):
    deadline = time.monotonic() + timeout_s
    while not predicate() and time.monotonic() < deadline:
        app.processEvents()
        time.sleep(0.005)
    return predicate()


class TestUiEventBridge:
    def test_dispatches_to_registered_handler(self, qt_app):
        bridge = UiEventBridge()
        received = []
        bridge.on("ptt-amplitude", received.append)

        bridge.emit_event("ptt-amplitude", 0.5)

        assert _pump_until(qt_app, lambda: received == [0.5])

    def test_unregistered_event_is_dropped(self, qt_app):
        bridge = UiEventBridge()
        received = []
        bridge.on("handled", received.append)

        bridge.emit_event("recording-transcribe-progress", {"x": 1})
        bridge.emit_event("handled", "ok")

        assert _pump_until(qt_app, lambda: received == ["ok"])

    def test_cross_thread_emit_delivers_on_pumping_thread(self, qt_app):
        bridge = UiEventBridge()
        received = []
        handler_thread = []

        def handler(payload):
            handler_thread.append(threading.current_thread())
            received.append(payload)

        bridge.on("meeting-state", handler)

        t = threading.Thread(
            target=lambda: bridge.emit_event("meeting-state", {"state": "recording"})
        )
        t.start()
        t.join()

        assert _pump_until(qt_app, lambda: received == [{"state": "recording"}])
        # Queued delivery: handler ran on the thread pumping the Qt loop
        # (this test's main thread), not the emitting thread.
        assert handler_thread == [threading.main_thread()]

    def test_handler_exception_does_not_break_bridge(self, qt_app):
        bridge = UiEventBridge()
        received = []

        def bad_handler(_payload):
            raise RuntimeError("boom")

        bridge.on("bad", bad_handler)
        bridge.on("good", received.append)

        bridge.emit_event("bad", None)
        bridge.emit_event("good", 1)

        assert _pump_until(qt_app, lambda: received == [1])
