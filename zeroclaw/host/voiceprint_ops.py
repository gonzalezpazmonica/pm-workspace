"""Voiceprint operations — identify, list, delete. Split from voiceprint.py."""
import os
import json
import numpy as np
from .voiceprint import (
    _load_index, _save_index, _cosine_similarity, _load_encoder,
    VOICEPRINT_DIR, SIMILARITY_THRESHOLD_HIGH, SIMILARITY_THRESHOLD_LOW,
)


def identify(audio_path):
    """Identify speaker from audio file. Returns {name, confidence, id}."""
    encoder = _load_encoder()
    if encoder is None:
        return {"name": "Unknown", "confidence": 0.0,
                "error": "speechbrain not installed"}
    segment_emb = encoder.encode_batch(
        encoder.load_audio(audio_path).unsqueeze(0)
    ).squeeze().cpu().numpy()
    return identify_from_embedding(segment_emb)


def identify_from_embedding(embedding):
    """Identify speaker from pre-extracted embedding vector."""
    index = _load_index()
    if not index:
        return {"name": "Unknown", "confidence": 0.0}
    best_name, best_score, best_id = "Unknown", 0.0, None
    for emb_id, info in index.items():
        emb_path = os.path.join(VOICEPRINT_DIR, info["file"])
        if not os.path.isfile(emb_path):
            continue
        stored = np.load(emb_path)
        score = _cosine_similarity(embedding, stored)
        if score > best_score:
            best_score, best_name, best_id = score, info["name"], emb_id
    if best_score >= SIMILARITY_THRESHOLD_HIGH:
        return {"name": best_name, "confidence": best_score, "id": best_id}
    elif best_score >= SIMILARITY_THRESHOLD_LOW:
        return {"name": f"{best_name}?", "confidence": best_score, "id": best_id}
    return {"name": "Unknown", "confidence": best_score}


def list_voiceprints():
    """List all enrolled voiceprints."""
    return _load_index()


def delete(name_or_id):
    """Delete voiceprint by name or ID (RGPD right to erasure)."""
    index = _load_index()
    to_delete = []
    for emb_id, info in index.items():
        if emb_id == name_or_id or info["name"].lower() == name_or_id.lower():
            emb_path = os.path.join(VOICEPRINT_DIR, info["file"])
            if os.path.isfile(emb_path):
                os.remove(emb_path)
            to_delete.append(emb_id)
    for eid in to_delete:
        del index[eid]
    _save_index(index)
    return {"deleted": len(to_delete)}


def is_available():
    """Check if speaker identification is available."""
    try:
        import speechbrain
        return True
    except ImportError:
        return False
