#!/usr/bin/env python3
"""Savia Voice Daemon v2.4 — Full duplex with conversation model."""

import threading
import time

import numpy as np
import sounddevice as sd

from audio import load_vad, load_whisper, check_vad, transcribe, load_whisper_prompt
from config import load_config
from conversation_model import classify_overlap, OverlapType
from session import SessionManager
from tts import TTSSynthesizer

cfg = load_config()
SR = cfg["audio"]["sample_rate"]
CH = cfg["audio"]["channels"]
BLOCKSIZE = cfg["audio"]["blocksize"]
VAD_THRESH = cfg["vad"]["threshold"]
SILENCE_TO = cfg["vad"]["silence_timeout"]
MIN_SPEECH = cfg["vad"]["min_speech_duration"]
STT_MODEL = cfg["stt"]["model"]
STT_LANG = cfg["stt"]["language"]
STT_PROMPT_FILE = cfg["stt"].get("prompt_file")


def main():
    vad = load_vad()
    whisper = load_whisper(STT_MODEL)
    stt_prompt = load_whisper_prompt(STT_PROMPT_FILE)

    tts = TTSSynthesizer(
        engine=cfg["tts"]["engine"],
        voice=cfg["tts"]["voice"],
        lead_in_silence=cfg["tts"]["lead_in_silence"],
    )
    # Pre-load TTS model at startup
    if cfg["tts"]["engine"] == "kokoro":
        tts.load_kokoro()
    session = SessionManager(
        model=cfg["claude"]["model"],
        permission_mode=cfg["claude"]["permission_mode"],
        append_system_prompt=cfg["claude"].get("append_system_prompt"),
        tts=tts,
    )

    lock = threading.Lock()
    state = {
        "buf": [], "speaking": False,
        "sil_start": None, "sp_start": None,
        "pipeline_active": False,
        "was_overlap": False,  # speech started during TTS
    }

    print()
    print("=" * 50)
    print("  SAVIA VOICE v2.4 — Conversation Model")
    print(f"  STT: whisper-{STT_MODEL} | LLM: {cfg['claude']['model']}")
    print(f"  TTS: {cfg['tts']['voice']}")
    print("  Ctrl+C para salir.")
    print("=" * 50)
    print()

    print("[savia] Saludando...")
    greeting = session.ask(
        "El modo voz acaba de arrancar. Saluda al usuario por su nombre "
        "y dile que te escucha. Una sola frase corta y natural."
    )
    print(f"[savia] {greeting}")
    tts.speak(greeting)
    print("[mic] Escuchando...\n")

    def on_audio(indata, frames, time_info, status):
        """Audio callback — NEVER blocked. Always listens."""
        chunk = indata[:, 0].copy()
        conf = check_vad(vad, chunk, SR)

        with lock:
            if conf >= VAD_THRESH:
                if not state["speaking"]:
                    state["speaking"] = True
                    state["sp_start"] = time.time()
                    state["was_overlap"] = tts.is_playing
                    if not state["pipeline_active"] and not state["was_overlap"]:
                        print("[mic] Habla detectada...")
                state["sil_start"] = None
                state["buf"].append(chunk)

            elif state["speaking"]:
                state["buf"].append(chunk)
                if state["sil_start"] is None:
                    state["sil_start"] = time.time()
                elif time.time() - state["sil_start"] >= SILENCE_TO:
                    dur = time.time() - state["sp_start"]
                    if dur >= MIN_SPEECH:
                        audio = np.concatenate(state["buf"])
                        was_overlap = state["was_overlap"]
                        threading.Thread(
                            target=process_with_model,
                            args=(audio, dur, was_overlap),
                            daemon=True
                        ).start()
                    state["buf"] = []
                    state["speaking"] = False
                    state["sil_start"] = None
                    state["sp_start"] = None
                    state["was_overlap"] = False

    def process_with_model(audio_data, duration, was_overlap):
        """Transcribe, classify overlap, decide action."""
        with lock:
            state["pipeline_active"] = True
        try:
            t0 = time.time()
            text = transcribe(audio_data, whisper, STT_LANG, stt_prompt, CH, SR)
            if not text or len(text) < 2:
                return
            t1 = time.time()

            overlap_type, action = classify_overlap(text, duration, was_overlap)

            if was_overlap:
                print(f"[overlap] ({t1-t0:.1f}s) \"{text}\" "
                      f"→ {overlap_type} → {action}")
                if action == "ignore":
                    return
                elif action == "listen":
                    # Savia keeps talking. Save text as follow-up.
                    with lock:
                        state.setdefault("pending_followup", [])
                        state["pending_followup"].append(text)
                    print(f"[listen] Guardado para después: \"{text}\"")
                    return
                elif action == "stop":
                    tts.cancel()
                    print("[stop] Savia para (comando explícito).")
            else:
                print(f"[stt] ({t1-t0:.1f}s) \"{text}\"")

            # Check for pending follow-ups from overlaps
            with lock:
                followups = state.pop("pending_followup", [])
            if followups:
                context = " ".join(followups)
                text = f"{text} (mientras hablabas también dije: {context})"
                print(f"[followup] Contexto añadido: {context}")

            respond(text, t1)
        finally:
            with lock:
                state["pipeline_active"] = False
                # Process any follow-ups queued while Savia was speaking
                followups = state.pop("pending_followup", [])
            if followups:
                combined = " ".join(followups)
                print(f"[followup] Procesando pendiente: \"{combined}\"")
                respond(combined, time.time())

    def respond(text, t_start):
        """Send text to LLM and stream TTS response."""
        n = 0
        fa_time = None
        resp = []
        for sentence in session.ask_streaming(text):
            n += 1
            resp.append(sentence)
            if n == 1:
                fa_time = time.time()
                print(f"[stream] 1a frase ({fa_time-t_start:.1f}s): "
                      f"\"{sentence}\"")
            else:
                print(f"[stream] Frase {n}: \"{sentence}\"")
            tts.queue_sentence(sentence, first=(n == 1))

        tts.wait_done()
        t_end = time.time()
        fa = f" FA:{fa_time-t_start:.1f}s" if fa_time else ""
        print(f"[timing]{fa} Total:{t_end-t_start:.1f}s ({n} frases)")
        print("[mic] Escuchando...\n")

    with sd.InputStream(
        samplerate=SR, channels=CH, blocksize=BLOCKSIZE,
        dtype="float32", callback=on_audio
    ):
        try:
            while True:
                time.sleep(0.1)
        except KeyboardInterrupt:
            tts.cancel()
            print("\n[savia] Hasta luego.")


if __name__ == "__main__":
    main()
