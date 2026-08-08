"""Tests for the Silero VAD backend (SE-308 S2).

Mocks torch/silero so tests don't require the heavy dependency.
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from services.recording.vad_silero import SileroVadBackend


class _FakeTensor:
    def __init__(self, shape):
        self.shape = shape
        self.dim_count = len(shape)

    def dim(self):
        return self.dim_count

    def unsqueeze(self, _axis):
        self.dim_count = self.dim_count + 1
        self.shape = (1,) + tuple(self.shape)
        return self


def test_silero_backend_imports_lazily():
    """El backend no importa torch/silero hasta la primera llamada."""
    backend = SileroVadBackend()
    assert backend._model is None  # no cargado todavia


def test_raises_without_silero():
    backend = SileroVadBackend()
    import builtins
    real_import = builtins.__import__

    def fake_import(name, *args, **kwargs):
        if name == 'silero_vad':
            raise ImportError('no silero')
        return real_import(name, *args, **kwargs)

    builtins.__import__ = fake_import
    try:
        try:
            backend.speech_probability(b'\x00' * 512)
            assert False, "deberia haber lanzado RuntimeError"
        except RuntimeError as e:
            assert 'silero-vad not installed' in str(e)
    finally:
        builtins.__import__ = real_import
