"""Tests for the session coordinator (SE-308 S3).

SessionCoordinator wires VAD start/stop to both the audio recorder and
the screen capture: on start both begin, on stop both finish.
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))


def _load_vad():
    import importlib.util
    path = os.path.join(os.path.dirname(__file__), '..', 'services', 'recording', 'vad.py')
    spec = importlib.util.spec_from_file_location('vad_mod_s3', path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules['vad_mod_s3'] = mod
    spec.loader.exec_module(mod)
    return mod


def _load_coordinator():
    import importlib.util
    path = os.path.join(os.path.dirname(__file__), '..', 'services', 'recording', 'session_coordinator.py')
    spec = importlib.util.spec_from_file_location('coord_mod_s3', path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules['coord_mod_s3'] = mod
    spec.loader.exec_module(mod)
    return mod


class FakeVad:
    def __init__(self, probs):
        self._p = list(probs)

    def speech_probability(self, f):
        return self._p.pop(0) if self._p else 0.0


class FakeAudioRecorder:
    def __init__(self):
        self.starts = 0
        self.stops = 0

    def start(self):
        self.starts += 1

    def stop(self):
        self.stops += 1


class FakeScreenCapture:
    def __init__(self):
        self.starts = 0
        self.stops = 0

    def start(self):
        self.starts += 1

    def stop(self):
        self.stops += 1


class TestSessionCoordinator:
    def setup_method(self):
        self.vad_mod = _load_vad()
        self.coord_mod = _load_coordinator()

    def test_start_starts_audio_and_screen(self):
        vad = FakeVad([0.9] * 110)
        audio = FakeAudioRecorder()
        screen = FakeScreenCapture()
        sup = self.vad_mod.VadSupervisor(vad, sample_rate=16000, speech_ms=3000)
        coord = self.coord_mod.SessionCoordinator(
            vad_supervisor=sup, audio_recorder=audio, screen_capture=screen
        )
        coord.feed_frames(object())  # un frame cualquiera; el test alimenta 110
        for _ in range(109):
            coord.feed_frames(object())
        assert audio.starts == 1
        assert screen.starts == 1
        assert coord.is_recording is True

    def test_stop_stops_audio_and_screen(self):
        vad = FakeVad([0.9] * 67 + [0.05] * 2000)
        audio = FakeAudioRecorder()
        screen = FakeScreenCapture()
        sup = self.vad_mod.VadSupervisor(vad, sample_rate=16000, speech_ms=1000, silence_ms=60000)
        coord = self.coord_mod.SessionCoordinator(
            vad_supervisor=sup, audio_recorder=audio, screen_capture=screen
        )
        for _ in range(67):
            coord.feed_frames(object())
        assert audio.starts == 1 and screen.starts == 1
        for _ in range(2000):
            coord.feed_frames(object())
        assert audio.stops == 1
        assert screen.stops == 1
        assert coord.is_recording is False

    def test_no_double_start(self):
        """Una sesion no se reinicia en medio del arranque."""
        vad = FakeVad([0.9] * 300)
        audio = FakeAudioRecorder()
        screen = FakeScreenCapture()
        sup = self.vad_mod.VadSupervisor(vad, sample_rate=16000, speech_ms=3000)
        coord = self.coord_mod.SessionCoordinator(
            vad_supervisor=sup, audio_recorder=audio, screen_capture=screen
        )
        for _ in range(300):
            coord.feed_frames(object())
        # Solo arranca una vez, no rearranca en cada frame de voz
        assert audio.starts == 1
        assert screen.starts == 1
