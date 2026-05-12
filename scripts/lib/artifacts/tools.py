"""
tools.py — Las cuatro tools canónicas del toolset de artifacts.

Decisión D-1 de SPEC-AGENT-ARTIFACTS:
  save_artifact, load_artifact, list_artifacts, export_artifact.
  Funciones puras testeables. El ArtifactStore se inyecta vía parámetro
  o se obtiene del singleton del proceso (configurado por cli.py / tests).

Rule #26: lógica en Python, bash solo wrappers.
"""
from __future__ import annotations

import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from pydantic import BaseModel, Field

from scripts.lib.artifacts.ephemeral import generate_token
from scripts.lib.artifacts.request_processor import build_injection_block
from scripts.lib.artifacts.store import ArtifactMetadata, ArtifactStore


# ---------------------------------------------------------------------------
# Modelos de retorno públicos
# ---------------------------------------------------------------------------

class ArtifactRef(BaseModel):
    """Referencia devuelta por save_artifact."""

    artifact_id: str
    run_id: str
    created_at: str
    sha256: str
    name: str
    confidentiality: str

    model_config = {"frozen": True}


class ArtifactContent(BaseModel):
    """Contenido devuelto por load_artifact con bloque de inyección."""

    artifact_id: str
    name: str
    mime_type: str
    injection_block: dict[str, Any]     # bloque listo para mensajes
    raw_bytes: bytes                     # bytes originales para pipelines internos

    model_config = {"frozen": True}


class EphemeralURL(BaseModel):
    """URL efímera devuelta por export_artifact."""

    url: str
    expires_at: str          # ISO-8601
    artifact_id: str
    token: str               # token HMAC opaco

    model_config = {"frozen": True}


# ---------------------------------------------------------------------------
# Singleton de store (configurable, reemplazable en tests)
# ---------------------------------------------------------------------------

_DEFAULT_BASE = Path("output/artifacts")
_store: ArtifactStore | None = None


def get_store() -> ArtifactStore:
    global _store
    if _store is None:
        _store = ArtifactStore(_DEFAULT_BASE)
    return _store


def configure_store(store: ArtifactStore) -> None:
    """Permite inyectar un store distinto (tests, cli, mcp server)."""
    global _store
    _store = store


# ---------------------------------------------------------------------------
# Tool 1: save_artifact
# ---------------------------------------------------------------------------

def save_artifact(
    name: str,
    content: bytes | str,
    mime_type: str,
    *,
    run_id: str | None = None,
    description: str | None = None,
    agent_id: str | None = None,
    confidentiality: str = "N1",
    store: ArtifactStore | None = None,
) -> ArtifactRef:
    """
    Persiste un artifact y devuelve una referencia estable.

    La traza JSONL debe registrar solo el ArtifactRef, NO el contenido.

    Parameters
    ----------
    name:
        Nombre lógico del artifact (e.g. "report.pdf").
    content:
        Contenido. bytes para binarios, str para texto.
    mime_type:
        MIME type (e.g. "text/csv", "application/pdf", "image/png").
    run_id:
        ID del run actual. Si None, se genera uno desde env SAVIA_RUN_ID o UUID.
    description:
        Descripción opcional para list_artifacts.
    agent_id:
        ID del agente que produce el artifact.
    confidentiality:
        Nivel de confidencialidad ("N1", "N3", "N4", "N4b").
    store:
        Store a usar. Si None, se usa el singleton.

    Returns
    -------
    ArtifactRef con artifact_id, run_id, sha256, created_at.
    """
    effective_store = store or get_store()
    effective_run_id = run_id or os.environ.get("SAVIA_RUN_ID") or _default_run_id()

    meta = effective_store.save(
        run_id=effective_run_id,
        name=name,
        content=content,
        mime_type=mime_type,
        description=description,
        agent_id=agent_id,
        confidentiality=confidentiality,
    )

    return ArtifactRef(
        artifact_id=meta.artifact_id,
        run_id=meta.run_id,
        created_at=meta.created_at,
        sha256=meta.sha256,
        name=meta.name,
        confidentiality=meta.confidentiality,
    )


# ---------------------------------------------------------------------------
# Tool 2: load_artifact
# ---------------------------------------------------------------------------

def load_artifact(
    artifact_id: str,
    *,
    provider: str | None = None,
    store: ArtifactStore | None = None,
) -> ArtifactContent:
    """
    Carga un artifact e inyecta el contenido vía RequestProcessor.

    El bloque de inyección resultante es adecuado para incluirse en la lista
    de content blocks del siguiente mensaje al modelo.

    Parameters
    ----------
    artifact_id:
        ID del artifact (devuelto por save_artifact).
    provider:
        Proveedor del modelo ("anthropic", "openai", …). Si None, se detecta
        desde env SAVIA_PROVIDER.
    store:
        Store a usar. Si None, se usa el singleton.

    Returns
    -------
    ArtifactContent con injection_block y raw_bytes.
    """
    effective_store = store or get_store()
    raw_bytes, meta = effective_store.load_content(artifact_id)

    block = build_injection_block(
        content=raw_bytes,
        mime_type=meta.mime_type,
        artifact_name=meta.name,
        provider=provider,
    )

    return ArtifactContent(
        artifact_id=artifact_id,
        name=meta.name,
        mime_type=meta.mime_type,
        injection_block=block,
        raw_bytes=raw_bytes,
    )


# ---------------------------------------------------------------------------
# Tool 3: list_artifacts
# ---------------------------------------------------------------------------

def list_artifacts(
    run_id: str | None = None,
    filter_mime_type: str | None = None,
    *,
    store: ArtifactStore | None = None,
) -> list[ArtifactMetadata]:
    """
    Enumera artifacts de un run con su metadata.

    Parameters
    ----------
    run_id:
        Run a listar. Si None, se usa SAVIA_RUN_ID del entorno.
    filter_mime_type:
        Filtro exacto por MIME type. Ej.: "text/csv".
    store:
        Store a usar. Si None, se usa el singleton.

    Returns
    -------
    Lista de ArtifactMetadata ordenada por created_at ascendente.
    """
    effective_store = store or get_store()
    effective_run_id = run_id or os.environ.get("SAVIA_RUN_ID") or _default_run_id()
    return effective_store.list_by_run(effective_run_id, filter_mime_type)


# ---------------------------------------------------------------------------
# Tool 4: export_artifact
# ---------------------------------------------------------------------------

def export_artifact(
    artifact_id: str,
    ttl_seconds: int = 3600,
    *,
    base_url: str | None = None,
    secret: bytes | None = None,
    store: ArtifactStore | None = None,
) -> EphemeralURL:
    """
    Genera una URL efímera firmada para descarga externa del artifact.

    El token HMAC-SHA256 contiene {artifact_id, expires_at}. Verificable
    sin base de datos. Firmado con SAVIA_ARTIFACT_SECRET.

    Parameters
    ----------
    artifact_id:
        ID del artifact a exportar.
    ttl_seconds:
        Tiempo de vida del token en segundos. Default 3600.
    base_url:
        URL base del servidor de artifacts. Si None se usa
        SAVIA_ARTIFACT_BASE_URL o un placeholder de desarrollo.
    secret:
        Clave HMAC (para tests). Si None, se usa SAVIA_ARTIFACT_SECRET.
    store:
        Store a usar. Si None, se usa el singleton (para verificar existencia).

    Returns
    -------
    EphemeralURL con url, expires_at (ISO-8601), artifact_id, token.
    """
    effective_store = store or get_store()

    # Verificar que el artifact existe antes de generar el token
    meta = effective_store.get_metadata(artifact_id)

    token = generate_token(artifact_id, ttl_seconds, secret=secret)

    effective_base_url = (
        base_url
        or os.environ.get("SAVIA_ARTIFACT_BASE_URL")
        or "http://localhost:8765/api/v1/ephemeral/artifacts"
    )
    url = f"{effective_base_url}/{token}"

    from scripts.lib.artifacts.ephemeral import expires_at_from_token
    if secret is not None:
        expires_dt = expires_at_from_token(token, secret=secret)
    else:
        expires_dt = expires_at_from_token(token)

    return EphemeralURL(
        url=url,
        expires_at=expires_dt.isoformat(),
        artifact_id=artifact_id,
        token=token,
    )


# ---------------------------------------------------------------------------
# Helpers internos
# ---------------------------------------------------------------------------

_cached_run_id: str | None = None


def _default_run_id() -> str:
    """Genera un run_id de proceso único (estable dentro del mismo proceso)."""
    global _cached_run_id
    if _cached_run_id is None:
        import uuid
        _cached_run_id = "run_" + uuid.uuid4().hex[:12]
    return _cached_run_id
