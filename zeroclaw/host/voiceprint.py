"""ZeroClaw Voiceprint Manager — learn and store voice fingerprints.

Speaker embeddings are biometric data (RGPD Art. 9). Stored locally
only (N4b level). Never in git, never shared, never sent to APIs.

Dependencies (install when needed):
  pip install speechbrain torch torchaudio
"""
import os
import json
import time
import hashlib
import numpy as np

VOICEPRINT_DIR = os.path.expanduser("~/.savia/zeroclaw/voiceprints")
INDEX_FILE = os.path.join(VOICEPRINT_DIR, "index.json")
SIMILARITY_THRESHOLD_HIGH = 0.75
SIMILARITY_THRESHOLD_LOW = 0.50

_encoder = None


def _load_encoder():
    """Lazy-load SpeechBrain ECAPA-TDNN encoder."""
    global _encoder
    if _encoder is not None:
        return _encoder
    try:
        from speechbrain.inference.speaker import EncoderClassifier
        _encoder = EncoderClassifier.from_hparams(
            source="speechbrain/spkrec-ecapa-voxceleb",
            savedir=os.path.expanduser("~/.savia/models/ecapa"),
            run_opts={"device": "cpu"},
        )
        return _encoder
    except ImportError:
        return None


def _ensure_dir():
    os.makedirs(VOICEPRINT_DIR, exist_ok=True)


def _load_index():
    _ensure_dir()
    if os.path.isfile(INDEX_FILE):
        with open(INDEX_FILE) as f:
            return json.load(f)
    return {}


def _save_index(index):
    _ensure_dir()
    with open(INDEX_FILE, 'w') as f:
        json.dump(index, f, indent=2)


def _cosine_similarity(a, b):
    """Cosine similarity between two vectors."""
    dot = np.dot(a, b)
    norm = np.linalg.norm(a) * np.linalg.norm(b)
    return float(dot / norm) if norm > 0 else 0.0


def enroll(name, audio_path):
    """Enroll a new voice from a WAV file (10-15s of speech).

    Returns:
        dict with status, embedding_id
    """
    encoder = _load_encoder()
    if encoder is None:
        return {"ok": False, "error": "speechbrain not installed. "
                "Run: pip install speechbrain torch torchaudio"}
    _ensure_dir()
    embedding = encoder.encode_batch(
        encoder.load_audio(audio_path).unsqueeze(0)
    ).squeeze().cpu().numpy()

    emb_id = hashlib.sha256(f"{name}{time.time()}".encode()).hexdigest()[:12]
    emb_file = os.path.join(VOICEPRINT_DIR, f"{name.lower()}-{emb_id}.npy")
    np.save(emb_file, embedding)

    index = _load_index()
    index[emb_id] = {
        "name": name,
        "file": os.path.basename(emb_file),
        "created": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "dim": int(embedding.shape[0]),
    }
    _save_index(index)
    return {"ok": True, "id": emb_id, "name": name,
            "dim": int(embedding.shape[0])}
