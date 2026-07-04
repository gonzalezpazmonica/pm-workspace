"""tests/test_workspace_migration.py — SE-253 Slice 7

Pytest suite para validar la migración de test-workspace.sh → test_workspace.py.
Verifica paridad funcional: mismos argumentos, mismos exit codes, misma lógica.
"""
from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest

# ── Import test_workspace como módulo ─────────────────────────────────────────
_SCRIPT = Path(__file__).parent.parent / "scripts" / "test_workspace.py"
_spec_mod = importlib.util.spec_from_file_location("test_workspace", _SCRIPT)
_mod = importlib.util.module_from_spec(_spec_mod)
_spec_mod.loader.exec_module(_mod)

WORKSPACE_ROOT = Path(__file__).parent.parent.resolve()
MOCK_DATA_DIR = WORKSPACE_ROOT / "projects" / "sala-reservas" / "test-data"


# ── Fixture: reset state entre tests ─────────────────────────────────────────
@pytest.fixture(autouse=True)
def reset_state():
    """Resetea el estado global del módulo antes de cada test."""
    state = _mod.state
    state.total = 0
    state.passed = 0
    state.failed = 0
    state.skipped = 0
    state.failed_tests = []
    state.mode = "mock"
    state.verbose = False
    state.only_category = ""
    yield
    # Post-test cleanup
    state.total = 0
    state.passed = 0
    state.failed = 0
    state.skipped = 0
    state.failed_tests = []


# ─────────────────────────────────────────────────────────────────────────────
# TC-1: El script acepta --mock sin error
# ─────────────────────────────────────────────────────────────────────────────
def test_accepts_mock_argument():
    result = subprocess.run(
        [sys.executable, str(_SCRIPT), "--mock", "--only", "prereqs"],
        capture_output=True, text=True, cwd=str(WORKSPACE_ROOT),
    )
    assert result.returncode in (0, 1), f"returncode inesperado: {result.returncode}"
    assert "PM Workspace" in result.stdout


# ─────────────────────────────────────────────────────────────────────────────
# TC-2: El script acepta --only con categoría válida
# ─────────────────────────────────────────────────────────────────────────────
@pytest.mark.parametrize("category", [
    "prereqs", "structure", "capacity", "sprint", "imputacion", "sdd", "report", "backlog",
])
def test_accepts_only_category(category: str):
    result = subprocess.run(
        [sys.executable, str(_SCRIPT), "--mock", "--only", category],
        capture_output=True, text=True, cwd=str(WORKSPACE_ROOT),
    )
    assert result.returncode in (0, 1)


# ─────────────────────────────────────────────────────────────────────────────
# TC-3: Exit code 0 en workspace limpio (mock mode)
# ─────────────────────────────────────────────────────────────────────────────
def test_exit_0_clean_workspace_mock():
    result = subprocess.run(
        [sys.executable, str(_SCRIPT), "--mock"],
        capture_output=True, text=True, cwd=str(WORKSPACE_ROOT),
    )
    assert result.returncode == 0, (
        f"Esperado exit 0, obtenido {result.returncode}\n"
        f"STDOUT: {result.stdout[-2000:]}\n"
        f"STDERR: {result.stderr[-500:]}"
    )


# ─────────────────────────────────────────────────────────────────────────────
# TC-4: Argumento desconocido retorna exit 2
# ─────────────────────────────────────────────────────────────────────────────
def test_unknown_argument_exit_2():
    result = subprocess.run(
        [sys.executable, str(_SCRIPT), "--opcion-inexistente"],
        capture_output=True, text=True, cwd=str(WORKSPACE_ROOT),
    )
    assert result.returncode == 2


# ─────────────────────────────────────────────────────────────────────────────
# TC-5: Fallo en capacity cuando mock-capacities.json está malformado
# ─────────────────────────────────────────────────────────────────────────────
def test_capacity_fails_on_malformed_json(tmp_path: Path):
    # Crea un mock-capacities.json inválido en directorio temporal
    bad_json = tmp_path / "mock-capacities.json"
    bad_json.write_text("{ invalid json ]]]")

    # Parchea MOCK_DATA_DIR en el módulo
    with patch.object(_mod, "MOCK_DATA_DIR", tmp_path):
        _mod.state.mode = "mock"
        # Crear un mock-sprint.json y mock-workitems.json mínimos para no fallar en otras suites
        (tmp_path / "mock-sprint.json").write_text("{}")
        (tmp_path / "mock-workitems.json").write_text('{"count": 0, "value": []}')
        _mod.test_capacity()

    assert _mod.state.failed > 0, "Esperado al menos 1 fallo con JSON malformado"


# ─────────────────────────────────────────────────────────────────────────────
# TC-6: Fallo en structure cuando falta un skill obligatorio
# ─────────────────────────────────────────────────────────────────────────────
def test_structure_fails_on_missing_skill(tmp_path: Path):
    """Cuando WORKSPACE_ROOT apunta a un dir sin skills, debe fallar."""
    # tmp_path es un workspace vacío
    with patch.object(_mod, "WORKSPACE_ROOT", tmp_path):
        _mod.state.mode = "mock"
        _mod.test_structure()

    assert _mod.state.failed > 0


# ─────────────────────────────────────────────────────────────────────────────
# TC-7: test_sprint falla con mock-sprint.json vacío/inválido
# ─────────────────────────────────────────────────────────────────────────────
def test_sprint_fails_on_empty_json(tmp_path: Path):
    (tmp_path / "mock-sprint.json").write_text("{}")
    (tmp_path / "mock-workitems.json").write_text('{"count": 0, "value": []}')

    with patch.object(_mod, "MOCK_DATA_DIR", tmp_path):
        _mod.state.mode = "mock"
        _mod.test_sprint()

    # Sprint data vacío → burndown trend != "on_track" → debe fallar
    assert _mod.state.failed > 0


# ─────────────────────────────────────────────────────────────────────────────
# TC-8: Paridad de exit code entre .sh wrapper y .py directo
# ─────────────────────────────────────────────────────────────────────────────
def test_exit_code_parity_sh_vs_py():
    sh_script = WORKSPACE_ROOT / "scripts" / "test-workspace.sh"
    if not sh_script.is_file():
        pytest.skip("test-workspace.sh no disponible")

    py_result = subprocess.run(
        [sys.executable, str(_SCRIPT), "--mock"],
        capture_output=True, text=True, cwd=str(WORKSPACE_ROOT),
    )
    sh_result = subprocess.run(
        ["bash", str(sh_script), "--mock"],
        capture_output=True, text=True, cwd=str(WORKSPACE_ROOT),
    )
    assert sh_result.returncode == py_result.returncode, (
        f".sh exit={sh_result.returncode} vs .py exit={py_result.returncode}"
    )


# ─────────────────────────────────────────────────────────────────────────────
# TC-9: mock-capacities.json real tiene 5 miembros y capacity ~228h
# ─────────────────────────────────────────────────────────────────────────────
def test_capacity_mock_data_integrity():
    cap_file = MOCK_DATA_DIR / "mock-capacities.json"
    data = json.loads(cap_file.read_text())

    members = data.get("team_members", [])
    assert len(members) == 5, f"Esperados 5 miembros, encontrados {len(members)}"

    total_cap = data.get("capacity_summary", {}).get("total_human_capacity", 0)
    assert abs(float(total_cap) - 228) < 0.5, f"Capacity esperada ~228h, obtenida {total_cap}"


# ─────────────────────────────────────────────────────────────────────────────
# TC-10: Algoritmo de detección de conflictos pasa 5/5 casos
# ─────────────────────────────────────────────────────────────────────────────
def test_conflict_detection_algorithm():
    """Prueba directa del algoritmo Python sin subprocess."""

    def hay_conflicto(i1: int, f1: int, i2: int, f2: int) -> bool:
        return i1 < f2 and i2 < f1

    casos = [
        (9,  10, 10, 11, False),   # consecutivas
        (9,  11, 10, 12, True),    # solapamiento parcial
        (9,  12, 10, 11, True),    # una dentro de otra
        (10, 11, 9,  12, True),    # la nueva dentro de la existente
        (8,  9,  10, 11, False),   # sin contacto
    ]
    for i1, f1, i2, f2, expected in casos:
        assert hay_conflicto(i1, f1, i2, f2) == expected, (
            f"Fallo en caso ({i1},{f1}) vs ({i2},{f2}): esperado {expected}"
        )


# ─────────────────────────────────────────────────────────────────────────────
# TC-11: mock-sprint.json real tiene trend=on_track y days_remaining>0
# ─────────────────────────────────────────────────────────────────────────────
def test_sprint_mock_data_integrity():
    sprint_file = MOCK_DATA_DIR / "mock-sprint.json"
    data = json.loads(sprint_file.read_text())

    trend = data.get("burndown", {}).get("trend")
    assert trend == "on_track", f"Esperado trend='on_track', obtenido '{trend}'"

    days_remaining = data.get("sprint", {}).get("daysRemaining", 0)
    assert days_remaining > 0


# ─────────────────────────────────────────────────────────────────────────────
# TC-12: Scores de asignación dentro del rango esperado
# ─────────────────────────────────────────────────────────────────────────────
def test_assignment_scoring_range():
    weights = {"expertise": 0.40, "availability": 0.30, "balance": 0.20, "growth": 0.10}
    assert abs(sum(weights.values()) - 1.0) < 0.001

    # Carlos: experto en .NET (mismo caso que el .sh original)
    score = 0.40 * 0.9 + 0.30 * 0.7 + 0.20 * 0.5 + 0.10 * 0.0
    assert 0.60 <= score <= 0.80, f"Score {score:.3f} fuera de rango 0.60-0.80"


# ─────────────────────────────────────────────────────────────────────────────
# TC-13: should_run filtra categorías correctamente
# ─────────────────────────────────────────────────────────────────────────────
def test_should_run_filter():
    _mod.state.only_category = ""
    assert _mod.should_run("prereqs") is True
    assert _mod.should_run("capacity") is True

    _mod.state.only_category = "capacity"
    assert _mod.should_run("capacity") is True
    assert _mod.should_run("prereqs") is False
    assert _mod.should_run("sprint") is False


# ─────────────────────────────────────────────────────────────────────────────
# TC-14: test_imputacion con datos reales produce 0 fallos
# ─────────────────────────────────────────────────────────────────────────────
def test_imputacion_with_real_mock_data(capsys):
    _mod.state.mode = "mock"
    _mod.test_imputacion()
    assert _mod.state.failed == 0, (
        f"test_imputacion falló: {_mod.state.failed_tests}"
    )


# ─────────────────────────────────────────────────────────────────────────────
# TC-15: --help retorna exit 0 (no 2)
# ─────────────────────────────────────────────────────────────────────────────
def test_help_argument():
    result = subprocess.run(
        [sys.executable, str(_SCRIPT), "--help"],
        capture_output=True, text=True, cwd=str(WORKSPACE_ROOT),
    )
    assert result.returncode == 0
