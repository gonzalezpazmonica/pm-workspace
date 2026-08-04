"""
Single source of truth for the Whisper model catalog.

Every backend module that needs to know which models exist, how big they
are, or which HuggingFace repo they live in imports from here. Do not
re-declare model names/repos anywhere else (that's how the catalog drifted
across model_manager, settings, and transcription before this module).

The frontend gets repo IDs over RPC (get_model_info -> repoId) rather than
keeping its own copy of the mapping.
"""

# All models supported by faster-whisper with approximate download sizes (bytes)
# Sizes are estimates based on the CTranslate2 converted models.
# Order matters: it is the display order used by the settings UI
# (multilingual first, then English-only, then distilled).
MODEL_SIZES = {
    # Standard models (multilingual)
    "tiny": 75_000_000,           # ~75 MB
    "base": 145_000_000,          # ~145 MB
    "small": 466_000_000,         # ~466 MB
    "medium": 1_530_000_000,      # ~1.53 GB
    "large-v1": 3_090_000_000,    # ~3.09 GB
    "large-v2": 3_090_000_000,    # ~3.09 GB
    "large-v3": 3_090_000_000,    # ~3.09 GB
    "turbo": 1_620_000_000,       # ~1.62 GB (large-v3-turbo)
    # English-only models (slightly smaller, optimized for English)
    "tiny.en": 75_000_000,        # ~75 MB
    "base.en": 145_000_000,       # ~145 MB
    "small.en": 466_000_000,      # ~466 MB
    "medium.en": 1_530_000_000,   # ~1.53 GB
    # Distilled models (faster inference, English-only)
    "distil-small.en": 332_000_000,    # ~332 MB
    "distil-medium.en": 756_000_000,   # ~756 MB
    "distil-large-v2": 1_510_000_000,  # ~1.51 GB
    "distil-large-v3": 1_510_000_000,  # ~1.51 GB
}

# Model name to HuggingFace repo ID mapping
# Based on faster-whisper's internal mapping
MODEL_REPOS = {
    # Standard multilingual models
    "tiny": "Systran/faster-whisper-tiny",
    "base": "Systran/faster-whisper-base",
    "small": "Systran/faster-whisper-small",
    "medium": "Systran/faster-whisper-medium",
    "large-v1": "Systran/faster-whisper-large-v1",
    "large-v2": "Systran/faster-whisper-large-v2",
    "large-v3": "Systran/faster-whisper-large-v3",
    "turbo": "mobiuslabsgmbh/faster-whisper-large-v3-turbo",
    # English-only models
    "tiny.en": "Systran/faster-whisper-tiny.en",
    "base.en": "Systran/faster-whisper-base.en",
    "small.en": "Systran/faster-whisper-small.en",
    "medium.en": "Systran/faster-whisper-medium.en",
    # Distilled models
    "distil-small.en": "Systran/faster-distil-whisper-small.en",
    "distil-medium.en": "Systran/faster-distil-whisper-medium.en",
    "distil-large-v2": "Systran/faster-distil-whisper-large-v2",
    "distil-large-v3": "Systran/faster-distil-whisper-large-v3",
}

# Ordered list of model names (the settings dropdown / picker order)
WHISPER_MODELS = list(MODEL_SIZES.keys())


def get_repo_id(model_name: str) -> str:
    """Get the HuggingFace repo ID for a model name."""
    return MODEL_REPOS.get(model_name, f"Systran/faster-whisper-{model_name}")


def hf_cache_folder_name(repo_id: str) -> str:
    """HuggingFace hub cache folder name for a repo.

    e.g. "Systran/faster-whisper-tiny" -> "models--Systran--faster-whisper-tiny"
    """
    return "models--" + repo_id.replace("/", "--")
