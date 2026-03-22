#!/usr/bin/env python3
"""E2E test — simulates voice conversation without a microphone.
Generates synthetic audio with TTS and feeds it through the full pipeline."""

import os
import subprocess
import tempfile
import time
import wave
from pathlib import Path

import numpy as np

VENV_BIN = str(Path.home() / ".savia/whisper-env/bin")
VOICE = "es-ES-AlvaroNeural"  # different voice to simulate another person

TEST_PHRASES = [
    "Hola Savia, me escuchas.",
    "Dime qué proyectos tengo abiertos.",
    "Cuéntame un resumen del proyecto savia web.",
]


def generate_audio(text, output_path):
    """Generate WAV audio from text using edge-tts."""
    tmp_mp3 = tempfile.mktemp(suffix=".mp3")
    try:
        subprocess.run(
            [f"{VENV_BIN}/edge-tts", "--voice", VOICE,
             "--text", text, "--write-media", tmp_mp3],
            capture_output=True, timeout=15, check=True
        )
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error",
             "-i", tmp_mp3, "-ar", "16000", "-ac", "1",
             "-f", "wav", output_path],
            capture_output=True, timeout=10, check=True
        )
    finally:
        if os.path.exists(tmp_mp3):
            os.unlink(tmp_mp3)


def transcribe_audio(wav_path):
    """Transcribe WAV using Whisper."""
    from audio import load_whisper, load_whisper_prompt
    model = load_whisper("base")
    prompt = load_whisper_prompt()
    segs, _ = model.transcribe(
        wav_path, language="es", beam_size=1,
        vad_filter=True, initial_prompt=prompt
    )
    return " ".join(s.text.strip() for s in segs).strip()


def ask_claude(text, session):
    """Ask via streaming session, collect full response."""
    sentences = list(session.ask_streaming(text))
    return " ".join(sentences)


def main():
    from session import SessionManager
    from tts import TTSSynthesizer

    tts = TTSSynthesizer(voice="es-ES-ElviraNeural", lead_in_silence=0)
    session = SessionManager(
        model="sonnet",
        append_system_prompt="voice-prompt.md",
        tts=tts,
    )

    print("=" * 60)
    print("  E2E TEST — Conversacion simulada")
    print("=" * 60)

    # Greeting
    print("\n[test] Pidiendo saludo...")
    t0 = time.time()
    greeting = session.ask(
        "El modo voz acaba de arrancar. Saluda al usuario por su nombre "
        "y dile que te escucha. Una sola frase corta y natural."
    )
    print(f"[test] Saludo ({time.time()-t0:.1f}s): {greeting}")

    results = []

    for i, phrase in enumerate(TEST_PHRASES, 1):
        print(f"\n--- Turno {i}/{len(TEST_PHRASES)} ---")
        print(f"[user] Frase original: \"{phrase}\"")

        # Generate synthetic audio
        wav_path = tempfile.mktemp(suffix=".wav")
        try:
            t0 = time.time()
            generate_audio(phrase, wav_path)
            t1 = time.time()
            print(f"[tts-gen] Audio generado: {t1-t0:.1f}s")

            # Transcribe
            transcribed = transcribe_audio(wav_path)
            t2 = time.time()
            print(f"[stt] ({t2-t1:.1f}s) Transcrito: \"{transcribed}\"")

            # Check transcription accuracy
            match = phrase.lower().replace(",", "").replace(".", "")
            trans = transcribed.lower().replace(",", "").replace(".", "")
            words_orig = set(match.split())
            words_trans = set(trans.split())
            overlap = len(words_orig & words_trans) / max(len(words_orig), 1)
            print(f"[stt] Precision palabras: {overlap*100:.0f}%")

            # Ask Claude (streaming)
            t3 = time.time()
            sentences = []
            for j, sentence in enumerate(session.ask_streaming(transcribed), 1):
                if j == 1:
                    fa = time.time() - t3
                    print(f"[stream] 1a frase ({fa:.1f}s): \"{sentence}\"")
                else:
                    print(f"[stream] Frase {j}: \"{sentence}\"")
                sentences.append(sentence)
            t4 = time.time()
            response = " ".join(sentences)
            print(f"[llm] ({t4-t3:.1f}s) Total: {response}")

            results.append({
                "phrase": phrase,
                "transcribed": transcribed,
                "stt_accuracy": overlap,
                "stt_time": t2 - t1,
                "llm_time": t4 - t3,
                "first_audio": fa if sentences else None,
                "response": response,
                "sentences": len(sentences),
            })

        finally:
            if os.path.exists(wav_path):
                os.unlink(wav_path)

    # Summary
    print("\n" + "=" * 60)
    print("  RESULTADOS")
    print("=" * 60)
    for r in results:
        print(f"\n  \"{r['phrase']}\"")
        print(f"    STT: \"{r['transcribed']}\" "
              f"({r['stt_accuracy']*100:.0f}% acc, {r['stt_time']:.1f}s)")
        print(f"    LLM: {r['llm_time']:.1f}s total, "
              f"FA: {r['first_audio']:.1f}s, "
              f"{r['sentences']} frases")
        print(f"    Resp: {r['response'][:100]}")

    avg_fa = np.mean([r["first_audio"] for r in results if r["first_audio"]])
    avg_stt = np.mean([r["stt_accuracy"] for r in results])
    print(f"\n  Media first-audio: {avg_fa:.1f}s")
    print(f"  Media STT accuracy: {avg_stt*100:.0f}%")
    print(f"  Target FA: <4s | {'OK' if avg_fa < 4 else 'PENDIENTE'}")


if __name__ == "__main__":
    main()
