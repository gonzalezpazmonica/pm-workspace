import pytest
import numpy as np
from services.audio import AudioService


def _has_input_device() -> bool:
    try:
        import sounddevice as sd
        sd.query_devices(kind="input")
        return True
    except Exception:
        return False


requires_input_device = pytest.mark.skipif(
    not _has_input_device(),
    reason="No audio input device available (headless CI)",
)


class TestAudioService:
    def test_initial_state_not_recording(self):
        """Audio service starts in non-recording state."""
        service = AudioService()
        assert service.is_recording() == False

    @requires_input_device
    def test_start_recording_changes_state(self):
        """Starting recording changes state to recording."""
        service = AudioService()
        service.start_recording()

        assert service.is_recording() == True

        # Cleanup
        service.stop_recording()

    @requires_input_device
    def test_stop_recording_changes_state(self):
        """Stopping recording changes state back to not recording."""
        service = AudioService()
        service.start_recording()
        service.stop_recording()

        assert service.is_recording() == False

    @requires_input_device
    def test_stop_recording_returns_numpy_array(self):
        """Stopping recording returns numpy array of audio data."""
        service = AudioService()
        service.start_recording()

        # Brief recording
        import time
        time.sleep(0.1)

        audio = service.stop_recording()

        assert isinstance(audio, np.ndarray)
        assert audio.dtype == np.float32

    def test_stop_without_start_returns_empty_array(self):
        """Stopping without starting returns empty array."""
        service = AudioService()
        audio = service.stop_recording()

        assert isinstance(audio, np.ndarray)
        assert len(audio) == 0

    @requires_input_device
    def test_start_twice_is_idempotent(self):
        """Starting recording twice doesn't cause issues."""
        service = AudioService()
        service.start_recording()
        service.start_recording()  # Should not error

        assert service.is_recording() == True

        # Cleanup
        service.stop_recording()

    def test_sample_rate_is_16khz(self):
        """Audio is recorded at 16kHz for Whisper compatibility.

        Renamed to TARGET_SAMPLE_RATE in fix d5ecc49 when the audio service
        gained a fallback path for devices that don't natively support 16kHz.
        The target is still 16kHz; the actual rate may differ at the device
        boundary and gets resampled before transcription.
        """
        assert AudioService.TARGET_SAMPLE_RATE == 16000

    def test_channels_is_mono(self):
        """Audio is recorded in mono."""
        assert AudioService.CHANNELS == 1

    @requires_input_device
    def test_amplitude_callback_is_called(self):
        """Amplitude callback receives values during recording."""
        service = AudioService()
        amplitudes = []

        def callback(amp):
            amplitudes.append(amp)

        service.set_amplitude_callback(callback)
        service.start_recording()

        import time
        time.sleep(0.2)

        service.stop_recording()

        # Should have received some amplitude values
        assert len(amplitudes) > 0
        # Amplitudes should be floats
        assert all(isinstance(a, float) for a in amplitudes)

    def test_get_input_devices_returns_list(self):
        """Can get list of available input devices."""
        devices = AudioService.get_input_devices()

        assert isinstance(devices, list)
        # Each device should have id, name, channels
        for device in devices:
            assert "id" in device
            assert "name" in device
            assert "channels" in device
