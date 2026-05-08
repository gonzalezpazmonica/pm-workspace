#!/usr/bin/env python3
"""SPEC-WR01 — Render F1 Markdown desde fixture/data + plantilla Jinja2.

MVP de demostración (T5 parcial). Lee un fixture JSON con la estructura completa
del informe (en producción será generado por weekly-report.py tras consultar
fuentes con snapshot pinning RN-19) y produce el .md lean según AC-11 + AC-12.

Uso:
    python weekly-report-render.py --data <fixture.json> --output <salida.md>
"""
import argparse
import json
import sys
from pathlib import Path

from jinja2 import Environment, FileSystemLoader, StrictUndefined


def format_eur_es(v):
    """es-ES: '60.308,16 €'."""
    if v is None:
        return ""
    return f"{v:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".") + " €"


def format_eur_or_empty(v):
    return format_eur_es(v) if v is not None else ""


def format_pct(v):
    if v is None:
        return ""
    return f"{v:.2f}".replace(".", ",") + " %"


def format_pct_or_empty(v):
    return format_pct(v) if v is not None else ""


def format_eur_or_dash(v):
    """v0.2 (WR08): em-dash en lugar de celda vacía."""
    return format_eur_es(v) if v is not None else "—"


def format_pct_or_dash(v):
    """v0.2 (WR08): em-dash en lugar de celda vacía."""
    return format_pct(v) if v is not None else "—"


def format_h_signed(v):
    sign = "+" if v >= 0 else "−"
    return f"{sign}{abs(v):.1f}".replace(".", ",") + " h"


def format_signed(v):
    sign = "+" if v >= 0 else "−"
    return f"{sign}{abs(v)}"


def format_signed_decimal(v):
    sign = "+" if v >= 0 else "−"
    return f"{sign}{abs(v):.1f}".replace(".", ",")


def format_score(avg, n, m):
    """Score medio con anotación si hay personas sin score (RN §4.7)."""
    if n == 0:
        return "—"
    avg_str = f"{avg:.1f}".replace(".", ",")
    if n < m:
        return f"{avg_str} (sobre N={n} de {m}; {m - n} sin score)"
    return avg_str


def format_vacation_names(items, cap=3):
    """Cap de 3 nombres en banners (RN-26)."""
    def shortname(full):
        parts = full.split()
        if len(parts) >= 2:
            return f"{parts[0]} {parts[-1][0]}."
        return full
    names = [shortname(it["persona"]) for it in items]
    if len(names) <= cap:
        return ", ".join(names)
    visible = ", ".join(names[:cap])
    rest = len(names) - cap
    return f"{visible} ({rest} más con --expanded)"


def build_critical_source_banners(sources):
    """Agregación de banners por categoría de status (RN-26 v1.6).

    1 banner por categoría, no uno por fuente. Cap 3 fuentes por línea.
    """
    by_status = {"STALE": [], "MISSING": [], "AUTH-FAIL": [], "TIMEOUT": []}
    msgs = {
        "STALE":     "stale — datos pueden estar incompletos",
        "MISSING":   "missing — datos no disponibles",
        "AUTH-FAIL": "auth-fail — regenerar credenciales",
        "TIMEOUT":   "timeout — superado el límite por fuente",
    }
    for name, info in sources.items():
        status = info.get("status", "ok").lower()
        if status == "stale":
            by_status["STALE"].append(name)
        elif status == "missing":
            by_status["MISSING"].append(name)
        elif status == "auth-fail":
            by_status["AUTH-FAIL"].append(name)
        elif status == "timeout":
            by_status["TIMEOUT"].append(name)
    banners = []
    for cat, names in by_status.items():
        if not names:
            continue
        cap = 3
        visible = names[:cap]
        rest = len(names) - cap
        line = f"{', '.join(visible)} {msgs[cat]}"
        if rest > 0:
            line += f" ({rest} más)"
        banners.append(line)
    return banners


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True, help="Fixture JSON con datos del informe")
    ap.add_argument("--output", required=True, help="Ruta del .md generado")
    ap.add_argument("--template-dir", default=".claude/skills/weekly-report/templates")
    args = ap.parse_args()

    data_path = Path(args.data)
    if not data_path.exists():
        print(f"ERROR: fixture no existe: {data_path}", file=sys.stderr)
        return 2

    with data_path.open(encoding="utf-8") as f:
        data = json.load(f)

    data["sources_ok_count"] = sum(1 for v in data["sources"].values() if v.get("status") == "ok")
    data["sources_stale_count"] = sum(
        1 for v in data["sources"].values() if v.get("status") in ("stale", "missing", "auth-fail", "timeout")
    )
    data["critical_source_banners"] = build_critical_source_banners(data["sources"])

    env = Environment(
        loader=FileSystemLoader(args.template_dir),
        undefined=StrictUndefined,
        trim_blocks=True,           # WR03 v0.2: trim newline tras {% %}
        lstrip_blocks=True,         # WR03 v0.2: strip whitespace inicial en líneas con {% %}
        keep_trailing_newline=True,
    )
    env.filters["format_eur_or_empty"] = format_eur_or_empty
    env.filters["format_eur_or_dash"] = format_eur_or_dash
    env.filters["format_pct"] = format_pct
    env.filters["format_pct_or_empty"] = format_pct_or_empty
    env.filters["format_pct_or_dash"] = format_pct_or_dash
    env.filters["format_h_signed"] = format_h_signed
    env.filters["format_signed"] = format_signed
    env.filters["format_signed_decimal"] = format_signed_decimal
    env.filters["format_score"] = format_score
    env.filters["format_vacation_names"] = format_vacation_names

    tpl = env.get_template("weekly-report.md.j2")
    rendered = tpl.render(**data)

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(rendered, encoding="utf-8")
    print(f"OK: informe generado en {out_path} ({len(rendered)} chars)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
