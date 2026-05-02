"""Voice daemon thread — wake word + listen + respond + LCD sync.

Runs as a thread inside saviaclaw_daemon. Listens for 'Savia',
records question, sends to LLM backend, speaks answer, updates LCD.
"""
import threading
import logging
import time

from .voice import say, listen, check_deps
from .wakeword import listen_loop, SILENCE_THRESHOLD
from .daemon_util import call_llm, truncate_lcd, send_cmd

log = logging.getLogger("saviaclaw.voice")

_voice_active = False
_serial_lock = threading.Lock()
_ser_ref = None


def set_serial(ser, lock=None):
    """Set serial reference for LCD updates. Thread-safe."""
    global _ser_ref, _serial_lock
    _ser_ref = ser
    if lock:
        _serial_lock = lock


def _lcd(text):
    """Update LCD if serial available. Thread-safe."""
    if not _ser_ref:
        return
    l1, l2 = truncate_lcd(text)
    cmd = f"lcd {l1} | {l2}" if l2 else f"lcd {l1}"
    with _serial_lock:
        try:
            send_cmd(_ser_ref, cmd, 1)
        except Exception:
            pass


def _on_wake():
    """Called when wake word detected. Full voice loop."""
    global _voice_active
    if _voice_active:
        return
    _voice_active = True
    try:
        log.info("Wake word detected")
        _lcd("Escuchando...")
        say("Te escucho")
        question = listen(seconds=5)
        if not question:
            say("No he entendido")
            _lcd("No entendi")
            return
        log.info("Voice Q: %s", question)
        _lcd("Pensando...")
        say("Pensando")
        answer = call_llm(question)
        if answer:
            log.info("Voice A: %s", answer[:80])
            say(answer)
            _lcd(answer)
        else:
            say("No tengo respuesta")
            _lcd("Sin respuesta")
    finally:
        _voice_active = False


def voice_thread(threshold=SILENCE_THRESHOLD):
    """Main voice thread entry point. Blocks forever."""
    deps = check_deps()
    has_tts = deps.get("espeak-ng") or deps.get("spd-say")
    has_mic = deps.get("arecord")
    if not has_mic:
        log.warning("No mic (arecord). Voice disabled.")
        return
    if not has_tts:
        log.warning("No TTS. Voice will be text-only.")
    log.info("Voice thread starting (TTS=%s, mic=%s)", has_tts, has_mic)
    _lcd("Voz activa")
    try:
        listen_loop(_on_wake, threshold=threshold)
    except Exception as e:
        log.error("Voice thread error: %s", e)


def start(ser=None, lock=None, threshold=SILENCE_THRESHOLD):
    """Start voice daemon as background thread. Returns thread."""
    if ser:
        set_serial(ser, lock)
    t = threading.Thread(
        target=voice_thread, args=(threshold,),
        daemon=True, name="voice-daemon")
    t.start()
    return t
