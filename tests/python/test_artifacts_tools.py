"""
tests/python/test_artifacts_tools.py — 12 casos para las cuatro tools.

Usa tmp_path de pytest — NUNCA escribe en output/ real.
SPEC-AGENT-ARTIFACTS Slice 1.
"""
from __future__ import annotations

import os
from pathlib import Path

import pytest

from scripts.lib.artifacts.store import ArtifactStore
from scripts.lib.artifacts.tools import (
    ArtifactContent,
    ArtifactRef,
    EphemeralURL,
    export_artifact,
    list_artifacts,
    load_artifact,
    save_artifact,
)

# ---------------------------------------------------------------------------
# Fixture: store aislado en tmp_path
# ---------------------------------------------------------------------------

@pytest.fixture()
def store(tmp_path: Path) -> ArtifactStore:
    return ArtifactStore(tmp_path / "artifacts")


@pytest.fixture()
def secret() -> bytes:
    return b"test-secret-12345"


# ---------------------------------------------------------------------------
# save_artifact — 4 casos
# ---------------------------------------------------------------------------

class TestSaveArtifact:
    def test_returns_artifact_ref(self, store: ArtifactStore) -> None:
        """save_artifact devuelve ArtifactRef con campos obligatorios."""
        ref = save_artifact(
            "report.csv",
            b"col1,col2\n1,2",
            "text/csv",
            run_id="run_test001",
            store=store,
        )
        assert isinstance(ref, ArtifactRef)
        assert ref.artifact_id.startswith("art_")
        assert ref.run_id == "run_test001"
        assert len(ref.sha256) == 64

    def test_content_persisted_on_disk(self, store: ArtifactStore) -> None:
        """El contenido queda en disco bajo la estructura correcta."""
        ref = save_artifact(
            "data.txt",
            "hello artifact",
            "text/plain",
            run_id="run_disk01",
            store=store,
        )
        # Buscar el fichero content en el árbol
        content_files = list((store._base).rglob("content"))
        assert len(content_files) == 1
        assert content_files[0].read_text() == "hello artifact"

    def test_confidentiality_level_directory(self, store: ArtifactStore) -> None:
        """El nivel de confidencialidad determina el subdirectorio."""
        ref = save_artifact(
            "private.txt",
            b"secret data",
            "text/plain",
            run_id="run_conf01",
            confidentiality="N3",
            store=store,
        )
        # El path debe contener N3
        n3_dir = store._base / "N3"
        assert n3_dir.exists()
        content_files = list(n3_dir.rglob("content"))
        assert len(content_files) == 1

    def test_metadata_yaml_written(self, store: ArtifactStore) -> None:
        """metadata.yaml se crea junto al contenido."""
        ref = save_artifact(
            "report.pdf",
            b"%PDF-stub",
            "application/pdf",
            run_id="run_meta01",
            description="Test PDF artifact",
            store=store,
        )
        yaml_files = list((store._base).rglob("metadata.yaml"))
        assert len(yaml_files) == 1
        import yaml
        data = yaml.safe_load(yaml_files[0].read_text())
        assert data["name"] == "report.pdf"
        assert data["mime_type"] == "application/pdf"
        assert data["description"] == "Test PDF artifact"


# ---------------------------------------------------------------------------
# load_artifact — 4 casos
# ---------------------------------------------------------------------------

class TestLoadArtifact:
    def test_load_text_artifact(self, store: ArtifactStore) -> None:
        """load_artifact devuelve ArtifactContent con injection_block tipo text."""
        ref = save_artifact(
            "hello.txt",
            "contenido de prueba",
            "text/plain",
            run_id="run_load01",
            store=store,
        )
        result = load_artifact(ref.artifact_id, provider="anthropic", store=store)
        assert isinstance(result, ArtifactContent)
        assert result.injection_block["type"] == "text"
        assert "contenido de prueba" in result.injection_block["text"]

    def test_load_image_anthropic_block(self, store: ArtifactStore, tmp_path: Path) -> None:
        """load_artifact con imagen en proveedor anthropic devuelve bloque image."""
        png_path = Path("tests/python/fixtures/artifacts/sample.png")
        content = png_path.read_bytes()
        ref = save_artifact(
            "img.png",
            content,
            "image/png",
            run_id="run_img01",
            store=store,
        )
        result = load_artifact(ref.artifact_id, provider="anthropic", store=store)
        assert result.injection_block["type"] == "image"
        assert result.injection_block["source"]["media_type"] == "image/png"

    def test_load_pdf_fallback_base64(self, store: ArtifactStore) -> None:
        """load_artifact con PDF en proveedor desconocido usa fallback base64."""
        pdf_path = Path("tests/python/fixtures/artifacts/sample.pdf")
        content = pdf_path.read_bytes()
        ref = save_artifact(
            "doc.pdf",
            content,
            "application/pdf",
            run_id="run_pdf01",
            store=store,
        )
        result = load_artifact(ref.artifact_id, provider="unknown_llm", store=store)
        assert result.injection_block["type"] == "text"
        assert "base64" in result.injection_block["text"]

    def test_load_nonexistent_artifact_raises(self, store: ArtifactStore) -> None:
        """load_artifact con ID inexistente lanza FileNotFoundError."""
        with pytest.raises(FileNotFoundError):
            load_artifact("art_000000000000", store=store)


# ---------------------------------------------------------------------------
# list_artifacts — 2 casos
# ---------------------------------------------------------------------------

class TestListArtifacts:
    def test_list_returns_all_for_run(self, store: ArtifactStore) -> None:
        """list_artifacts retorna todos los artifacts del run."""
        for i in range(3):
            save_artifact(
                f"file_{i}.csv",
                f"data_{i}",
                "text/csv",
                run_id="run_list01",
                store=store,
            )
        items = list_artifacts("run_list01", store=store)
        assert len(items) == 3

    def test_list_filter_by_mime(self, store: ArtifactStore) -> None:
        """list_artifacts filtra correctamente por MIME type."""
        save_artifact("a.csv", "csv data", "text/csv", run_id="run_mime01", store=store)
        save_artifact("b.pdf", b"%PDF", "application/pdf", run_id="run_mime01", store=store)

        csv_items = list_artifacts("run_mime01", filter_mime_type="text/csv", store=store)
        assert len(csv_items) == 1
        assert csv_items[0].name == "a.csv"


# ---------------------------------------------------------------------------
# export_artifact — 2 casos
# ---------------------------------------------------------------------------

class TestExportArtifact:
    def test_export_returns_ephemeral_url(
        self, store: ArtifactStore, secret: bytes
    ) -> None:
        """export_artifact devuelve EphemeralURL con url y token."""
        ref = save_artifact(
            "export_me.txt",
            "contenido exportable",
            "text/plain",
            run_id="run_exp01",
            store=store,
        )
        result = export_artifact(
            ref.artifact_id,
            ttl_seconds=600,
            secret=secret,
            store=store,
        )
        assert isinstance(result, EphemeralURL)
        assert result.artifact_id == ref.artifact_id
        assert result.token in result.url
        assert "expires_at" in result.model_dump()

    def test_export_nonexistent_raises(
        self, store: ArtifactStore, secret: bytes
    ) -> None:
        """export_artifact lanza FileNotFoundError si el artifact_id no existe."""
        with pytest.raises(FileNotFoundError):
            export_artifact(
                "art_000000000000",
                secret=secret,
                store=store,
            )
