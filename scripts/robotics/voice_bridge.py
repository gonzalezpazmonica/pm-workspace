"""ZeroClaw Voice Bridge — host-side server for voice pipeline.

Runs on the PC/RPi, receives audio from ESP32, processes through
STT → Savia → TTS, and streams audio back.

Dependencies (optional, graceful fallback):
  pip install piper-tts       # TTS (fast, local, Spanish)
  pip install faster-whisper   # STT (fast, local)
  pip install pyttsx3          # TTS fallback (zero deps)
"""
import json, http.server, threading, io, wave, time, os, sys

# Try to import optional dependencies
STT_ENGINE = None
TTS_ENGINE = None

try:
    from faster_whisper import WhisperModel
    STT_ENGINE = "faster-whisper"
except ImportError:
    pass

try:
    import pyttsx3
    TTS_ENGINE = "pyttsx3"
except ImportError:
    pass


class VoiceBridge:
    """Bridges ZeroClaw ESP32 audio with Savia processing."""

    def __init__(self, stt_model="tiny", tts_lang="es", port=8765):
        self.port = port
        self.tts_lang = tts_lang
        self.stt = None
        self.tts = None
        self.callbacks = {"on_transcript": None, "on_response": None}
        self._init_stt(stt_model)
        self._init_tts(tts_lang)

    def _init_stt(self, model_size):
        if STT_ENGINE == "faster-whisper":
            self.stt = WhisperModel(model_size, compute_type="int8")
            print(f"  STT: faster-whisper ({model_size})")
        else:
            print("  STT: not available (install faster-whisper)")

    def _init_tts(self, lang):
        if TTS_ENGINE == "pyttsx3":
            self.tts = pyttsx3.init()
            self.tts.setProperty('rate', 140)
            voices = self.tts.getProperty('voices')
            for v in voices:
                if 'spanish' in v.name.lower():
                    self.tts.setProperty('voice', v.id)
                    break
            print(f"  TTS: pyttsx3 ({lang})")
        else:
            print("  TTS: not available (install pyttsx3)")

    def transcribe(self, audio_bytes, sample_rate=16000):
        """Transcribe audio bytes to text."""
        if not self.stt:
            return None
        # Write to temp WAV
        buf = io.BytesIO()
        with wave.open(buf, 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes(audio_bytes)
        buf.seek(0)
        segments, _ = self.stt.transcribe(buf, language=self.tts_lang)
        return " ".join(s.text for s in segments).strip()

    def speak(self, text):
        """Speak text via local TTS."""
        if self.tts:
            self.tts.say(text)
            self.tts.runAndWait()
        else:
            print(f"  [TTS unavailable] {text}")

    def on_transcript(self, callback):
        """Register callback for when transcript is ready."""
        self.callbacks["on_transcript"] = callback

    def on_response(self, callback):
        """Register callback for when Savia response is ready."""
        self.callbacks["on_response"] = callback

    def status(self):
        """Return bridge status."""
        return {
            "stt": STT_ENGINE or "none",
            "tts": TTS_ENGINE or "none",
            "port": self.port,
            "lang": self.tts_lang,
        }


def check_dependencies():
    """Check which voice deps are available."""
    deps = {
        "faster-whisper": STT_ENGINE == "faster-whisper",
        "pyttsx3": TTS_ENGINE == "pyttsx3",
        "piper-tts": False,
    }
    try:
        import piper
        deps["piper-tts"] = True
    except ImportError:
        pass
    return deps


def print_setup_guide():
    """Print setup instructions for missing dependencies."""
    deps = check_dependencies()
    print("ZeroClaw Voice Bridge — Dependency Status")
    print("─" * 45)
    for name, ok in deps.items():
        icon = "✅" if ok else "❌"
        print(f"  {icon} {name}")
    if not any(deps.values()):
        print("\nInstall at least one STT and one TTS:")
        print("  pip install faster-whisper  # STT (recommended)")
        print("  pip install pyttsx3         # TTS (simplest)")
        print("  pip install piper-tts       # TTS (best quality)")
