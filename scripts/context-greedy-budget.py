#!/usr/bin/env python3
"""context-greedy-budget.py — SPEC-189: Greedy context budget selection.

Given a context graph (.acm, knowledge-graph.db, JSONL) and a query, returns
the most relevant subgraph that fits a token budget. Uses scoring (PageRank +
TF-IDF + code boost) and greedy selection with neighbor decay.

Pattern inspiration: scoring + greedy budget + neighbor decay observed in
CarlosVallejoRuiz/slurp. This is a stdlib-only re-implementation tailored to
Savia's context formats. No external deps required.

Usage:
    python3 scripts/context-greedy-budget.py <input> <query> [options]

    <input>           Path to .acm | .db | .jsonl | .json file
    <query>           Free-text query string

    --budget N        Token budget (default: 4000)
    --format FMT      markdown | json | jsonl (default: markdown)
    --input-format F  acm | kg-sqlite | jsonl-graph (default: auto-detect)
    --min-score X     Pre-filter threshold (default: 0.15)
    --neighbor-decay D Score multiplier for neighbors (default: 0.7)
    --explain         Print per-node score breakdown table
    --token-counter T heuristic | tiktoken (default: heuristic)

Exit codes:
    0  OK
    2  empty graph
    3  invalid input

References:
    SPEC-189 docs/propuestas/SPEC-189-greedy-context-budget.md
"""
from __future__ import annotations

import argparse
import json
import math
import re
import sqlite3
import sys
from collections import Counter
from pathlib import Path
from typing import Any


# ─────────────────────────────────────────────────────────────────────────────
# Tokenization
# ─────────────────────────────────────────────────────────────────────────────


def tokenize(text: str) -> list[str]:
    """Split text into tokens handling camelCase, snake_case, kebab-case.

    Pipeline:
      1. Insert spaces at camelCase/PascalCase boundaries (preserve original case).
      2. Lowercase + extract alphanumeric runs.
      3. Append the original (pre-split) tokens not already present so compound
         identifiers remain searchable alongside their parts.

    Examples:
        >>> tokenize("calcularPlayerStats")
        ['calcular', 'player', 'stats', 'calcularplayerstats']
        >>> tokenize("XMLParser")
        ['xml', 'parser', 'xmlparser']
        >>> tokenize("auth_flow")
        ['auth', 'flow', 'auth_flow']
    """
    if not text:
        return []
    split = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1 \2", text)
    split = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", split)
    primary = re.findall(r"[a-z0-9]+", split.lower())
    original = re.findall(r"[a-z0-9_]+", text.lower())
    seen = set(primary)
    extras = [t for t in original if t not in seen and t]
    return primary + extras


# ─────────────────────────────────────────────────────────────────────────────
# Scoring
# ─────────────────────────────────────────────────────────────────────────────


def pagerank(
    nodes: list[str],
    edges_out: dict[str, list[str]],
    alpha: float = 0.85,
    max_iter: int = 100,
    tol: float = 1e-6,
) -> dict[str, float]:
    """Power-iteration PageRank without numpy/scipy.

    Handles dangling nodes (no out-edges) by redistributing rank uniformly.

    Args:
        nodes: List of all node ids.
        edges_out: Mapping node_id → list of successor node_ids.
        alpha: Damping factor (default 0.85).
        max_iter: Maximum iterations (default 100).
        tol: Convergence tolerance — stops when L1 delta < N · tol.

    Returns:
        Mapping node_id → rank (sums to ~1.0).
    """
    n = len(nodes)
    if n == 0:
        return {}
    rank: dict[str, float] = {nid: 1.0 / n for nid in nodes}

    out_w: dict[str, int] = {nid: max(1, len(edges_out.get(nid, []))) for nid in nodes}
    dangling = [nid for nid in nodes if not edges_out.get(nid)]

    edges_in: dict[str, list[str]] = {nid: [] for nid in nodes}
    for src, outs in edges_out.items():
        for tgt in outs:
            if tgt in edges_in:
                edges_in[tgt].append(src)

    for _ in range(max_iter):
        prev = dict(rank)
        dangling_sum = alpha * sum(prev[nid] for nid in dangling) / n
        for nid in nodes:
            incoming = sum(prev[u] / out_w[u] for u in edges_in[nid])
            rank[nid] = alpha * incoming + dangling_sum + (1.0 - alpha) / n
        if sum(abs(rank[nid] - prev[nid]) for nid in nodes) < n * tol:
            break
    return rank


def tfidf_scores(docs: dict[str, list[str]], query: str) -> dict[str, float]:
    """Cosine similarity between query and each doc using TF-IDF.

    IDF is smoothed sklearn-style: log((N+1)/(df+1)) + 1, restricted to query
    terms. This avoids building a full vocabulary while remaining correct for
    the retrieval use-case.

    Args:
        docs: Mapping doc_id → list of tokens.
        query: Free-text query string.

    Returns:
        Mapping doc_id → cosine similarity in [0.0, 1.0].
    """
    q_tokens = tokenize(query)
    if not q_tokens or not docs:
        return {nid: 0.0 for nid in docs}

    n = len(docs)
    doc_token_sets = {nid: set(tokens) for nid, tokens in docs.items()}

    idf: dict[str, float] = {}
    for term in set(q_tokens):
        df = sum(1 for tok_set in doc_token_sets.values() if term in tok_set)
        idf[term] = math.log((n + 1) / (df + 1)) + 1

    q_tf = Counter(q_tokens)
    q_vec = {t: (c / len(q_tokens)) * idf[t] for t, c in q_tf.items()}
    q_norm = math.sqrt(sum(v * v for v in q_vec.values()))

    scores: dict[str, float] = {}
    for nid, tokens in docs.items():
        if not tokens:
            scores[nid] = 0.0
            continue
        d_tf = Counter(tokens)
        d_vec = {t: (d_tf[t] / len(tokens)) * idf[t] for t in idf if d_tf[t] > 0}
        d_norm = math.sqrt(sum(v * v for v in d_vec.values()))
        if d_norm == 0.0 or q_norm == 0.0:
            scores[nid] = 0.0
        else:
            dot = sum(q_vec[t] * d_vec[t] for t in d_vec)
            scores[nid] = dot / (q_norm * d_norm)
    return scores


def compute_scores(
    graph: dict[str, Any],
    query: str,
    alpha: float = 0.4,
    beta: float = 0.6,
    code_boost: float = 0.3,
) -> tuple[dict[str, float], dict[str, float], dict[str, float]]:
    """Combine structural (PageRank) and semantic (TF-IDF) scores.

    Score formula:
        final = α · pagerank_normalized + β · tfidf
        if kind == 'code': final = min(1.0, final + 0.3)

    Args:
        graph: Canonical graph dict from an adapter.
        query: Free-text query.
        alpha: Weight for structural component (default 0.4).
        beta: Weight for semantic component (default 0.6).
        code_boost: Additive boost for nodes with kind='code' (default 0.3).

    Returns:
        Tuple of (final, structural, semantic), each mapping node_id → float.
    """
    nodes_dict = graph.get("nodes", {})
    if not nodes_dict:
        return {}, {}, {}

    node_ids = sorted(nodes_dict.keys())
    edges_out = {nid: list(nodes_dict[nid].get("neighbors", [])) for nid in node_ids}

    pr = pagerank(node_ids, edges_out)
    max_pr = max(pr.values()) if pr else 0.0
    pr_norm = {nid: (r / max_pr) if max_pr > 0.0 else 0.0 for nid, r in pr.items()}

    docs = {nid: tokenize(nodes_dict[nid].get("text", "")) for nid in node_ids}
    tfidf = tfidf_scores(docs, query)

    final: dict[str, float] = {}
    for nid in node_ids:
        s = alpha * pr_norm[nid] + beta * tfidf[nid]
        if nodes_dict[nid].get("kind") == "code":
            s = min(1.0, s + code_boost)
        final[nid] = s
    return final, pr_norm, tfidf


# ─────────────────────────────────────────────────────────────────────────────
# Token counting
# ─────────────────────────────────────────────────────────────────────────────


def count_tokens_heuristic(text: str) -> int:
    """Rough estimate: 1 token ≈ 4 characters. No external deps."""
    if not text:
        return 0
    return max(1, (len(text) + 3) // 4)


def count_tokens_tiktoken(text: str) -> int:
    """Token count via tiktoken (cl100k_base). Requires tiktoken installed."""
    try:
        import tiktoken  # type: ignore[import-not-found]
    except ImportError:
        return count_tokens_heuristic(text)
    enc = tiktoken.get_encoding("cl100k_base")
    return len(enc.encode(text))


def make_token_counter(name: str):
    """Factory for token counter; falls back to heuristic if tiktoken missing."""
    if name == "tiktoken":
        return count_tokens_tiktoken
    return count_tokens_heuristic


# ─────────────────────────────────────────────────────────────────────────────
# Greedy budget selection
# ─────────────────────────────────────────────────────────────────────────────


def serialize_node(nid: str, attrs: dict[str, Any]) -> str:
    """Compact text rendering of a node, used for token counting and display."""
    parts = [nid]
    if (label := attrs.get("label")) and label != nid:
        parts.append(str(label))
    if kind := attrs.get("kind"):
        parts.append(f"({kind})")
    if text := attrs.get("text"):
        parts.append(str(text))
    return " ".join(parts)


def select_subgraph(
    graph: dict[str, Any],
    scores: dict[str, float],
    budget: int,
    neighbor_decay: float = 0.7,
    min_score: float = 0.15,
    token_counter=count_tokens_heuristic,
) -> tuple[list[str], dict[str, Any]]:
    """Greedy subgraph selection within a token budget.

    Algorithm:
      1. Pre-filter candidates by min_score.
      2. Compute token cost per candidate (cached).
      3. Loop: pick highest-scoring unprocessed candidate. If it fits, select
         and boost its unprocessed neighbors with score * neighbor_decay.
      4. Stop when budget exhausted or all candidates processed.

    Args:
        graph: Canonical graph dict (must have "nodes").
        scores: Mapping node_id → final score.
        budget: Maximum total tokens.
        neighbor_decay: Multiplier applied to selected node's score, then
            propagated to unprocessed neighbors as a lower bound.
        min_score: Pre-filter threshold.
        token_counter: Callable str → int.

    Returns:
        Tuple of (selected_ids_in_order, stats_dict). Stats contains
        nodes_selected, nodes_total, tokens_used, tokens_budget, coverage_pct.
    """
    nodes_dict = graph.get("nodes", {})
    nodes_total = len(nodes_dict)
    empty_stats = {
        "nodes_selected": 0,
        "nodes_total": nodes_total,
        "tokens_used": 0,
        "tokens_budget": budget,
        "coverage_pct": 0.0,
    }
    if nodes_total == 0 or budget <= 0:
        return [], empty_stats

    candidates = [nid for nid in nodes_dict if scores.get(nid, 0.0) >= min_score]
    if not candidates:
        return [], empty_stats

    token_cost: dict[str, int] = {
        nid: token_counter(serialize_node(nid, nodes_dict[nid])) for nid in candidates
    }
    effective: dict[str, float] = {nid: scores.get(nid, 0.0) for nid in candidates}

    processed: set[str] = set()
    selected: list[str] = []
    tokens_used = 0
    candidate_set = set(candidates)

    while len(processed) < len(candidates):
        # Highest score wins; ties break alphabetically for determinism.
        best = min(
            (nid for nid in candidates if nid not in processed),
            key=lambda nid: (-effective[nid], nid),
        )
        processed.add(best)

        cost = token_cost[best]
        if cost <= budget - tokens_used:
            selected.append(best)
            tokens_used += cost
            boosted = effective[best] * neighbor_decay
            for nbr in nodes_dict[best].get("neighbors", []):
                if (
                    nbr in candidate_set
                    and nbr not in processed
                    and boosted > effective.get(nbr, 0.0)
                ):
                    effective[nbr] = boosted

        if tokens_used >= budget:
            break

    coverage = round(len(selected) / nodes_total * 100, 1) if nodes_total else 0.0
    stats = {
        "nodes_selected": len(selected),
        "nodes_total": nodes_total,
        "tokens_used": tokens_used,
        "tokens_budget": budget,
        "coverage_pct": coverage,
    }
    return selected, stats


# ─────────────────────────────────────────────────────────────────────────────
# Adapters: input format → canonical graph dict
# ─────────────────────────────────────────────────────────────────────────────

# Canonical form:
# {
#   "nodes": {
#     "<id>": {
#       "label": str,
#       "text": str,
#       "kind": str,
#       "neighbors": [<id>, ...],
#       "extra": dict
#     }, ...
#   }
# }


def adapter_acm(path: Path) -> dict[str, Any]:
    """Parse a .acm markdown file into the canonical graph form.

    Each `## Heading` or `### Heading` line becomes a node. Body lines until
    next heading become the node's text. Wikilinks `[[other]]`, `→ Other` and
    `@include other.acm` references in the body become neighbors.
    """
    if not path.exists():
        raise FileNotFoundError(f"ACM file not found: {path}")
    raw = path.read_text(encoding="utf-8", errors="replace")

    nodes: dict[str, dict[str, Any]] = {}
    current_id: str | None = None
    current_body: list[str] = []
    heading_re = re.compile(r"^(#{2,3})\s+(.+?)\s*$")

    def flush() -> None:
        if current_id is None:
            return
        body = "\n".join(current_body).strip()
        nodes[current_id]["text"] = body
        # Detect neighbors
        nbrs: list[str] = []
        for ref in re.findall(r"\[\[([^\]]+)\]\]", body):
            nbrs.append(_slugify(ref))
        for ref in re.findall(r"@include\s+([^\s]+)", body):
            nbrs.append(_slugify(Path(ref).stem))
        for ref in re.findall(r"→\s+([A-Za-z][\w\-]*)", body):
            nbrs.append(_slugify(ref))
        # dedup, preserve order
        seen = set()
        nodes[current_id]["neighbors"] = [
            n for n in nbrs if not (n in seen or seen.add(n))
        ]

    for line in raw.splitlines():
        m = heading_re.match(line)
        if m:
            flush()
            label = m.group(2).strip()
            current_id = _slugify(label)
            nodes[current_id] = {
                "label": label,
                "text": "",
                "kind": "doc",
                "neighbors": [],
            }
            current_body = []
        elif current_id is not None:
            current_body.append(line)
    flush()

    # Fallback: if no headings, whole file is a single node
    if not nodes:
        stem = path.stem or "doc"
        nodes[stem] = {
            "label": stem,
            "text": raw[:2000],
            "kind": "doc",
            "neighbors": [],
        }

    return {"nodes": nodes}


def _slugify(text: str) -> str:
    """Lowercase, alphanumeric+hyphen, collapsed runs."""
    s = re.sub(r"[^a-zA-Z0-9]+", "-", text).strip("-").lower()
    return s or "node"


def adapter_kg_sqlite(path: Path) -> dict[str, Any]:
    """Read a knowledge-graph SQLite DB into the canonical graph form.

    Schema expected (compatible with scripts/knowledge-graph.py — SE-162):
      entities(id INTEGER, name TEXT, type TEXT, description TEXT, ...)
      relations(source_id INTEGER, target_id INTEGER, type TEXT, ...)
    """
    if not path.exists():
        raise FileNotFoundError(f"KG SQLite DB not found: {path}")
    nodes: dict[str, dict[str, Any]] = {}
    conn = sqlite3.connect(str(path))
    try:
        cur = conn.execute("SELECT id, name, type, description FROM entities")
        rows = cur.fetchall()
        for row in rows:
            nid = str(row[0])
            name = row[1] or nid
            kind = row[2] or "entity"
            desc = row[3] or ""
            nodes[nid] = {
                "label": name,
                "text": f"{name} {desc}".strip(),
                "kind": kind,
                "neighbors": [],
            }
        cur = conn.execute("SELECT source_id, target_id FROM relations")
        for src, tgt in cur.fetchall():
            sid, tid = str(src), str(tgt)
            if sid in nodes and tid in nodes:
                nodes[sid]["neighbors"].append(tid)
    finally:
        conn.close()
    return {"nodes": nodes}


def adapter_jsonl_graph(path: Path) -> dict[str, Any]:
    """Parse a JSON or JSONL graph file into the canonical form.

    Accepts:
      - JSON object: {"nodes": [{...}], "edges": [{...}]} or {"nodes": [...], "links": [...]}
        Each node: {"id": str, "label": str?, "type": str?, "description": str?, ...}
        Each edge: {"source": str, "target": str, ...}
      - JSONL: one node per line; edges via "neighbors" inline OR a separate
        block file is NOT supported (single-file format).
    """
    if not path.exists():
        raise FileNotFoundError(f"JSON/JSONL graph not found: {path}")
    raw = path.read_text(encoding="utf-8")
    nodes: dict[str, dict[str, Any]] = {}

    # Try JSON object first; fall back to JSONL on failure (some JSONL lines
    # also start with '{', so the heuristic is "parse whole file as JSON, else
    # treat as one-object-per-line").
    raw_strip = raw.strip()
    if raw_strip.startswith("{"):
        try:
            data = json.loads(raw_strip)
        except json.JSONDecodeError:
            data = None
        if data is not None:
            for node in data.get("nodes", []):
                nid = str(node["id"])
                nodes[nid] = {
                    "label": str(node.get("label", nid)),
                    "text": " ".join(
                        str(node.get(f, "")) for f in ("label", "description", "doc", "summary")
                    ).strip(),
                    "kind": str(node.get("type") or node.get("kind") or "entity"),
                    "neighbors": list(node.get("neighbors", [])),
                }
            edges_key = "edges" if "edges" in data else "links" if "links" in data else None
            if edges_key:
                for edge in data[edges_key]:
                    src, tgt = str(edge["source"]), str(edge["target"])
                    if src in nodes and tgt in nodes and tgt not in nodes[src]["neighbors"]:
                        nodes[src]["neighbors"].append(tgt)
            return {"nodes": nodes}

    # JSONL: one node per line
    for ln, line in enumerate(raw.splitlines(), 1):
        line = line.strip()
        if not line:
            continue
        try:
            node = json.loads(line)
        except json.JSONDecodeError as exc:
            raise ValueError(f"Invalid JSONL at line {ln}: {exc}") from exc
        nid = str(node["id"])
        nodes[nid] = {
            "label": str(node.get("label", nid)),
            "text": str(node.get("text") or node.get("description") or ""),
            "kind": str(node.get("type") or node.get("kind") or "entity"),
            "neighbors": [str(n) for n in node.get("neighbors", [])],
        }
    return {"nodes": nodes}


def auto_detect_adapter(path: Path) -> str:
    """Return adapter name based on file extension."""
    suffix = path.suffix.lower()
    if suffix == ".acm":
        return "acm"
    if suffix in (".db", ".sqlite", ".sqlite3"):
        return "kg-sqlite"
    if suffix in (".jsonl", ".json"):
        return "jsonl-graph"
    return "jsonl-graph"  # default fallback


_ADAPTERS = {
    "acm": adapter_acm,
    "kg-sqlite": adapter_kg_sqlite,
    "jsonl-graph": adapter_jsonl_graph,
}


# ─────────────────────────────────────────────────────────────────────────────
# Output formatters
# ─────────────────────────────────────────────────────────────────────────────


def format_markdown(
    graph: dict[str, Any],
    selected: list[str],
    stats: dict[str, Any],
    scores: dict[str, float],
    query: str,
) -> str:
    lines: list[str] = []
    lines.append(
        f"# Context Subgraph — query: \"{query}\" "
        f"(budget {stats['tokens_budget']:,} tokens)"
    )
    lines.append("")
    lines.append(
        f"Selected {stats['nodes_selected']}/{stats['nodes_total']} nodes · "
        f"{stats['tokens_used']:,}/{stats['tokens_budget']:,} tokens used "
        f"({stats['coverage_pct']}% coverage)"
    )
    lines.append("")
    lines.append("## Selected Nodes")
    lines.append("")
    nodes_dict = graph["nodes"]
    for nid in selected:
        attrs = nodes_dict[nid]
        score = scores.get(nid, 0.0)
        label = attrs.get("label", nid)
        kind = attrs.get("kind", "")
        head = f"### {label}"
        if kind:
            head += f" ({kind})"
        head += f" · score: {score:.3f}"
        lines.append(head)
        if text := attrs.get("text"):
            lines.append(text)
        lines.append("")
    if any(nodes_dict[n].get("neighbors") for n in selected):
        lines.append("## Relationships")
        for nid in selected:
            for nbr in nodes_dict[nid].get("neighbors", []):
                if nbr in selected:
                    lines.append(f"- {nid} → {nbr}")
        lines.append("")
    excluded = stats["nodes_total"] - stats["nodes_selected"]
    if excluded > 0:
        lines.append(f"_{excluded} additional nodes available — increase --budget to include._")
    return "\n".join(lines)


def format_json(
    graph: dict[str, Any],
    selected: list[str],
    stats: dict[str, Any],
    scores: dict[str, float],
    query: str,
) -> str:
    nodes_dict = graph["nodes"]
    out_nodes = []
    for nid in selected:
        attrs = nodes_dict[nid]
        out_nodes.append({
            "id": nid,
            "label": attrs.get("label", nid),
            "kind": attrs.get("kind", ""),
            "text": attrs.get("text", ""),
            "score": round(scores.get(nid, 0.0), 4),
            "neighbors": [n for n in attrs.get("neighbors", []) if n in selected],
        })
    payload = {"query": query, "stats": stats, "nodes": out_nodes}
    return json.dumps(payload, indent=2, ensure_ascii=False)


def format_jsonl(
    graph: dict[str, Any],
    selected: list[str],
    stats: dict[str, Any],
    scores: dict[str, float],
    query: str,
) -> str:
    nodes_dict = graph["nodes"]
    lines: list[str] = []
    # First line: stats meta
    lines.append(json.dumps({"_meta": stats, "query": query}, ensure_ascii=False))
    for nid in selected:
        attrs = nodes_dict[nid]
        lines.append(json.dumps({
            "id": nid,
            "label": attrs.get("label", nid),
            "kind": attrs.get("kind", ""),
            "text": attrs.get("text", ""),
            "score": round(scores.get(nid, 0.0), 4),
            "neighbors": [n for n in attrs.get("neighbors", []) if n in selected],
        }, ensure_ascii=False))
    return "\n".join(lines)


_FORMATTERS = {
    "markdown": format_markdown,
    "json": format_json,
    "jsonl": format_jsonl,
}


def format_explain_table(
    selected: list[str],
    scores: dict[str, float],
    structural: dict[str, float],
    semantic: dict[str, float],
    token_costs: dict[str, int],
) -> str:
    """Render the per-node score breakdown as a plain-text table."""
    if not selected:
        return ""
    lines: list[str] = []
    header = "id".ljust(40) + "score".rjust(10) + "structural".rjust(12) + "semantic".rjust(12) + "tokens".rjust(10)
    lines.append(header)
    lines.append("-" * len(header))
    for nid in selected:
        row = (
            nid.ljust(40)[:40]
            + f"{scores.get(nid, 0.0):.4f}".rjust(10)
            + f"{structural.get(nid, 0.0):.4f}".rjust(12)
            + f"{semantic.get(nid, 0.0):.4f}".rjust(12)
            + str(token_costs.get(nid, 0)).rjust(10)
        )
        lines.append(row)
    return "\n".join(lines)


# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="context-greedy-budget",
        description="Select the most relevant subgraph fitting a token budget. (SPEC-189)",
    )
    p.add_argument("input", help="Path to .acm | .db | .jsonl | .json file")
    p.add_argument("query", help="Free-text query string")
    p.add_argument("--budget", type=int, default=4000, help="Token budget (default: 4000)")
    p.add_argument(
        "--format",
        choices=["markdown", "json", "jsonl"],
        default="markdown",
        help="Output format (default: markdown)",
    )
    p.add_argument(
        "--input-format",
        dest="input_format",
        choices=["acm", "kg-sqlite", "jsonl-graph", "auto"],
        default="auto",
        help="Input format (default: auto-detect by extension)",
    )
    p.add_argument(
        "--min-score",
        type=float,
        default=0.15,
        help="Pre-filter threshold (default: 0.15)",
    )
    p.add_argument(
        "--neighbor-decay",
        type=float,
        default=0.7,
        help="Score multiplier for neighbors (default: 0.7)",
    )
    p.add_argument(
        "--explain",
        action="store_true",
        help="Print per-node score breakdown table after the formatted output",
    )
    p.add_argument(
        "--token-counter",
        choices=["heuristic", "tiktoken"],
        default="heuristic",
        help="Token counter (default: heuristic, 4 chars per token)",
    )
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    in_path = Path(args.input)
    if not in_path.exists():
        print(f"context-greedy-budget: input not found: {in_path}", file=sys.stderr)
        return 3

    fmt = args.input_format if args.input_format != "auto" else auto_detect_adapter(in_path)
    adapter = _ADAPTERS.get(fmt)
    if adapter is None:
        print(f"context-greedy-budget: unknown input format: {fmt}", file=sys.stderr)
        return 3

    try:
        graph = adapter(in_path)
    except (FileNotFoundError, ValueError) as exc:
        print(f"context-greedy-budget: {exc}", file=sys.stderr)
        return 3

    if not graph.get("nodes"):
        print("context-greedy-budget: graph is empty", file=sys.stderr)
        return 2

    counter = make_token_counter(args.token_counter)

    final, structural, semantic = compute_scores(graph, args.query)
    selected, stats = select_subgraph(
        graph,
        final,
        budget=args.budget,
        neighbor_decay=args.neighbor_decay,
        min_score=args.min_score,
        token_counter=counter,
    )

    formatter = _FORMATTERS[args.format]
    output = formatter(graph, selected, stats, final, args.query)
    sys.stdout.write(output)
    if not output.endswith("\n"):
        sys.stdout.write("\n")

    if args.explain:
        token_costs = {
            nid: counter(serialize_node(nid, graph["nodes"][nid])) for nid in selected
        }
        sys.stderr.write("\n")
        sys.stderr.write(format_explain_table(selected, final, structural, semantic, token_costs))
        sys.stderr.write("\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
