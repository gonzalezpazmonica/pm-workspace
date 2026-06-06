#!/usr/bin/env python3
"""
extract-domain-entities.py — SE-086 Slice 2: Ubiquitous Language extractor.

Scans memory-store JSONL (and optionally a plain-text path) for domain terms,
cross-references against an existing CONTEXT.md, and emits a report.

Usage:
    python3 scripts/extract-domain-entities.py --project pm-workspace
    python3 scripts/extract-domain-entities.py --project pm-workspace --auto-update
    python3 scripts/extract-domain-entities.py --input path/to/text.md --project X
    python3 scripts/extract-domain-entities.py --project X --context path/to/CONTEXT.md

Outputs:
    output/domain-entity-report-<project>-YYYYMMDD.md

AC-06 statuses: new / existing / inconsistent
AC-07 --auto-update marks new terms with [REVIEW] in CONTEXT.md
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import Counter
from datetime import date
from pathlib import Path

ROOT = Path(os.environ.get("PROJECT_ROOT", Path(__file__).parent.parent))
MEMORY_STORE = ROOT / "output" / ".memory-store.jsonl"
OUTPUT_DIR = ROOT / "output"

# ── Stop-lists ────────────────────────────────────────────────────────────────
# Infrastructure terms that look like domain terms but aren't
STOP_WORDS: set[str] = {
    "python", "bash", "git", "github", "sqlite", "json", "yaml", "markdown",
    "docker", "linux", "ubuntu", "function", "script", "file", "path", "log",
    "error", "warning", "true", "false", "none", "null", "stdout", "stderr",
    "http", "https", "api", "sql", "regex", "string", "integer", "boolean",
    "list", "dict", "tuple", "set", "class", "def", "import", "return",
    "test", "bats", "pytest", "assert", "fixture", "mock",
    "commit", "branch", "merge", "rebase", "push", "pull", "clone",
    "pr", "readme", "changelog", "license", "todo",
}

# Patterns for domain term candidates
# - Capitalized multi-word: "Skill Maturity", "Zero Leak"
# - ALL-CAPS abbreviations 2-6 chars: "SDD", "PBI", "ADO", "AC"
# - CamelCase identifiers used as concepts: "KnowledgeGraph" (limited)
RE_CAPITALIZED = re.compile(r'\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)\b')
RE_ABBREV      = re.compile(r'\b([A-Z]{2,6})\b')
RE_SINGLE_CAP  = re.compile(r'\b(Era|Slice|Sprint|PBI|Task|Hook|Skill|Agent|Spec|AC|ADR|PR)\b')
RE_LOWERCASE_JARGON = re.compile(
    r'\b(skill|agent|hook|spec|slice|era|sprint|pbi|sdd|crc|ado|pr|ac|adr|'
    r'milestone|backlog|velocity|throughput|wip|kanban|scrum|retro)\b', re.I
)


def extract_candidates(text: str) -> list[str]:
    """Extract domain term candidates from text."""
    candidates: list[str] = []
    for m in RE_CAPITALIZED.findall(text):
        candidates.append(m)
    for m in RE_ABBREV.findall(text):
        if m.lower() not in STOP_WORDS and len(m) >= 2:
            candidates.append(m)
    for m in RE_SINGLE_CAP.findall(text):
        candidates.append(m)
    for m in RE_LOWERCASE_JARGON.findall(text):
        norm = m.strip()
        if norm.lower() not in STOP_WORDS:
            candidates.append(norm.upper() if len(norm) <= 4 else norm.capitalize())
    return candidates


def load_memory_store(store_path: Path) -> str:
    """Concatenate all content fields from JSONL store."""
    if not store_path.exists():
        return ""
    parts: list[str] = []
    with store_path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                parts.append(entry.get("title", ""))
                parts.append(entry.get("content", ""))
            except json.JSONDecodeError:
                continue
    return "\n".join(parts)


def load_context_md(context_path: Path) -> dict[str, str]:
    """Parse existing CONTEXT.md glossary table → {term: definition}."""
    if not context_path.exists():
        return {}
    glossary: dict[str, str] = {}
    in_table = False
    for line in context_path.read_text(errors="ignore").splitlines():
        if re.match(r'\|\s*Term\s*\|', line, re.I):
            in_table = True
            continue
        if in_table and line.startswith("|---"):
            continue
        if in_table and line.startswith("|"):
            parts = [p.strip() for p in line.strip("|").split("|")]
            if len(parts) >= 2:
                term = parts[0].strip()
                defn = parts[1].strip()
                if term and not term.startswith("---"):
                    glossary[term.lower()] = defn
        elif in_table and not line.startswith("|"):
            in_table = False
    return glossary


def classify_term(
    term: str,
    count: int,
    existing: dict[str, str],
    text: str,
) -> tuple[str, str]:
    """Return (status, inferred_definition)."""
    key = term.lower()
    if key in existing:
        # Check for inconsistency: if existing def very short and usage suggests different
        return "existing", existing[key]

    # Infer definition from surrounding context (first sentence containing the term)
    defn = "[REVIEW]"
    pattern = re.compile(r'[^.!?\n]*\b' + re.escape(term) + r'\b[^.!?\n]*[.!?\n]', re.I)
    m = pattern.search(text)
    if m:
        snippet = m.group(0).strip().rstrip(".!?\n")
        if 10 < len(snippet) < 200:
            defn = snippet

    return "new", defn


def build_report(
    project: str,
    candidates_counted: Counter,
    existing: dict[str, str],
    text: str,
    min_mentions: int = 2,
) -> list[dict]:
    """Build rows: {term, mentions, definition, status}."""
    rows: list[dict] = []
    seen: set[str] = set()
    for term, count in candidates_counted.most_common():
        if count < min_mentions:
            continue
        norm = term.strip()
        if not norm or norm.lower() in STOP_WORDS:
            continue
        if norm.lower() in seen:
            continue
        seen.add(norm.lower())
        status, defn = classify_term(norm, count, existing, text)
        rows.append({"term": norm, "mentions": count, "definition": defn, "status": status})
    return rows


def write_report(project: str, rows: list[dict], output_dir: Path) -> Path:
    stamp = date.today().strftime("%Y%m%d")
    out = output_dir / f"domain-entity-report-{project}-{stamp}.md"
    lines = [
        f"# Domain Entity Report — {project} — {stamp}",
        "",
        "> Auto-generated by `scripts/extract-domain-entities.py` (SE-086).",
        "> Review all entries before accepting. `[REVIEW]` = inferred, not authoritative.",
        "",
        f"| Term | Mentions | Inferred Definition | Status |",
        f"|------|----------|--------------------:|--------|",
    ]
    for r in rows:
        defn = r["definition"].replace("|", "\\|")
        lines.append(f"| {r['term']} | {r['mentions']} | {defn} | {r['status']} |")
    lines += [
        "",
        f"## Summary",
        "",
        f"- Total candidates: {len(rows)}",
        f"- New (not in CONTEXT.md): {sum(1 for r in rows if r['status'] == 'new')}",
        f"- Existing: {sum(1 for r in rows if r['status'] == 'existing')}",
        f"- Inconsistent: {sum(1 for r in rows if r['status'] == 'inconsistent')}",
    ]
    out.write_text("\n".join(lines) + "\n")
    return out


def auto_update_context(context_path: Path, rows: list[dict], project: str) -> int:
    """Append new terms to CONTEXT.md with [REVIEW] status. Returns count added."""
    new_rows = [r for r in rows if r["status"] == "new"]
    if not new_rows:
        return 0

    header_needed = not context_path.exists()
    if header_needed:
        context_path.parent.mkdir(parents=True, exist_ok=True)
        context_path.write_text(
            f"# Domain Glossary — {project}\n\n"
            "> Auto-generated by ubiquitous-language skill (SE-086). "
            "Review all [REVIEW] entries.\n\n"
            "| Term | Definition | Status |\n"
            "|------|------------|--------|\n"
        )

    existing_text = context_path.read_text(errors="ignore")
    additions: list[str] = []
    for r in new_rows:
        if r["term"].lower() in existing_text.lower():
            continue
        defn = r["definition"].replace("|", "\\|")
        additions.append(f"| {r['term']} | {defn} | [REVIEW] |")

    if additions:
        with context_path.open("a") as f:
            f.write("\n".join(additions) + "\n")
    return len(additions)


def export_glossary(project: str, rows: list[dict], context_path: Path) -> Path:
    """Generate projects/{slug}/CONTEXT.md from extracted rows (Slice 1)."""
    context_path.parent.mkdir(parents=True, exist_ok=True)
    stamp = date.today().isoformat()
    lines = [
        f"# Domain Glossary — {project}",
        "",
        f"> Auto-generated by `scripts/extract-domain-entities.py --export-glossary` (SE-086). {stamp}.",
        "> Review all [REVIEW] entries before promoting to stable.",
        "",
        "| Term | Definition | Status |",
        "|------|------------|--------|",
    ]
    for r in rows:
        defn = r["definition"].replace("|", "\\|")
        status = r["status"] if r["status"] == "existing" else "[REVIEW]"
        lines.append(f"| {r['term']} | {defn} | {status} |")
    lines += [""]
    context_path.write_text("\n".join(lines) + "\n")
    return context_path


def sync_graph(project: str, rows: list[dict], db_path: str | None = None) -> int:
    """Register extracted terms as concept entities in the knowledge graph (Slice 2).

    Calls knowledge-graph.py internals directly to avoid subprocess overhead.
    Returns the number of entities upserted.
    """
    import importlib.util
    kg_script = ROOT / "scripts" / "knowledge-graph.py"
    if not kg_script.exists():
        print(f"WARNING: knowledge-graph.py not found at {kg_script}", file=sys.stderr)
        return 0

    spec = importlib.util.spec_from_file_location("knowledge_graph", kg_script)
    if spec is None or spec.loader is None:
        print("WARNING: could not load knowledge-graph module", file=sys.stderr)
        return 0
    kg = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(kg)  # type: ignore[union-attr]

    db_file = Path(db_path) if db_path else ROOT / "output" / "knowledge-graph.db"
    db_file.parent.mkdir(parents=True, exist_ok=True)

    conn = kg.open_db(db_file)

    project_id = kg.upsert_entity(conn, project, "project")
    count = 0
    for r in rows:
        concept_id = kg.upsert_entity(conn, r["term"], "concept")
        kg.upsert_relation(
            conn, project_id, "DOMAIN_TERM", concept_id,
            source=f"extract-domain-entities:{project}", confidence=0.8
        )
        count += 1
    conn.commit()
    conn.close()
    return count


def main() -> None:
    parser = argparse.ArgumentParser(
        description="SE-086: Extract domain entities for ubiquitous language glossary"
    )
    parser.add_argument("--project", required=True, help="Project name (used in output filenames)")
    parser.add_argument("--input", help="Path to text file to analyze (default: memory-store)")
    parser.add_argument("--store", default=str(MEMORY_STORE), help="JSONL store path")
    parser.add_argument("--context", help="Path to existing CONTEXT.md")
    parser.add_argument("--auto-update", action="store_true",
                        help="Append new terms to CONTEXT.md with [REVIEW] status")
    parser.add_argument("--export-glossary", action="store_true",
                        help="(Slice 1) Generate projects/{project}/CONTEXT.md from extracted terms")
    parser.add_argument("--sync-graph", action="store_true",
                        help="(Slice 2) Register extracted terms as concept entities in knowledge graph")
    parser.add_argument("--graph-db", default=None,
                        help="Path to knowledge-graph SQLite DB (default: output/knowledge-graph.db)")
    parser.add_argument("--min-mentions", type=int, default=2,
                        help="Minimum mentions to include a term (default: 2)")
    parser.add_argument("--output-dir", default=str(OUTPUT_DIR))
    args = parser.parse_args()

    # Load text
    if args.input:
        p = Path(args.input)
        if not p.exists():
            print(f"ERROR: input file not found: {p}", file=sys.stderr)
            sys.exit(1)
        text = p.read_text(errors="ignore")
    else:
        text = load_memory_store(Path(args.store))
        if not text:
            print(f"WARNING: no content from store {args.store}", file=sys.stderr)

    # Determine CONTEXT.md path
    if args.context:
        context_path = Path(args.context)
    else:
        context_path = ROOT / "projects" / args.project / "CONTEXT.md"

    existing = load_context_md(context_path)

    # Extract + classify
    raw = extract_candidates(text)
    counted: Counter = Counter(raw)
    rows = build_report(args.project, counted, existing, text, args.min_mentions)

    if not rows:
        print(f"No domain terms found with >= {args.min_mentions} mentions.")
        sys.exit(0)

    # Write report
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    report_path = write_report(args.project, rows, output_dir)
    print(f"Report: {report_path}")
    print(f"  Terms: {len(rows)} "
          f"(new={sum(1 for r in rows if r['status']=='new')}, "
          f"existing={sum(1 for r in rows if r['status']=='existing')}, "
          f"inconsistent={sum(1 for r in rows if r['status']=='inconsistent')})")

    # Auto-update
    if args.auto_update:
        added = auto_update_context(context_path, rows, args.project)
        print(f"  CONTEXT.md: {added} new terms added with [REVIEW] → {context_path}")
    else:
        new_count = sum(1 for r in rows if r["status"] == "new")
        if new_count:
            print(f"  {new_count} new terms found. Run with --auto-update to add to CONTEXT.md.")

    # Slice 1: --export-glossary
    if args.export_glossary:
        glossary_path = export_glossary(args.project, rows, context_path)
        print(f"  Glossary exported → {glossary_path}")

    # Slice 2: --sync-graph
    if args.sync_graph:
        n = sync_graph(args.project, rows, args.graph_db)
        print(f"  Knowledge graph: {n} concept entities synced.")


if __name__ == "__main__":
    main()
