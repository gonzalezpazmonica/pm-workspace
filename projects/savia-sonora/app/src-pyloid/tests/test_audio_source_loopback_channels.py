"""Regression tests for the WASAPI loopback channel-count fallback.

A real Windows user reported every meeting-recording attempt produced a
44-byte WAV (header only, zero audio frames) and the log carried:

    [WARN] [meeting] preview start failed |
        {"error": "Could not open audio device 8: Error opening InputStream:
         Invalid number of channels [PaErrorCode -9998]"}

PortAudio's `paInvalidChannelCount` (-9998). WASAPI loopback / Stereo Mix
devices on Windows are stereo-only — `sd.InputStream(channels=1, ...)` is
rejected. The fix in `audio_source.start()` is to consult the device's
`max_input_channels` and, on loopback, open at the device-native channel
count first (the existing callback already downmixes to mono).

These tests fake `sounddevice` to assert the fallback iterates as expected
without touching real audio hardware.
"""

from __future__ import annotations

import sys
import types
from typing import Any

import numpy as np
import pytest


@pytest.fixture
def fake_sd(monkeypatch):
    """Install a fake `sounddevice` module under sys.modules. Returns the
    module so individual tests can configure its `InputStream` behaviour
    and inspect the resulting call log."""
    sd = types.ModuleType("sounddevice")

    sd.calls: list[dict[str, Any]] = []
    sd.fail_for_channels: set[int] = set()

    def query_devices(idx):
        # Three stub devices modeled after a real Windows enumeration:
        #
        # - id=8 is a WASAPI loopback target. These are OUTPUT devices
        #   (speakers) that PortAudio captures via WasapiSettings(loopback=True),
        #   so they report max_input_channels=0 and the real stereo count
        #   shows up under max_output_channels. The previous version of this
        #   test used max_input_channels=2 — that was wrong and let a buggy
        #   fix pass; the live Windows error was exactly what max_input_channels=0
        #   would produce.
        # - id=12 is a mono "What U Hear" style loopback (rare but exists).
        # - id=21 is a normal mono mic.
        if idx == 8:
            return {
                "name": "Speakers (Realtek) [Loopback]",
                "max_input_channels": 0,
                "max_output_channels": 2,
                "default_samplerate": 48000.0,
            }
        if idx == 12:
            return {
                "name": "Mono Loopback",
                "max_input_channels": 0,
                "max_output_channels": 1,
                "default_samplerate": 48000.0,
            }
        if idx == 21:
            return {
                "name": "Microphone Array",
                "max_input_channels": 1,
                "max_output_channels": 0,
                "default_samplerate": 16000.0,
            }
        return {
            "max_input_channels": 1,
            "max_output_channels": 0,
            "default_samplerate": 16000.0,
        }

    sd.query_devices = query_devices

    class WasapiSettings:
        def __init__(self, loopback: bool = False) -> None:
            self.loopback = loopback

    sd.WasapiSettings = WasapiSettings

    class _FakeStream:
        def __init__(self, **kwargs):
            sd.calls.append(kwargs)
            if kwargs.get("channels") in sd.fail_for_channels:
                raise RuntimeError(
                    "Error opening InputStream: Invalid number of channels "
                    "[PaErrorCode -9998]"
                )
            self._started = False

        def start(self):
            self._started = True

        def stop(self):
            self._started = False

        def close(self):
            pass

    sd.InputStream = _FakeStream

    monkeypatch.setitem(sys.modules, "sounddevice", sd)
    return sd


def _on_frames(_arr: np.ndarray) -> None:
    pass


class TestLoopbackChannelFallback:
    def test_loopback_opens_at_output_channel_count(self, fake_sd):
        """Loopback device should be opened at max_output_channels (2 for a
        stereo speaker), not max_input_channels (which is 0 for outputs).

        This is the regression that the live Windows user hit: the previous
        fix read max_input_channels, got 0, clamped to 1, and PortAudio still
        rejected channels=1 with PaErrorCode -9998."""
        from services.recording.audio_source import SoundDeviceAudioSource

        src = SoundDeviceAudioSource(device_id=8, loopback=True)
        src.start(_on_frames)
        # First (and only successful) call should ask for stereo.
        assert fake_sd.calls[0]["channels"] == 2, (
            f"expected channels=2 (max_output_channels), got "
            f"{fake_sd.calls[0]['channels']}; full call log: {fake_sd.calls}"
        )
        assert fake_sd.calls[0]["device"] == 8
        src.stop()

    def test_mic_keeps_mono_open(self, fake_sd):
        """Plain mic open keeps the prior channels=1 default."""
        from services.recording.audio_source import SoundDeviceAudioSource

        src = SoundDeviceAudioSource(device_id=21, loopback=False)
        src.start(_on_frames)
        assert fake_sd.calls[0]["channels"] == 1
        assert fake_sd.calls[0]["device"] == 21
        src.stop()

    def test_loopback_handles_mono_output_device(self, fake_sd):
        """Rare case: a 'What U Hear' style loopback that's mono. We should
        still pick max_output_channels (1) rather than blindly forcing 2."""
        from services.recording.audio_source import SoundDeviceAudioSource

        src = SoundDeviceAudioSource(device_id=12, loopback=True)
        src.start(_on_frames)
        assert fake_sd.calls[0]["channels"] == 1
        assert fake_sd.calls[0]["device"] == 12
        src.stop()

    def test_loopback_falls_back_through_candidate_list(self, fake_sd):
        """If the device-native channel count is rejected, the iteration
        should keep trying — output count → input count → mono — before
        giving up."""
        from services.recording.audio_source import SoundDeviceAudioSource

        # Reject the obvious answer (stereo on the speaker) — this also
        # rejects 0 (input channels for a loopback target). Iteration should
        # land on channels=1 as the last viable option.
        fake_sd.fail_for_channels = {2, 0}
        src = SoundDeviceAudioSource(device_id=8, loopback=True)
        src.start(_on_frames)
        opened = next(c for c in fake_sd.calls if c["channels"] == 1)
        assert opened["device"] == 8
        src.stop()

    def test_loopback_passes_wasapi_loopback_extra_settings(self, fake_sd):
        """Make sure the WasapiSettings(loopback=True) flag is still attached
        on Windows (regression guard against accidentally dropping it)."""
        from services.recording.audio_source import SoundDeviceAudioSource

        src = SoundDeviceAudioSource(device_id=8, loopback=True)
        src.start(_on_frames)
        extra = fake_sd.calls[0].get("extra_settings")
        assert extra is not None
        assert getattr(extra, "loopback", False) is True
        src.stop()

    def test_loopback_raises_when_every_attempt_fails(self, fake_sd):
        """If every channel count fails, raise so the caller's WARN message
        surfaces the real PortAudio error."""
        from services.recording.audio_source import SoundDeviceAudioSource

        fake_sd.fail_for_channels = {0, 1, 2}
        src = SoundDeviceAudioSource(device_id=8, loopback=True)
        with pytest.raises(RuntimeError, match="Could not open audio device 8"):
            src.start(_on_frames)
