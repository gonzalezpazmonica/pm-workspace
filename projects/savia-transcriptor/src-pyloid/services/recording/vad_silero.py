"""Silero VAD backend for the auto-trigger supervisor (SE-308 S2).

Wraps silero-vad's `get_speech_timestamps` into the simple
`speech_probability(frames) -> float` protocol the VadSupervisor expects.
Uses a lazy import so the rest of the app doesn't pay for torch/silero
unless the auto-trigger feature is enabled.
"""

from __future__ import annotations

import numpy as np


class SileroVadBackend:
    """Production VAD backend wrapping silero-vad."""

    def __init__(self, threshold: float = 0.5, model_dir: str | None = None) -> None:
        self.threshold = threshold
        self._model = None
        self._model_dir = model_dir

    def _load_model(self):
        if self._model is not None:
            return self._model
        try:
            from silero_vad import load_silero_vad  # type: ignore[import-untyped]
        except ImportError as e:
            raise RuntimeError(
                "silero-vad not installed. Run: pip install silero-vad"
            ) from e
        import torch  # type: ignore[import-untyped]

        torch.set_num_threads(1)
        self._model = load_silero_vad(model_dir=self._model_dir)
        return self._model

    def speech_probability(self, frames) -> float:
        """Return 0..1 probability that `frames` contains speech."""
        model = self._load_model()
        import torch

        audio = frames
        if not isinstance(audio, torch.Tensor):
            audio = torch.from_numpy(np.asarray(audio, dtype=np.float32))
        if audio.dim() == 1:
            audio = audio.unsqueeze(0)
        if audio.shape[1] != 512:
            # silero expects 512-sample chunks; pad/truncate
            n = audio.shape[1]
            if n < 512:
                pad = 512 - n
                audio = torch.nn.functional.pad(audio, (0, pad))
            else:
                audio = audio[:, :512]
        prob = model(audio).item()
        return float(prob)
