"""Tests for slice 4 + 5 — loopback device discovery (Linux monitor sources + Windows WASAPI).

The actual stream opening hits real audio hardware and is covered only by manual
smoke tests; here we exercise the pure filter logic that decides *which* devices
qualify as loopback sources. Both modules expose a private `_filter_loopback`
function that the public `list_loopback_sources()` feeds with real sounddevice
output — tests target the private function with fixture data.
"""

import pytest

from services.recording.loopback_linux import _filter_linux_loopback
from services.recording.loopback_windows import _filter_wasapi_loopback


# ---------- Linux: PipeWire / PulseAudio monitor sources ----------

class TestLinuxLoopbackFilter:
    def test_monitor_suffix_is_loopback(self):
        devices = [
            {"index": 0, "name": "Built-in Audio Analog Stereo", "max_input_channels": 0, "hostapi": 0},
            {"index": 1, "name": "Built-in Audio Analog Stereo.monitor", "max_input_channels": 2, "hostapi": 0},
        ]
        hostapis = [{"name": "ALSA"}]
        result = _filter_linux_loopback(devices, hostapis)
        assert len(result) == 1
        assert result[0]["id"] == 1
        assert result[0]["kind"] == "loopback"

    def test_monitor_of_prefix_is_loopback(self):
        devices = [
            {"index": 7, "name": "Monitor of Speakers", "max_input_channels": 2, "hostapi": 0},
        ]
        result = _filter_linux_loopback(devices, [{"name": "ALSA"}])
        assert len(result) == 1
        assert result[0]["id"] == 7

    def test_non_monitor_input_is_not_loopback(self):
        """A regular microphone should not show up in the loopback list."""
        devices = [
            {"index": 2, "name": "USB Microphone", "max_input_channels": 1, "hostapi": 0},
        ]
        result = _filter_linux_loopback(devices, [{"name": "ALSA"}])
        assert result == []

    def test_output_only_device_skipped(self):
        """Speakers (no input channels) cannot be tapped — different from .monitor."""
        devices = [
            {"index": 3, "name": "HDMI Output", "max_input_channels": 0, "hostapi": 0},
        ]
        result = _filter_linux_loopback(devices, [{"name": "ALSA"}])
        assert result == []

    def test_hostapi_name_attached(self):
        devices = [
            {"index": 5, "name": "speaker.monitor", "max_input_channels": 2, "hostapi": 1},
        ]
        hostapis = [{"name": "ALSA"}, {"name": "JACK"}]
        result = _filter_linux_loopback(devices, hostapis)
        assert result[0]["hostApi"] == "JACK"

    def test_case_insensitive_match(self):
        devices = [
            {"index": 9, "name": "MONITOR OF Built-in", "max_input_channels": 2, "hostapi": 0},
            {"index": 10, "name": "thing.MONITOR", "max_input_channels": 2, "hostapi": 0},
        ]
        result = _filter_linux_loopback(devices, [{"name": "ALSA"}])
        ids = {r["id"] for r in result}
        assert ids == {9, 10}

    def test_returns_audiosource_shape(self):
        """Frontend expects {id, name, kind, hostApi, isDefault} per types.ts."""
        devices = [
            {"index": 1, "name": "speakers.monitor", "max_input_channels": 2, "hostapi": 0},
        ]
        result = _filter_linux_loopback(devices, [{"name": "ALSA"}])
        d = result[0]
        for key in ("id", "name", "kind", "hostApi", "isDefault"):
            assert key in d, f"missing key {key} in result: {d}"


# ---------- Windows: WASAPI loopback ----------

class TestWindowsWasapiFilter:
    def test_wasapi_outputs_become_loopback_sources(self):
        """On Windows every WASAPI output device can be loopback-recorded."""
        devices = [
            {"index": 0, "name": "Speakers (Realtek)", "max_input_channels": 0,
             "max_output_channels": 2, "hostapi": 1},
            {"index": 1, "name": "Headphones", "max_input_channels": 0,
             "max_output_channels": 2, "hostapi": 1},
        ]
        hostapis = [
            {"name": "MME", "devices": [0, 1]},
            {"name": "Windows WASAPI", "devices": [0, 1]},
        ]
        result = _filter_wasapi_loopback(devices, hostapis)
        names = {r["name"] for r in result}
        assert "Speakers (Realtek)" in names
        assert "Headphones" in names
        for r in result:
            assert r["kind"] == "loopback"
            assert r["hostApi"] == "Windows WASAPI"

    def test_skips_non_wasapi_outputs(self):
        """MME / DirectSound outputs do not support loopback the same way."""
        devices = [
            {"index": 0, "name": "Speakers", "max_input_channels": 0,
             "max_output_channels": 2, "hostapi": 0},  # MME — skip
        ]
        hostapis = [
            {"name": "MME", "devices": [0]},
        ]
        result = _filter_wasapi_loopback(devices, hostapis)
        assert result == []

    def test_skips_input_only_under_wasapi(self):
        """A WASAPI mic (input-only) is not a loopback source."""
        devices = [
            {"index": 0, "name": "Microphone (USB)", "max_input_channels": 2,
             "max_output_channels": 0, "hostapi": 0},
        ]
        hostapis = [
            {"name": "Windows WASAPI", "devices": [0]},
        ]
        result = _filter_wasapi_loopback(devices, hostapis)
        assert result == []

    def test_no_wasapi_host_returns_empty(self):
        """Older Windows machines without WASAPI return nothing rather than crashing."""
        devices = [{"index": 0, "name": "Speakers", "max_input_channels": 0,
                    "max_output_channels": 2, "hostapi": 0}]
        hostapis = [{"name": "MME", "devices": [0]}]
        result = _filter_wasapi_loopback(devices, hostapis)
        assert result == []

    def test_returns_audiosource_shape(self):
        devices = [{"index": 0, "name": "Speakers", "max_input_channels": 0,
                    "max_output_channels": 2, "hostapi": 0}]
        hostapis = [{"name": "Windows WASAPI", "devices": [0]}]
        result = _filter_wasapi_loopback(devices, hostapis)
        d = result[0]
        for key in ("id", "name", "kind", "hostApi", "isDefault"):
            assert key in d
