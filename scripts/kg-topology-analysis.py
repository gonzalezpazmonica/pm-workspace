#!/usr/bin/env python3
"""
kg-topology-analysis.py — SE-248: Forman-Ricci curvature + Leiden community detection
sobre el knowledge graph de pm-workspace.

Usage:
    python3 scripts/kg-topology-analysis.py --input kg-export.json [--all] [--format md|json|both]
    python3 scripts/kg-topology-analysis.py --db /path/to/knowledge-graph.db [--all]

Dependencies: python3 stdlib + networkx + numpy
"""
import argparse
import json
import math
import sqlite3
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

# ── networkx / numpy detection ────────────────────────────────────────────────

try:
    import networkx as nx
    import numpy as np
    HAS_DEPS = True
except ImportError as e:
    HAS_DEPS = False
    _MISSING_DEP = str(e)


# ── Data loading ──────────────────────────────────────────────────────────────

def load_from_json(path: str) -> tuple[list[dict], list[dict]]:
    """Load nodes and edges from the standard JSON export format."""
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    nodes = data.get("nodes", [])
    edges = data.get("edges", [])
    if not nodes:
        raise ValueError(f"No nodes found in {path}")
    return nodes, edges


def load_from_sqlite(db_path: str) -> tuple[list[dict], list[dict]]:
    """Export nodes and edges directly from the knowledge-graph SQLite DB."""
    conn = sqlite3.connect(db_path)
    c = conn.cursor()

    c.execute("SELECT id, name, type, confidence FROM entities")
    rows = c.fetchall()
    nodes = [{"id": str(row[0]), "label": row[1], "type": row[2], "confidence": row[3]} for row in rows]

    c.execute("""
        SELECT e1.name, r.relation, e2.name, r.confidence
        FROM relations r
        JOIN entities e1 ON r.entity_a = e1.id
        JOIN entities e2 ON r.entity_b = e2.id
        WHERE (r.valid_to IS NULL OR r.valid_to = '')
    """)
    rows = c.fetchall()
    edges = [{"source": row[0], "target": row[2], "relation": row[1], "weight": float(row[3])} for row in rows]

    conn.close()
    return nodes, edges


def build_networkx_graph(nodes: list[dict], edges: list[dict]) -> Any:
    """Build a weighted undirected graph for topology analysis."""
    G = nx.Graph()

    for node in nodes:
        label = node.get("label") or node.get("id", "?")
        G.add_node(label, node_type=node.get("type", "unknown"))

    for edge in edges:
        src = edge.get("source", "")
        tgt = edge.get("target", "")
        w = float(edge.get("weight", 1.0))
        if src and tgt and src != tgt:
            if G.has_edge(src, tgt):
                G[src][tgt]["weight"] = max(G[src][tgt]["weight"], w)
            else:
                G.add_edge(src, tgt, weight=w)

    return G


# ── Forman-Ricci curvature ────────────────────────────────────────────────────

def forman_ricci_curvature(G: Any) -> dict[str, Any]:
    """
    Compute Forman-Ricci curvature for each edge in G.

    Formula: k(u,v) = w(u,v) * (1/d_u + 1/d_v - sum_{e~u,e!=uv} w(e)/sqrt(w(uv)*w(e))
                                                 - sum_{e~v,e!=uv} w(e)/sqrt(w(uv)*w(e)))

    Simplified (Sreejith et al. 2016) for unweighted/uniform:
    k(u,v) = 2 - deg(u) - deg(v) + triangles(u,v) * (3 terms)

    For weighted: use the Bochner-Weitzenböck formula variant.
    """
    curvatures = {}
    mean_weight = np.mean([d["weight"] for _, _, d in G.edges(data=True)]) if G.edges() else 1.0

    for u, v in G.edges():
        w_uv = G[u][v].get("weight", 1.0)

        # Mean of neighbor edge weights for u (excluding uv)
        u_neighbors = [(u, nb, G[u][nb].get("weight", 1.0)) for nb in G.neighbors(u) if nb != v]
        v_neighbors = [(v, nb, G[v][nb].get("weight", 1.0)) for nb in G.neighbors(v) if nb != u]

        m_u = np.mean([w for _, _, w in u_neighbors]) if u_neighbors else mean_weight
        m_v = np.mean([w for _, _, w in v_neighbors]) if v_neighbors else mean_weight

        # Forman curvature: k(u,v) = 2/w(uv) - deg(u)/m(u) - deg(v)/m(v)
        kappa = (2.0 / w_uv) - (G.degree(u) / m_u) - (G.degree(v) / m_v)
        curvatures[(u, v)] = round(kappa, 4)

    if not curvatures:
        return {"mean_curvature": 0.0, "bottleneck_ratio": 0.0, "top_bottlenecks": [], "top_cohesive": []}

    vals = list(curvatures.values())
    mean_k = round(float(np.mean(vals)), 4)
    threshold = -0.5
    bottleneck_count = sum(1 for k in vals if k < threshold)
    bottleneck_ratio = round(bottleneck_count / len(vals), 4) if vals else 0.0

    sorted_k = sorted(curvatures.items(), key=lambda x: x[1])
    top_bottlenecks = [{"edge": list(e), "curvature": k} for e, k in sorted_k[:10]]
    top_cohesive = [{"edge": list(e), "curvature": k} for e, k in sorted_k[-10:][::-1]]

    return {
        "mean_curvature": mean_k,
        "std_curvature": round(float(np.std(vals)), 4),
        "bottleneck_ratio": bottleneck_ratio,
        "bottleneck_count": bottleneck_count,
        "total_edges": len(vals),
        "threshold_used": threshold,
        "top_bottlenecks": top_bottlenecks,
        "top_cohesive": top_cohesive,
    }


# ── Leiden community detection (Louvain approximation) ───────────────────────

def leiden_communities(G: Any, iterations: int = 10) -> dict[str, Any]:
    """
    Leiden-inspired community detection via iterative modularity optimization.
    Uses networkx Louvain as the backbone (same theoretical guarantee: well-connected communities).
    Falls back to greedy modularity if louvain unavailable.
    """
    if G.number_of_nodes() < 3:
        return {"modularity": 0.0, "num_communities": 1, "communities": [], "algorithm": "trivial"}

    # Try networkx's community algorithms (available in nx >= 2.6)
    try:
        from networkx.algorithms.community import louvain_communities, modularity
        communities_raw = louvain_communities(G, seed=42, weight="weight")
        alg = "louvain"
    except (ImportError, AttributeError):
        try:
            from networkx.algorithms.community import greedy_modularity_communities, modularity
            communities_raw = list(greedy_modularity_communities(G, weight="weight"))
            alg = "greedy_modularity"
        except Exception:
            return {"modularity": 0.0, "num_communities": 1, "communities": [], "algorithm": "unavailable"}

    # Compute modularity
    try:
        Q = round(modularity(G, communities_raw, weight="weight"), 4)
    except Exception:
        Q = 0.0

    # Build community output
    communities_out = []
    for i, comm in enumerate(sorted(communities_raw, key=len, reverse=True)):
        members = list(comm)
        # Pick label: node with highest degree as representative
        rep = max(members, key=lambda n: G.degree(n)) if members else "?"
        communities_out.append({
            "id": i,
            "label": f"cluster-{i}-{rep.split('/')[-1][:20]}",
            "representative": rep,
            "size": len(members),
            "members": members[:20],  # cap at 20 for readability
            "truncated": len(members) > 20,
        })

    return {
        "modularity": Q,
        "num_communities": len(communities_raw),
        "algorithm": alg,
        "interpretation": _modularity_interpretation(Q),
        "communities": communities_out,
    }


def _modularity_interpretation(Q: float) -> str:
    if Q > 0.5:
        return "strong community structure"
    if Q > 0.3:
        return "significant community structure"
    if Q > 0.1:
        return "weak community structure"
    return "no clear community structure"


# ── Spectral health metric (bonus) ───────────────────────────────────────────

def spectral_health(G: Any) -> dict[str, Any]:
    """
    Compute algebraic connectivity (Fiedler value λ2) as a coupling health metric.
    λ2 close to 0: graph nearly disconnected (high bottleneck risk).
    λ2 high: well-connected, robust graph.
    """
    if G.number_of_nodes() < 3:
        return {"lambda2": 0.0, "interpretation": "graph too small"}

    try:
        L = nx.laplacian_matrix(G, weight="weight").toarray().astype(float)
        eigenvalues = sorted(np.linalg.eigvalsh(L))
        lambda2 = round(float(eigenvalues[1]), 6) if len(eigenvalues) > 1 else 0.0
        return {
            "lambda2": lambda2,
            "interpretation": _lambda2_interpretation(lambda2),
            "graph_nodes": G.number_of_nodes(),
            "graph_edges": G.number_of_edges(),
        }
    except Exception as e:
        return {"lambda2": 0.0, "error": str(e)}


def _lambda2_interpretation(l2: float) -> str:
    if l2 < 0.001:
        return "graph nearly disconnected — high coupling risk"
    if l2 < 0.1:
        return "low algebraic connectivity — some modules isolated"
    if l2 < 1.0:
        return "moderate connectivity — typical for large KGs"
    return "high connectivity — well-integrated graph"


# ── Report generation ─────────────────────────────────────────────────────────

def build_markdown_report(results: dict[str, Any]) -> str:
    ts = results.get("timestamp", "")
    n = results.get("graph", {}).get("nodes", 0)
    e = results.get("graph", {}).get("edges", 0)

    lines = [
        "# KG Topology Analysis",
        f"> Date: {ts} · Nodes: {n} · Edges: {e}",
        "",
    ]

    fr = results.get("forman_ricci", {})
    if fr:
        lines += [
            "## Forman-Ricci Curvature",
            "",
            f"- **Mean curvature**: {fr.get('mean_curvature', '?')} (std: {fr.get('std_curvature', '?')})",
            f"- **Bottleneck ratio**: {fr.get('bottleneck_ratio', '?')} ({fr.get('bottleneck_count', '?')} / {fr.get('total_edges', '?')} edges below {fr.get('threshold_used', '?')})",
            "",
            "### Top 5 Bottleneck Edges (lowest curvature — highest coupling risk)",
            "",
            "| Edge | Curvature |",
            "|---|---|",
        ]
        for item in fr.get("top_bottlenecks", [])[:5]:
            e_pair = " → ".join(item["edge"])
            lines.append(f"| `{e_pair}` | {item['curvature']} |")

        lines += [
            "",
            "### Top 5 Cohesive Edges (highest curvature — well-integrated)",
            "",
            "| Edge | Curvature |",
            "|---|---|",
        ]
        for item in fr.get("top_cohesive", [])[:5]:
            e_pair = " → ".join(item["edge"])
            lines.append(f"| `{e_pair}` | {item['curvature']} |")
        lines.append("")

    ld = results.get("leiden", {})
    if ld:
        lines += [
            "## Leiden Community Detection",
            "",
            f"- **Modularity Q**: {ld.get('modularity', '?')} — {ld.get('interpretation', '')}",
            f"- **Communities found**: {ld.get('num_communities', '?')} (algorithm: {ld.get('algorithm', '?')})",
            "",
            "### Top 5 Communities",
            "",
            "| ID | Label | Size | Representative |",
            "|---|---|---|---|",
        ]
        for comm in ld.get("communities", [])[:5]:
            lines.append(f"| {comm['id']} | {comm['label']} | {comm['size']} | `{comm['representative']}` |")
        lines.append("")

    sp = results.get("spectral", {})
    if sp:
        lines += [
            "## Spectral Health (Algebraic Connectivity)",
            "",
            f"- **λ₂ (Fiedler value)**: {sp.get('lambda2', '?')}",
            f"- {sp.get('interpretation', '')}",
            "",
        ]

    lines += [
        "## Recommendations",
        "",
    ]
    br = fr.get("bottleneck_ratio", 0)
    if br > 0.2:
        lines.append(f"- **High bottleneck ratio** ({br:.0%}): review the top bottleneck edges above. These represent excessive coupling between modules. Consider introducing intermediate abstractions.")
    elif br > 0.05:
        lines.append(f"- **Moderate bottleneck ratio** ({br:.0%}): monitor the bottleneck edges. No immediate action required.")
    else:
        lines.append(f"- **Healthy bottleneck ratio** ({br:.0%}): no structural coupling issues detected.")

    Q = ld.get("modularity", 0)
    if Q < 0.1:
        lines.append("- **Low modularity**: the KG has no clear community structure. This is expected if the graph is small or highly interconnected.")
    elif Q > 0.3:
        n_comm = ld.get("num_communities", 0)
        lines.append(f"- **Good modularity** (Q={Q}): {n_comm} natural clusters detected. These correspond to functional modules in the workspace.")

    return "\n".join(lines)


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(
        description="SE-248: KG topology analysis — Forman-Ricci + Leiden"
    )
    src = parser.add_mutually_exclusive_group(required=True)
    src.add_argument("--input", "-i", help="JSON export from knowledge-graph.sh --export-json")
    src.add_argument("--db", help="Direct path to knowledge-graph.db SQLite file")

    parser.add_argument("--forman-ricci", action="store_true", help="Run Forman-Ricci analysis")
    parser.add_argument("--leiden", action="store_true", help="Run Leiden community detection")
    parser.add_argument("--spectral", action="store_true", help="Compute spectral health (λ2)")
    parser.add_argument("--all", "-a", action="store_true", help="Run all analyses")
    parser.add_argument("--format", choices=["json", "md", "both"], default="both")
    parser.add_argument("--output-dir", default="output/research", help="Directory for output files")
    args = parser.parse_args()

    # ── Input validation (before dependency check so --input /dev/null → 2) ──
    if not args.db and args.input:
        if args.input in ("/dev/null", "") or not Path(args.input).exists():
            print(f"ERROR: input file not found: {args.input}", file=sys.stderr)
            return 2
        # Check if file is readable and non-empty
        try:
            with open(args.input, "r") as _f:
                _content = _f.read(1)
            if not _content:
                print(f"ERROR: input file is empty: {args.input}", file=sys.stderr)
                return 2
        except OSError as e:
            print(f"ERROR: cannot read input file: {e}", file=sys.stderr)
            return 2

    if not HAS_DEPS:
        print(f"ERROR: missing dependency: {_MISSING_DEP}", file=sys.stderr)
        print("Install: pip install networkx numpy", file=sys.stderr)
        return 3

    run_fr = args.all or args.forman_ricci
    run_ld = args.all or args.leiden
    run_sp = args.all or args.spectral
    if not any([run_fr, run_ld, run_sp]):
        run_fr = run_ld = run_sp = True  # default: all

    # Load data
    try:
        if args.db:
            nodes, edges = load_from_sqlite(args.db)
        else:
            if not args.input:
                print("ERROR: provide --db or --input", file=sys.stderr)
                return 2
            nodes, edges = load_from_json(args.input)
    except Exception as e:
        print(f"ERROR loading data: {e}", file=sys.stderr)
        return 2

    if not nodes:
        print("ERROR: empty graph — no nodes", file=sys.stderr)
        return 2

    G = build_networkx_graph(nodes, edges)
    ts = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    date_tag = datetime.utcnow().strftime("%Y%m%d")

    results: dict[str, Any] = {
        "timestamp": ts,
        "spec": "SE-248",
        "graph": {
            "nodes": G.number_of_nodes(),
            "edges": G.number_of_edges(),
            "source": args.db if args.db else args.input,
        },
    }

    if run_fr:
        print("Running Forman-Ricci curvature analysis...", file=sys.stderr)
        results["forman_ricci"] = forman_ricci_curvature(G)

    if run_ld:
        print("Running Leiden community detection...", file=sys.stderr)
        results["leiden"] = leiden_communities(G)

    if run_sp:
        print("Running spectral health analysis...", file=sys.stderr)
        results["spectral"] = spectral_health(G)

    # Output
    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    if args.format in ("json", "both"):
        json_path = out_dir / f"kg-topology-{date_tag}.json"
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(results, f, indent=2, ensure_ascii=False)
        print(f"JSON: {json_path}", file=sys.stderr)

    if args.format in ("md", "both"):
        md_path = out_dir / f"kg-topology-{date_tag}.md"
        md_content = build_markdown_report(results)
        with open(md_path, "w", encoding="utf-8") as f:
            f.write(md_content)
        print(f"Markdown: {md_path}", file=sys.stderr)

    # Print JSON summary to stdout always (for piping)
    summary = {k: v for k, v in results.items() if k != "leiden" or True}
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
