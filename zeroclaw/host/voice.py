#!/usr/bin/env python3
"""SaviaClaw Voice — TTS (espeak-ng/spd-say) + STT (whisper) pipeline."""
import subprocess
import tempfile
import os
import shutil

LANG = "es"
TTS_RATE = 160
RECORD_SECONDS = 5
SAMPLE_RATE = 16000
WHISPER_MODEL = "base"

def _audio_env():
    """Env dict ensuring PipeWire/PulseAudio routing works."""
    env = os.environ.copy()
    env.setdefault("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    return env


def check_deps():
    """Check available voice dependencies."""
    deps = {
        "espeak-ng": shutil.which("espeak-ng") is not None,
        "spd-say": shutil.which("spd-say") is not None,
        "arecord": shutil.which("arecord") is not None,
        "aplay": shutil.which("aplay") is not None,
    }
    try:
        import whisper  # noqa: F401
        deps["whisper"] = True
    except ImportError:
        deps["whisper"] = False
    return deps


def say(text, lang=LANG, rate=TTS_RATE):
    """Speak text. Tries espeak-ng, then spd-say, then prints."""
    if shutil.which("espeak-ng"):
        try:
            subprocess.run(
                ["espeak-ng", "-v", lang, "-s", str(rate), text],
                timeout=30, check=True, env=_audio_env())
            return True
        except subprocess.SubprocessError:
            pass
    if shutil.which("spd-say"):
        try:
            subprocess.run(
                ["spd-say", "-l", lang, "-r", "-30", text],
                timeout=10, check=True, env=_audio_env())
            return True
        except subprocess.SubprocessError:
            pass
    print(f"[voice] (no TTS) {text}")
    return False


def record(seconds=RECORD_SECONDS, out_path=None):
    """Record audio from mic. Returns path to WAV file or None."""
    if not shutil.which("arecord"):
        print("[voice] arecord not found")
        return None
    if out_path is None:
        fd, out_path = tempfile.mkstemp(suffix=".wav")
        os.close(fd)
    try:
        subprocess.run(
            ["arecord", "-D", "pulse", "-f", "S16_LE", "-r", str(SAMPLE_RATE),
             "-c", "1", "-d", str(seconds), out_path],
            timeout=seconds + 5, check=True, capture_output=True,
            env=_audio_env())
        return out_path
    except subprocess.SubprocessError as e:
        print(f"[voice] Record error: {e}")
        return None


def transcribe(wav_path, lang=LANG):
    """Transcribe WAV to text via Whisper. Returns text or None."""
    try:
        import whisper
    except ImportError:
        print("[voice] whisper not installed — pip3 install openai-whisper")
        return None
    model = whisper.load_model(WHISPER_MODEL)
    result = model.transcribe(wav_path, language=lang)
    return result.get("text", "").strip()


def listen(seconds=RECORD_SECONDS):
    """Record + transcribe. Returns text or None."""
    wav = record(seconds)
    if not wav:
        return None
    try:
        return transcribe(wav)
    finally:
        try:
            os.unlink(wav)
        except OSError:
            pass


def listen_and_respond(brain_fn, seconds=RECORD_SECONDS):
    """Full voice loop: listen → think → speak."""
    say("Te escucho")
    question = listen(seconds)
    if not question:
        return say("No he entendido nada") or None
    print(f"[voice] Q: {question}")
    say("Pensando")
    answer = brain_fn(question)
    say(answer if answer else "No tengo respuesta")
    return answer


def test_voice():
    """Test TTS and recording."""
    deps = check_deps()
    print("Deps:", {k: "OK" if v else "MISS" for k, v in deps.items()})
    if deps["espeak-ng"] or deps["spd-say"]:
        print(f"TTS: {'OK' if say('Hola, soy Savia.') else 'FAILED'}")
    if deps["arecord"]:
        wav = record(seconds=2)
        if wav:
            print(f"Rec: OK ({os.path.getsize(wav)}B)")
            os.unlink(wav)
    if not deps["whisper"]:
        print("STT: pip3 install openai-whisper")
    return deps


if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser(description="SaviaClaw Voice")
    p.add_argument("--say", help="Text to speak")
    p.add_argument("--listen", action="store_true")
    p.add_argument("--test", action="store_true")
    p.add_argument("--seconds", type=int, default=RECORD_SECONDS)
    args = p.parse_args()
    if args.test:
        test_voice()
    elif args.say:
        say(args.say)
    elif args.listen:
        text = listen(args.seconds)
        print(f"Transcribed: {text}" if text else "Could not transcribe")
    else:
        p.print_help()
