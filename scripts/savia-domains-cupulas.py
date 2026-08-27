#!/usr/bin/env python3
"""savia-domains-cupulas.py — apertura de cúpulas N1 por dominio (Labs L23).

Lee `docs/domains/savia-domains-catalog.md` (tabla ID|Categoría|Dominio|Temas|
Capacidad) y crea, para cada dominio, su cúpula N1:
  vaults/SaviaDomains/<categoria>/<ID>/INDEX.md   (lifecycle: cupula-creada)

También mantiene el INDEX.md y MAP.md del dome. Determinista y local
(CRIT-001, sin red). Uso:
  savia-domains-cupulas.py [--check] [--catalog FILE] [--vault DIR]
Exit: 0 ok · 1 stale/missing · 2 usage
"""

import argparse
import datetime
import os
import re
import sys

CATEGORY_SLUG = {
    "Sector público": "sector-publico",
    "Legal y normativa": "legal-normativa",
    "Finanzas": "finanzas",
    "Tecnología": "tecnologia",
    "Electrónica": "electronica",
    "Robótica": "robotica",
    "Educación": "educacion",
    "Electricidad": "electricidad",
    "Infraestructuras": "infraestructuras",
    "Industria": "industria",
    "Comercio": "comercio",
    "Personas": "personas",
    "Sector productivo": "sector-productivo",
}


def parse_catalog(path):
    rows = []
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) < 4 or cells[0].strip() in ("ID", "---"):
            continue
        did = cells[0].strip()
        if not re.fullmatch(r"[A-Z]{2,3}", did):
            continue
        rows.append({
            "id": did,
            "category": cells[1].strip(),
            "name": cells[2].strip(),
            "topics": cells[3].strip() if len(cells) > 3 else "",
            "capacity": cells[4].strip() if len(cells) > 4 else "",
        })
    return rows


def iso_now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def index_content(row):
    return f"""---
entity: {{type: cupula, id: cupula-{row['id'].lower()}}}
title: "Cúpula N1 — {row['name']}"
domain: {row['id']}
category: {row['category']}
lifecycle: cupula-creada
confidentiality: N1
source: "docs/domains/savia-domains-catalog.md (Labs L23)"
---

# Cúpula N1 — {row['name']} ({row['id']})

Cúpula de conocimiento público de referencia para el dominio **{row['name']}**.
Base neutra (N1) para la digestión posterior de contenido (criterio L23:
conocimiento genérico, nunca datos de empresa/cliente/persona).

## Temas objetivo (digestión posterior)

{row['topics'] or '—'}

## Capacidad Savia existente (cimiento)

{row['capacity'] or '—'}
"""


def main():
    ap = argparse.ArgumentParser(description="Apertura de cúpulas N1 (Labs L23)")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--catalog", default="docs/domains/savia-domains-catalog.md")
    ap.add_argument("--vault", default="vaults/SaviaDomains")
    args = ap.parse_args()

    rows = parse_catalog(args.catalog)
    if not rows:
        print(f"ERROR: no se extrajeron dominios de {args.catalog}", file=sys.stderr)
        sys.exit(2)

    missing = []
    for r in rows:
        cat = CATEGORY_SLUG.get(r["category"], "otras")
        d = os.path.join(args.vault, cat, r["id"])
        f = os.path.join(d, "INDEX.md")
        if not os.path.exists(f):
            missing.append(f)
        elif args.check:
            continue

    if args.check:
        if missing:
            print(f"STALE: {len(missing)} cúpulas faltan (ej: {missing[0]})", file=sys.stderr)
            sys.exit(1)
        print(f"OK: {len(rows)} cúpulas N1 presentes")
        sys.exit(0)

    created = 0
    for r in rows:
        cat = CATEGORY_SLUG.get(r["category"], "otras")
        d = os.path.join(args.vault, cat, r["id"])
        os.makedirs(d, exist_ok=True)
        f = os.path.join(d, "INDEX.md")
        if os.path.exists(f):
            continue
        with open(f, "w", encoding="utf-8") as fh:
            fh.write(index_content(r))
        created += 1

    # Índices del dome
    os.makedirs(args.vault, exist_ok=True)
    dome_index = os.path.join(args.vault, "INDEX.md")
    with open(dome_index, "w", encoding="utf-8") as fh:
        fh.write(f"""# SaviaDomains

Cúpulas N1 por dominio (Labs L23). Conocimiento público de referencia por
vertical; base neutra para digestión posterior. Generado automáticamente por
`scripts/savia-domains-cupulas.py` ({iso_now()}).

| ID | Categoría | Dominio |
|---|---|---|
""" + "\n".join(
            f"| {r['id']} | {r['category']} | {r['name']} |" for r in rows
        ) + "\n")

    print(f"OK: {created} cúpulas creadas ({len(rows)} dominios en catálogo)")
    sys.exit(0)


if __name__ == "__main__":
    main()
