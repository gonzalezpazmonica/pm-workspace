#!/usr/bin/env python3
"""savia-catalog.py — Local data-asset catalog with lineage (SE-342 S1 / Labs L17).

Registers data assets (dataset -> feature -> model -> report) with a
confidentiality level (N1-N4b) and directed lineage edges, stored in the same
SQLite knowledge-graph DB (scripts/knowledge-graph.py schema), zero egress.

This is the SE-342 S1 POC: adopt/extend decision -- extending the existing
local graph rather than importing a heavy catalog OSS (OpenMetadata/DataHub).
Deterministic, local, CRIT-001.

Usage:
  register --type dataset|feature|model|report --name X --level N1|N2|N3|N4b \
           [--project P] [--source PATH] [--from NAME] [--relation feeds|trained_on|used_in]
  show     --name X [--level N]
  lineage  --name X            (1-hop upstream/downstream)
  list     [--type T] [--level L]

Exit codes: 0 ok | 1 not found | 2 invalid invocation | 3 validation fail
Env: SAVIA_CATALOG_DB (default same kg DB), SAVIA_CATALOG_STRICT=1 (default)
"""

import argparse
import os
import sqlite3
import sys
from pathlib import Path

DEFAULT_DB = Path(os.environ.get(
    "SAVIA_CATALOG_DB",
    os.environ.get("KG_DB", Path.home() / ".savia" / "knowledge-graph.db")))
LEVELS = {"N1", "N2", "N3", "N4b"}
TYPES = {"dataset", "feature", "model", "report"}
RELATIONS = {"feeds", "trained_on", "used_in"}
STRICT = os.environ.get("SAVIA_CATALOG_STRICT", "1") == "1"


def open_db(path) -> sqlite3.Connection:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path))
    conn.row_factory = sqlite3.Row
    conn.executescript("""
    CREATE TABLE IF NOT EXISTS catalog_assets (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        name      TEXT    NOT NULL,
        type      TEXT    NOT NULL,
        level     TEXT    NOT NULL,
        project   TEXT,
        source    TEXT,
        created   TEXT    DEFAULT (datetime('now')),
        UNIQUE(name, type)
    );
    CREATE TABLE IF NOT EXISTS catalog_lineage (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        src_id    INTEGER NOT NULL REFERENCES catalog_assets(id) ON DELETE CASCADE,
        relation  TEXT    NOT NULL,
        dst_id    INTEGER NOT NULL REFERENCES catalog_assets(id) ON DELETE CASCADE,
        created   TEXT    DEFAULT (datetime('now')),
        UNIQUE(src_id, relation, dst_id)
    );
    """)
    return conn


def register(args) -> int:
    if args.type not in TYPES:
        print(f"ERROR: invalid type '{args.type}' ({', '.join(sorted(TYPES))})", file=sys.stderr)
        return 2
    if args.level not in LEVELS:
        print(f"ERROR: invalid level '{args.level}' ({', '.join(sorted(LEVELS))})", file=sys.stderr)
        return 2
    conn = open_db(args.db)
    cur = conn.cursor()
    cur.execute(
        "INSERT OR REPLACE INTO catalog_assets (name,type,level,project,source) VALUES (?,?,?,?,?)",
        (args.name, args.type, args.level, args.project, args.source))
    asset_id = cur.lastrowid
    if args.relation and args.from_name:
        if args.relation not in RELATIONS:
            print(f"ERROR: invalid relation '{args.relation}'", file=sys.stderr)
            conn.close()
            return 2
        cur.execute("SELECT id FROM catalog_assets WHERE name=? AND type=?", (args.from_name, args.from_type or ""))
        row = cur.fetchone()
        if not row:
            print(f"ERROR: source asset '{args.from_name}' not found (create it first)", file=sys.stderr)
            conn.close()
            return 1
        # Level guard: lineage across strict levels is allowed only if levels are compatible.
        cur.execute("SELECT level FROM catalog_assets WHERE id=?", (row["id"],))
        src_level = cur.fetchone()["level"]
        if STRICT and _incompatible(src_level, args.level):
            print(f"ERROR: lineage {src_level} -> {args.level} rejected (strict level guard)", file=sys.stderr)
            conn.close()
            return 3
        cur.execute("INSERT OR REPLACE INTO catalog_lineage (src_id,relation,dst_id) VALUES (?,?,?)",
                    (row["id"], args.relation, asset_id))
    conn.commit()
    print(f"registered: {args.type}:{args.name} (level={args.level})")
    conn.close()
    return 0


def _incompatible(a: str, b: str) -> bool:
    # Simplest strict rule: an asset cannot feed INTO a lower (more sensitive) level lane
    # without explicit intent; forbid N1 -> N3/N4b chains in the POC catalog.
    order = {"N1": 1, "N2": 2, "N3": 3, "N4b": 4}
    return order.get(a, 3) < order.get(b, 3)


def show(args) -> int:
    conn = open_db(args.db)
    name = getattr(args, "name", None)
    atype = getattr(args, "type", None)
    level = getattr(args, "level", None)
    if name:
        rows = conn.execute(
            "SELECT * FROM catalog_assets WHERE name=? AND (?='' OR type=?)",
            (name, atype or "", atype or "")).fetchall()
    else:
        q = "SELECT * FROM catalog_assets WHERE 1=1"
        params = []
        if atype:
            q += " AND type=?"; params.append(atype)
        if level:
            q += " AND level=?"; params.append(level)
        rows = conn.execute(q, params).fetchall()
    if not rows:
        conn.close()
        return 1
    for r in rows:
        print(f"{r['id']}\t{r['name']}\t{r['type']}\t{r['level']}\t{r['project'] or ''}\t{r['source'] or ''}")
    conn.close()
    return 0


def lineage(args) -> int:
    conn = open_db(args.db)
    row = conn.execute(
        "SELECT id,type FROM catalog_assets WHERE name=? AND (?='' OR type=?)",
        (args.name, args.type or "", args.type or "")).fetchone()
    if not row:
        conn.close()
        return 1
    aid = row["id"]
    # Bounded transitive lineage (up to 3 hops), deterministic order by created/id.
    up = conn.execute("""
        WITH RECURSIVE upstream(id, relation, depth) AS (
          SELECT l.src_id, l.relation, 1 FROM catalog_lineage l WHERE l.dst_id=?
          UNION ALL
          SELECT l.src_id, l.relation, u.depth+1 FROM catalog_lineage l
          JOIN upstream u ON l.dst_id=u.id WHERE u.depth<3)
        SELECT DISTINCT a.name,a.type,a.level,u.relation,u.depth
        FROM upstream u JOIN catalog_assets a ON a.id=u.id
        ORDER BY u.depth ASC, a.name ASC""", (aid,)).fetchall()
    down = conn.execute("""
        WITH RECURSIVE downstream(id, relation, depth) AS (
          SELECT l.dst_id, l.relation, 1 FROM catalog_lineage l WHERE l.src_id=?
          UNION ALL
          SELECT l.dst_id, l.relation, d.depth+1 FROM catalog_lineage l
          JOIN downstream d ON l.src_id=d.id WHERE d.depth<3)
        SELECT DISTINCT a.name,a.type,a.level,d.relation,d.depth
        FROM downstream d JOIN catalog_assets a ON a.id=d.id
        ORDER BY d.depth ASC, a.name ASC""", (aid,)).fetchall()
    print(f"lineage: {row['type']}:{args.name}")
    for r in sorted(up, key=lambda x: (x["depth"], x["name"])):
        print(f"  <- {r['relation']:10s} {r['type']}:{r['name']} ({r['level']}) [{r['depth']}hop]")
    for r in sorted(down, key=lambda x: (x["depth"], x["name"])):
        print(f"  -> {r['relation']:10s} {r['type']}:{r['name']} ({r['level']}) [{r['depth']}hop]")
    conn.close()
    return 0


def build_parser():
    p = argparse.ArgumentParser(prog="savia-catalog")
    p.add_argument("--db", default=str(DEFAULT_DB))
    sub = p.add_subparsers(dest="cmd", required=True)

    pr = sub.add_parser("register")
    pr.add_argument("--type", required=True)
    pr.add_argument("--name", required=True)
    pr.add_argument("--level", required=True)
    pr.add_argument("--project")
    pr.add_argument("--source")
    pr.add_argument("--from-name", dest="from_name")
    pr.add_argument("--from-type", dest="from_type")
    pr.add_argument("--relation", choices=sorted(RELATIONS))
    pr.set_defaults(fn=register)

    ps = sub.add_parser("show")
    ps.add_argument("--name")
    ps.add_argument("--type")
    ps.add_argument("--level")
    ps.set_defaults(fn=show)

    pl = sub.add_parser("lineage")
    pl.add_argument("--name", required=True)
    pl.add_argument("--type")
    pl.set_defaults(fn=lineage)

    pls = sub.add_parser("list")
    pls.add_argument("--type")
    pls.add_argument("--level")
    pls.set_defaults(fn=show)
    return p


def main(argv=None) -> int:
    argv = argv if argv is not None else sys.argv[1:]
    if "--version" in argv:
        print("savia-catalog.py 0.1.0 (SE-342 S1 / L17)")
        return 0
    args = build_parser().parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())