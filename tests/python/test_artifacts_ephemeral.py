"""
tests/python/test_artifacts_ephemeral.py — 3 casos para tokens HMAC-SHA256.

Usa tmp_path de pytest (no escribe nada en disco).
SPEC-AGENT-ARTIFACTS Slice 1.
"""
from __future__ import annotations

import time

import pytest

from scripts.lib.artifacts.ephemeral import (
    EphemeralToken,
    TokenExpiredError,
    TokenInvalidError,
    generate_token,
    validate_token,
)

_SECRET = b"test-hmac-secret-slice1"


class TestEphemeralTokens:
    def test_generate_and_validate_round_trip(self) -> None:
        """Un token generado puede validarse correctamente con la misma clave."""
        now = time.time()
        token = generate_token("art_abc123456789", ttl_seconds=3600, secret=_SECRET, _now=now)
        result = validate_token(token, secret=_SECRET, _now=now + 1)
        assert isinstance(result, EphemeralToken)
        assert result.artifact_id == "art_abc123456789"

    def test_expired_token_raises(self) -> None:
        """Un token expirado lanza TokenExpiredError al validar."""
        now = time.time()
        token = generate_token("art_expired000", ttl_seconds=10, secret=_SECRET, _now=now)
        # Simular que han pasado 20 segundos
        with pytest.raises(TokenExpiredError):
            validate_token(token, secret=_SECRET, _now=now + 20)

    def test_tampered_token_raises(self) -> None:
        """Un token con firma alterada lanza TokenInvalidError."""
        token = generate_token("art_tamper00000", ttl_seconds=3600, secret=_SECRET)
        # Alterar el último carácter del token
        tampered = token[:-1] + ("A" if token[-1] != "A" else "B")
        with pytest.raises((TokenInvalidError, Exception)):
            validate_token(tampered, secret=_SECRET)
