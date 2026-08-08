"""Periodic screen capture for Savia Transcriptor (SE-308 S3).

Captures a screenshot of a configured monitor every `interval` seconds
during a recording session. Screenshots (not video) — lightweight, private,
and directly consumable by a vision model.

Backends are injected so tests don't need mss (C dependency). Production
uses python-mss + PIL for optional downscaling.
"""

from __future__ import annotations

import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


class MssBackend:
    """Production capture backend wrapping python-mss."""

    def __init__(self, monitors=None):
        self._monitors = monitors
        self._sct = None

    def _ensure(self):
        if self._sct is None:
            import mss  # type: ignore[import-untyped]
            self._sct = mss.mss()
            self._monitors = self._sct.monitors
        return self._sct

    def grab(self, monitor_index: int):
        sct = self._ensure()
        return sct.grab(sct.monitors[monitor_index])

    def close(self):
        if self._sct is not None:
            self._sct.close()
            self._sct = None


class MssSaver:
    """Saves a raw mss screenshot to PNG via mss.tools."""

    def to_png(self, rgb, size, output: str) -> None:
        import mss.tools  # type: ignore[import-untyped]
        mss.tools.to_png(rgb, size, output=output)


class ScreenCapture:
    """Captures screenshots on a timer until stopped.

    Config:
    - monitor: 1 = principal (default), 0 = todos, N = especifico
    - interval_seconds: periodo entre capturas
    - resize_width: redimensionar a este ancho (default 1920, 0 = nativo)
    """

    def __init__(
        self,
        output_dir: Path,
        backend=None,
        saver=None,
        monitor: int = 1,
        interval_seconds: int = 15,
        resize_width: int = 1920,
    ) -> None:
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.monitor = monitor
        self.interval = interval_seconds
        self.resize_width = resize_width
        self._backend = backend or MssBackend()
        self._saver = saver or MssSaver()
        self._thread: Optional[threading.Thread] = None
        self._stop_event = threading.Event()
        self._running = False

    @property
    def running(self) -> bool:
        return self._running

    def capture_once(self) -> Path:
        """Grab one screenshot of the configured monitor; return its path."""
        img = self._backend.grab(self.monitor)
        ts = datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S_%f')
        path = self.output_dir / f"{ts}.png"
        self._saver.to_png(img['rgb'], (img['width'], img['height']), str(path))
        if self.resize_width and self.resize_width > 0:
            self._resize(path)
        return path

    def start(self) -> None:
        if self._running:
            return
        self._running = True
        self._stop_event.clear()
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._running = False
        self._stop_event.set()
        if self._thread is not None:
            self._thread.join(timeout=2)
            self._thread = None
        if hasattr(self._backend, 'close'):
            self._backend.close()

    def _loop(self) -> None:
        while self._running and not self._stop_event.is_set():
            try:
                self.capture_once()
            except Exception:
                pass  # una captura fallida no mata el bucle
            self._stop_event.wait(self.interval)

    def _resize(self, path: Path) -> None:
        try:
            from PIL import Image  # type: ignore[import-untyped]
            img = Image.open(path)
            ratio = self.resize_width / img.width
            new_h = int(img.height * ratio)
            img = img.resize((self.resize_width, new_h), Image.LANCZOS)
            img.save(path, 'PNG')
        except ImportError:
            pass  # sin PIL se conserva la resolucion nativa
