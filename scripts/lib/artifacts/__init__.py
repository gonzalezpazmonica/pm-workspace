"""
scripts/lib/artifacts — Toolset universal para outputs de agentes con URLs efímeras.

Slice 1: cuatro tools canónicas, storage, RequestProcessor, ephemeral tokens.
SPEC-AGENT-ARTIFACTS, Rule #26 Language Boundaries.
"""
from __future__ import annotations

from scripts.lib.artifacts.tools import (
    ArtifactContent,
    ArtifactMetadata,
    ArtifactRef,
    EphemeralURL,
    export_artifact,
    list_artifacts,
    load_artifact,
    save_artifact,
)

__all__ = [
    "save_artifact",
    "load_artifact",
    "list_artifacts",
    "export_artifact",
    "ArtifactRef",
    "ArtifactContent",
    "ArtifactMetadata",
    "EphemeralURL",
]
