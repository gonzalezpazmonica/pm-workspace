"""
ephemeral.py — Generación y validación de tokens HMAC-SHA256 para URLs efímeras.

Decisión D-5 de SPEC-AGENT-ARTIFACTS:
  export_artifact genera un token firmado con SAVIA_ARTIFACT_SECRET.
  El token contiene {artifact_id, expires_at, signature}.
  Verificable sin consultar base de datos.

Stdlib only: hmac, hashlib, json, base64 (sin dependencias externas).
Rule #26: lógica en Python, bash solo wrappers.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import time
from dataclasses import dataclass
from datetime import datetime, timezone


# ---------------------------------------------------------------------------
# Excepciones de dominio
# ---------------------------------------------------------------------------

class TokenExpiredError(Exception):
    """El token ha superado su TTL."""


class TokenInvalidError(Exception):
    """La firma del token no es válida o el payload está malformado."""


# ---------------------------------------------------------------------------
# Modelo
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class EphemeralToken:
    artifact_id: str
    expires_at: float        # Unix timestamp UTC
    signature: str           # hex de HMAC-SHA256


# ---------------------------------------------------------------------------
# Generación
# ---------------------------------------------------------------------------

_DEFAULT_TTL = 3600          # 1 hora
_ENV_SECRET = "SAVIA_ARTIFACT_SECRET"
_FALLBACK_DEV_SECRET = "dev-only-insecure-secret"


def _get_secret() -> bytes:
    """
    Lee SAVIA_ARTIFACT_SECRET del entorno.

    Admite fallback inseguro solo en tests (cuando la var empieza por 'test-').
    En producción sin el var, lanza EnvironmentError.
    """
    secret = os.environ.get(_ENV_SECRET, "")
    if not secret:
        # Fallback de dev explícito (tests deben setear SAVIA_ARTIFACT_SECRET=test-...)
        fallback = os.environ.get("SAVIA_ARTIFACT_SECRET_DEV_FALLBACK", "")
        if fallback:
            return fallback.encode()
        raise EnvironmentError(
            f"Variable de entorno {_ENV_SECRET} no configurada. "
            "Para desarrollo: export SAVIA_ARTIFACT_SECRET=test-dev-secret"
        )
    return secret.encode()


def generate_token(
    artifact_id: str,
    ttl_seconds: int = _DEFAULT_TTL,
    *,
    secret: bytes | None = None,
    _now: float | None = None,
) -> str:
    """
    Genera un token URL-safe que contiene artifact_id y expires_at firmados.

    Parameters
    ----------
    artifact_id:
        ID del artifact a exportar.
    ttl_seconds:
        Tiempo de vida en segundos (default 3600).
    secret:
        Clave HMAC. Si None, se lee de SAVIA_ARTIFACT_SECRET.
    _now:
        Timestamp de 'ahora' (inyectable en tests).

    Returns
    -------
    Token opaco URL-safe (base64url del JSON firmado).
    """
    key = secret if secret is not None else _get_secret()
    now = _now if _now is not None else time.time()
    expires_at = now + ttl_seconds

    payload_dict = {
        "artifact_id": artifact_id,
        "expires_at": expires_at,
    }
    payload_bytes = json.dumps(payload_dict, separators=(",", ":")).encode()
    signature = hmac.new(key, payload_bytes, hashlib.sha256).hexdigest()

    token_dict = {
        "p": payload_bytes.decode(),   # payload como string
        "s": signature,
    }
    token_json = json.dumps(token_dict, separators=(",", ":")).encode()
    return base64.urlsafe_b64encode(token_json).decode("ascii").rstrip("=")


# ---------------------------------------------------------------------------
# Validación
# ---------------------------------------------------------------------------

def validate_token(
    token: str,
    *,
    secret: bytes | None = None,
    _now: float | None = None,
) -> EphemeralToken:
    """
    Valida un token y retorna EphemeralToken si es correcto y no ha expirado.

    Raises
    ------
    TokenInvalidError:
        Si la firma no coincide o el payload está malformado.
    TokenExpiredError:
        Si el token ha superado su TTL.
    """
    key = secret if secret is not None else _get_secret()
    now = _now if _now is not None else time.time()

    # Decodificar base64url (padding opcional)
    try:
        padding = "=" * (-len(token) % 4)
        token_json = base64.urlsafe_b64decode(token + padding)
        token_dict: dict[str, str] = json.loads(token_json)
        payload_str: str = token_dict["p"]
        claimed_sig: str = token_dict["s"]
    except Exception as exc:
        raise TokenInvalidError(f"Token malformado: {exc}") from exc

    # Verificar firma (comparación en tiempo constante)
    payload_bytes = payload_str.encode()
    expected_sig = hmac.new(key, payload_bytes, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected_sig, claimed_sig):
        raise TokenInvalidError("Firma HMAC inválida")

    # Extraer payload
    try:
        payload_dict: dict[str, object] = json.loads(payload_str)
        artifact_id = str(payload_dict["artifact_id"])
        expires_at = float(payload_dict["expires_at"])  # type: ignore[arg-type]
    except Exception as exc:
        raise TokenInvalidError(f"Payload inválido: {exc}") from exc

    # Verificar expiración
    if now > expires_at:
        raise TokenExpiredError(
            f"Token expirado en {datetime.fromtimestamp(expires_at, tz=timezone.utc).isoformat()}"
        )

    return EphemeralToken(
        artifact_id=artifact_id,
        expires_at=expires_at,
        signature=claimed_sig,
    )


def expires_at_from_token(token: str, *, secret: bytes | None = None) -> datetime:
    """Retorna la fecha de expiración del token (puede estar expirado)."""
    et = validate_token(token, secret=secret, _now=0.0)  # _now=0 no expira nunca
    return datetime.fromtimestamp(et.expires_at, tz=timezone.utc)
