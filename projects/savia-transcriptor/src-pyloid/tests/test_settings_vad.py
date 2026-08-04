"""Tests for VAD auto-trigger settings (SE-308 S2)."""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))


def _load_settings_dataclass():
    """Carga el dataclass Settings sin ejecutar todo services.__init__."""
    import importlib.util
    # settings.py importa services.hotkey y services.logger (evdev). Para aislar,
    # verificamos los campos via el source directamente.
    with open(os.path.join(os.path.dirname(__file__), '..', 'services', 'settings.py')) as f:
        src = f.read()
    return src


class TestVadSettingsFields:
    def test_has_auto_trigger_enabled(self):
        src = _load_settings_dataclass()
        assert "vad_auto_trigger_enabled" in src

    def test_has_speech_ms(self):
        src = _load_settings_dataclass()
        assert "vad_speech_ms" in src

    def test_has_silence_ms(self):
        src = _load_settings_dataclass()
        assert "vad_silence_ms" in src

    def test_has_speech_threshold(self):
        src = _load_settings_dataclass()
        assert "vad_speech_threshold" in src

    def test_has_monitor_interval(self):
        src = _load_settings_dataclass()
        assert "vad_capture_interval_s" in src

    def test_defaults_are_sane(self):
        src = _load_settings_dataclass()
        assert "vad_auto_trigger_enabled: bool = False" in src
        assert "vad_speech_ms: int = 3000" in src
        assert "vad_silence_ms: int = 60000" in src
