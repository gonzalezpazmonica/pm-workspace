"""
tests/scripts/test_org_registrar.py — pytest para SE-365 org-registrar validate.

Cubre: validación de frontmatter común, vocabulario de relaciones cerrado,
consistencia referencial, reglas de origin/source, escritura mediada.

Ref: SE-365 — Company as Code
"""
import importlib.util
import json
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "org-registrar.py"


def _load():
    spec = importlib.util.spec_from_file_location("org_registrar", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def org():
    return _load()


def _write_entity(tmp_path, content):
    p = tmp_path / "entity.md"
    p.write_text(content, encoding="utf-8")
    return p


VALID_ENTITY = """---
id: role-arquitecto
type: role
name: "Arquitecto/a de Soluciones"
status: active
owner: person-monica
relations:
  - { type: BelongsToUnit, target: unit-consultoria }
created: 2026-09-01
updated: 2026-09-01
origin: owner
source: human
---
Contexto narrativo.
"""


def test_entidad_valida_pasa(org, tmp_path):
    p = _write_entity(tmp_path, VALID_ENTITY)
    res = org.validate(p)
    assert res["valid"] is True, res["errors"]


def test_type_invalido_rechazado(org, tmp_path):
    content = VALID_ENTITY.replace("type: role", "type: rocket")
    p = _write_entity(tmp_path, content)
    res = org.validate(p)
    assert res["valid"] is False
    assert any("type" in e for e in res["errors"])


def test_relacion_no_listada_rechazada(org, tmp_path):
    content = VALID_ENTITY.replace("BelongsToUnit", "FliesToMoon")
    p = _write_entity(tmp_path, content)
    res = org.validate(p)
    assert res["valid"] is False
    assert any("relaci" in e.lower() or "FliesToMoon" in e for e in res["errors"])


def test_consistencia_referencial_target_inexistente(org, tmp_path):
    # entidad de ejemplo con target inexistente
    p = _write_entity(tmp_path, VALID_ENTITY)
    # se valida contra un índice sin ese target
    res = org.validate(p, known_ids={"person-monica"})
    assert res["valid"] is False
    assert any("unit-consultoria" in e for e in res["errors"])


def test_policy_requiere_origin_owner(org, tmp_path):
    content = VALID_ENTITY.replace("type: role", "type: policy").replace(
        "origin: owner", "origin: agent"
    ).replace("source: human", "source: agent:org-registrar")
    p = _write_entity(tmp_path, content)
    res = org.validate(p)
    # policy con origin agent → rechazada (políticas solo las declara origin: owner)
    assert res["valid"] is False


def test_resource_secret_sensitivity_rechazada(org, tmp_path):
    content = """---
id: resource-x
type: resource
category: infra
name: "X"
sensitivity: secret
origin: owner
source: human
---
"""
    p = _write_entity(tmp_path, content)
    res = org.validate(p)
    assert res["valid"] is False  # sensitivity nunca "secret"
