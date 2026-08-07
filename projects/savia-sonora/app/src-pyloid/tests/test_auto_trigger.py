"""Tests for the VAD auto-trigger orchestration (SE-308 S2).

The AutoTrigger service owns a listener AudioSource and a VadSupervisor.
On VAD start → invokes a recording starter callback. On VAD stop →
invokes a stopper. This decouples VAD detection from the concrete
RecordingController.
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))


def _load_auto_trigger_module():
    import importlib.util
    path = os.path.join(os.path.dirname(__file__), '..', 'services', 'recording', 'auto_trigger.py')
    spec = importlib.util.spec_from_file_location('auto_trigger_module', path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules['auto_trigger_module'] = mod
    spec.loader.exec_module(mod)
    return mod


def _load_vad_module():
    import importlib.util
    path = os.path.join(os.path.dirname(__file__), '..', 'services', 'recording', 'vad.py')
    spec = importlib.util.spec_from_file_location('vad_module', path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules['vad_module'] = mod
    spec.loader.exec_module(mod)
    return mod


class FakeVad:
    def __init__(self, probs):
        self._p = list(probs)

    def speech_probability(self, f):
        return self._p.pop(0) if self._p else 0.0


class TestAutoTrigger:
    def setup_method(self):
        self.at_mod = _load_auto_trigger_module()
        self.vad_mod = _load_vad_module()

    def test_start_called_on_speech(self):
        """Al detectar voz sostenida se llama al starter."""
        calls = {"start": 0, "stop": 0}

        class FakeSource:
            def start(self, cb): self.cb = cb
            def stop(self): pass

        source = FakeSource()
        vad = FakeVad([0.9] * 110)
        sup = self.vad_mod.VadSupervisor(vad, sample_rate=16000, speech_ms=3000)
        trigger = self.at_mod.AutoTrigger(
            vad_supervisor=sup,
            listener=source,
            on_start=lambda: calls.__setitem__("start", calls["start"] + 1),
            on_stop=lambda: calls.__setitem__("stop", calls["stop"] + 1),
        )
        trigger.start()
        # Alimentar frames de voz
        for _ in range(110):
            source.cb(object())
        assert calls["start"] == 1
        assert calls["stop"] == 0

    def test_stop_called_on_silence(self):
        calls = {"start": 0, "stop": 0}

        class FakeSource:
            def start(self, cb): self.cb = cb
            def stop(self): pass

        source = FakeSource()
        # Voz para arrancar, luego silencio para parar
        vad = FakeVad([0.9] * 67 + [0.05] * 2000)
        sup = self.vad_mod.VadSupervisor(vad, sample_rate=16000, speech_ms=1000, silence_ms=60000)
        trigger = self.at_mod.AutoTrigger(
            vad_supervisor=sup,
            listener=source,
            on_start=lambda: calls.__setitem__("start", calls["start"] + 1),
            on_stop=lambda: calls.__setitem__("stop", calls["stop"] + 1),
        )
        trigger.start()
        for _ in range(67):
            source.cb(object())
        assert calls["start"] == 1
        for _ in range(2000):
            source.cb(object())
        assert calls["stop"] == 1

    def test_stop_halts_listener(self):
        """stop() detiene el listener y deja de procesar frames."""
        stopped = {"n": 0}

        class FakeSource:
            def start(self, cb): self.cb = cb
            def stop(self): stopped["n"] += 1

        source = FakeSource()
        sup = self.vad_mod.VadSupervisor(FakeVad([]), sample_rate=16000)
        trigger = self.at_mod.AutoTrigger(
            vad_supervisor=sup,
            listener=source,
            on_start=lambda: None,
            on_stop=lambda: None,
        )
        trigger.start()
        trigger.stop()
        assert stopped["n"] == 1
