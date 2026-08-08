"""The single backend→UI event pathway.

Backend code (hotkey/audio/transcription threads, MeetingsController) calls
`emit_event(name, payload)` from any thread; one Qt signal with a
QueuedConnection marshals it to the main thread, where the handler registered
via `on(name, handler)` runs. Events with no registered handler are dropped
silently — that's the contract for meetings events the popup doesn't care
about (e.g. recording-transcribe-progress).

Replaces the previous two parallel pathways (per-event Qt signals for PTT +
a separately installed meetings emitter), which kept drifting apart and each
had its own registration-order trap.

Requires a running QCoreApplication/QApplication for queued delivery — same
constraint the old per-event signals had.
"""

from PySide6.QtCore import QObject, Signal, Qt

from services.logger import get_logger

log = get_logger("window")


class UiEventBridge(QObject):
    _event = Signal(str, object)

    def __init__(self):
        super().__init__()
        self._handlers = {}
        self._event.connect(self._dispatch, Qt.QueuedConnection)

    def on(self, name: str, handler):
        """Register the main-thread handler for `name` (one per event)."""
        self._handlers[name] = handler

    def emit_event(self, name: str, payload=None):
        """Thread-safe: queue `payload` to `name`'s handler on the main thread."""
        self._event.emit(name, payload)

    def _dispatch(self, name, payload):
        handler = self._handlers.get(name)
        if handler is None:
            return
        try:
            handler(payload)
        except Exception:
            log.exception("ui event handler failed", event=name)
