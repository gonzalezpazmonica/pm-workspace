from dataclasses import dataclass, fields
from typing import Optional
from .database import DatabaseService
from .hotkey import normalize_hotkey
from .model_catalog import WHISPER_MODELS

# Supported languages (subset - full list at https://github.com/openai/whisper)
WHISPER_LANGUAGES = [
    "auto",  # Auto-detect
    "en", "es", "fr", "de", "it", "pt", "nl", "pl", "ru",
    "zh", "ja", "ko", "ar", "hi", "tr", "vi", "th", "id"
]

# History retention options (in days, -1 = forever)
RETENTION_OPTIONS = {
    "7 days": 7,
    "30 days": 30,
    "90 days": 90,
    "Forever": -1,
}

# Theme options
THEME_OPTIONS = ["system", "light", "dark"]

# Device options for transcription
DEVICE_OPTIONS = ["auto", "cpu", "cuda"]


# LLM presets for meeting summarization. Order matches the UI radio group.
LLM_PRESETS = ["openai", "groq", "openrouter", "ollama", "custom"]

DEFAULT_LLM_PROMPT = (
    "You are a meeting-notes assistant. Read the transcript and produce a "
    "structured summary in Markdown with these sections, in this order:\n\n"
    "## TL;DR\nOne or two sentences.\n\n"
    "## Key topics\nBulleted list.\n\n"
    "## Decisions\nBulleted list.\n\n"
    "## Action items\nBulleted list. When an owner is mentioned, prefix with [Owner].\n\n"
    "## Open questions\nBulleted list. Omit the section if none.\n\n"
    "Transcript:\n{transcript}\n"
)


@dataclass
class Settings:
    language: str = "auto"
    model: str = "tiny"
    device: str = "auto"  # "auto", "cpu", or "cuda"
    auto_start: bool = True
    retention: int = -1  # days, -1 = forever
    theme: str = "dark"
    onboarding_complete: bool = False
    microphone: int = -1  # -1 = default device, otherwise device id
    save_audio_to_history: bool = False
    # UI settings
    show_popup: bool = True  # Show/hide the floating recording indicator
    # Hotkey settings
    hold_hotkey: str = "ctrl+win"
    hold_hotkey_enabled: bool = True
    toggle_hotkey: str = "ctrl+shift+win"
    toggle_hotkey_enabled: bool = False
    # Transcription settings
    prepend_space: bool = False  # Add leading space before pasted text
    # Recordings (Meetings feature)
    recordings_mic_device: Optional[str] = None
    recordings_loopback_device: Optional[str] = None
    recordings_auto_transcribe: bool = True
    recordings_auto_summarize: bool = False
    recordings_auto_rename_title: bool = True
    # LLM config for summarization (API key stored separately via services.recording.secrets)
    llm_preset: str = "ollama"
    llm_endpoint: str = "http://localhost:11434/v1"
    llm_model: str = "llama3.2"
    llm_prompt_template: str = DEFAULT_LLM_PROMPT


# The Settings dataclass above is the single schema for all settings: field
# names are the DB keys, defaults are the app defaults, and the camelCase
# aliases used over RPC are derived mechanically by to_camel_case(). Adding a
# setting = adding a field (plus RPC_SETTINGS_FIELDS if it is exposed on the
# main settings RPC surface).

# Hotkey fields are normalized before storage so stored values stay canonical.
_HOTKEY_FIELDS = {"hold_hotkey", "toggle_hotkey"}

# Settings exposed over the get_settings/update_settings RPC surface.
# Recordings/LLM settings are managed through the meetings.* RPC methods and
# are intentionally absent here.
RPC_SETTINGS_FIELDS = (
    "language",
    "model",
    "device",
    "auto_start",
    "retention",
    "theme",
    "onboarding_complete",
    "microphone",
    "save_audio_to_history",
    "show_popup",
    "hold_hotkey",
    "hold_hotkey_enabled",
    "toggle_hotkey",
    "toggle_hotkey_enabled",
    "prepend_space",
    "recordings_auto_rename_title",
)


def to_camel_case(name: str) -> str:
    head, *rest = name.split("_")
    return head + "".join(part.capitalize() for part in rest)


def settings_to_rpc(settings: "Settings") -> dict:
    """Render the RPC-exposed subset of Settings as a camelCase dict."""
    return {to_camel_case(name): getattr(settings, name) for name in RPC_SETTINGS_FIELDS}


def rpc_to_settings_kwargs(payload: dict) -> dict:
    """Map camelCase RPC keys back to Settings field names, dropping unknowns."""
    mapped = {}
    for name in RPC_SETTINGS_FIELDS:
        camel = to_camel_case(name)
        if camel in payload:
            mapped[name] = payload[camel]
    return mapped


def _serialize(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def _parse(raw: str, default):
    # bool check must precede int: bool is a subclass of int.
    if isinstance(default, bool):
        return raw == "true"
    if isinstance(default, int):
        return int(raw)
    return raw


class SettingsService:
    def __init__(self, db: DatabaseService):
        self.db = db
        self._cache: Optional[Settings] = None

    def get_settings(self) -> Settings:
        if self._cache:
            return self._cache

        values = {}
        for field in fields(Settings):
            raw = self.db.get_setting(field.name, None)
            values[field.name] = field.default if raw is None else _parse(raw, field.default)

        settings = Settings(**values)
        self._cache = settings
        return settings

    def update_settings(self, **kwargs) -> Settings:
        """Persist the given settings. Keys are Settings field names; None
        values mean "leave unchanged". Unknown keys raise before anything is
        written."""
        known = {field.name for field in fields(Settings)}
        unknown = set(kwargs) - known
        if unknown:
            raise TypeError(f"Unknown setting(s): {', '.join(sorted(unknown))}")

        for key, value in kwargs.items():
            if value is None:
                continue
            if key in _HOTKEY_FIELDS:
                value = normalize_hotkey(value)
            self.db.set_setting(key, _serialize(value))

        self._cache = None  # Invalidate cache
        return self.get_settings()

    def get_available_models(self) -> list:
        return WHISPER_MODELS

    def get_available_languages(self) -> list:
        return WHISPER_LANGUAGES

    def get_retention_options(self) -> dict:
        return RETENTION_OPTIONS

    def get_theme_options(self) -> list:
        return THEME_OPTIONS

    def get_device_options(self) -> list:
        return DEVICE_OPTIONS
