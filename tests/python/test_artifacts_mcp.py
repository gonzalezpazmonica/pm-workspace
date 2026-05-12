"""
tests/python/test_artifacts_mcp.py — Tests del MCP server savia-artifacts.

Slice 2 — SPEC-AGENT-ARTIFACTS §4 criterio: ≥ 8 casos MCP.

Estrategia:
  - Instanciar FastMCP y llamar a las tools directamente (sin levantar un server real),
    inyectando un ArtifactStore con tmp_path.
  - Verificar que las 4 tools devuelven la estructura correcta.
  - Verificar confidencialidad: artifact N3 no accesible desde un store N1-only.
  - Verificar token HMAC en export_artifact.

Rule #26: tests en Python. Nunca escriben en output/ real (tmp_path).
"""
from __future__ import annotations

import base64
import json
import os
from pathlib import Path
from typing import Any

import pytest

# ---------------------------------------------------------------------------
# Fixtures compartidos
# ---------------------------------------------------------------------------

TEST_SECRET = b"test-mcp-secret-slice2"


@pytest.fixture()
def store(tmp_path: Path):
    """ArtifactStore apuntando a tmp_path (aislado por test)."""
    from scripts.lib.artifacts.store import ArtifactStore
    return ArtifactStore(tmp_path / "artifacts")


@pytest.fixture()
def configured_store(store, monkeypatch):
    """Configura el singleton de tools con el store de test."""
    from scripts.lib.artifacts import tools as tools_mod
    monkeypatch.setattr(tools_mod, "_store", store)
    # También necesitamos que mcp_server use este store
    import scripts.lib.artifacts.mcp_server as mcp_mod
    monkeypatch.setattr(mcp_mod, "_store", store)
    return store


@pytest.fixture()
def secret_env(monkeypatch):
    """Setea SAVIA_ARTIFACT_SECRET para los tests."""
    monkeypatch.setenv("SAVIA_ARTIFACT_SECRET", TEST_SECRET.decode())
    return TEST_SECRET


# ---------------------------------------------------------------------------
# Helper: invocar tool MCP directamente sin transport
# ---------------------------------------------------------------------------

def call_mcp_tool(tool_name: str, **kwargs: Any) -> Any:
    """
    Llama a la tool registrada en el FastMCP server directamente.

    Accede a la función subyacente vía `mcp._tool_manager` y la invoca
    con los argumentos dados. Evita levantar un server real en tests.
    """
    import scripts.lib.artifacts.mcp_server as mcp_mod
    mcp = mcp_mod.mcp
    # FastMCP 1.27: las tools están en _tool_manager.tools
    tool_fn = mcp._tool_manager._tools[tool_name].fn
    return tool_fn(**kwargs)


# ---------------------------------------------------------------------------
# TC-MCP-01: save_artifact devuelve ArtifactRef completo
# ---------------------------------------------------------------------------

def test_mcp_save_returns_artifact_ref(configured_store, secret_env):
    result = call_mcp_tool(
        "save_artifact",
        name="hello.txt",
        content="hola mundo",
        mime_type="text/plain",
        run_id="run_mcp01",
    )
    assert result["name"] == "hello.txt"
    assert result["artifact_id"].startswith("art_")
    assert result["run_id"] == "run_mcp01"
    assert "sha256" in result
    assert result["confidentiality"] == "N1"


# ---------------------------------------------------------------------------
# TC-MCP-02: save_artifact con confidencialidad N3
# ---------------------------------------------------------------------------

def test_mcp_save_n3_confidentiality(configured_store, secret_env):
    result = call_mcp_tool(
        "save_artifact",
        name="privado.csv",
        content="id,valor\n1,secret",
        mime_type="text/csv",
        run_id="run_mcp02",
        confidentiality="N3",
    )
    assert result["confidentiality"] == "N3"
    # El artifact_id debe existir bajo N3 en el store
    store = configured_store
    base = store._base
    assert (base / "N3" / "run_mcp02" / result["artifact_id"]).is_dir()


# ---------------------------------------------------------------------------
# TC-MCP-03: load_artifact devuelve contenido correcto
# ---------------------------------------------------------------------------

def test_mcp_load_returns_content(configured_store, secret_env):
    # Primero guardar
    save_result = call_mcp_tool(
        "save_artifact",
        name="data.txt",
        content="contenido de test",
        mime_type="text/plain",
        run_id="run_mcp03",
    )
    artifact_id = save_result["artifact_id"]

    # Luego cargar
    load_result = call_mcp_tool("load_artifact", artifact_id=artifact_id)
    assert load_result["artifact_id"] == artifact_id
    assert load_result["name"] == "data.txt"
    assert load_result["mime_type"] == "text/plain"
    assert "injection_block" in load_result
    assert "raw_b64" in load_result

    # raw_b64 decodificado debe ser el contenido original
    raw = base64.standard_b64decode(load_result["raw_b64"])
    assert raw == b"contenido de test"


# ---------------------------------------------------------------------------
# TC-MCP-04: load_artifact con artifact inexistente lanza FileNotFoundError
# ---------------------------------------------------------------------------

def test_mcp_load_nonexistent_raises(configured_store, secret_env):
    with pytest.raises(FileNotFoundError):
        call_mcp_tool("load_artifact", artifact_id="art_nonexistent")


# ---------------------------------------------------------------------------
# TC-MCP-05: list_artifacts filtra por run_id
# ---------------------------------------------------------------------------

def test_mcp_list_filters_by_run(configured_store, secret_env):
    call_mcp_tool(
        "save_artifact", name="a.txt", content="aaa", mime_type="text/plain", run_id="run_A"
    )
    call_mcp_tool(
        "save_artifact", name="b.txt", content="bbb", mime_type="text/plain", run_id="run_B"
    )

    result = call_mcp_tool("list_artifacts", run_id="run_A")
    assert len(result) == 1
    assert result[0]["name"] == "a.txt"


# ---------------------------------------------------------------------------
# TC-MCP-06: list_artifacts filtra por mime_type
# ---------------------------------------------------------------------------

def test_mcp_list_filters_by_mime(configured_store, secret_env):
    call_mcp_tool(
        "save_artifact", name="r.csv", content="a,b", mime_type="text/csv", run_id="run_mime"
    )
    call_mcp_tool(
        "save_artifact", name="r.txt", content="abc", mime_type="text/plain", run_id="run_mime"
    )

    csv_only = call_mcp_tool("list_artifacts", run_id="run_mime", filter_mime_type="text/csv")
    assert len(csv_only) == 1
    assert csv_only[0]["mime_type"] == "text/csv"


# ---------------------------------------------------------------------------
# TC-MCP-07: export_artifact devuelve URL con token válido
# ---------------------------------------------------------------------------

def test_mcp_export_returns_url_with_token(configured_store, secret_env):
    save_result = call_mcp_tool(
        "save_artifact",
        name="export_me.txt",
        content="exportable",
        mime_type="text/plain",
        run_id="run_mcp07",
    )
    artifact_id = save_result["artifact_id"]

    export_result = call_mcp_tool(
        "export_artifact",
        artifact_id=artifact_id,
        ttl_seconds=3600,
    )
    assert export_result["artifact_id"] == artifact_id
    assert "url" in export_result
    assert "token" in export_result
    assert "expires_at" in export_result

    # El token debe ser válido y decodificable
    from scripts.lib.artifacts.ephemeral import validate_token
    et = validate_token(export_result["token"], secret=TEST_SECRET)
    assert et.artifact_id == artifact_id


# ---------------------------------------------------------------------------
# TC-MCP-08: summary N3 NO accesible desde store N1-only
# ---------------------------------------------------------------------------

def test_mcp_n3_not_accessible_from_n1_store(tmp_path, monkeypatch, secret_env):
    """
    Un artifact guardado en N3 NO debe aparecer si solo se monta el directorio N1.

    Verificación de la propiedad de confidencialidad: si el store apunta
    a un directorio diferente (sin N3), el artifact no es visible.
    """
    from scripts.lib.artifacts.store import ArtifactStore
    import scripts.lib.artifacts.mcp_server as mcp_mod

    # Store A guarda artifact N3
    store_a = ArtifactStore(tmp_path / "store_a")
    monkeypatch.setattr(mcp_mod, "_store", store_a)

    save_result = call_mcp_tool(
        "save_artifact",
        name="secreto.txt",
        content="datos confidenciales",
        mime_type="text/plain",
        run_id="run_n3",
        confidentiality="N3",
    )
    artifact_id = save_result["artifact_id"]

    # Store B apunta a directorio diferente (sin acceso a N3 del store A)
    store_b = ArtifactStore(tmp_path / "store_b")
    monkeypatch.setattr(mcp_mod, "_store", store_b)

    with pytest.raises(FileNotFoundError):
        call_mcp_tool("load_artifact", artifact_id=artifact_id)
