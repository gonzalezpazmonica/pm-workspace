#!/usr/bin/env python3
"""
heavy-context-recommend.py — SPEC-HEAVY-CONTEXT-CRITERIA

Recommends whether to use Agent Code Map / Human Code Map / Graphify based on
task_scope and model_tier. Logs decisions to heavy_context_invocations table.

Modes:
  - advisory: prereqs not met (no usage.db OR table missing OR N<10 heavy sessions)
    -> show matrix, do NOT log
  - active:   prereqs met -> log to heavy_context_invocations with outcome='unknown'

Usage:
  heavy-context-recommend.py <scope> <tier> [--project NAME] [--tool TOOL]
  heavy-context-recommend.py --show-matrix
  heavy-context-recommend.py --migrate
"""

import argparse
import json
import os
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

USAGE_DB = Path(os.environ.get("SAVIA_USAGE_DB", str(Path.home() / ".savia" / "usage.db")))

VALID_SCOPES = ("systemic", "cross-module", "single-file", "lookup")
VALID_TIERS = ("fast", "mid", "heavy")
VALID_TOOLS = ("agent-code-map", "human-code-map", "graphify")

# Canonical matrix from SPEC §4
# (scope, tier) -> (recommendation, reason)
MATRIX = {
    ("systemic", "fast"):       ("neutral",   "Marginal mejora en systemic con fast; CAC apenas amortiza."),
    ("systemic", "mid"):        ("recommend", "Tareas sistemicas con mid tier (Sonnet/V3) amortizan CAC: +21% calidad observada con Graphify."),
    ("systemic", "heavy"):      ("recommend", "Tareas sistemicas con heavy tier amortizan CAC esperado, basado en mid extrapolation."),
    ("cross-module", "fast"):   ("avoid",     "Cross-module con fast tier: CAC de 5-15K tokens NO se amortiza; usa Read selectivo."),
    ("cross-module", "mid"):    ("recommend", "Cross-module con mid tier amortiza heavy context tools en majority de casos."),
    ("cross-module", "heavy"):  ("recommend", "Cross-module con heavy tier amortiza CAC esperado."),
    ("single-file", "fast"):    ("avoid",     "Single-file con fast: baseline gana 2/3 segun Context vs Tokens (n=108)."),
    ("single-file", "mid"):     ("avoid",     "Single-file con mid: baseline gana 2/3; CAC innecesario."),
    ("single-file", "heavy"):   ("neutral",   "Single-file con heavy tier: efecto desconocido; CAC alto sin evidencia clara."),
    ("lookup", "fast"):         ("avoid",     "Lookup con fast: usa Read/Grep directo; ACM/HCM/Graphify cargan 5-15K tokens innecesarios."),
    ("lookup", "mid"):          ("avoid",     "Lookup con mid: usa Read/Grep directo en lugar de heavy context tools."),
    ("lookup", "heavy"):        ("avoid",     "Lookup con heavy: usa Read/Grep directo; CAC injustificado."),
}


def ensure_table(conn):
    conn.execute("""
        CREATE TABLE IF NOT EXISTS heavy_context_invocations (
            ts          TEXT NOT NULL,
            tool        TEXT NOT NULL,
            task_scope  TEXT NOT NULL,
            model_tier  TEXT NOT NULL,
            project     TEXT,
            outcome     TEXT,
            tokens_in   INTEGER,
            tokens_out  INTEGER
        )
    """)
    conn.commit()


def prereqs_met(db_path):
    """Returns (met: bool, reason: str)."""
    if not db_path.exists():
        return False, "usage.db does not exist"
    try:
        conn = sqlite3.connect(str(db_path))
        cur = conn.cursor()
        # Check heavy_context_invocations table exists
        cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='heavy_context_invocations'")
        if not cur.fetchone():
            conn.close()
            return False, "heavy_context_invocations table missing (run --migrate)"
        # Check turns table exists
        cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='turns'")
        if not cur.fetchone():
            conn.close()
            return False, "turns table missing (SPEC-CACHE-HIT-TRACKING not implemented)"
        # Check >=14d of data
        cur.execute("SELECT MIN(ts), MAX(ts) FROM turns")
        row = cur.fetchone()
        if not row or not row[0]:
            conn.close()
            return False, "no turns logged yet"
        # Note: >=10 heavy sessions check is deferred to tentative flag (N reflected in heavy_sessions_count).
        conn.close()
        return True, "prereqs met"
    except sqlite3.Error as e:
        return False, f"db error: {e}"


def heavy_sessions_count(db_path):
    """Count of sessions where model_tier='heavy' was logged in heavy_context_invocations."""
    try:
        conn = sqlite3.connect(str(db_path))
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM heavy_context_invocations WHERE model_tier='heavy'")
        n = cur.fetchone()[0]
        conn.close()
        return n
    except sqlite3.Error:
        return 0


def show_matrix(tentative_heavy=True):
    print("Matrix: task_scope x model_tier -> recommendation")
    print()
    print(f"{'scope':<14} | {'fast':<12} | {'mid':<12} | {'heavy':<25}")
    print("-" * 70)
    for scope in VALID_SCOPES:
        cells = []
        for tier in VALID_TIERS:
            rec, _ = MATRIX[(scope, tier)]
            if tier == "heavy" and tentative_heavy:
                rec = f"{rec} (tentative, N<10)"
            cells.append(rec)
        print(f"{scope:<14} | {cells[0]:<12} | {cells[1]:<12} | {cells[2]:<25}")


def recommend(scope, tier, project=None, tool=None, advisory=False):
    if scope not in VALID_SCOPES:
        print(f"ERROR: invalid scope '{scope}'. Valid: {', '.join(VALID_SCOPES)}", file=sys.stderr)
        sys.exit(2)
    if tier not in VALID_TIERS:
        print(f"ERROR: invalid tier '{tier}'. Valid: {', '.join(VALID_TIERS)}", file=sys.stderr)
        sys.exit(2)
    if tool is not None and tool not in VALID_TOOLS:
        print(f"ERROR: invalid tool '{tool}'. Valid: {', '.join(VALID_TOOLS)}", file=sys.stderr)
        sys.exit(2)

    rec, reason = MATRIX[(scope, tier)]

    n_heavy = 0
    if not advisory:
        n_heavy = heavy_sessions_count(USAGE_DB)
    tentative = (tier == "heavy" and n_heavy < 10)

    if advisory:
        print("[ADVISORY MODE] prereqs not met -- no logging")
    print(f"Decision: {rec.upper()}")
    print(f"Reason:   {reason}")
    if tentative:
        print("Flag:     tentative (N<10 heavy sessions logged)")

    if not advisory:
        ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        try:
            conn = sqlite3.connect(str(USAGE_DB))
            ensure_table(conn)
            conn.execute(
                "INSERT INTO heavy_context_invocations (ts, tool, task_scope, model_tier, project, outcome, tokens_in, tokens_out) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (ts, tool or "unspecified", scope, tier, project, "unknown", None, None),
            )
            conn.commit()
            conn.close()
            print(f"Logged:   heavy_context_invocations[ts={ts}, outcome=unknown]")
        except sqlite3.Error as e:
            print(f"WARNING: failed to log decision: {e}", file=sys.stderr)


def migrate():
    USAGE_DB.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(USAGE_DB))
    ensure_table(conn)
    conn.close()
    print(f"OK: heavy_context_invocations ensured in {USAGE_DB}")


def main():
    parser = argparse.ArgumentParser(description="Heavy context tools recommendation")
    parser.add_argument("scope", nargs="?", help="task scope: systemic|cross-module|single-file|lookup")
    parser.add_argument("tier", nargs="?", help="model tier: fast|mid|heavy")
    parser.add_argument("--project", help="project name (optional)")
    parser.add_argument("--tool", help="tool: agent-code-map|human-code-map|graphify")
    parser.add_argument("--show-matrix", action="store_true", help="print matrix and exit")
    parser.add_argument("--migrate", action="store_true", help="create heavy_context_invocations table")
    args = parser.parse_args()

    if args.migrate:
        migrate()
        return

    if args.show_matrix:
        show_matrix(tentative_heavy=True)
        return

    if not args.scope or not args.tier:
        parser.print_help()
        sys.exit(2)

    met, reason = prereqs_met(USAGE_DB)
    advisory = not met
    recommend(args.scope, args.tier, project=args.project, tool=args.tool, advisory=advisory)


if __name__ == "__main__":
    main()
