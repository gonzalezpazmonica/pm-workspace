"""Windows WASAPI loopback discovery.

On Windows every output device under the WASAPI host API can be recorded via
loopback (`extra_settings=sd.WasapiSettings(loopback=True)`). We list those
outputs and present them as loopback sources.

MME / DirectSound / WDM-KS hosts are skipped — they don't support the same
loopback flag and we don't want to mislead the UI.
"""

from __future__ import annotations

from typing import Any


_WASAPI = "Windows WASAPI"


def _filter_wasapi_loopback(
    devices: list[dict[str, Any]],
    hostapis: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    # Locate the WASAPI host API; if absent we have nothing to offer.
    wasapi_index = None
    for i, api in enumerate(hostapis):
        if api.get("name") == _WASAPI:
            wasapi_index = i
            break
    if wasapi_index is None:
        return []

    out: list[dict[str, Any]] = []
    for dev in devices:
        if dev.get("hostapi") != wasapi_index:
            continue
        if dev.get("max_output_channels", 0) <= 0:
            continue
        out.append({
            "id": int(dev.get("index", 0)),
            "name": str(dev.get("name", "")),
            "kind": "loopback",
            "hostApi": _WASAPI,
            "isDefault": False,
        })
    return out


def list_loopback_sources() -> list[dict[str, Any]]:  # pragma: no cover - hits real hw
    import sounddevice as sd
    devs = [{**dict(d), "index": i} for i, d in enumerate(sd.query_devices())]
    apis = [dict(a) for a in sd.query_hostapis()]
    return _filter_wasapi_loopback(devs, apis)
