"""Drift guards for the settings RPC surface.

The Settings dataclass is the single schema (services/settings.py); these
tests pin the derived pieces together so a new setting can't silently miss
one layer — the failure mode that broke the prependSpace toggle (exposed in
get_settings but absent from server.update_settings's signature).
"""

import inspect
from dataclasses import fields

import pytest

from services.settings import (
    RPC_SETTINGS_FIELDS,
    Settings,
    rpc_to_settings_kwargs,
    settings_to_rpc,
    to_camel_case,
)


class TestCamelCase:
    def test_single_word_unchanged(self):
        assert to_camel_case("language") == "language"

    def test_multi_word(self):
        assert to_camel_case("auto_start") == "autoStart"
        assert to_camel_case("recordings_auto_rename_title") == "recordingsAutoRenameTitle"


class TestSchemaConsistency:
    def test_rpc_fields_are_real_settings_fields(self):
        names = {f.name for f in fields(Settings)}
        for name in RPC_SETTINGS_FIELDS:
            assert name in names, f"RPC_SETTINGS_FIELDS lists unknown field {name}"

    def test_settings_to_rpc_uses_camel_aliases(self):
        d = settings_to_rpc(Settings())
        assert set(d) == {to_camel_case(n) for n in RPC_SETTINGS_FIELDS}
        assert "autoStart" in d
        assert "prependSpace" in d  # the field the old hand-written maps lost

    def test_rpc_kwargs_round_trip(self):
        payload = settings_to_rpc(Settings(prepend_space=True, model="base"))
        mapped = rpc_to_settings_kwargs(payload)
        assert mapped["prepend_space"] is True
        assert mapped["model"] == "base"
        assert set(mapped) == set(RPC_SETTINGS_FIELDS)

    def test_rpc_kwargs_drops_unknown_keys(self):
        mapped = rpc_to_settings_kwargs({"notASetting": 1, "model": "tiny"})
        assert mapped == {"model": "tiny"}


class TestServerSignatureCoversSchema:
    """server.update_settings declares explicit keyword params (the RPC
    contract); every RPC-exposed setting must appear there or the frontend
    can't set it."""

    def test_every_rpc_field_is_a_server_param(self):
        server = pytest.importorskip("server")
        params = set(inspect.signature(server.update_settings).parameters)
        missing = [
            to_camel_case(n) for n in RPC_SETTINGS_FIELDS
            if to_camel_case(n) not in params
        ]
        assert not missing, f"server.update_settings missing params: {missing}"
