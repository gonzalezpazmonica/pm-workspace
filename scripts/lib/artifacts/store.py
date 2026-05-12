"""
store.py — Gestión del directorio output/artifacts/{level}/{run_id}/{artifact_id}/.

Convención SPEC-AGENT-ARTIFACTS §2.2:
  output/artifacts/
  ├── N1/{run_id}/{artifact_id}/content
  │                              metadata.yaml
  ├── N3/{run_id}/{artifact_id}/...
  └── N4/{run_id}/{artifact_id}/...

Rule #26: lógica en Python, bash solo wrappers.
"""
from __future__ import annotations

import hashlib
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml
from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Modelos de datos
# ---------------------------------------------------------------------------

class ArtifactMetadata(BaseModel):
    """Representación en memoria de metadata.yaml de un artifact."""

    artifact_id: str
    run_id: str
    name: str
    mime_type: str
    sha256: str
    created_at: str          # ISO-8601
    agent_id: str | None = None
    confidentiality: str = "N1"
    description: str | None = None

    model_config = {"frozen": True}


# ---------------------------------------------------------------------------
# ArtifactStore
# ---------------------------------------------------------------------------

class ArtifactStore:
    """
    Gestiona el directorio raíz de artifacts.

    Parameters
    ----------
    base_dir:
        Raíz del directorio de artifacts. En producción = output/artifacts/
        En tests se inyecta via tmp_path (NUNCA escribir en output/ real).
    """

    def __init__(self, base_dir: Path) -> None:
        self._base = base_dir

    # ------------------------------------------------------------------
    # Escritura
    # ------------------------------------------------------------------

    def save(
        self,
        *,
        run_id: str,
        name: str,
        content: bytes | str,
        mime_type: str,
        description: str | None = None,
        agent_id: str | None = None,
        confidentiality: str = "N1",
    ) -> ArtifactMetadata:
        """
        Persiste un artifact y su metadata.yaml.

        Returns
        -------
        ArtifactMetadata con los campos definitivos (artifact_id, sha256…).
        """
        artifact_id = _generate_id()
        raw: bytes = content.encode() if isinstance(content, str) else content
        sha256 = hashlib.sha256(raw).hexdigest()
        created_at = datetime.now(tz=timezone.utc).isoformat()

        artifact_dir = self._artifact_dir(confidentiality, run_id, artifact_id)
        artifact_dir.mkdir(parents=True, exist_ok=True)

        # Contenido
        (artifact_dir / "content").write_bytes(raw)

        # metadata.yaml
        meta = ArtifactMetadata(
            artifact_id=artifact_id,
            run_id=run_id,
            name=name,
            mime_type=mime_type,
            sha256=sha256,
            created_at=created_at,
            agent_id=agent_id,
            confidentiality=confidentiality,
            description=description,
        )
        _write_metadata(artifact_dir / "metadata.yaml", meta)

        return meta

    # ------------------------------------------------------------------
    # Lectura
    # ------------------------------------------------------------------

    def load_content(self, artifact_id: str) -> tuple[bytes, ArtifactMetadata]:
        """
        Devuelve (contenido, metadata) de un artifact dado su artifact_id.

        Raises
        ------
        FileNotFoundError si el artifact_id no existe.
        """
        artifact_dir = self._find_artifact_dir(artifact_id)
        content = (artifact_dir / "content").read_bytes()
        meta = _read_metadata(artifact_dir / "metadata.yaml")
        return content, meta

    def get_metadata(self, artifact_id: str) -> ArtifactMetadata:
        """Retorna solo la metadata, sin leer el contenido."""
        artifact_dir = self._find_artifact_dir(artifact_id)
        return _read_metadata(artifact_dir / "metadata.yaml")

    # ------------------------------------------------------------------
    # Listado
    # ------------------------------------------------------------------

    def list_by_run(
        self,
        run_id: str,
        filter_mime_type: str | None = None,
    ) -> list[ArtifactMetadata]:
        """Lista todos los artifacts de un run_id."""
        results: list[ArtifactMetadata] = []

        if not self._base.exists():
            return results

        # Buscar en todos los niveles de confidencialidad
        for level_dir in self._base.iterdir():
            if not level_dir.is_dir():
                continue
            run_dir = level_dir / run_id
            if not run_dir.exists():
                continue
            for artifact_dir in run_dir.iterdir():
                if not artifact_dir.is_dir():
                    continue
                meta_path = artifact_dir / "metadata.yaml"
                if not meta_path.exists():
                    continue
                meta = _read_metadata(meta_path)
                if filter_mime_type and meta.mime_type != filter_mime_type:
                    continue
                results.append(meta)

        results.sort(key=lambda m: m.created_at)
        return results

    # ------------------------------------------------------------------
    # Helpers privados
    # ------------------------------------------------------------------

    def _artifact_dir(
        self, confidentiality: str, run_id: str, artifact_id: str
    ) -> Path:
        return self._base / confidentiality / run_id / artifact_id

    def _find_artifact_dir(self, artifact_id: str) -> Path:
        """
        Localiza el directorio de un artifact_id buscando en todos los niveles.

        Raises
        ------
        FileNotFoundError si no se encuentra.
        """
        for level_dir in self._base.iterdir():
            if not level_dir.is_dir():
                continue
            for run_dir in level_dir.iterdir():
                if not run_dir.is_dir():
                    continue
                candidate = run_dir / artifact_id
                if candidate.is_dir() and (candidate / "metadata.yaml").exists():
                    return candidate
        raise FileNotFoundError(f"Artifact '{artifact_id}' no encontrado en {self._base}")


# ---------------------------------------------------------------------------
# Helpers de serialización
# ---------------------------------------------------------------------------

def _generate_id() -> str:
    """Genera un artifact_id con prefijo art_ + UUID corto."""
    return "art_" + uuid.uuid4().hex[:12]


def _write_metadata(path: Path, meta: ArtifactMetadata) -> None:
    data: dict[str, Any] = meta.model_dump()
    with path.open("w", encoding="utf-8") as fh:
        yaml.dump(data, fh, allow_unicode=True, sort_keys=True)


def _read_metadata(path: Path) -> ArtifactMetadata:
    with path.open("r", encoding="utf-8") as fh:
        data: dict[str, Any] = yaml.safe_load(fh)
    return ArtifactMetadata(**data)
