"""Tests for the periodic screen capture (SE-308 S3).

ScreenCapture grabs screenshots every `interval` seconds during a session.
The capture backend is injected so tests don't need mss (a C dependency).

Design:
- `capture_once()` grabs a single screenshot of the configured monitor
- `run_loop()` captures every interval seconds until stopped
- `resize_width` optionally downscales (0 = native)
- captures land in `output_dir` with timestamped filenames
"""

import sys
import os
import time
import tempfile
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))


class FakeCaptureBackend:
    """Records calls; returns a fake raw image (bytes)."""

    def __init__(self, monitors=None):
        self.monitors = monitors or [None, {'width': 1920, 'height': 1080}]
        self.grabs = []

    def grab(self, monitor_index):
        self.grabs.append(monitor_index)
        return {'width': 1920, 'height': 1080, 'rgb': b'\x00' * 16}


class FakeImageSaver:
    def __init__(self):
        self.saved = []

    def to_png(self, rgb, size, output):
        self.saved.append((str(output), size))
        Path(output).write_bytes(rgb)


def _load_screen_module():
    import importlib.util
    path = os.path.join(os.path.dirname(__file__), '..', 'services', 'recording', 'screen.py')
    spec = importlib.util.spec_from_file_location('screen_module', path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules['screen_module'] = mod
    spec.loader.exec_module(mod)
    return mod


class TestScreenCapture:
    def setup_method(self):
        self.mod = _load_screen_module()
        self.tmp = tempfile.mkdtemp()
        self.out = Path(self.tmp) / 'captures'
        self.out.mkdir()

    def teardown_method(self):
        import shutil
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_capture_once_creates_file(self):
        backend = FakeCaptureBackend()
        cap = self.mod.ScreenCapture(
            backend=backend,
            saver=FakeImageSaver(),
            output_dir=self.out,
            monitor=1,
            resize_width=0,
        )
        path = cap.capture_once()
        assert path.exists()
        assert path.suffix == '.png'

    def test_capture_uses_configured_monitor(self):
        backend = FakeCaptureBackend()
        cap = self.mod.ScreenCapture(
            backend=backend,
            saver=FakeImageSaver(),
            output_dir=self.out,
            monitor=1,
            resize_width=0,
        )
        cap.capture_once()
        assert backend.grabs == [1]

    def test_filenames_timestamped_and_unique(self):
        backend = FakeCaptureBackend()
        cap = self.mod.ScreenCapture(
            backend=backend,
            saver=FakeImageSaver(),
            output_dir=self.out,
            monitor=1,
            resize_width=0,
        )
        p1 = cap.capture_once()
        time.sleep(0.01)
        p2 = cap.capture_once()
        assert p1 != p2
        assert p1.stem != p2.stem

    def test_run_loop_captures_until_stopped(self):
        backend = FakeCaptureBackend()
        cap = self.mod.ScreenCapture(
            backend=backend,
            saver=FakeImageSaver(),
            output_dir=self.out,
            monitor=1,
            resize_width=0,
            interval_seconds=0.01,
        )
        cap.start()
        time.sleep(0.06)  # ~6 capturas a 10ms
        cap.stop()
        count = len(list(self.out.glob('*.png')))
        assert count >= 2, f'solo {count} capturas'

    def test_stop_before_start_is_safe(self):
        backend = FakeCaptureBackend()
        cap = self.mod.ScreenCapture(
            backend=backend,
            saver=FakeImageSaver(),
            output_dir=self.out,
            monitor=1,
        )
        cap.stop()  # no-op, no crash
        cap.stop()
        assert True
