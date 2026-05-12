#!/usr/bin/env python3
"""flow_to_obsidian.py — Slice 4 of SPEC-AGENTIC-FLOW-GRAPH.

Renders each `.scm/flows/*.flow.yaml` as an Obsidian note with backlinks to
its constituent nodes (commands, agents, skills, hooks, subflows) so the
metacupula visualises the graph natively.

Usage:
  python3 scripts/flow_to_obsidian.py [--out DIR] [FLOW...]

Defaults:
  - When no FLOW given, renders all `.scm/flows/*.flow.yaml`.
  - --out defaults to `output/obsidian/flows/`.
"""
from __future__ import annotations
import argparse
import sys
from pathlib import Path

try:
    import yaml
except ImportError as e:
    print(f"ERROR: missing dep ({e}). Run: source scripts/savia-env.sh", file=sys.stderr)
    sys.exit(3)

REPO_ROOT = Path(__file__).resolve().parent.parent
FLOWS_DIR = REPO_ROOT / ".scm" / "flows"
DEFAULT_OUT = REPO_ROOT / "output" / "obsidian" / "flows"


def backlink_for(node: dict) -> str:
    """Return Obsidian wiki-link target string for a node, by kind."""
    kind = node.get("kind")
    invoke = node.get("invoke", "?")
    if kind == "command":
        name = invoke.lstrip("/")
        return f"[[command-{name}]]"
    if kind == "agent":
        return f"[[agent-{invoke}]]"
    if kind == "skill":
        return f"[[skill-{invoke}]]"
    if kind == "hook":
        return f"[[hook-{invoke}]]"
    if kind == "subflow":
        # invoke is flow_id (without .flow.yaml) by convention
        target = invoke.replace(".flow.yaml", "")
        return f"[[flow-{target}]]"
    return f"[[unknown-{invoke}]]"


def render_flow(flow_path: Path) -> str:
    flow = yaml.safe_load(flow_path.read_text())
    flow_id = flow.get("flow_id", flow_path.stem)
    desc = flow.get("description", "").strip()
    conf = flow.get("confidentiality", "?")
    nodes = flow.get("nodes", [])
    edges = flow.get("edges", [])

    lines: list[str] = []
    lines.append(f"# Flow: {flow_id}")
    lines.append("")
    lines.append(f"**Confidentiality:** {conf}")
    if desc:
        lines.append("")
        lines.append(f"> {desc}")
    lines.append("")
    lines.append(f"**Source:** `{flow_path.relative_to(REPO_ROOT)}`")
    lines.append("")

    # Nodes table with backlinks
    lines.append("## Nodes")
    lines.append("")
    lines.append("| id | kind | invoke | backlink | parallel_group | idempotent |")
    lines.append("|---|---|---|---|---|---|")
    for n in nodes:
        bl = backlink_for(n)
        pg = n.get("parallel_group", "")
        idem = "yes" if n.get("idempotent", False) else ""
        lines.append(f"| `{n['id']}` | {n['kind']} | `{n.get('invoke','')}` | {bl} | {pg} | {idem} |")
    lines.append("")

    # Edges (mermaid)
    lines.append("## Graph")
    lines.append("")
    lines.append("```mermaid")
    lines.append("flowchart TD")
    for n in nodes:
        lines.append(f"  {n['id']}[\"{n['id']}<br/>{n['kind']}\"]")
    for e in edges:
        when = e.get("when")
        label = f"|{when}|" if when else ""
        lines.append(f"  {e['from']} -->{label} {e['to']}")
    lines.append("```")
    lines.append("")

    # Backlinks section (flat list — Obsidian indexes these)
    lines.append("## Backlinks")
    lines.append("")
    seen = set()
    for n in nodes:
        bl = backlink_for(n)
        if bl in seen:
            continue
        seen.add(bl)
        lines.append(f"- {bl}")
    lines.append("")

    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description="Render .flow.yaml files as Obsidian notes")
    ap.add_argument("flows", nargs="*", help="Flow file(s) to render. Default: all in .scm/flows/")
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT, help="Output directory")
    args = ap.parse_args()

    if args.flows:
        targets = []
        for f in args.flows:
            p = Path(f)
            if not p.is_absolute():
                # accept either bare flow_id or path
                if not p.exists():
                    cand = FLOWS_DIR / (f if f.endswith(".flow.yaml") else f"{f}.flow.yaml")
                    if cand.exists():
                        p = cand
            targets.append(p)
    else:
        targets = sorted(FLOWS_DIR.glob("*.flow.yaml"))

    if not targets:
        print("ERROR: no flow files found", file=sys.stderr)
        return 1

    args.out.mkdir(parents=True, exist_ok=True)
    rendered = 0
    for fp in targets:
        if not fp.exists():
            print(f"WARN: {fp} not found, skipping", file=sys.stderr)
            continue
        try:
            md = render_flow(fp)
        except Exception as e:
            print(f"ERROR rendering {fp}: {e}", file=sys.stderr)
            continue
        flow_id = yaml.safe_load(fp.read_text()).get("flow_id", fp.stem)
        out_path = args.out / f"flow-{flow_id}.md"
        out_path.write_text(md)
        try:
            disp = out_path.relative_to(REPO_ROOT)
        except ValueError:
            disp = out_path
        print(f"rendered: {disp}")
        rendered += 1

    try:
        disp_out = args.out.relative_to(REPO_ROOT)
    except ValueError:
        disp_out = args.out
    print(f"\ntotal: {rendered}/{len(targets)} flows rendered to {disp_out}")
    return 0 if rendered > 0 else 1


if __name__ == "__main__":
    sys.exit(main())
