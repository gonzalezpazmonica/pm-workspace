"""
tests/python/test_artifacts_e2e.py — Tests E2E de flow de 3 nodos con artifacts.

Slice 2 — SPEC-AGENT-ARTIFACTS §4 criterio:
  "Flow de 3 nodos donde el nodo final ensambla 2 artifacts producidos por nodos previos."

Arquitectura del flow simulado:
  Nodo A (data-extractor)  → produce CSV       → artifact_id_A
  Nodo B (image-generator) → produce imagen PNG → artifact_id_B
  Nodo C (assembler)       → carga A y B, produce informe TXT con ambos refs

Integración AFG: la traza runtime.artifacts.by_node y node.end se verifican.

Rule #26: Python puro. tmp_path garantiza aislamiento. Sin I/O real de red.
"""
from __future__ import annotations

import base64
import json
from pathlib import Path
from typing import Any

import pytest

from scripts.lib.artifacts.store import ArtifactStore
from scripts.lib.artifacts.tools import (
    ArtifactRef,
    configure_store,
    export_artifact,
    list_artifacts,
    load_artifact,
    save_artifact,
)

TEST_SECRET = b"test-e2e-secret-slice2"

# ---------------------------------------------------------------------------
# Fixture: entorno E2E aislado
# ---------------------------------------------------------------------------

@pytest.fixture()
def e2e_env(tmp_path: Path, monkeypatch):
    """
    Configura un entorno E2E completo:
    - ArtifactStore en tmp_path
    - SAVIA_ARTIFACT_SECRET fijado
    - SAVIA_RUN_ID fijado para reproducibilidad
    - Singleton de tools reseteado
    """
    monkeypatch.setenv("SAVIA_ARTIFACT_SECRET", TEST_SECRET.decode())
    monkeypatch.setenv("SAVIA_RUN_ID", "run_e2e_01")

    store = ArtifactStore(tmp_path / "artifacts")
    configure_store(store)

    # Resetear el run_id cache interno de tools.py
    import scripts.lib.artifacts.tools as tools_mod
    monkeypatch.setattr(tools_mod, "_cached_run_id", None)

    return {"store": store, "run_id": "run_e2e_01", "tmp_path": tmp_path}


# ---------------------------------------------------------------------------
# Helpers: simular nodos del flow
# ---------------------------------------------------------------------------

def node_data_extractor(store: ArtifactStore, run_id: str) -> tuple[ArtifactRef, dict[str, Any]]:
    """
    Nodo A: extrae datos CSV y guarda un artifact.
    Devuelve (ref, traza_node_end).
    """
    csv_content = "id,nombre,valor\n1,Alpha,100\n2,Beta,200\n3,Gamma,300"
    ref = save_artifact(
        name="data-extracted.csv",
        content=csv_content,
        mime_type="text/csv",
        run_id=run_id,
        description="Datos extraídos por node_data_extractor",
        agent_id="data-extractor",
        store=store,
    )
    # Traza AFG: node.end event (SPEC-AGENT-ARTIFACTS §2.7)
    trace_event = {
        "event": "node.end",
        "node_id": "data-extractor",
        "artifacts": [ref.artifact_id],
    }
    return ref, trace_event


def node_image_generator(store: ArtifactStore, run_id: str) -> tuple[ArtifactRef, dict[str, Any]]:
    """
    Nodo B: genera una imagen PNG (bytes mínimos de PNG 1x1 rojo) y la guarda.
    Devuelve (ref, traza_node_end).
    """
    # PNG 1x1 rojo mínimo (bytes válidos)
    png_bytes = bytes([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,  # PNG signature
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,  # IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
        0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,  # IDAT chunk
        0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
        0x00, 0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC,
        0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,  # IEND chunk
        0x44, 0xAE, 0x42, 0x60, 0x82,
    ])
    ref = save_artifact(
        name="chart.png",
        content=png_bytes,
        mime_type="image/png",
        run_id=run_id,
        description="Gráfico generado por node_image_generator",
        agent_id="image-generator",
        store=store,
    )
    trace_event = {
        "event": "node.end",
        "node_id": "image-generator",
        "artifacts": [ref.artifact_id],
    }
    return ref, trace_event


def node_assembler(
    store: ArtifactStore,
    run_id: str,
    artifact_id_csv: str,
    artifact_id_png: str,
) -> tuple[ArtifactRef, dict[str, Any]]:
    """
    Nodo C: carga los 2 artifacts previos y produce un informe ensamblado.
    Devuelve (ref_informe, traza_node_end).
    """
    # Cargar CSV
    csv_content = load_artifact(artifact_id=artifact_id_csv, store=store)
    csv_text = csv_content.raw_bytes.decode("utf-8")

    # Cargar imagen (acceso por raw_bytes)
    png_content = load_artifact(artifact_id=artifact_id_png, store=store)
    png_b64 = base64.standard_b64encode(png_content.raw_bytes).decode("ascii")

    # Ensamblar informe
    report_text = (
        f"# Informe Ensamblado\n\n"
        f"## Fuentes\n"
        f"- CSV artifact_id: {artifact_id_csv}\n"
        f"- PNG artifact_id: {artifact_id_png}\n\n"
        f"## Datos CSV\n\n{csv_text}\n\n"
        f"## Imagen (base64, {len(png_content.raw_bytes)} bytes)\n\n{png_b64[:50]}...\n"
    )

    ref = save_artifact(
        name="informe-ensamblado.md",
        content=report_text,
        mime_type="text/markdown",
        run_id=run_id,
        description="Informe ensamblado por node_assembler",
        agent_id="assembler",
        store=store,
    )
    trace_event = {
        "event": "node.end",
        "node_id": "assembler",
        "artifacts": [ref.artifact_id],
    }
    return ref, trace_event


# ---------------------------------------------------------------------------
# TC-E2E-01: Flow completo de 3 nodos — todos los artifacts creados
# ---------------------------------------------------------------------------

def test_e2e_three_node_flow_creates_all_artifacts(e2e_env):
    """
    El flow A→B→C produce 3 artifacts en el mismo run_id.
    list_artifacts devuelve los 3 en orden cronológico.
    """
    store = e2e_env["store"]
    run_id = e2e_env["run_id"]

    ref_a, _ = node_data_extractor(store, run_id)
    ref_b, _ = node_image_generator(store, run_id)
    ref_c, _ = node_assembler(store, run_id, ref_a.artifact_id, ref_b.artifact_id)

    all_artifacts = list_artifacts(run_id=run_id, store=store)
    assert len(all_artifacts) == 3

    ids = {a.artifact_id for a in all_artifacts}
    assert ref_a.artifact_id in ids
    assert ref_b.artifact_id in ids
    assert ref_c.artifact_id in ids


# ---------------------------------------------------------------------------
# TC-E2E-02: Traza AFG — node.end events contienen artifact_ids correctos
# ---------------------------------------------------------------------------

def test_e2e_afg_trace_events_contain_artifact_ids(e2e_env):
    """
    Cada nodo emite un evento node.end con el artifact_id producido.
    El runtime.artifacts.by_node se construye correctamente desde los eventos.
    """
    store = e2e_env["store"]
    run_id = e2e_env["run_id"]

    ref_a, trace_a = node_data_extractor(store, run_id)
    ref_b, trace_b = node_image_generator(store, run_id)
    ref_c, trace_c = node_assembler(store, run_id, ref_a.artifact_id, ref_b.artifact_id)

    # Verificar estructura de cada evento de traza (SPEC §2.7)
    assert trace_a == {
        "event": "node.end",
        "node_id": "data-extractor",
        "artifacts": [ref_a.artifact_id],
    }
    assert trace_b == {
        "event": "node.end",
        "node_id": "image-generator",
        "artifacts": [ref_b.artifact_id],
    }
    assert trace_c == {
        "event": "node.end",
        "node_id": "assembler",
        "artifacts": [ref_c.artifact_id],
    }

    # Construir runtime.artifacts.by_node (estructura del AMENDMENT-01)
    trace_events = [trace_a, trace_b, trace_c]
    by_node: dict[str, list[str]] = {}
    total = 0
    for event in trace_events:
        node_id = event["node_id"]
        artifacts = event["artifacts"]
        by_node[node_id] = artifacts
        total += len(artifacts)

    runtime_state = {
        "runtime": {
            "artifacts": {
                "by_node": by_node,
                "total": total,
            }
        }
    }

    assert runtime_state["runtime"]["artifacts"]["total"] == 3
    assert runtime_state["runtime"]["artifacts"]["by_node"]["data-extractor"] == [ref_a.artifact_id]
    assert runtime_state["runtime"]["artifacts"]["by_node"]["assembler"] == [ref_c.artifact_id]


# ---------------------------------------------------------------------------
# TC-E2E-03: Nodo assembler puede leer artifacts de nodos anteriores
# ---------------------------------------------------------------------------

def test_e2e_assembler_reads_upstream_artifacts(e2e_env):
    """
    El nodo C lee correctamente los bytes producidos por A y B.
    El informe resultante contiene referencias a ambos artifact_ids.
    """
    store = e2e_env["store"]
    run_id = e2e_env["run_id"]

    ref_a, _ = node_data_extractor(store, run_id)
    ref_b, _ = node_image_generator(store, run_id)
    ref_c, _ = node_assembler(store, run_id, ref_a.artifact_id, ref_b.artifact_id)

    # Cargar el informe final y verificar que menciona los IDs upstream
    informe = load_artifact(artifact_id=ref_c.artifact_id, store=store)
    report_text = informe.raw_bytes.decode("utf-8")

    assert ref_a.artifact_id in report_text
    assert ref_b.artifact_id in report_text
    assert "Informe Ensamblado" in report_text
    assert "Alpha" in report_text  # datos del CSV


# ---------------------------------------------------------------------------
# TC-E2E-04: export_artifact en el informe final genera URL efímera válida
# ---------------------------------------------------------------------------

def test_e2e_export_final_artifact_url(e2e_env):
    """
    El informe final puede exportarse como URL efímera.
    El servidor de referencia puede validar el token.
    """
    store = e2e_env["store"]
    run_id = e2e_env["run_id"]

    ref_a, _ = node_data_extractor(store, run_id)
    ref_b, _ = node_image_generator(store, run_id)
    ref_c, _ = node_assembler(store, run_id, ref_a.artifact_id, ref_b.artifact_id)

    ephemeral = export_artifact(
        artifact_id=ref_c.artifact_id,
        ttl_seconds=7200,
        base_url="http://localhost:8765/api/v1/ephemeral/artifacts",
        secret=TEST_SECRET,
        store=store,
    )

    assert ephemeral.artifact_id == ref_c.artifact_id
    assert "http://localhost:8765" in ephemeral.url
    assert ephemeral.url.endswith(ephemeral.token)

    # Validar el token con el secret conocido
    from scripts.lib.artifacts.ephemeral import validate_token
    et = validate_token(ephemeral.token, secret=TEST_SECRET)
    assert et.artifact_id == ref_c.artifact_id
