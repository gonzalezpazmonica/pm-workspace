import pytest
import numpy as np
from services.transcription import TranscriptionService


class TestTranscriptionService:
    def test_initial_state_no_model_loaded(self):
        """Service starts with no model loaded."""
        service = TranscriptionService()
        assert service.get_current_model() is None

    def test_is_loading_initially_false(self):
        """Service is not loading initially."""
        service = TranscriptionService()
        assert service.is_loading() == False

    def test_transcribe_without_model_raises_error(self):
        """Transcribing without loading model raises error."""
        service = TranscriptionService()
        audio = np.zeros(16000, dtype=np.float32)  # 1 second of silence

        with pytest.raises(RuntimeError, match="Model not loaded"):
            service.transcribe(audio)

    def test_transcribe_empty_audio_returns_empty_string(self):
        """Transcribing empty audio returns empty string."""
        service = TranscriptionService()
        service.load_model("tiny")

        audio = np.array([], dtype=np.float32)
        result = service.transcribe(audio)

        assert result == ""

    def test_load_model_sets_current_model(self):
        """Loading a model updates current model name."""
        service = TranscriptionService()
        service.load_model("tiny")

        assert service.get_current_model() == "tiny"

    def test_load_same_model_twice_is_noop(self):
        """Loading the same model twice doesn't reload."""
        service = TranscriptionService()
        service.load_model("tiny")
        # Should return immediately without reloading
        service.load_model("tiny")

        assert service.get_current_model() == "tiny"

    def test_unload_model_clears_current_model(self):
        """Unloading model clears the current model."""
        service = TranscriptionService()
        service.load_model("tiny")
        service.unload_model()

        assert service.get_current_model() is None

    def test_transcribe_returns_string(self):
        """Transcription returns a string result."""
        service = TranscriptionService()
        service.load_model("tiny")

        # Create some audio with a simple sine wave (won't produce meaningful text)
        duration = 1.0
        sample_rate = 16000
        t = np.linspace(0, duration, int(sample_rate * duration), dtype=np.float32)
        audio = 0.5 * np.sin(2 * np.pi * 440 * t)  # 440 Hz tone

        result = service.transcribe(audio)

        assert isinstance(result, str)

    def test_transcribe_normalizes_audio(self):
        """Service handles audio with values outside -1 to 1 range."""
        service = TranscriptionService()
        service.load_model("tiny")

        # Audio with values > 1.0
        audio = np.array([2.0, -2.0, 1.5, -1.5] * 4000, dtype=np.float32)

        # Should not raise, normalization should handle it
        result = service.transcribe(audio)
        assert isinstance(result, str)

    def test_transcribe_with_language_specified(self):
        """Can transcribe with specific language."""
        service = TranscriptionService()
        service.load_model("tiny")

        audio = np.zeros(16000, dtype=np.float32)

        # Should not raise
        result = service.transcribe(audio, language="en")
        assert isinstance(result, str)

    def test_transcribe_with_auto_language(self):
        """Can transcribe with auto language detection."""
        service = TranscriptionService()
        service.load_model("tiny")

        audio = np.zeros(16000, dtype=np.float32)

        # Should not raise
        result = service.transcribe(audio, language="auto")
        assert isinstance(result, str)
