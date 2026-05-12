"""
mcp_server.py — MCP server ``savia-artifacts`` con las cuatro tools canónicas.

Decisión D-7 de SPEC-AGENT-ARTIFACTS:
  Expone save_artifact, load_artifact, list_artifacts, export_artifact
  como MCP tools accesibles desde cualquier frontend MCP-compatible.

Uso:
  python3 -m scripts.lib.artifacts.mcp_server          # stdin/stdout (FastMCP)
  python3 -m scripts.lib.artifacts.mcp_server --help

Dependencia: MCP SDK ≥ 1.0 (``mcp``). Pinado en requirements.txt.
Rule #26: lógica en Python. El server stdio es el entrypoint.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

from mcp.server.fastmcp import FastMCP

from scripts.lib.artifacts.store import ArtifactStore
from scripts.lib.artifacts.tools import (
    ArtifactContent,
    ArtifactRef,
    EphemeralURL,
    configure_store,
    export_artifact as _export_artifact,
    list_artifacts as _list_artifacts,
    load_artifact as _load_artifact,
    save_artifact as _save_artifact,
)
from scripts.lib.artifacts.store import ArtifactMetadata

# ---------------------------------------------------------------------------
# Inicialización del store desde env (configurable)
# ---------------------------------------------------------------------------

_BASE_DIR = Path(
    os.environ.get("SAVIA_ARTIFACTS_DIR", "output/artifacts")
)
_store = ArtifactStore(_BASE_DIR)
configure_store(_store)

# ---------------------------------------------------------------------------
# FastMCP server
# ---------------------------------------------------------------------------

mcp = FastMCP(
    name="savia-artifacts",
    instructions=(
        "Universal artifact toolset for Savia agents. "
        "Four canonical tools: save_artifact, load_artifact, list_artifacts, export_artifact. "
        "Artifacts are write-once, immutable, and confidentiality-scoped (N1-N4b). "
        "SPEC-AGENT-ARTIFACTS D-1 through D-8."
    ),
)


# ---------------------------------------------------------------------------
# Tool 1: save_artifact
# ---------------------------------------------------------------------------

@mcp.tool(
    name="save_artifact",
    description=(
        "Persist an artifact to disk and return a stable ArtifactRef. "
        "The trace JSONL records only the artifact_id, NOT the content. "
        "Returns: {artifact_id, run_id, created_at, sha256, name, confidentiality}."
    ),
)
def save_artifact(
    name: str,
    content: str,
    mime_type: str,
    run_id: str | None = None,
    description: str | None = None,
    agent_id: str | None = None,
    confidentiality: str = "N1",
) -> dict[str, Any]:
    """
    Save an artifact.

    Parameters
    ----------
    name:
        Logical name (e.g. ``report.pdf``).
    content:
        Content as UTF-8 string. Binary artifacts should be base64-encoded.
    mime_type:
        MIME type (e.g. ``text/csv``, ``application/pdf``, ``image/png``).
    run_id:
        Run identifier. Defaults to SAVIA_RUN_ID env var or a process-stable UUID.
    description:
        Optional human-readable description (shown in list_artifacts).
    agent_id:
        ID of the agent producing the artifact.
    confidentiality:
        Confidentiality level: ``N1`` (public), ``N3`` (user), ``N4`` (project),
        ``N4b`` (pm-only). Default ``N1``.
    """
    ref: ArtifactRef = _save_artifact(
        name=name,
        content=content,
        mime_type=mime_type,
        run_id=run_id,
        description=description,
        agent_id=agent_id,
        confidentiality=confidentiality,
        store=_store,
    )
    return ref.model_dump()


# ---------------------------------------------------------------------------
# Tool 2: load_artifact
# ---------------------------------------------------------------------------

@mcp.tool(
    name="load_artifact",
    description=(
        "Load an artifact by ID and return its content ready for injection "
        "into the conversation (RequestProcessor pattern, SPEC-AGENT-ARTIFACTS D-4). "
        "Binary artifacts are base64-encoded in the injection_block. "
        "Returns: {artifact_id, name, mime_type, injection_block, raw_b64}."
    ),
)
def load_artifact(
    artifact_id: str,
    provider: str | None = None,
) -> dict[str, Any]:
    """
    Load an artifact by its ID.

    Parameters
    ----------
    artifact_id:
        Artifact identifier returned by save_artifact.
    provider:
        Model provider for injection block format (``anthropic``, ``openai``, …).
        Defaults to SAVIA_PROVIDER env var.
    """
    ac: ArtifactContent = _load_artifact(
        artifact_id=artifact_id,
        provider=provider,
        store=_store,
    )
    # raw_bytes is not JSON-serializable: encode as base64 for MCP transport
    import base64
    result = {
        "artifact_id": ac.artifact_id,
        "name": ac.name,
        "mime_type": ac.mime_type,
        "injection_block": ac.injection_block,
        "raw_b64": base64.standard_b64encode(ac.raw_bytes).decode("ascii"),
    }
    return result


# ---------------------------------------------------------------------------
# Tool 3: list_artifacts
# ---------------------------------------------------------------------------

@mcp.tool(
    name="list_artifacts",
    description=(
        "List artifacts for a run, with metadata. "
        "Returns a JSON array of ArtifactMetadata objects sorted by created_at."
    ),
)
def list_artifacts(
    run_id: str | None = None,
    filter_mime_type: str | None = None,
) -> list[dict[str, Any]]:
    """
    List artifacts.

    Parameters
    ----------
    run_id:
        Run to list. Defaults to SAVIA_RUN_ID env var or current process run.
    filter_mime_type:
        Exact MIME type filter (e.g. ``text/csv``). None returns all types.
    """
    items: list[ArtifactMetadata] = _list_artifacts(
        run_id=run_id,
        filter_mime_type=filter_mime_type,
        store=_store,
    )
    return [m.model_dump() for m in items]


# ---------------------------------------------------------------------------
# Tool 4: export_artifact
# ---------------------------------------------------------------------------

@mcp.tool(
    name="export_artifact",
    description=(
        "Generate a signed ephemeral URL for external download of an artifact. "
        "The HMAC-SHA256 token is self-verifying (no DB needed) and expires after ttl_seconds. "
        "Returns: {url, expires_at, artifact_id, token}."
    ),
)
def export_artifact(
    artifact_id: str,
    ttl_seconds: int = 3600,
    base_url: str | None = None,
) -> dict[str, Any]:
    """
    Export an artifact as an ephemeral signed URL.

    Parameters
    ----------
    artifact_id:
        Artifact identifier to export.
    ttl_seconds:
        Token time-to-live in seconds. Default 3600 (1 hour).
    base_url:
        Base URL for the ephemeral server. Defaults to SAVIA_ARTIFACT_BASE_URL
        env var or ``http://localhost:8765/api/v1/ephemeral/artifacts``.
    """
    eu: EphemeralURL = _export_artifact(
        artifact_id=artifact_id,
        ttl_seconds=ttl_seconds,
        base_url=base_url,
        store=_store,
    )
    return eu.model_dump()


# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------

def main() -> None:
    """Arranca el MCP server en modo stdio (compatible con OpenCode / Claude Code)."""
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
