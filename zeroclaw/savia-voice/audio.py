"""Audio capture, VAD, and transcription."""

import os
import tempfile
import wave
from pathlib import Path

import numpy as np

# ── Lazy globals ────────────────────────────────────────────────────────
_vad_model = None
_whisper_model = None


def load_vad():
    global _vad_model
    if _vad_model:
        return _vad_model
    print("[init] Cargando VAD...")
    from silero_vad import load_silero_vad
    _vad_model = load_silero_vad()
    print("[init] VAD listo.")
    return _vad_model


def load_whisper(model_name="base"):
    global _whisper_model
    if _whisper_model:
        return _whisper_model
    print(f"[init] Cargando Whisper ({model_name})...")
    from faster_whisper import WhisperModel
    _whisper_model = WhisperModel(model_name, device="cpu", compute_type="int8")
    print("[init] Whisper listo.")
    return _whisper_model


def check_vad(model, chunk, sample_rate):
    import torch
    return model(torch.from_numpy(chunk).float(), sample_rate).item()


def load_whisper_prompt(prompt_file=None):
    if prompt_file:
        p = Path(prompt_file).expanduser()
        if p.exists():
            return p.read_text().strip()
    return "Savia, ZeroClaw, ESP32, sprint actual, backlog, proyecto, reunión"


def transcribe(audio_data, model, language="es", prompt="",
               channels=1, sample_rate=16000):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
        with wave.open(f, "wb") as wf:
            wf.setnchannels(channels)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes((audio_data * 32767).astype(np.int16).tobytes())
    try:
        segs, _ = model.transcribe(
            tmp, language=language, beam_size=1,
            vad_filter=True, initial_prompt=prompt
        )
        return " ".join(s.text.strip() for s in segs).strip()
    finally:
        os.unlink(tmp)
