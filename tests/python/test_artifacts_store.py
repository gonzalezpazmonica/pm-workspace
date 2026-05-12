"""
tests/python/test_artifacts_store.py — 5 casos para ArtifactStore.

Usa tmp_path de pytest — NUNCA escribe en output/ real.
SPEC-AGENT-ARTIFACTS Slice 1.
"""
from __future__ import annotations

from pathlib import Path

import pytest
import yaml

from scripts.lib.artifacts.store import ArtifactStore, ArtifactMetadata


@pytest.fixture()
def store(tmp_path: Path) -> ArtifactStore:
    return ArtifactStore(tmp_path / "artifacts")


class TestArtifactStore:
    def test_save_creates_content_and_metadata(self, store: ArtifactStore) -> None:
        """save() crea el fichero content y metadata.yaml correctamente."""
        meta = store.save(
            run_id="run_s01",
            name="test.txt",
            content=b"hello",
            mime_type="text/plain",
        )
        assert meta.artifact_id.startswith("art_")
        artifact_dir = store._base / "N1" / "run_s01" / meta.artifact_id
        assert (artifact_dir / "content").read_bytes() == b"hello"
        assert (artifact_dir / "metadata.yaml").exists()

    def test_load_content_round_trip(self, store: ArtifactStore) -> None:
        """Guardar y cargar devuelve los mismos bytes y metadata."""
        original = b"round-trip-data"
        meta = store.save(
            run_id="run_rt01",
            name="rt.bin",
            content=original,
            mime_type="application/octet-stream",
        )
        loaded_bytes, loaded_meta = store.load_content(meta.artifact_id)
        assert loaded_bytes == original
        assert loaded_meta.name == "rt.bin"
        assert loaded_meta.sha256 == meta.sha256

    def test_sha256_correct(self, store: ArtifactStore) -> None:
        """El SHA-256 almacenado en metadata coincide con el del contenido."""
        import hashlib
        content = b"verify my hash"
        meta = store.save(
            run_id="run_sha01",
            name="hash.txt",
            content=content,
            mime_type="text/plain",
        )
        expected = hashlib.sha256(content).hexdigest()
        assert meta.sha256 == expected

    def test_list_by_run_multiple_levels(self, store: ArtifactStore) -> None:
        """list_by_run retorna artifacts de distintos niveles de confidencialidad."""
        store.save(run_id="run_ml01", name="pub.txt", content=b"p", mime_type="text/plain", confidentiality="N1")
        store.save(run_id="run_ml01", name="priv.txt", content=b"q", mime_type="text/plain", confidentiality="N3")
        items = store.list_by_run("run_ml01")
        assert len(items) == 2
        levels = {m.confidentiality for m in items}
        assert levels == {"N1", "N3"}

    def test_find_nonexistent_raises(self, store: ArtifactStore) -> None:
        """Intentar cargar un artifact inexistente lanza FileNotFoundError."""
        # Necesitamos que el base_dir exista para que iterdir() no falle
        store._base.mkdir(parents=True, exist_ok=True)
        with pytest.raises(FileNotFoundError, match="art_000000000000"):
            store.load_content("art_000000000000")
