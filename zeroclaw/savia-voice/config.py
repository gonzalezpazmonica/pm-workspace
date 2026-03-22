"""Config loader — defaults + local overrides."""

from pathlib import Path

import yaml

DEFAULTS = {
    "audio": {
        "sample_rate": 16000,
        "channels": 1,
        "blocksize": 512,
    },
    "vad": {
        "threshold": 0.5,
        "silence_timeout": 1.2,
        "min_speech_duration": 0.4,
    },
    "stt": {
        "model": "tiny",
        "language": "es",
        "prompt_file": None,
    },
    "tts": {
        "engine": "edge-tts",
        "voice": "es-ES-ElviraNeural",
        "lead_in_silence": 1.0,
    },
    "claude": {
        "model": "sonnet",
        "permission_mode": "default",
        "append_system_prompt": None,
    },
}


def deep_merge(base, override):
    result = base.copy()
    for k, v in override.items():
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = deep_merge(result[k], v)
        else:
            result[k] = v
    return result


def load_config():
    cfg = DEFAULTS.copy()
    base_dir = Path(__file__).parent

    default_file = base_dir / "config.default.yaml"
    if default_file.exists():
        with open(default_file) as f:
            data = yaml.safe_load(f) or {}
        cfg = deep_merge(cfg, data)

    local_file = base_dir / "config.local.yaml"
    if local_file.exists():
        with open(local_file) as f:
            data = yaml.safe_load(f) or {}
        cfg = deep_merge(cfg, data)

    return cfg
