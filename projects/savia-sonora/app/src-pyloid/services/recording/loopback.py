"""Loopback discovery — the one seam over the platform-specific backends.

Three backends feed the system-audio device picker:
  * PortAudio device filtering on Linux (`loopback_linux`) — ALSA/JACK monitor
    devices, conservative fallback.
  * pactl/parec (`loopback_pulse`) — PipeWire/PulseAudio monitor sources; the
    path that actually works for capturing Chrome / Teams audio on Linux.
  * WASAPI output filtering on Windows (`loopback_windows`).

Callers (MeetingsController) see two operations: `list_sources()` to populate
the picker, and `build_source(device_id)` to open whatever the user picked.
The pactl ID range (PULSE_ID_BASE+N → source-name mapping) is a session cache
owned HERE — `build_source` must be called on the same instance that listed,
which is why this is a class and not free functions. A new platform backend
means editing this module only.
"""

from typing import Optional

from services.recording.audio_source import ParecAudioSource, SoundDeviceAudioSource
from services.recording.loopback_linux import _filter_linux_loopback
from services.recording.loopback_pulse import list_pulse_monitor_sources
from services.recording.loopback_windows import _filter_wasapi_loopback


def _is_windows() -> bool:
    import sys
    return sys.platform.startswith("win")


class LoopbackDiscovery:
    def __init__(self) -> None:
        # Session cache: PULSE_ID_BASE+N → PipeWire monitor source name.
        # Refreshed by list_sources() and read by build_source() so the user
        # picks an int id in the dropdown but we open a ParecAudioSource with
        # the actual name.
        self._pulse_monitor_by_id: dict[int, str] = {}

    def list_sources(self, devs: list, apis: list) -> list:
        """All loopback candidates from every backend. `devs`/`apis` are the
        caller's sounddevice query results (queried once, shared with mic
        enumeration).

        The PortAudio filters are conservative — they won't double-list
        anything that doesn't look like loopback — so running both platform
        filters unconditionally is safe."""
        loopback = _filter_linux_loopback(devs, apis) + _filter_wasapi_loopback(devs, apis)

        self._pulse_monitor_by_id = {}
        for entry in list_pulse_monitor_sources():
            self._pulse_monitor_by_id[entry["id"]] = entry["pulseSourceName"]
            loopback.append({
                "id": entry["id"],
                "name": entry["name"],
                "kind": entry["kind"],
                "hostApi": entry["hostApi"],
                "isDefault": entry["isDefault"],
            })
        return loopback

    def build_source(self, device_id: Optional[int]):
        """AudioSource for a loopback id previously returned by list_sources();
        None passes through (source not picked)."""
        if device_id is None:
            return None
        # Route PipeWire monitor sources through parec instead of PortAudio.
        pulse_name = self._pulse_monitor_by_id.get(device_id)
        if pulse_name is not None:
            return ParecAudioSource(source_name=pulse_name)
        return SoundDeviceAudioSource(
            device_id=device_id,
            # WASAPI loopback flag only matters on Windows; on Linux the
            # PortAudio device IS the monitor source, no flag needed.
            loopback=_is_windows(),
        )
