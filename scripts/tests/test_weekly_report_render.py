"""Tests SPEC-WR01 — render F1 Markdown desde fixture + plantilla.

Cubre:
- AC-08 reproducibilidad byte a byte (mismo input ⇒ mismo md).
- AC-11 vista lean: ≤9 bloques contables.
- AC-12 alertas críticas siempre visibles.
- RN-26 agregación de banners + cap 3 nombres.
- §4.7 score medio squad con N<M.
- §6.5 formato es-ES (importes, %, meses).
"""
import json
import re
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "scripts" / "tests" / "fixtures" / "weekly_report" / "fixture_data.json"
RENDER = ROOT / "scripts" / "weekly-report-render.py"


def render(tmp_path, fixture_path=FIXTURE):
    out = tmp_path / "out.md"
    result = subprocess.run(
        [sys.executable, str(RENDER), "--data", str(fixture_path), "--output", str(out)],
        capture_output=True, text=True, cwd=ROOT,
    )
    assert result.returncode == 0, f"render failed: {result.stderr}"
    return out.read_text(encoding="utf-8")


def count_blocks(md: str) -> int:
    """AC-11 cuenta: secciones ## (1 c/u) + banners ⚠ (1 c/u) + footer (1) + cabecera (1).

    Excluye banners de alertas críticas que el spec marca como NO-cap.
    Para este test contamos tal cual y verificamos ≤9 (incluyendo banners ya agregados).
    """
    sections = len(re.findall(r"^## ", md, re.MULTILINE))
    banners = len(re.findall(r"^> ⚠", md, re.MULTILINE))
    header = 1  # `# ` heading + metadata-line
    footer = 1 if md.rstrip().endswith("--narrative") else 1
    return sections + banners + header + footer


def test_render_produces_output(tmp_path):
    md = render(tmp_path)
    assert "Informe Semanal" in md
    assert "Sprint 2026-26" in md


def test_ac08_reproducibility(tmp_path):
    """AC-08: mismo input ⇒ mismo md byte a byte (sin generated_at en .md v1.7+)."""
    out1 = render(tmp_path / "a")
    out2 = render(tmp_path / "b")
    assert out1 == out2


def test_ac11_lean_block_cap(tmp_path):
    """AC-11: ≤9 bloques en vista lean."""
    md = render(tmp_path)
    blocks = count_blocks(md)
    assert blocks <= 9, f"vista lean produce {blocks} bloques, cap 9 excedido"


def test_ac12_critical_alerts_visible(tmp_path):
    """AC-12: alertas críticas siempre visibles. Fixture tiene teams_meetings stale + 2 vac pendientes."""
    md = render(tmp_path)
    # Banner stale debe aparecer
    assert re.search(r"^> ⚠.*stale", md, re.MULTILINE), "falta banner de fuente stale"
    # Banner vacaciones pendientes
    assert re.search(r"^> ⚠.*vacaciones pendientes", md, re.MULTILINE), "falta banner vacaciones"
    # Score < 5 inline en tabla equipo
    assert "score <5" in md, "falta indicador inline de score <5"


def test_rn26_banner_aggregation(tmp_path):
    """RN-26: 1 banner por categoría status, no uno por fuente."""
    md = render(tmp_path)
    # Solo 1 banner stale (no múltiples)
    stale_banners = re.findall(r"^> ⚠.*stale", md, re.MULTILINE)
    assert len(stale_banners) == 1, f"esperado 1 banner stale agregado, encontrado {len(stale_banners)}"


def test_rn26_vacations_cap_3_names(tmp_path):
    """RN-26: cap de 3 nombres en banners de vacaciones."""
    md = render(tmp_path)
    # Fixture tiene 2 vacaciones pendientes (≤3) ⇒ todos visibles, sin "(N más)"
    vac_line = next((l for l in md.split("\n") if "vacaciones pendientes" in l), None)
    assert vac_line is not None
    assert "más con --expanded" not in vac_line, "fixture tiene 2 vac, no debería tener cap"


def test_section_4_7_score_avg_partial(tmp_path):
    """§4.7: si score_n < score_m, render muestra '(sobre N=X de Y; Z sin score)'."""
    md = render(tmp_path)
    # Fixture: Data squad tiene N=1, M=2 ⇒ debe aparecer la nota
    assert "sobre N=1 de 2" in md, "falta nota de score parcial en squad Data"


def test_economic_es_es_format(tmp_path):
    """§6.5: formato es-ES — '12.500,00 €', '39,03 %'."""
    md = render(tmp_path)
    # Importes con punto miles + coma decimal + €
    assert re.search(r"\d{1,3}\.\d{3},\d{2} €", md) or re.search(r"\d+,\d{2} €", md), "formato € es-ES ausente"
    # Porcentajes con coma decimal
    assert re.search(r"\d+,\d{2} %", md), "formato % es-ES ausente"


def test_economic_months_es(tmp_path):
    """§6.5: meses ES abreviados (Ene, Feb, Mar, Abr...)."""
    md = render(tmp_path)
    for m in ["Ene", "Feb", "Mar", "Abr"]:
        assert m in md, f"falta mes {m}"


def test_delta_section_present(tmp_path):
    """AC-10: bloque Delta presente cuando hay informe previo."""
    md = render(tmp_path)
    assert "Delta vs informe previo" in md
    assert "asof 2026-04-22" in md
    # Métricas
    assert re.search(r"Δ \+27,5 h imputadas", md), "falta delta imputadas"
    assert "+4 closed" in md or "+4" in md, "falta delta closed"


def test_no_generated_at_in_md(tmp_path):
    """AC-08 v1.7+: .md no contiene generated_at (solo manifest)."""
    md = render(tmp_path)
    assert "generated_at" not in md, ".md no debe contener generated_at"


def test_first_run_no_previous(tmp_path):
    """Cuando no hay previous_run.available, dice 'Primera ejecución del sprint'."""
    fix = json.loads(FIXTURE.read_text(encoding="utf-8"))
    fix["previous_run"]["available"] = False
    fix["delta"] = {"imputed_h": 0, "closed_count": 0, "remaining_h": 0, "score_swings": [], "source_status_changes": []}
    alt = tmp_path / "fix.json"
    alt.write_text(json.dumps(fix), encoding="utf-8")
    md = render(tmp_path, fixture_path=alt)
    assert "Primera ejecución del sprint" in md


if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-v"]))
