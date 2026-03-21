"""ZeroClaw Meeting Pipeline — live audio → diarization → transcript.
Deps: pip install pyannote.audio faster-whisper speechbrain torch
"""
import os
import json
import time
import wave
import io

# Lazy imports for optional dependencies
_diarization_pipeline = None
_whisper_model = None


def _load_diarization():
    global _diarization_pipeline
    if _diarization_pipeline is not None:
        return _diarization_pipeline
    try:
        from pyannote.audio import Pipeline
        _diarization_pipeline = Pipeline.from_pretrained(
            "pyannote/speaker-diarization-3.1",
            use_auth_token=os.environ.get("HF_TOKEN"))
        return _diarization_pipeline
    except (ImportError, Exception):
        return None


def _load_whisper():
    global _whisper_model
    if _whisper_model is not None:
        return _whisper_model
    try:
        from faster_whisper import WhisperModel
        _whisper_model = WhisperModel("tiny", compute_type="int8")
        return _whisper_model
    except ImportError:
        return None


def process_audio_buffer(audio_bytes, sample_rate=16000, session_dir=None,
                         voiceprint_module=None):
    """Process an audio buffer: diarize → identify speakers → transcribe.

    Args:
        audio_bytes: Raw PCM bytes (16-bit mono)
        sample_rate: Audio sample rate
        session_dir: Directory to write transcript chunks
        voiceprint_module: Module with identify_from_embedding()

    Returns:
        List of {ts, speaker, confidence, text} dicts
    """
    wav_buf = io.BytesIO()
    with wave.open(wav_buf, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(audio_bytes)
    wav_buf.seek(0)

    results = []

    diarizer = _load_diarization()
    if diarizer:
        diarization = diarizer(wav_buf)
        segments = list(diarization.itertracks(yield_label=True))
    else:
        # Fallback: treat entire buffer as one speaker
        duration = len(audio_bytes) / (sample_rate * 2)
        segments = [(_FakeSegment(0, duration), None, "SPEAKER_0")]

    whisper = _load_whisper()
    for turn, _, label in segments:
        start_s = turn.start
        end_s = turn.end
        start_byte = int(start_s * sample_rate * 2)
        end_byte = int(end_s * sample_rate * 2)
        seg_bytes = audio_bytes[start_byte:end_byte]
        if len(seg_bytes) < sample_rate:  # < 0.5s, skip
            continue

        # Identify speaker
        speaker = label
        confidence = 0.0
        if voiceprint_module and voiceprint_module.is_available():
            seg_wav = _bytes_to_wav(seg_bytes, sample_rate)
            match = voiceprint_module.identify(seg_wav)
            speaker = match.get("name", label)
            confidence = match.get("confidence", 0.0)

        # Transcribe
        text = ""
        if whisper:
            seg_wav_path = _bytes_to_wav(seg_bytes, sample_rate)
            segs, _ = whisper.transcribe(seg_wav_path, language="es")
            text = " ".join(s.text for s in segs).strip()

        if text:
            entry = {
                "ts": f"{int(start_s//60):02d}:{int(start_s%60):02d}",
                "speaker": speaker,
                "confidence": round(confidence, 2),
                "text": text,
            }
            results.append(entry)

    # Write to session if provided
    if session_dir and results:
        os.makedirs(session_dir, exist_ok=True)
        transcript_path = os.path.join(session_dir, "transcript.jsonl")
        with open(transcript_path, 'a') as f:
            for r in results:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")

    return results


def _bytes_to_wav(pcm_bytes, sample_rate):
    """Convert raw PCM to temporary WAV file path."""
    import tempfile
    tmp = tempfile.NamedTemporaryFile(suffix='.wav', delete=False)
    with wave.open(tmp, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(pcm_bytes)
    return tmp.name


class _FakeSegment:
    """Minimal segment for fallback (no pyannote)."""
    def __init__(self, start, end):
        self.start = start
        self.end = end


def check_dependencies():
    """Check which meeting pipeline deps are available."""
    deps = {}
    for name, imp in [("pyannote.audio", "pyannote.audio"),
                      ("faster-whisper", "faster_whisper"),
                      ("speechbrain", "speechbrain"),
                      ("torch", "torch")]:
        try:
            __import__(imp)
            deps[name] = True
        except ImportError:
            deps[name] = False
    return deps
